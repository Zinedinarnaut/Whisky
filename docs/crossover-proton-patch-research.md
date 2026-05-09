# CrossOver / Proton / Wine Patch Research

Date: 2026-05-09

Scope: public Wine, Proton, CrossOver, DXVK, vkd3d-proton, Winetricks, and launcher/runtime documentation. This document intentionally summarizes public behavior and does not copy proprietary CrossOver code or private compatibility database entries.

## Public Source Baseline

- Proton is a Wine-based Steam compatibility layer with bundled graphics API implementations and reversible runtime config. Its documented switches include `PROTON_USE_WINED3D`, `PROTON_NO_D3D11`, `PROTON_NO_D3D10`, `PROTON_DISABLE_NVAPI`, log/crash paths, and sync toggles. Proton states these are runtime options and do not permanently mutate the prefix.
- CrossOver Mac exposes graphics backend choices as product settings: Auto, DXMT, D3DMetal, DXVK, and WineD3D. CodeWeavers' public changelog shows CrossOver 25 moved to Wine 10.0, vkd3d 1.14, MoltenVK 1.2.10, a per-game settings database, DXMT for D3D11 on macOS, and launcher support for GOG Galaxy and Epic Games Store.
- Wine supports DLL load-order overrides through `WINEDLLOVERRIDES` and winecfg AppDefaults. Wine's docs describe native, builtin, and disabled DLL choices, and Wine passes host shell environment variables into the Windows process environment.
- DXVK is best treated as a D3D9/10/11 DLL override payload plus optional per-game `dxvk.conf`. Public DXVK configuration supports `DXVK_CONFIG_FILE` so Vector can write an app-scoped config file instead of relying on global bottle state.
- vkd3d-proton is the relevant public D3D12-to-Vulkan project on Linux/Proton. Its release notes are useful for pattern matching D3D12 risk, but Vector on macOS should prefer D3DMetal/GPTK-style D3D12 translation when available and use vkd3d findings as diagnosis, not a direct macOS dependency.
- Winetricks is a public source for dependency vocabulary. It explicitly covers missing DLL/runtime installs and lists redistributable verbs such as `vcrun2022`, `vcrun2026`, `winhttp`, `wininet`, `windowscodecs`, `wmp10`, `wmp11`, and `vkd3d`.
- Microsoft documents WebView2 detection and deployment through registry/API checks plus Evergreen bootstrapper or offline installer paths. For launchers using WebView2, Vector should preflight presence and repair missing runtime state rather than injecting opaque browser binaries.
- Steamworks' Proton guidance says EAC and BattlEye support require developer/vendor enablement. It also calls out .NET/WPF launchers, Media Foundation, kernel anti-cheat, and DRM as known Proton compatibility risks. Vector should keep protected-title handling non-mutating unless official support exists.

## Existing Vector Repo Surface

- `docs/proton-style-compatibility.md` already states the right legal boundary: Vector does not run Proton directly on macOS; it catalogs safe upstream patterns, exposes launch/runtime rules through VecPatch, and dry-runs source patchsets before runtime promotion.
- `scripts/runtime/generate_proton_style_patchset.sh` already produces a public-source catalog with dispatch rules and upstream patch metadata for media/auth-style work.
- `scripts/runtime/generate_crossover_patchset.sh` and `scripts/runtime/generate_winecx_patchset.sh` can generate public/comparable patchsets from Wine/winecx sources. These should remain review/diff tooling, not a path to copy proprietary CrossOver-only code.
- `docs/security-and-anticheat.md` already blocks protected multiplayer mutation and defines `trust_class`, `risk_level`, protected policy, and allowed override keys for VecPatch.
- Game notes for Parcel Simulator and High On Life 2 already show safe, app-scoped patterns: D3D DLL override allowlists, disabled NVAPI/NVIDIA shim DLLs, backend selection, one-time config writes, and Steam argument repair.
- Runtime repair surfaces already include launcher dependency repair, media playback repair, runtime DLL mirror validation, WebView2/Microsoft auth repair, and Smart Launch Doctor classification.

## Safe Patch Categories

### 1. Reversible Environment Flags

Safe candidates:

- `DXVK_ENABLE_NVAPI=0`
- `PROTON_ENABLE_NVAPI=0`
- `PROTON_DISABLE_NVAPI=1` when mirroring Proton semantics
- `SteamNoOverlayUIDrawing=1`
- `DISABLE_VK_LAYER_VALVE_steam_overlay=1`
- `DXVK_CONFIG_FILE=<Vector-managed dxvk.conf>`
- `PROTON_LOG=1` or Vector-owned log paths for diagnostics only
- `WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--disable-gpu --disable-gpu-compositing` only for launcher/auth WebView repair profiles

Rules:

- Keep env flags app-scoped or launcher-scoped.
- Do not apply Proton's Linux-only kernel/sync switches as macOS promises.
- Treat diagnostic flags as temporary; do not persist noisy logging without user consent.

