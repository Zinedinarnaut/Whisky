<div align="center">

# Vector

A native macOS bottle manager for running Windows games and apps on Apple Silicon.

[![Build](https://github.com/Zinedinarnaut/Whisky/actions/workflows/Build.yml/badge.svg)](https://github.com/Zinedinarnaut/Whisky/actions/workflows/Build.yml)
[![SwiftLint](https://github.com/Zinedinarnaut/Whisky/actions/workflows/SwiftLint.yml/badge.svg)](https://github.com/Zinedinarnaut/Whisky/actions/workflows/SwiftLint.yml)
[![Runtime Channel](https://github.com/Zinedinarnaut/Whisky/actions/workflows/RuntimeChannel.yml/badge.svg)](https://github.com/Zinedinarnaut/Whisky/actions/workflows/RuntimeChannel.yml)

</div>

---

## What Vector Is

Vector is a SwiftUI app for creating and managing Wine bottles on macOS. It focuses on Apple Silicon gaming: launchers, per-game profiles, graphics backend selection, dependency repair, compatibility patches, and safer runtime management.

The app is built around a simple idea: keep the normal path clean, and keep the dangerous tooling clearly separated.

## What Vector Is Not

Vector does not bypass anti-cheat. Protected multiplayer titles are treated as protected by default. If a game depends on Easy Anti-Cheat, BattlEye, EOS anti-cheat, or similar systems, Vector blocks unsafe local mutations and shows a clear compatibility state instead of pretending the title is supported.

Memory tooling exists for developer and single-player workflows only. It is gated, audited, and disabled automatically for protected titles.

## Current Focus

| Area | Status |
| --- | --- |
| Bottle management | Native macOS UI for creating, configuring, and launching bottles |
| Game compatibility | Per-title profiles, launch arguments, dependency presets, and backend hints |
| Patch delivery | Signed VecPatch manifests with stable/beta/experimental channel support |
| Protected multiplayer | Hard-lockdown policy for anti-cheat titles and studio-review export data |
| Runtime work | Vector-owned Wine patchsets, Proton-style media patch cataloging, runtime validation |
| Developer tooling | Wine process memory APIs behind Developer Mode and protected-title guards |

## Highlights

- Create and manage Wine bottles from a compact native UI.
- Pin Windows apps and games for quick launching.
- Apply compatibility profiles without stacking duplicate patches.
- Select or auto-select graphics backends such as DXVK, DXMT, and D3DMetal where available.
- Install and repair common dependencies such as VC runtimes, fonts, and .NET components.
- Detect protected multiplayer markers before launch.
- Export security and runtime attestation data for studio review.
- Consume signed compatibility rules from VecPatch.
- Track runtime patchsets under version control instead of relying on undocumented local fixes.

## Compatibility Model

Vector classifies games by trust level:

| Class | Meaning |
| --- | --- |
| `singlePlayer` | Normal compatibility patching is allowed |
| `moddingAllowed` | Modding and developer workflows may be enabled by the user |
| `protectedMultiplayer` | Strict policy applies; risky tools are disabled |
| `blockedAntiCheat` | Local launch is blocked until official support exists |

For protected titles, Vector disables trainers, memory APIs, unsigned rules, local patch overrides, risky DLL overrides, and custom launch mutations. The goal is not to trick anti-cheat systems. The goal is to make Vector reviewable.

## VecPatch

VecPatch is the dispatch service used by Vector for compatibility metadata and patch rules. Vector expects signed rules and validates trust-sensitive fields before applying them.

Production endpoint:

```text
https://vector.nanite.com.au
```

Useful routes:

```text
/api/health
/api/v1/patches
/api/v1/telemetry
```

See [docs/vecpatch-repo.md](docs/vecpatch-repo.md) for repository and deployment notes.

## Runtime Channel

Vector supports a signed runtime manifest for Wine runtime updates. Runtime archives are validated before publishing and can require Vector-specific tools such as `vectorvmctl`.

Start here:

- [docs/runtime-channel.md](docs/runtime-channel.md)
- [runtime/Wine](runtime/Wine)
- [scripts/runtime](scripts/runtime)

Vector-owned patchsets live in:

```text
runtime/Wine/patchsets
```

The NT memory bridge patchset adds `vectorvmctl`, a Wine-side helper used by VectorKit for process and memory inspection through Wine's own NT layer. On Apple Silicon, building that runtime requires a proper PE cross-compilation toolchain such as `llvm-mingw`.

## Project Layout

```text
Vector/            macOS app UI
VectorKit/         bottle, Wine, patch, runtime, and compatibility logic
VectorCmd/         command line tools
VectorThumbnail/   Quick Look thumbnail extension
runtime/           runtime metadata and Wine patchsets
scripts/           helper scripts for runtime and patchset workflows
docs/              implementation notes and operational docs
```

## Building

Requirements:

- Apple Silicon Mac
- macOS Sonoma 14 or newer
- Xcode 16 or newer
- SwiftLint for local linting

Clone and build:

```bash
git clone https://github.com/Zinedinarnaut/Whisky.git
cd Whisky
xcodebuild \
  -project Vector.xcodeproj \
  -scheme Vector \
  -configuration Debug \
  -destination 'generic/platform=macOS' \
  build
```

Run VectorKit tests:

```bash
cd VectorKit
swift test
```

Run linting:

```bash
swiftlint
```

## Runtime Patchsets

Dry-run Vector-owned runtime patchsets against a Wine source tree:

```bash
scripts/runtime/apply_vector_runtime_patchsets.sh \
  --wine-source /path/to/wine/source \
  --dry-run
```

Apply them for real:

```bash
scripts/runtime/apply_vector_runtime_patchsets.sh \
  --wine-source /path/to/wine/source
```

Validate a runtime archive before publishing:

```bash
scripts/runtime/validate_runtime_archive.sh /path/to/Libraries.tar.gz
```

## Security Position

Vector keeps protected multiplayer support conservative by design:

- No anti-cheat bypasses.
- No hidden launch mutations for protected titles.
- No memory tools in protected contexts.
- No unsigned patch rules for protected-title behavior.
- No local override layer for protected multiplayer.
- Runtime and patch metadata are exportable for review.

More detail: [docs/security-and-anticheat.md](docs/security-and-anticheat.md)

## Documentation

| Document | Purpose |
| --- | --- |
| [runtime-channel.md](docs/runtime-channel.md) | Runtime manifest, publishing, and archive validation |
| [nt-memory-bridge.md](docs/nt-memory-bridge.md) | Developer memory API and Wine NT bridge design |
| [security-and-anticheat.md](docs/security-and-anticheat.md) | Protected multiplayer policy and studio-facing posture |
| [proton-style-compatibility.md](docs/proton-style-compatibility.md) | Proton-style media and compatibility patch tracking |
| [crossover-patch-pipeline.md](docs/crossover-patch-pipeline.md) | CrossOver/Wine patch extraction workflow |
| [highonlife2-compatibility.md](docs/highonlife2-compatibility.md) | High On Life 2 compatibility notes |
| [parcelsimulator-compatibility.md](docs/parcelsimulator-compatibility.md) | Parcel Simulator compatibility notes |
| [vecpatch-repo.md](docs/vecpatch-repo.md) | VecPatch repository and deployment notes |

## Credits

Vector builds on work from Wine, CodeWeavers, Apple Game Porting Toolkit, DXVK, MoltenVK, Sparkle, Swift Argument Parser, SemanticVersion, and the wider macOS gaming community.

Special thanks to the upstream Whisky/Vector work that made this fork possible.

## License

Vector is distributed under the terms in [LICENSE](LICENSE).
