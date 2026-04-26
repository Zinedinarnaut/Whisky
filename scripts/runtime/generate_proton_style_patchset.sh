#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Generate a managed Proton/Wine-GE compatibility patch catalog for Vector.

The generated catalog keeps upstream patches under upstream-patches/ by default.
That makes them inspectable and checksumed without automatically applying them to
VectorKit's Wine tree. Runtime-owned patchsets should be promoted to vector-* only
after a dry-run against the exact Wine source used by the runtime.

Usage:
  scripts/runtime/generate_proton_style_patchset.sh \
    [--source <existing-wine-ge-or-proton-ge-checkout>] \
    [--clone-url <repo-url>] \
    [--branch <branch>] \
    [--output-dir <output-directory>] \
    [--label <patchset-label>] \
    [--version <patchset-version>]

Examples:
  scripts/runtime/generate_proton_style_patchset.sh \
    --source /tmp/vector-wine-ge-scan \
    --output-dir runtime/Wine/patchsets/proton-style-media

  scripts/runtime/generate_proton_style_patchset.sh \
    --clone-url https://github.com/GloriousEggroll/wine-ge-custom.git \
    --branch master
USAGE
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
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

copy_patch_if_present() {
  local source_root="$1"
  local relative_path="$2"
  local output_dir="$3"
  local source_file="${source_root}/${relative_path}"

  if [[ ! -f "$source_file" ]]; then
    echo "Skipping missing upstream patch: ${relative_path}" >&2
    return 0
  fi

  local safe_name
  safe_name="$(printf "%s" "$relative_path" | tr '/ ' '--')"
  local index
  index="$(printf "%04d" "$PATCH_INDEX")"
  local destination="${output_dir}/${index}-${safe_name}"
  cp "$source_file" "$destination"

  local sha lines scope
  sha="$(shasum -a 256 "$destination" | awk '{print $1}')"
  lines="$(wc -l < "$destination" | tr -d ' ')"
  scope="$(dirname "$relative_path")"
  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$(basename "$destination")" "$sha" "$lines" "$scope" "$relative_path" >> "$PATCH_ROWS"
  PATCH_INDEX=$((PATCH_INDEX + 1))
}

write_dispatch_rules() {
  local destination="$1"
  local created_at="$2"
  cat > "$destination" <<JSON
{
  "version": 1,
  "generated_at": "$created_at",
  "changelog": "Bundled Proton-style compatibility rules for media, web auth, and Steam launch recovery.",
  "rules": [
    {
      "id": "proton-style-minecraft-dungeons-media-auth-v1",
      "name": "Proton-style: Minecraft Dungeons media/auth",
      "executable_match": "dungeons-win64-shipping.exe",
      "steam_app_id": "1672970",
      "arguments": "-force-d3d11 -dx11 -d3d11 -cef-disable-gpu -cef-disable-gpu-compositing -cef-disable-accelerated-video-decode -cef-disable-low-latency-dxva -cef-disable-zero-copy-dxgi-video -nosound",
      "environment": {
        "WINEDLLOVERRIDES": "dxgi,d3d11,d3d10core,d3d9=n,b;nvapi,nvapi64=d",
        "DXVK_ENABLE_NVAPI": "0",
        "PROTON_ENABLE_NVAPI": "0",
        "SteamNoOverlayUIDrawing": "1",
        "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
        "VECTOR_PROTON_STYLE_COMPAT": "1",
        "VECTOR_PROTON_MEDIA_SHIMS": "1",
        "VECTOR_MEDIA_FOUNDATION_MODE": "proton-style"
      },
      "enabled": true,
      "channel": "stable",
      "signature": "bundled-proton-style-catalog",
      "changelog": "Routes Steam-owned Minecraft Dungeons through Steam with DX11, CEF GPU fallback, and Proton-style media/auth markers while avoiding broad mmdevapi disable.",
      "priority": 5,
      "rule_version": 1,
      "graphics_backend": "dxvk",
      "fallback_graphics_backend": "wined3d",
      "source": "proton"
    }
  ]
}
JSON
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_cmd find
require_cmd git
require_cmd jq
require_cmd shasum
require_cmd wc

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SOURCE_DIR=""
CLONE_URL="https://github.com/GloriousEggroll/wine-ge-custom.git"
BRANCH="master"
OUTPUT_DIR="${REPO_ROOT}/runtime/Wine/patchsets/proton-style-media"
PATCHSET_LABEL="proton-style-media"
PATCHSET_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE_DIR="${2:-}"
      shift 2
      ;;
    --clone-url)
      CLONE_URL="${2:-}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:-}"
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

WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [[ -z "$SOURCE_DIR" ]]; then
  SOURCE_DIR="${WORK_DIR}/source"
  git clone --depth 1 --filter=blob:none --sparse --branch "$BRANCH" "$CLONE_URL" "$SOURCE_DIR"
  (
    cd "$SOURCE_DIR"
    git sparse-checkout set patches README.md VERSION || git sparse-checkout set patches
  )
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Missing source checkout: $SOURCE_DIR" >&2
  exit 1
fi
SOURCE_DIR="$(abs_path "$SOURCE_DIR")"
OUTPUT_DIR="$(abs_path "$OUTPUT_DIR")"
UPSTREAM_PATCH_DIR="${OUTPUT_DIR}/upstream-patches"
MANIFEST_PATH="${OUTPUT_DIR}/patchset.json"
PATCH_LIST_PATH="${OUTPUT_DIR}/PATCHES.txt"
SOURCES_PATH="${OUTPUT_DIR}/PATCH_SOURCES.md"
RULES_PATH="${OUTPUT_DIR}/dispatch-rules.json"
PATCH_ROWS="${WORK_DIR}/patch-rows.tsv"
touch "$PATCH_ROWS"
PATCH_INDEX=1

rm -rf "$UPSTREAM_PATCH_DIR"
mkdir -p "$UPSTREAM_PATCH_DIR"

CURATED_PATCHES=(
  "patches/wine-hotfixes/staging/windows.networking.connectivity-new-dll/0001-include-Add-windows.networking.connectivity.idl.patch"
  "patches/wine-hotfixes/staging/windows.networking.connectivity-new-dll/0002-include-Add-windows.networking.idl.patch"
  "patches/wine-hotfixes/staging/windows.networking.connectivity-new-dll/0003-windows.networking.connectivity-Add-stub-dll.patch"
  "patches/wine-hotfixes/staging/windows.networking.connectivity-new-dll/0004-windows.networking.connectivity-Implement-IActivatio.patch"
  "patches/wine-hotfixes/staging/windows.networking.connectivity-new-dll/0005-windows.networking.connectivity-Implement-INetworkIn.patch"
  "patches/wine-hotfixes/staging/windows.networking.connectivity-new-dll/0006-windows.networking.connectivity-Registry-DLL.patch"
  "patches/wine-hotfixes/staging/windows.networking.connectivity-new-dll/0007-windows.networking.connectivity-Implement-INetworkIn.patch"
  "patches/wine-hotfixes/staging/windows.networking.connectivity-new-dll/0008-windows.networking.connectivity-IConnectionProfile-G.patch"
  "patches/wine-hotfixes/staging/wininet-Cleanup/0001-wininet-tests-Add-more-tests-for-cookies.patch"
  "patches/wine-hotfixes/staging/wininet-Cleanup/0002-wininet-tests-Test-auth-credential-reusage-with-host.patch"
  "patches/wine-hotfixes/staging/wininet-Cleanup/0003-wininet-tests-Check-cookie-behaviour-when-overriding.patch"
  "patches/wine-hotfixes/staging/wininet-Cleanup/0004-wininet-Strip-filename-if-no-path-is-set-in-cookie.patch"
  "patches/wine-hotfixes/staging/wininet-Cleanup/0005-wininet-Replacing-header-fields-should-fail-if-they-.patch"
  "patches/wine-hotfixes/staging/d3dx11_43-D3DX11CreateTextureFromMemory/0001-d3dx11_43-Implement-D3DX11GetImageInfoFromMemory.patch"
  "patches/wine-hotfixes/staging/d3dx11_43-D3DX11CreateTextureFromMemory/0002-d3dx11_42-Implement-D3DX11CreateTextureFromMemory.patch"
  "patches/wine-hotfixes/staging/xactengine-initial/0001-x3daudio1_7-Create-import-library.patch"
  "patches/game-patches/ffxiv_hydaelyn_intro_playback_fix.patch"
)

