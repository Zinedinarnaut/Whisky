#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Apply Vector-owned Wine patchsets (runtime/Wine/patchsets/vector-*) to a Wine source tree.

Usage:
  scripts/runtime/apply_vector_runtime_patchsets.sh \
    --wine-source <path-to-wine-source> \
    [--patchsets-root <path-to-runtime-patchsets>] \
    [--dry-run] \
    [--reverse]

Examples:
  scripts/runtime/apply_vector_runtime_patchsets.sh \
    --wine-source ~/src/wine \
    --dry-run

  scripts/runtime/apply_vector_runtime_patchsets.sh \
    --wine-source ~/src/wine
USAGE
}

require_dir() {
  local key="$1"
  local dir="$2"
  if [[ -z "$dir" || ! -d "$dir" ]]; then
    echo "Missing or invalid directory for $key: $dir" >&2
    exit 1
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APPLY_SCRIPT="${SCRIPT_DIR}/apply_patchset.sh"

if [[ ! -x "$APPLY_SCRIPT" ]]; then
  echo "Required script is missing or not executable: $APPLY_SCRIPT" >&2
  exit 1
fi

WINE_SOURCE=""
PATCHSETS_ROOT="${REPO_ROOT}/runtime/Wine/patchsets"
DRY_RUN=0
REVERSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wine-source)
      WINE_SOURCE="${2:-}"
      shift 2
      ;;
    --patchsets-root)
      PATCHSETS_ROOT="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --reverse)
      REVERSE=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_dir "--wine-source" "$WINE_SOURCE"
require_dir "--patchsets-root" "$PATCHSETS_ROOT"

PATCHSET_DIRS=()
while IFS= read -r patchset_dir; do
  PATCHSET_DIRS+=("$patchset_dir")
done < <(find "$PATCHSETS_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'vector-*' | sort)
if [[ ${#PATCHSET_DIRS[@]} -eq 0 ]]; then
  echo "No vector-owned patchsets found under $PATCHSETS_ROOT"
  exit 0
fi

echo "Applying ${#PATCHSET_DIRS[@]} Vector patchset(s) to $WINE_SOURCE"
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Mode: dry-run"
fi
if [[ $REVERSE -eq 1 ]]; then
  echo "Mode: reverse (unapply)"
fi

declare -a failed=()

for patchset_dir in "${PATCHSET_DIRS[@]}"; do
  patchset_name="$(basename "$patchset_dir")"
  patch_dir="${patchset_dir}/patches"
  echo
  echo "==> Patchset: ${patchset_name}"

  if [[ ! -d "$patch_dir" ]]; then
    echo "    Skipping (no patches directory): $patch_dir"
    continue
  fi

  cmd=("$APPLY_SCRIPT" --wine-source "$WINE_SOURCE" --patchset-dir "$patch_dir")
  if [[ $DRY_RUN -eq 1 ]]; then
    cmd+=(--dry-run)
  fi
  if [[ $REVERSE -eq 1 ]]; then
    cmd+=(--reverse)
  fi

  if "${cmd[@]}"; then
    echo "    Patchset applied: ${patchset_name}"
  else
    echo "    Patchset failed: ${patchset_name}"
    failed+=("$patchset_name")
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo
  echo "Failed patchsets:"
  for name in "${failed[@]}"; do
    echo "  - $name"
  done
  exit 1
fi

echo
if [[ $REVERSE -eq 1 ]]; then
  echo "All Vector patchsets reversed successfully."
else
  echo "All Vector patchsets applied successfully."
fi
