#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK="$REPO_ROOT/scripts/validate_vector_app_architectures.sh"

if [[ ! -x /usr/bin/file || ! -x /usr/bin/lipo ]]; then
  echo "Skipping app architecture tests: file/lipo are unavailable on this host."
  exit 0
fi

TMP_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/vector-app-arch-test.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

write_macho_header() {
  local arch="$1"
  local output="$2"
  mkdir -p "$(dirname "$output")"

  case "$arch" in
    arm64)
      printf '\xcf\xfa\xed\xfe\x0c\x00\x00\x01\x00\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' > "$output"
      ;;
    x86_64)
      printf '\xcf\xfa\xed\xfe\x07\x00\x00\x01\x03\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' > "$output"
      ;;
    *)
      echo "Unsupported fixture architecture: $arch" >&2
      exit 1
      ;;
  esac

  chmod +x "$output"
}

make_app_bundle() {
  local app_path="$1"
  mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Frameworks"
  write_macho_header arm64 "$app_path/Contents/MacOS/Vector"
}

ARM_ONLY_APP="$TMP_DIR/ArmOnly.app"
make_app_bundle "$ARM_ONLY_APP"
"$CHECK" --app "$ARM_ONLY_APP" >/dev/null

UNIVERSAL_APP="$TMP_DIR/Universal.app"
make_app_bundle "$UNIVERSAL_APP"
write_macho_header arm64 "$TMP_DIR/universal-arm64"
write_macho_header x86_64 "$TMP_DIR/universal-x86_64"
/usr/bin/lipo -create "$TMP_DIR/universal-arm64" "$TMP_DIR/universal-x86_64" -output "$UNIVERSAL_APP/Contents/Frameworks/UniversalHelper"
chmod +x "$UNIVERSAL_APP/Contents/Frameworks/UniversalHelper"
if "$CHECK" "$UNIVERSAL_APP" >"$TMP_DIR/universal.out" 2>"$TMP_DIR/universal.err"; then
  echo "Expected universal nested Mach-O with x86_64 slice validation to fail." >&2
  exit 1
fi

if ! grep -q "contains x86_64 slice" "$TMP_DIR/universal.err"; then
  echo "Expected failure output to identify the x86_64 slice." >&2
  cat "$TMP_DIR/universal.err" >&2
  exit 1
fi

INTEL_ONLY_APP="$TMP_DIR/IntelOnlyNested.app"
make_app_bundle "$INTEL_ONLY_APP"
write_macho_header x86_64 "$INTEL_ONLY_APP/Contents/Frameworks/IntelOnlyHelper"

if "$CHECK" --app "$INTEL_ONLY_APP" >"$TMP_DIR/intel-only.out" 2>"$TMP_DIR/intel-only.err"; then
  echo "Expected x86_64-only nested Mach-O validation to fail." >&2
  exit 1
fi

if ! grep -q "x86_64-only" "$TMP_DIR/intel-only.err"; then
  echo "Expected failure output to identify the x86_64-only file." >&2
  cat "$TMP_DIR/intel-only.err" >&2
  exit 1
fi

echo "validate_vector_app_architectures tests passed"
