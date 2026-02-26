#!/usr/bin/env bash
set -euo pipefail

RUNTIME_VERSION="${RUNTIME_VERSION:-11.0}"
RUNTIME_URL="${RUNTIME_URL:-https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.0/wine-stable-11.0-osx64.tar.xz}"
RUNTIME_SHA256="${RUNTIME_SHA256:-573d43fc4618521148d98ad9c74e63387831827395c014925fdfdc52fe55cb5a}"

APP_SUPPORT_DIR="${HOME}/Library/Application Support/com.isaacmarovitz.Vector"
INSTALL_DIR="${APP_SUPPORT_DIR}/Compatibility/SteamWine"
DEFAULTS_DOMAIN="com.isaacmarovitz.Vector"
DEFAULTS_WINE_KEY="steamCompatibilityWineBinaryPath"
DEFAULTS_WINESERVER_KEY="steamCompatibilityWineserverBinaryPath"

WORK_DIR="$(mktemp -d)"
ARCHIVE_PATH="${WORK_DIR}/wine-stable-${RUNTIME_VERSION}.tar.xz"

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

echo "Downloading Wine ${RUNTIME_VERSION} compatibility runtime..."
curl -L --fail --output "${ARCHIVE_PATH}" "${RUNTIME_URL}"

echo "Verifying archive checksum..."
ACTUAL_SHA256="$(shasum -a 256 "${ARCHIVE_PATH}" | awk '{print $1}')"
if [[ "${ACTUAL_SHA256}" != "${RUNTIME_SHA256}" ]]; then
  echo "Checksum mismatch for ${ARCHIVE_PATH}" >&2
  echo "Expected: ${RUNTIME_SHA256}" >&2
  echo "Actual:   ${ACTUAL_SHA256}" >&2
  exit 1
fi

echo "Installing runtime into ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
tar -xJf "${ARCHIVE_PATH}" -C "${INSTALL_DIR}"

WINE_BIN="$(find "${INSTALL_DIR}" -type f -path "*/Contents/Resources/wine/bin/wine" | head -n 1)"
WINESERVER_BIN="$(find "${INSTALL_DIR}" -type f -path "*/Contents/Resources/wine/bin/wineserver" | head -n 1)"

if [[ -z "${WINE_BIN}" || -z "${WINESERVER_BIN}" ]]; then
  echo "Failed to locate wine binaries in ${INSTALL_DIR}" >&2
  exit 1
fi

defaults write "${DEFAULTS_DOMAIN}" "${DEFAULTS_WINE_KEY}" "${WINE_BIN}"
defaults write "${DEFAULTS_DOMAIN}" "${DEFAULTS_WINESERVER_KEY}" "${WINESERVER_BIN}"

echo "Steam compatibility runtime installed."
echo "Wine binary: ${WINE_BIN}"
echo "Wineserver binary: ${WINESERVER_BIN}"
echo "Restart Vector and launch Steam again."
