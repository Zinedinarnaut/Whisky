#!/bin/bash
set -eu

usage() {
  echo "usage: $0 [--verify-only] /path/to/Vector.app" >&2
}

verify_only=0
if [ "${1:-}" = "--verify-only" ]; then
  verify_only=1
  shift
fi

bundle_path="${1:-}"
if [ -z "$bundle_path" ]; then
  usage
  exit 2
fi

if [ ! -d "$bundle_path" ]; then
  echo "[vector-thin] Bundle not found: $bundle_path" >&2
  exit 2
fi

info_plist="$bundle_path/Contents/Info.plist"
main_executable_name=""
if [ -f "$info_plist" ]; then
  main_executable_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info_plist" 2>/dev/null || true)
fi
main_executable="$bundle_path/Contents/MacOS/$main_executable_name"

if [ -n "$main_executable_name" ] && [ -f "$main_executable" ]; then
  main_info=$(lipo -info "$main_executable" 2>/dev/null || true)
  if echo "$main_info" | grep -q 'x86_64'; then
    if [ "$verify_only" -eq 1 ]; then
      echo "[vector-thin] Intel slice found in main executable: $main_executable" >&2
      exit 1
    fi
    echo "[vector-thin] Main executable is universal/Intel-capable; leaving embedded slices intact."
    exit 0
  fi
fi

strip_count=0
intel_only_count=0
intel_slice_count=0
changed_bundles_file=$(mktemp "${TMPDIR:-/tmp}/vector-thin-bundles.XXXXXX")
trap 'rm -f "$changed_bundles_file"' EXIT

nearest_code_bundle() {
  path=$1
  while [ "$path" != "/" ] && [ -n "$path" ]; do
    case "$path" in
      *.app|*.appex|*.framework|*.xpc|*.bundle)
        echo "$path"
        return 0
        ;;
    esac
    path=$(dirname "$path")
  done
  return 1
}

record_code_bundle_ancestors() {
  file_path=$1
  path=$(dirname "$file_path")
  while [ "$path" != "/" ] && [ -n "$path" ]; do
    case "$path" in
      *.app|*.appex|*.framework|*.xpc|*.bundle)
        printf '%s\n' "$path" >> "$changed_bundles_file"
        ;;
    esac
    [ "$path" = "$bundle_path" ] && break
    path=$(dirname "$path")
  done
}

while IFS= read -r -d '' file_path; do
  info=$(lipo -info "$file_path" 2>/dev/null || true)
  [ -n "$info" ] || continue

  case "$info" in
    *x86_64*) intel_slice_count=$((intel_slice_count + 1)) ;;
    *) continue ;;
  esac

  if ! echo "$info" | grep -q 'arm64'; then
    echo "[vector-thin] Intel-only Mach-O component: $file_path" >&2
    intel_only_count=$((intel_only_count + 1))
    continue
  fi

  if [ "$verify_only" -eq 1 ]; then
    echo "[vector-thin] Intel slice present: $file_path" >&2
    continue
  fi

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/vector-thin.XXXXXX")
  mode=$(stat -f '%Lp' "$file_path")
  lipo "$file_path" -remove x86_64 -output "$tmp_file"
  chmod "$mode" "$tmp_file"
  mv "$tmp_file" "$file_path"
  record_code_bundle_ancestors "$file_path"
  strip_count=$((strip_count + 1))
done < <(find "$bundle_path" -type f -print0)

if [ "$verify_only" -eq 1 ]; then
  if [ "$intel_only_count" -gt 0 ] || [ "$intel_slice_count" -gt 0 ]; then
    echo "[vector-thin] Found $intel_slice_count Mach-O file(s) with x86_64 slices." >&2
    exit 1
  fi
  echo "[vector-thin] Apple Silicon bundle check passed: no x86_64 Mach-O slices found."
  exit 0
fi

if [ "$intel_only_count" -gt 0 ]; then
  echo "[vector-thin] Refusing to continue with $intel_only_count Intel-only component(s)." >&2
  exit 1
fi

if [ "$strip_count" -eq 0 ]; then
  echo "[vector-thin] No Intel slices found in Apple Silicon bundle."
  exit 0
fi

if [ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ] && command -v codesign >/dev/null 2>&1; then
  identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
  [ -n "$identity" ] || identity="-"
  # Re-sign changed nested bundles deepest-first; Xcode signs the main app after run-script phases.
  sort -u "$changed_bundles_file" | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2- | while IFS= read -r code_bundle; do
    [ "$code_bundle" = "$bundle_path" ] && continue
    codesign --force --sign "$identity" --preserve-metadata=identifier,entitlements,flags --timestamp=none "$code_bundle"
  done
fi

echo "[vector-thin] Removed x86_64 slices from $strip_count embedded Mach-O file(s)."
