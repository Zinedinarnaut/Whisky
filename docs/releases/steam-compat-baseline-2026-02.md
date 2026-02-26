# Release Notes: Steam Compatibility Baseline (February 2026)

## Highlights
- Steam now supports a dedicated compatibility Wine runtime path (Wine 11).
- Steam launch handling is more robust for Apple Silicon.
- Steam-launched D3D11 games keep DXVK/DLL override environment when compatibility runtime is active.
- Compatibility runtime launches now avoid forced CEF GPU-disable flags by default, improving client responsiveness.

## New
- Compatibility runtime installer:
  - `scripts/runtime/install_steam_compat_wine.sh`
- Runtime override keys:
  - `steamCompatibilityWineBinaryPath`
  - `steamCompatibilityWineserverBinaryPath`
- New safe-mode override key:
  - `steamForceSafeLaunchFlags`

## Behavior changes
- Steam launched with legacy runtime keeps conservative startup flags and bootstrap compatibility handling.
- Steam launched with compatibility runtime uses a lean arg set unless safe mode is explicitly forced.

## Operator commands
- Install compatibility runtime:
```bash
scripts/runtime/install_steam_compat_wine.sh
```

- Force conservative Steam flags:
```bash
defaults write com.isaacmarovitz.Whisky steamForceSafeLaunchFlags -bool true
```

- Return to lean Steam launch args:
```bash
defaults delete com.isaacmarovitz.Whisky steamForceSafeLaunchFlags
```

- Clear runtime overrides:
```bash
defaults delete com.isaacmarovitz.Whisky steamCompatibilityWineBinaryPath
defaults delete com.isaacmarovitz.Whisky steamCompatibilityWineserverBinaryPath
```

## Known constraints
- Compatibility runtime defaults currently target a fixed upstream archive in the install script.
- Some Steam media decode warnings can still appear in `cef_log.txt` but do not block startup.
