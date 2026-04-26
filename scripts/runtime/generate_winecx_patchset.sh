#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Generate a CrossOver-style patchset directly from winecx against upstream Wine.

Usage:
  scripts/runtime/generate_winecx_patchset.sh \
    --output-dir <output-directory> \
    [--wine-ref <upstream-ref>] \
    [--winecx-ref <winecx-ref>] \
    [--version <label-version>]

Defaults:
  --wine-ref master
  --winecx-ref master
  --version auto-from-refs

Example:
  scripts/runtime/generate_winecx_patchset.sh \
    --output-dir runtime/Wine/patchsets/winecx-master \
    --wine-ref wine-9.0 \
    --winecx-ref crossover-wine-24.0.4
USAGE
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_cmd git

OUTPUT_DIR=""
WINE_REF="master"
WINECX_REF="master"
VERSION_LABEL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --wine-ref)
      WINE_REF="${2:-}"
      shift 2
      ;;
    --winecx-ref)
      WINECX_REF="${2:-}"
      shift 2
      ;;
    --version)
      VERSION_LABEL="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$OUTPUT_DIR" ]]; then
  echo "Missing required argument: --output-dir" >&2
  usage
  exit 1
fi

if [[ -z "$VERSION_LABEL" ]]; then
  VERSION_LABEL="${WINECX_REF}-vs-${WINE_REF}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATOR_SCRIPT="${SCRIPT_DIR}/generate_crossover_patchset.sh"
if [[ ! -x "$GENERATOR_SCRIPT" ]]; then
  echo "Required script not found or not executable: $GENERATOR_SCRIPT" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

UPSTREAM_DIR="${WORK_DIR}/wine-upstream"
WINECX_DIR="${WORK_DIR}/winecx"

echo "Cloning upstream Wine (${WINE_REF})..."
git clone --depth=1 --branch "$WINE_REF" https://gitlab.winehq.org/wine/wine.git "$UPSTREAM_DIR"

echo "Cloning winecx (${WINECX_REF})..."
git clone --depth=1 --branch "$WINECX_REF" https://github.com/Gcenx/winecx.git "$WINECX_DIR"

echo "Generating patchset..."
"$GENERATOR_SCRIPT" \
  --base-wine-source "$UPSTREAM_DIR" \
  --crossover-wine-source "$WINECX_DIR" \
  --output-dir "$OUTPUT_DIR" \
  --label "winecx" \
  --version "$VERSION_LABEL"

echo "Done."
