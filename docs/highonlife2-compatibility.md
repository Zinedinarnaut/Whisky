# High On Life 2 Compatibility Notes

This document describes the compatibility workarounds Vector applies for **High On Life 2** on Apple Silicon.

## Supported IDs

- Steam App ID: `2069250`
- Legacy App ID (kept for compatibility): `2676880`

## What Vector patches automatically

When High On Life 2 is detected (direct EXE launch, matching App ID, or Steam install path detection), Vector applies these runtime fixes:

- Uses bundled Wine binaries for this title (`wine64` and `wineserver`).
- Forces D3D/DXVK-related DLL overrides to `builtin` for:
  - `dxgi`, `d3d11`, `d3d10core`, `d3d9`, `d3d12`, `d3d12core`
- Disables NVAPI and Streamline/NVIDIA plugin DLLs.
- Keeps AMD FSR runtime DLL overrides at `native,builtin` for:
  - `amd_fidelityfx_upscaler_dx12`
  - `amd_fidelityfx_framegeneration_dx12`
- Installs missing shim DLLs in the game binary folder when needed:
  - `nvngx.dll`, `_nvngx.dll`
  - `amd_fidelityfx_upscaler_dx12.dll`, `amd_fidelityfx_framegeneration_dx12.dll`
- Writes one-time `Engine.ini` overrides under:
  - `drive_c/users/<user>/AppData/Local/HighOnLife2/Saved/Config/Windows/Engine.ini`

## Steam launch behavior

Vector normalizes Steam app-launch arguments:

- Fixes typo `-appluanch` -> `-applaunch`
- If `-applaunch` is present without an app ID, Vector inserts `activeSteamAppID` when available.
- If `-applaunch` has no app ID and no fallback app ID is configured, Vector drops the broken `-applaunch` token and launches Steam normally.

This avoids Steam startup loops caused by incomplete app-launch arguments.

## Recommended bottle settings

- Runtime: `Bundled` (or `Auto` if bundled is selected by policy)
- Graphics backend: `D3DMetal`
- DXVK: `Off` for Steam client process (game-specific overrides still apply)
- Overlay: disabled (`SteamNoOverlayUIDrawing=1`, `DISABLE_VK_LAYER_VALVE_steam_overlay=1`)
- Active Steam AppID: `2069250`

## Troubleshooting

- `wineserver -k` exit code `1` can be normal when no wineserver is running.
- `reg: Unable to find the specified registry value` is normal when cleanup is idempotent and value is already absent.
- If Steam is launched with only `-applaunch`, set `Active Steam AppID` in bottle settings so Vector can complete the launch command.
