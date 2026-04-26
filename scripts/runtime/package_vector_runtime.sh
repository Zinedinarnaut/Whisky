#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/runtime/package_vector_runtime.sh \
    --runtime-root <path-to-Libraries-or-runtime-root> \
    --output <Libraries.tar.gz> \
    --version <runtime-version> \
    --archive-url <published-archive-url> \
    --wine-version <wine-version> \
    --dxvk-version <dxvk-version> \
    --d3dmetal-version <d3dmetal-version> \
    --winetricks-version <winetricks-version> \
    --wine-mono-version <wine-mono-version> \
    [--vectorvmctl <path-to-vectorvmctl.exe>] \
    [--manifest-output <manifest.json>] \
    [--runtime-channel stable|beta|experimental] \
    [--codesign-identity <identity>]

If --manifest-output is provided, PRIVATE_KEY_B64 must be set so the runtime
manifest can be signed with scripts/runtime/generate_manifest.sh.
USAGE
}

require_arg() {
  local key="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    echo "Missing required argument: $key" >&2
    usage
    exit 1
  fi
}

sha256_file() {
  /usr/bin/shasum -a 256 "$1" | awk '{print $1}'
}

copy_runtime_root() {
  local source_root="$1"
  local stage_root="$2"

  mkdir -p "$stage_root"
  if [[ -d "$source_root/Libraries" ]]; then
    /usr/bin/ditto "$source_root/Libraries" "$stage_root/Libraries"
  elif [[ -d "$source_root/Wine" ]]; then
    mkdir -p "$stage_root/Libraries"
    /usr/bin/ditto "$source_root/Wine" "$stage_root/Libraries/Wine"
  else
    echo "Runtime root must contain Libraries/ or Wine/." >&2
    exit 1
  fi
}

sign_runtime_binaries() {
  local libraries_root="$1"
  local identity="$2"
  [[ -z "$identity" ]] && return 0

  while IFS= read -r -d '' file_path; do
    if /usr/bin/file "$file_path" | grep -q "Mach-O"; then
      /usr/bin/codesign --force --timestamp --options runtime --sign "$identity" "$file_path"
    fi
  done < <(/usr/bin/find "$libraries_root/Wine/bin" -type f -perm -111 -print0 2>/dev/null)
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

RUNTIME_ROOT=""
OUTPUT=""
RUNTIME_VERSION=""
ARCHIVE_URL=""
WINE_VERSION=""
DXVK_VERSION=""
D3DMETAL_VERSION=""
WINETRICKS_VERSION=""
WINE_MONO_VERSION=""
VECTORVMCTL=""
MANIFEST_OUTPUT=""
RUNTIME_CHANNEL="stable"
CODESIGN_IDENTITY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-root)
      RUNTIME_ROOT="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --version)
      RUNTIME_VERSION="$2"
      shift 2
      ;;
    --archive-url)
      ARCHIVE_URL="$2"
      shift 2
      ;;
    --wine-version)
      WINE_VERSION="$2"
      shift 2
      ;;
    --dxvk-version)
      DXVK_VERSION="$2"
      shift 2
      ;;
    --d3dmetal-version)
      D3DMETAL_VERSION="$2"
      shift 2
      ;;
    --winetricks-version)
      WINETRICKS_VERSION="$2"
      shift 2
      ;;
    --wine-mono-version)
      WINE_MONO_VERSION="$2"
      shift 2
      ;;
    --vectorvmctl)
      VECTORVMCTL="$2"
      shift 2
      ;;
    --manifest-output)
      MANIFEST_OUTPUT="$2"
      shift 2
      ;;
    --runtime-channel)
      RUNTIME_CHANNEL="$2"
      shift 2
      ;;
    --codesign-identity)
      CODESIGN_IDENTITY="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_arg "--runtime-root" "$RUNTIME_ROOT"
