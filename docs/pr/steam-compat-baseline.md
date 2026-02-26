# PR Summary: Steam Compatibility Runtime Baseline (Wine 11)

## Goal
Stabilize Steam on Apple Silicon while keeping D3D11 games (for example, Raft) launchable through Steam and improving client/runtime responsiveness.

## What changed
- Added Steam-specific Wine runtime override support (Wine 11) via:
  - `VECTOR_WINE_BIN_OVERRIDE`
  - `VECTOR_WINESERVER_BIN_OVERRIDE`
- Added compatibility runtime installer script with SHA-256 validation:
  - `scripts/runtime/install_steam_compat_wine.sh`
- Added one-time Steam htmlcache reset marker flow.
- Preserved bottle graphics env (DXVK and DLL overrides) when Steam is using compatibility runtime so child games keep D3D11 support.
- Changed Steam launch argument policy:
  - Legacy runtime: keep conservative crash-workaround args.
  - Compatibility runtime: default to no forced CEF/GPU-disable args for better responsiveness.
  - Manual override: `defaults write com.isaacmarovitz.Vector steamForceSafeLaunchFlags -bool true`.

## Why
- Steam webhelper failures required runtime and bootstrap hardening.
- Aggressive always-on CEF disable flags can reduce client responsiveness and are not always required with the compatibility runtime.
- Stripping DXVK env for Steam prevented D3D11 initialization in games launched from Steam.

## Validation done
- `swiftlint --strict`
- `cd VectorKit && swift build`
- `xcodebuild -project Vector.xcodeproj -scheme Vector -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
- Manual Steam smoke test (compat runtime, no forced CEF args):
  - Steam started cleanly.
  - `steam.exe` and `steamwebhelper` processes remained alive.
  - `bootstrap_log.txt` confirmed Steam launch with no extra args.
- Manual Raft launch through Steam:
  - Previous D3D11 init error was resolved after preserving DXVK env.

## Rollback knobs
- Force legacy-safe args (if a machine regresses):
  - `defaults write com.isaacmarovitz.Vector steamForceSafeLaunchFlags -bool true`
- Disable forced-safe args again:
  - `defaults delete com.isaacmarovitz.Vector steamForceSafeLaunchFlags`
- Remove compatibility runtime override:
  - `defaults delete com.isaacmarovitz.Vector steamCompatibilityWineBinaryPath`
  - `defaults delete com.isaacmarovitz.Vector steamCompatibilityWineserverBinaryPath`

## Follow-ups
- Move compatibility runtime versioning to signed manifest metadata.
- Add CI coverage for Steam runtime override and launch argument policy.
- Add UI toggle for `steamForceSafeLaunchFlags`.