### 2. DLL Override Allowlists

Safe single-player/app-scoped allowlist:

- D3D11/DXVK path: `dxgi,d3d11,d3d10core,d3d9=n,b`
- D3D12/D3DMetal path: `dxgi,d3d11,d3d10core,d3d9=b;d3d12,d3d12core=n,b`
- Launcher bootstrap: `version=n,b` only where a known launcher path benefits from native version detection
- Disable NVIDIA-specific paths on Apple Silicon: `nvapi,nvapi64=d`

Rules:

- Prefer Wine AppDefaults per executable over bottle-global DLL overrides.
- Never apply DLL override mutations to `protectedMultiplayer` or `blockedAntiCheat` titles unless signed and officially approved.
- Do not recommend downloading proprietary Windows DLLs except through licensed redistributable/runtime installers.

### 3. Graphics Backend Choices

Safe backend matrix:

- D3D9/10/11 default: DXVK first, D3DMetal or WineD3D fallback depending on title and runtime.
- D3D12 default on macOS: D3DMetal first, DXVK fallback only if the title can run a D3D11 mode.
- Legacy/launcher UI: WineD3D or DXVK with GPU compositing disabled when Chromium/Electron/CEF windows go blank.
- Auto policy: prefer per-title data and launch doctor evidence over global bottle toggles.

Rules:

- Store both primary and fallback backend in VecPatch metadata.
- Include rollback version metadata so a bad backend rule can be reverted.
- Record the observed failure signature that justified backend changes.

### 4. Media Playback and Web/Auth Repair

Safe candidates:

- Preflight Media Foundation risk from logs and executable/module names.
- Repair GStreamer/media compatibility markers already cataloged by Vector's Proton-style media patchset.
- Install/repair legal dependencies through Winetricks verbs or official redistributables.
- Detect WebView2 through documented registry keys/API equivalents in the prefix and repair through the official Evergreen bootstrapper/standalone installer.
- Apply CEF/WebView GPU-disable flags only to launcher/helper processes with known blank-window failures.

Rules:

- Do not ship Windows media DLLs copied from a user system.
- Keep media/auth fixes tied to a repair action and explain what was installed or changed.
- Avoid broad `mmdevapi` or audio stack disables unless a title-specific rule has evidence.

### 5. Launcher Repair Preflights

Safe launcher categories:

- EA App / Origin: version DLL bootstrap, launcher dependency repair, WebView/login preflight.
- Epic Games Launcher: CEF/GPU fallback, prerequisite installer check, overlay/NVAPI suppression.
- Ubisoft Connect: launcher dependency repair and protected-title detection before game launch.
- GOG Galaxy: WebView2/browser runtime preflight, Visual C++/UCRT repair, GPU compositing fallback.
- Battle.net: launcher dependency repair and overlay/NVAPI suppression.

Rules:

- Separate launcher rules from game rules. A launcher rule is not a compatibility claim for every game launched through it.
- If a protected game is detected downstream, protected policy overrides launcher defaults.
- Preserve owned-store launch paths for Steam/Epic/EA/Ubisoft/GOG so auth and entitlement checks remain legitimate.

## VecPatch Rule Recommendations

- Add category rules for Epic Games Launcher, Ubisoft Connect, GOG Galaxy, Battle.net, and generic WebView2/Electron launchers with `trust_class=singlePlayer`, `risk_level=medium`, `fix_ids=["repairLauncherDependencies","repairRuntime","reapplyVecPatch"]`, and explicit doctor hints.
- For launcher category rules, allow only `environment` and, where already proven, `arguments`; do not allow arbitrary DLL override or game executable mutation.
- Keep anti-cheat or protected multiplayer titles as non-mutating block/preflight rules with `official_support_required=true`.
- Include source URLs in changelogs or adjacent docs, not inside rule payloads, to keep manifests compact.

## Sources

- Proton README runtime options: https://github.com/ValveSoftware/Proton
- Steamworks Proton and anti-cheat guidance: https://partner.steamgames.com/doc/steamdeck/proton?l=dutch&language=english
- CrossOver Mac advanced graphics settings: https://support.codeweavers.com/miscellanous/advanced-settings-in-crossover-mac
- CrossOver public changelog: https://www.codeweavers.com/crossover/changelog
- Wine user guide DLL overrides and environment handling: https://mirrors.sau.edu.cn/winehq/wine/docs/en/wineusr-guide.html
- DXVK configuration wiki: https://github.com/doitsujin/dxvk/wiki/Configuration/2a96918251c41d6cc3acc2c66bd3e91befd279e9
- vkd3d-proton releases: https://github.com/HansKristian-Work/vkd3d-proton/releases
- Winetricks README and verb list: https://github.com/Winetricks/winetricks and https://github.com/Winetricks/winetricks/blob/master/files/verbs/all.txt
- Microsoft WebView2 distribution docs: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution
- ULWGL public launcher/protonfixes pattern: https://github.com/GloriousEggroll/ULWGL
