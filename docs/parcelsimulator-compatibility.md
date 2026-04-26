# Parcel Simulator Compatibility Notes

This document describes the compatibility workarounds Vector applies for **Parcel Simulator** on Apple Silicon.

## Supported ID

- Steam App ID: `2424010`

## What Vector patches automatically

When Parcel Simulator is detected (direct EXE launch, matching App ID, or Steam install path detection), Vector applies these runtime fixes:

- Uses Parcel-specific executable detection for:
  - `parcel.exe`
  - `parcel-Win64-Shipping.exe`
- Ensures Steam launch options include:
  - `-force-d3d11`
- Applies Parcel-focused DLL override sanitization and then forces:
  - `dxgi`, `d3d11`, `d3d10core`, `d3d9` to `builtin`
  - `nvapi`, `nvapi64` to disabled
- Disables NVAPI flags in environment:
  - `DXVK_ENABLE_NVAPI=0`
  - `PROTON_ENABLE_NVAPI=0`
- Disables Steam overlay drawing for the launch context:
  - `SteamNoOverlayUIDrawing=1`
  - `DISABLE_VK_LAYER_VALVE_steam_overlay=1`

## Steam AppDefaults behavior

On `steam.exe -applaunch` launches, Vector writes per-executable AppDefaults registry overrides for:

- `parcel-Win64-Shipping.exe`
- `parcel.exe`

The AppDefaults patch includes:

- D3D DLL overrides (`builtin`) for `dxgi`, `d3d11`, `d3d10core`, `d3d9`
- Disabled overrides for `nvapi`, `nvapi64`
- Direct3D renderer set to `vulkan` after cleaning stale PCI-related Direct3D values

These are app-scoped, not global.

## Recommended bottle settings

- Runtime: `Auto`
- Graphics backend: `D3DMetal`
- DXVK: `On`
- Force D3D11 compatibility: `On`
- Overlay: disabled
- Active Steam AppID: `2424010`

## Troubleshooting

- `wineserver -k` exit code `1` is normal when no wineserver is running.
- `reg: Unable to find the specified registry value` is normal for idempotent cleanup passes.
