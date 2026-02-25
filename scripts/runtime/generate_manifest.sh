#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  PRIVATE_KEY_B64=<base64-ed25519-private-key> scripts/runtime/generate_manifest.sh \
    --output <manifest-path> \
    --version <runtime-version> \
    --archive-url <url> \
    --archive-sha256 <sha256> \
    --wine-version <wine-version> \
    --dxvk-version <dxvk-version> \
    --d3dmetal-version <d3dmetal-version> \
    --winetricks-version <winetricks-version> \
    --wine-mono-version <wine-mono-version>
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

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "${PRIVATE_KEY_B64:-}" ]]; then
  echo "PRIVATE_KEY_B64 environment variable is required" >&2
  usage
  exit 1
fi

OUTPUT=""
RUNTIME_VERSION=""
ARCHIVE_URL=""
ARCHIVE_SHA256=""
WINE_VERSION=""
DXVK_VERSION=""
D3DMETAL_VERSION=""
WINETRICKS_VERSION=""
WINE_MONO_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --archive-sha256)
      ARCHIVE_SHA256="$2"
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
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_arg "--output" "$OUTPUT"
require_arg "--version" "$RUNTIME_VERSION"
require_arg "--archive-url" "$ARCHIVE_URL"
require_arg "--archive-sha256" "$ARCHIVE_SHA256"
require_arg "--wine-version" "$WINE_VERSION"
require_arg "--dxvk-version" "$DXVK_VERSION"
require_arg "--d3dmetal-version" "$D3DMETAL_VERSION"
require_arg "--winetricks-version" "$WINETRICKS_VERSION"
require_arg "--wine-mono-version" "$WINE_MONO_VERSION"

mkdir -p "$(dirname "$OUTPUT")"

SIGNATURE=$(PRIVATE_KEY_B64="$PRIVATE_KEY_B64" \
  ARCHIVE_SHA256="$ARCHIVE_SHA256" \
  ARCHIVE_URL="$ARCHIVE_URL" \
  D3DMETAL_VERSION="$D3DMETAL_VERSION" \
  DXVK_VERSION="$DXVK_VERSION" \
  RUNTIME_VERSION="$RUNTIME_VERSION" \
  WINE_MONO_VERSION="$WINE_MONO_VERSION" \
  WINE_VERSION="$WINE_VERSION" \
  WINETRICKS_VERSION="$WINETRICKS_VERSION" \
  swift - <<'SWIFT'
import Foundation
import CryptoKit

let environment = ProcessInfo.processInfo.environment

guard let privateKeyRaw = environment["PRIVATE_KEY_B64"],
      let privateKeyData = Data(base64Encoded: privateKeyRaw),
      let archiveSHA256 = environment["ARCHIVE_SHA256"],
      let archiveURL = environment["ARCHIVE_URL"],
      let d3dMetalVersion = environment["D3DMETAL_VERSION"],
      let dxvkVersion = environment["DXVK_VERSION"],
      let runtimeVersion = environment["RUNTIME_VERSION"],
      let wineMonoVersion = environment["WINE_MONO_VERSION"],
      let wineVersion = environment["WINE_VERSION"],
      let winetricksVersion = environment["WINETRICKS_VERSION"] else {
    fputs("Missing signing input\n", stderr)
    exit(1)
}

let canonicalObject: [String: String] = [
    "archiveSHA256": archiveSHA256,
    "archiveURL": archiveURL,
    "d3dMetalVersion": d3dMetalVersion,
    "dxvkVersion": dxvkVersion,
    "version": runtimeVersion,
    "wineMonoVersion": wineMonoVersion,
    "wineVersion": wineVersion,
    "winetricksVersion": winetricksVersion
]

do {
    let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
    let payload = try JSONSerialization.data(withJSONObject: canonicalObject, options: [.sortedKeys])
    let signature = try privateKey.signature(for: payload)
    print(signature.base64EncodedString())
} catch {
    fputs("Signing failed: \(error)\n", stderr)
    exit(1)
}
SWIFT
)

jq -n --arg version "$RUNTIME_VERSION" \
  --arg archiveURL "$ARCHIVE_URL" \
  --arg archiveSHA256 "$ARCHIVE_SHA256" \
  --arg wineVersion "$WINE_VERSION" \
  --arg dxvkVersion "$DXVK_VERSION" \
  --arg d3dMetalVersion "$D3DMETAL_VERSION" \
  --arg winetricksVersion "$WINETRICKS_VERSION" \
  --arg wineMonoVersion "$WINE_MONO_VERSION" \
  --arg signature "$SIGNATURE" \
  '{manifest:{version:$version,archiveURL:$archiveURL,archiveSHA256:$archiveSHA256,wineVersion:$wineVersion,dxvkVersion:$dxvkVersion,d3dMetalVersion:$d3dMetalVersion,winetricksVersion:$winetricksVersion,wineMonoVersion:$wineMonoVersion},signature:$signature}' > "$OUTPUT"
