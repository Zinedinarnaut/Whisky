#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Generate a managed patchset from CrossOver Wine sources compared to an upstream Wine tree.

Usage:
  scripts/runtime/generate_crossover_patchset.sh \
    --base-wine-source <path-to-upstream-wine-source> \
    --crossover-wine-source <path-to-crossover-sources/wine> \
    --output-dir <output-directory> \
    [--label <patchset-label>] \
    [--version <patchset-version>]

Example:
  scripts/runtime/generate_crossover_patchset.sh \
    --base-wine-source ~/src/wine \
    --crossover-wine-source ~/Downloads/sources/wine \
    --output-dir runtime/Wine/patchsets/crossover-23.7.1 \
    --label crossover \
    --version 23.7.1
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

abs_path() {
  local path="$1"
  if [[ -d "$path" ]]; then
    (cd "$path" && pwd)
  else
    local parent
    parent="$(cd "$(dirname "$path")" && pwd)"
    printf "%s/%s\n" "$parent" "$(basename "$path")"
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_cmd diff
require_cmd find
require_cmd jq
require_cmd shasum
require_cmd sort
require_cmd wc

BASE_SOURCE=""
CROSSOVER_SOURCE=""
OUTPUT_DIR=""
PATCHSET_LABEL="crossover"
PATCHSET_VERSION="unknown"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-wine-source)
      BASE_SOURCE="${2:-}"
      shift 2
      ;;
    --crossover-wine-source)
      CROSSOVER_SOURCE="${2:-}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --label)
      PATCHSET_LABEL="${2:-}"
      shift 2
      ;;
    --version)
      PATCHSET_VERSION="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_dir "--base-wine-source" "$BASE_SOURCE"
require_dir "--crossover-wine-source" "$CROSSOVER_SOURCE"

if [[ -z "$OUTPUT_DIR" ]]; then
  echo "Missing required argument: --output-dir" >&2
  usage
  exit 1
fi

BASE_SOURCE="$(abs_path "$BASE_SOURCE")"
CROSSOVER_SOURCE="$(abs_path "$CROSSOVER_SOURCE")"
OUTPUT_DIR="$(abs_path "$OUTPUT_DIR")"
PATCH_DIR="${OUTPUT_DIR}/patches"
MANIFEST_PATH="${OUTPUT_DIR}/patchset.json"
PATCH_LIST_PATH="${OUTPUT_DIR}/PATCHES.txt"

WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"
rm -rf "$PATCH_DIR"
mkdir -p "$PATCH_DIR"

TOP_LEVEL_LIST="${WORK_DIR}/top-level.txt"
PATCH_ROWS="${WORK_DIR}/patch-rows.tsv"
touch "$PATCH_ROWS"

{
  find "$BASE_SOURCE" -mindepth 1 -maxdepth 1 -print
  find "$CROSSOVER_SOURCE" -mindepth 1 -maxdepth 1 -print
} | sed 's#.*/##' | sort -u > "$TOP_LEVEL_LIST"

patch_index=0
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  case "$name" in
    .git|.github|.DS_Store)
      continue
      ;;
  esac

  base_item="${BASE_SOURCE}/${name}"
  crossover_item="${CROSSOVER_SOURCE}/${name}"
  tmp_patch="${WORK_DIR}/delta.patch"
  rm -f "$tmp_patch"

  set +e
  diff -urN \
    --exclude=.git \
    --exclude=.DS_Store \
    --exclude=*.orig \
    --exclude=*.rej \
    --exclude=*.o \
    --exclude=*.a \
    --exclude=*.so \
    --exclude=*.dylib \
    --exclude=*.dll \
    --exclude=build \
    --exclude=build-* \
    --exclude=obj-* \
    --exclude=node_modules \
    "$base_item" "$crossover_item" > "$tmp_patch"
  diff_status=$?
  set -e

  if [[ $diff_status -eq 0 ]]; then
    continue
  fi

  if [[ $diff_status -gt 1 && ! -s "$tmp_patch" ]]; then
    echo "Diff failed for scope '$name'" >&2
    exit 1
  fi

  if [[ ! -s "$tmp_patch" ]]; then
    continue
  fi

  patch_index=$((patch_index + 1))
  patch_name="$(printf "%04d-%s-%s.patch" "$patch_index" "$PATCHSET_LABEL" "$name" | tr ' /' '--')"
  patch_path="${PATCH_DIR}/${patch_name}"
  mv "$tmp_patch" "$patch_path"

  patch_sha="$(shasum -a 256 "$patch_path" | awk '{print $1}')"
  patch_lines="$(wc -l < "$patch_path" | tr -d ' ')"
  printf "%s\t%s\t%s\t%s\n" "$patch_name" "$patch_sha" "$patch_lines" "$name" >> "$PATCH_ROWS"
done < "$TOP_LEVEL_LIST"

if [[ $patch_index -eq 0 ]]; then
  echo "No source deltas found; empty patchset was generated at ${OUTPUT_DIR}" >&2
fi

PATCH_ARRAY_JSON="${WORK_DIR}/patch-array.json"
echo '[]' > "$PATCH_ARRAY_JSON"
while IFS=$'\t' read -r file sha256 lines scope; do
  [[ -z "$file" ]] && continue
  tmp_json="${WORK_DIR}/patch-array-next.json"
  jq --arg file "$file" \
     --arg sha256 "$sha256" \
     --arg scope "$scope" \
     --argjson lines "$lines" \
     '. + [{"file":$file,"sha256":$sha256,"lineCount":$lines,"scope":$scope}]' \
     "$PATCH_ARRAY_JSON" > "$tmp_json"
  mv "$tmp_json" "$PATCH_ARRAY_JSON"
done < "$PATCH_ROWS"

created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
jq -n \
  --arg label "$PATCHSET_LABEL" \
  --arg version "$PATCHSET_VERSION" \
  --arg createdAt "$created_at" \
  --arg baseSource "$BASE_SOURCE" \
  --arg crossoverSource "$CROSSOVER_SOURCE" \
  --argjson patchCount "$patch_index" \
  --slurpfile patches "$PATCH_ARRAY_JSON" \
  '{
    patchset: {
      label: $label,
      version: $version,
      createdAt: $createdAt,
      baseWineSource: $baseSource,
      crossoverWineSource: $crossoverSource,
      patchCount: $patchCount,
      patches: $patches[0]
    }
  }' > "$MANIFEST_PATH"

{
  echo "# Generated patchset: ${PATCHSET_LABEL} (${PATCHSET_VERSION})"
  echo "# Base source: ${BASE_SOURCE}"
  echo "# CrossOver source: ${CROSSOVER_SOURCE}"
  echo "# Generated at (UTC): ${created_at}"
  echo
  if [[ -s "$PATCH_ROWS" ]]; then
    awk -F '\t' '{printf "%s  sha256=%s  lines=%s  scope=%s\n", $1, $2, $3, $4}' "$PATCH_ROWS"
  else
    echo "No patch files generated."
  fi
} > "$PATCH_LIST_PATH"

echo "Patchset generated:"
echo "  Manifest:  ${MANIFEST_PATH}"
echo "  Patches:   ${PATCH_DIR}"
echo "  Patch list:${PATCH_LIST_PATH}"
echo
echo "Next:"
echo "  scripts/runtime/apply_patchset.sh --wine-source <path> --patchset-dir ${PATCH_DIR} --dry-run"
