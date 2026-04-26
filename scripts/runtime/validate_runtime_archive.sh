#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Validate runtime archive contents for required Vector runtime tools.

Usage:
  scripts/runtime/validate_runtime_archive.sh \
    --archive <path-to-Libraries.tar.gz|tar.xz|tar>

Options:
  --require-nt-memory-bridge <true|false>   default: true

Checks:
- archive contains Wine runtime binaries
- when required, archive contains vectorvmctl memory bridge tool
USAGE
}

require_file() {
  local key="$1"
  local value="$2"
  if [[ -z "$value" || ! -f "$value" ]]; then
    echo "Missing or invalid file for $key: $value" >&2
    exit 1
  fi
}

truthy() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ARCHIVE=""
REQUIRE_NT_MEMORY_BRIDGE="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --archive)
      ARCHIVE="${2:-}"
      shift 2
      ;;
    --require-nt-memory-bridge)
      REQUIRE_NT_MEMORY_BRIDGE="${2:-true}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_file "--archive" "$ARCHIVE"

if ! command -v tar >/dev/null 2>&1; then
  echo "Missing required command: tar" >&2
  exit 1
fi

TMP_LIST="$(mktemp)"
trap 'rm -f "$TMP_LIST"' EXIT

tar -tf "$ARCHIVE" > "$TMP_LIST"

if [[ ! -s "$TMP_LIST" ]]; then
  echo "Archive appears empty: $ARCHIVE" >&2
  exit 1
fi

if ! grep -Eq '(^|/)Wine/bin/(wine|wine64)$' "$TMP_LIST"; then
  echo "Archive does not include expected Wine binary path (Wine/bin/wine or wine64)." >&2
  exit 1
fi

if truthy "$REQUIRE_NT_MEMORY_BRIDGE"; then
  if ! grep -Eq '(^|/)Wine/bin/(vectorvmctl|vectorvmctl\.exe)$' "$TMP_LIST"; then
    echo "Archive is missing required NT memory bridge binary: Wine/bin/vectorvmctl" >&2
    exit 1
  fi
fi

echo "Runtime archive validation succeeded: $ARCHIVE"
if truthy "$REQUIRE_NT_MEMORY_BRIDGE"; then
  echo "- NT memory bridge tool present"
else
  echo "- NT memory bridge requirement disabled"
fi
