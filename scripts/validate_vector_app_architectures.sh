#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Validate that every Mach-O file inside Vector.app is Apple-silicon-safe.

Usage:
  scripts/validate_vector_app_architectures.sh --app <path-to-Vector.app>
  scripts/validate_vector_app_architectures.sh <path-to-Vector.app>

Checks:
- walks the app bundle for Mach-O files
- fails when any Mach-O file lacks an arm64 or arm64e slice
- fails when any Mach-O file still contains an x86_64 slice
- reports Intel-only and universal-with-Intel files explicitly, because both can trigger
  macOS Intel component warnings for an Apple Silicon-only app
USAGE
}

require_command() {
  local command_path="$1"
  local command_name="$2"
  if [[ ! -x "$command_path" ]]; then
    echo "Missing required command: $command_name ($command_path)" >&2
    exit 1
  fi
}

has_apple_silicon_slice() {
  local archs=" $1 "
  case "$archs" in
    *" arm64 "*|*" arm64e "*) return 0 ;;
    *) return 1 ;;
  esac
}

arch_failure_reason() {
  local archs=" $1 "
  case "$archs" in
    " x86_64 ") echo "x86_64-only" ;;
    *" x86_64 "*) echo "contains x86_64 slice" ;;
    *) echo "missing arm64/arm64e slice" ;;
  esac
}

relative_to_app() {
  local path="$1"
  echo "${path#"$APP_PATH"/}"
}

APP_PATH=""
VERBOSE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP_PATH="${2:-}"
      shift 2
      ;;
    --verbose)
      VERBOSE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -n "$APP_PATH" ]]; then
        echo "Unexpected extra argument: $1" >&2
        usage
        exit 1
      fi
      APP_PATH="$1"
      shift
      ;;
  esac
done

if [[ -z "$APP_PATH" ]]; then
  echo "Missing required app bundle path." >&2
  usage
  exit 1
fi

APP_PATH="${APP_PATH%/}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle does not exist: $APP_PATH" >&2
  exit 1
fi

require_command "/usr/bin/file" "file"
require_command "/usr/bin/find" "find"
require_command "/usr/bin/lipo" "lipo"
require_command "/usr/bin/mktemp" "mktemp"

FAILURES="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/vector-app-arch-failures.XXXXXX")"
trap 'rm -f "$FAILURES"' EXIT

MACHO_COUNT=0

while IFS= read -r -d '' file_path; do
  file_info="$(/usr/bin/file -b "$file_path" 2>/dev/null || true)"
  case "$file_info" in
    *Mach-O*)
      MACHO_COUNT=$((MACHO_COUNT + 1))
      archs="$(/usr/bin/lipo -archs "$file_path" 2>/dev/null || true)"
      if [[ -z "$archs" ]]; then
        printf '%s\t%s\t%s\n' "$(relative_to_app "$file_path")" "unknown" "unable to read architectures" >> "$FAILURES"
      elif [[ " $archs " == *" x86_64 "* ]]; then
        printf '%s\t%s\t%s\n' "$(relative_to_app "$file_path")" "$archs" "$(arch_failure_reason "$archs")" >> "$FAILURES"
      elif ! has_apple_silicon_slice "$archs"; then
        printf '%s\t%s\t%s\n' "$(relative_to_app "$file_path")" "$archs" "$(arch_failure_reason "$archs")" >> "$FAILURES"
      elif [[ "$VERBOSE" == "true" ]]; then
        echo "OK: $(relative_to_app "$file_path") [$archs]"
      fi
      ;;
  esac
done < <(/usr/bin/find "$APP_PATH" -type f -print0)

if [[ "$MACHO_COUNT" -eq 0 ]]; then
  echo "No Mach-O files found in app bundle: $APP_PATH" >&2
  exit 1
fi

if [[ -s "$FAILURES" ]]; then
  echo "Vector.app architecture validation failed: Intel or non-Apple-Silicon Mach-O files were found." >&2
  while IFS=$'\t' read -r relative_path archs reason; do
    echo "- $relative_path: $archs ($reason)" >&2
  done < "$FAILURES"
  echo "Run the Apple Silicon thinning build phase or replace incompatible bundle components before publishing Vector." >&2
  exit 1
fi

echo "Vector.app architecture validation succeeded: $APP_PATH"
echo "- Mach-O files checked: $MACHO_COUNT"
echo "- Every Mach-O file is Apple Silicon-only"
