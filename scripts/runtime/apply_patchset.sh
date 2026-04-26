#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Apply a patchset directory to a Wine source tree.

Usage:
  scripts/runtime/apply_patchset.sh \
    --wine-source <path-to-wine-source> \
    --patchset-dir <path-to-patches-directory> \
    [--strip <n>] \
    [--dry-run] \
    [--reverse]

Examples:
  scripts/runtime/apply_patchset.sh \
    --wine-source ~/src/wine \
    --patchset-dir runtime/Wine/patchsets/crossover-23.7.1/patches \
    --dry-run

  scripts/runtime/apply_patchset.sh \
    --wine-source ~/src/wine \
    --patchset-dir runtime/Wine/patchsets/crossover-23.7.1/patches
USAGE
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
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

require_cmd find
require_cmd patch
require_cmd sort

WINE_SOURCE=""
PATCHSET_DIR=""
STRIP_LEVEL=1
DRY_RUN=0
REVERSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wine-source)
      WINE_SOURCE="${2:-}"
      shift 2
      ;;
    --patchset-dir)
      PATCHSET_DIR="${2:-}"
      shift 2
      ;;
    --strip)
      STRIP_LEVEL="${2:-}"
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
require_dir "--patchset-dir" "$PATCHSET_DIR"

PATCHES=()
while IFS= read -r patch_path; do
  PATCHES+=("$patch_path")
done < <(find "$PATCHSET_DIR" -maxdepth 1 -type f -name '*.patch' | sort)
if [[ ${#PATCHES[@]} -eq 0 ]]; then
  echo "No .patch files found in ${PATCHSET_DIR}" >&2
  exit 1
fi

echo "Applying ${#PATCHES[@]} patch(es) to: ${WINE_SOURCE}"
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Mode: dry-run"
fi
if [[ $REVERSE -eq 1 ]]; then
  echo "Mode: reverse (unapply)"
fi
echo

declare -a failed_patches=()
applied_count=0

for patch_path in "${PATCHES[@]}"; do
  patch_name="$(basename "$patch_path")"
  echo "==> ${patch_name}"

  cmd=(patch "-p${STRIP_LEVEL}" --directory "$WINE_SOURCE" --input "$patch_path" --batch --forward)
  if [[ $DRY_RUN -eq 1 ]]; then
    cmd+=(--dry-run)
  fi
  if [[ $REVERSE -eq 1 ]]; then
    cmd+=(-R)
  fi

  if "${cmd[@]}"; then
    applied_count=$((applied_count + 1))
    echo "    OK"
  else
    failed_patches+=("$patch_name")
    echo "    FAILED"
  fi
done

echo
echo "Summary:"
echo "  Attempted: ${#PATCHES[@]}"
echo "  Succeeded: ${applied_count}"
echo "  Failed:    ${#failed_patches[@]}"

if [[ ${#failed_patches[@]} -gt 0 ]]; then
  echo
  echo "Failed patches:"
  for patch_name in "${failed_patches[@]}"; do
    echo "  - ${patch_name}"
  done
  exit 1
fi

echo
echo "Patchset completed successfully."