require_arg "--output" "$OUTPUT"
require_arg "--version" "$RUNTIME_VERSION"
require_arg "--archive-url" "$ARCHIVE_URL"
require_arg "--wine-version" "$WINE_VERSION"
require_arg "--dxvk-version" "$DXVK_VERSION"
require_arg "--d3dmetal-version" "$D3DMETAL_VERSION"
require_arg "--winetricks-version" "$WINETRICKS_VERSION"
require_arg "--wine-mono-version" "$WINE_MONO_VERSION"

STAGE="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/vector-runtime-stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

copy_runtime_root "$RUNTIME_ROOT" "$STAGE"

if [[ -n "$VECTORVMCTL" ]]; then
  require_arg "--vectorvmctl" "$VECTORVMCTL"
  mkdir -p "$STAGE/Libraries/Wine/bin"
  /bin/cp "$VECTORVMCTL" "$STAGE/Libraries/Wine/bin/vectorvmctl.exe"
fi

if [[ ! -x "$STAGE/Libraries/Wine/bin/wine64" ]]; then
  echo "Missing executable Libraries/Wine/bin/wine64 in staged runtime." >&2
  exit 1
fi

if [[ ! -x "$STAGE/Libraries/Wine/bin/wineserver" ]]; then
  echo "Missing executable Libraries/Wine/bin/wineserver in staged runtime." >&2
  exit 1
fi

BUILD_ID="$(/usr/bin/uuidgen)"
CREATED_AT="$(/bin/date -u +"%Y-%m-%dT%H:%M:%SZ")"
VECTORVMCTL_SHA256=""
if [[ -f "$STAGE/Libraries/Wine/bin/vectorvmctl.exe" ]]; then
  VECTORVMCTL_SHA256="$(sha256_file "$STAGE/Libraries/Wine/bin/vectorvmctl.exe")"
fi

cat > "$STAGE/Libraries/VectorRuntimeBuild.json" <<JSON
{
  "schemaVersion": 1,
  "buildID": "$BUILD_ID",
  "createdAt": "$CREATED_AT",
  "runtimeChannel": "$RUNTIME_CHANNEL",
  "version": "$RUNTIME_VERSION",
  "vectorVMCTLSHA256": "$VECTORVMCTL_SHA256"
}
JSON

sign_runtime_binaries "$STAGE/Libraries" "$CODESIGN_IDENTITY"

mkdir -p "$(dirname "$OUTPUT")"
/usr/bin/tar -C "$STAGE" -czf "$OUTPUT" Libraries
ARCHIVE_SHA256="$(sha256_file "$OUTPUT")"

echo "Archive: $OUTPUT"
echo "Archive SHA256: $ARCHIVE_SHA256"
echo "Build ID: $BUILD_ID"
echo "vectorvmctl.exe SHA256: ${VECTORVMCTL_SHA256:-not packaged}"

if [[ -n "$MANIFEST_OUTPUT" ]]; then
  if [[ -z "${PRIVATE_KEY_B64:-}" ]]; then
    echo "PRIVATE_KEY_B64 is required when --manifest-output is used." >&2
    exit 1
  fi
  "$(dirname "$0")/generate_manifest.sh" \
    --output "$MANIFEST_OUTPUT" \
    --version "$RUNTIME_VERSION" \
    --archive-url "$ARCHIVE_URL" \
    --archive-sha256 "$ARCHIVE_SHA256" \
    --wine-version "$WINE_VERSION" \
    --dxvk-version "$DXVK_VERSION" \
    --d3dmetal-version "$D3DMETAL_VERSION" \
    --winetricks-version "$WINETRICKS_VERSION" \
    --wine-mono-version "$WINE_MONO_VERSION" \
    --runtime-channel "$RUNTIME_CHANNEL" \
    --build-id "$BUILD_ID" \
    --created-at "$CREATED_AT" \
    --vectorvmctl-sha256 "$VECTORVMCTL_SHA256"
  echo "Manifest: $MANIFEST_OUTPUT"
fi
