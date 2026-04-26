# Proton-Style Compatibility Layer

Vector does not run Proton directly on macOS. Proton is built around Linux Steam
runtime assumptions, Linux kernel interfaces, and Linux graphics/audio stacks.
Instead, Vector imports the useful parts in a controlled way:

- curated upstream Wine/Proton/Wine-GE patches are cataloged with checksums
- safe launch/runtime rules are exposed through VecPatch/dispatch profiles
- risky source patches are not auto-applied until they are dry-run validated
  against the exact VectorKit Wine source tree

This gives us the useful bits without pretending that Proton is a graphics
backend.

## Catalog Location

The bundled Proton-style catalog lives at:

```text
runtime/Wine/patchsets/proton-style-media
```

It contains:

- `dispatch-rules.json`: safe app-side patch rules Vector can apply
- `patchset.json`: source/version/checksum metadata
- `PATCHES.txt`: human-readable patch inventory
- `PATCH_SOURCES.md`: upstream source notes
- `upstream-patches/`: imported upstream patches kept unapplied by default

The current catalog focuses on Media Foundation, web/auth-adjacent networking,
WinINet cleanup, D3DX11 texture loading, and XAudio/X3DAudio coverage.

## Regenerating The Catalog

Use an existing Wine-GE/Proton-GE checkout:

```bash
scripts/runtime/generate_proton_style_patchset.sh \
  --source /tmp/vector-wine-ge-scan \
  --output-dir runtime/Wine/patchsets/proton-style-media
```

Or let the script clone Wine-GE:

```bash
scripts/runtime/generate_proton_style_patchset.sh \
  --clone-url https://github.com/GloriousEggroll/wine-ge-custom.git \
  --branch master
```

## Promoting Runtime Patches

Only promote a patch after validation:

1. Copy the selected upstream patch into a `runtime/Wine/patchsets/vector-*` patchset.
2. Dry-run against the exact Wine source tree used by VectorKit:

```bash
scripts/runtime/apply_vector_runtime_patchsets.sh \
  --wine-source /path/to/vector-wine-source \
  --dry-run
```

3. Apply and build the runtime only after the dry-run succeeds.

## Minecraft Dungeons

The Proton-style catalog ships a Minecraft Dungeons dispatch rule for Steam app
`1672970`. It keeps the owned Steam launch path intact, applies DX11/CEF fallback
arguments, disables NVAPI exposure, and marks the launch with Vector's
Proton-style media/auth environment flags.

Pinned Steam installs should be launched through Steam, not by raw-launching
`Dungeons-Win64-Shipping.exe`, because the game expects Steam/Microsoft auth
context.