for patch in "${CURATED_PATCHES[@]}"; do
  copy_patch_if_present "$SOURCE_DIR" "$patch" "$UPSTREAM_PATCH_DIR"
done

patch_count=$((PATCH_INDEX - 1))
if [[ -z "$PATCHSET_VERSION" ]]; then
  if [[ -f "${SOURCE_DIR}/VERSION" ]]; then
    PATCHSET_VERSION="$(tr -d '\r' < "${SOURCE_DIR}/VERSION" | head -n 1)"
  else
    PATCHSET_VERSION="$BRANCH"
  fi
fi

PATCH_ARRAY_JSON="${WORK_DIR}/patch-array.json"
echo '[]' > "$PATCH_ARRAY_JSON"
while IFS=$'\t' read -r file sha256 lines scope upstream_path; do
  [[ -z "$file" ]] && continue
  tmp_json="${WORK_DIR}/patch-array-next.json"
  jq --arg file "$file" \
     --arg sha256 "$sha256" \
     --arg scope "$scope" \
     --arg upstreamPath "$upstream_path" \
     --argjson lines "$lines" \
     '. + [{"file":$file,"sha256":$sha256,"lineCount":$lines,"scope":$scope,"upstreamPath":$upstreamPath,"status":"cataloged-unapplied"}]' \
     "$PATCH_ARRAY_JSON" > "$tmp_json"
  mv "$tmp_json" "$PATCH_ARRAY_JSON"
done < "$PATCH_ROWS"

created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
jq -n \
  --arg label "$PATCHSET_LABEL" \
  --arg version "$PATCHSET_VERSION" \
  --arg createdAt "$created_at" \
  --arg source "$SOURCE_DIR" \
  --arg cloneUrl "$CLONE_URL" \
  --arg branch "$BRANCH" \
  --argjson patchCount "$patch_count" \
  --slurpfile patches "$PATCH_ARRAY_JSON" \
  '{
    patchset: {
      label: $label,
      version: $version,
      createdAt: $createdAt,
      protonWineSource: $source,
      protonSource: $cloneUrl,
      branch: $branch,
      patchCount: $patchCount,
      autoApply: false,
      promotionNote: "Cataloged only. Promote curated patches into a vector-* patchset after dry-run validation against the active VectorKit Wine source.",
      patches: $patches[0]
    }
  }' > "$MANIFEST_PATH"

{
  echo "# ${PATCHSET_LABEL}"
  echo
  echo "Version: ${PATCHSET_VERSION}"
  echo "Source: ${SOURCE_DIR}"
  echo "Generated: ${created_at}"
  echo
  echo "These patches are cataloged, not auto-applied. Validate against VectorKit Wine before promotion."
  echo
  if [[ -s "$PATCH_ROWS" ]]; then
    while IFS=$'\t' read -r file sha256 lines scope upstream_path; do
      [[ -z "$file" ]] && continue
      echo "- ${file} (${lines} lines, ${scope})"
      echo "  - upstream: ${upstream_path}"
      echo "  - sha256: ${sha256}"
    done < "$PATCH_ROWS"
  else
    echo "No curated upstream patches were found in the source checkout."
  fi
} > "$PATCH_LIST_PATH"

cat > "$SOURCES_PATH" <<MD
# Proton-Style Patch Sources

Vector catalogs these upstream compatibility patches so they can be reviewed,
checksummed, and promoted intentionally. They are not applied by

automation until copied into a validated vector-* runtime patchset.

Primary source: ${CLONE_URL}
Branch: ${BRANCH}
Version: ${PATCHSET_VERSION}

This catalog focuses on:
- Media Foundation and web-auth-adjacent plumbing
- Windows networking connectivity stubs used by modern launch/auth flows
- WinINet cleanup patches used by Wine-GE
- D3DX11 texture-from-memory fixes
- XAudio/X3DAudio import-library coverage
MD

write_dispatch_rules "$RULES_PATH" "$created_at"

echo "Generated Proton-style patch catalog at ${OUTPUT_DIR}"
echo "Cataloged upstream patches: ${patch_count}"
echo "Dispatch rules: ${RULES_PATH}"
