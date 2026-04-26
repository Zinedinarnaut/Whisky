# Runtime Channel

This fork ships a signed runtime manifest at:

- Base URL: `https://raw.githubusercontent.com/Zinedinarnaut/Vector/main/runtime/Wine`
- Manifest URL: `https://raw.githubusercontent.com/Zinedinarnaut/Vector/main/runtime/Wine/manifest.json`

Vector reads runtime endpoints in this order:

1. `VECTOR_RUNTIME_MANIFEST_URL` / `vectorWineManifestURL`
2. `VECTOR_RUNTIME_BASE_URL` / `vectorWineRuntimeBaseURL`
3. Fork default runtime channel (`runtime/Wine` in this repo)
4. Legacy fallback (`https://data.getvector.app/Wine`)

## Required Secret

Set the private key used to sign `manifest.json`:

```bash
gh secret set RUNTIME_MANIFEST_PRIVATE_KEY -R Zinedinarnaut/Vector
```

The value must be a base64-encoded Curve25519 signing private key raw representation.

## Publish Runtime Metadata

Use the **Runtime Channel** workflow (`.github/workflows/RuntimeChannel.yml`) via workflow dispatch.

Minimum inputs:

- `archive_url`: direct URL to `Libraries.tar.gz`
- `version_plist_url`: URL to `VectorWineVersion.plist`
- component versions (`wine_version`, `dxvk_version`, `d3dmetal_version`, `winetricks_version`, `wine_mono_version`)

The workflow will:

1. Download and hash the archive
2. Validate required runtime tools in the archive (`scripts/runtime/validate_runtime_archive.sh`)
3. Generate and sign `runtime/Wine/manifest.json`
4. Update `runtime/Wine/VectorWineVersion.plist`
5. Commit metadata back to `main`

Optional:

- Set `publish_release=true` to also upload `Libraries.tar.gz`, plist, and manifest to a release tag `runtime-v<version>`.
- Use `require_nt_memory_bridge=true` (default) to enforce `Wine/bin/vectorvmctl` presence in archive.

## Local Overrides

```bash
# One shell session
export VECTOR_RUNTIME_BASE_URL="https://raw.githubusercontent.com/Zinedinarnaut/Vector/main/runtime/Wine"

# Persist for app launches
defaults write com.isaacmarovitz.Vector vectorWineRuntimeBaseURL -string "https://raw.githubusercontent.com/Zinedinarnaut/Vector/main/runtime/Wine"
```

## CrossOver Source Integration

If you want to port CrossOver Wine deltas into our own Wine tree, use:

- `scripts/runtime/generate_crossover_patchset.sh`
- `scripts/runtime/apply_patchset.sh`

Full workflow:

- `docs/crossover-patch-pipeline.md`

## Vector Runtime Patchsets

To apply Vector-owned runtime patchsets (including NT memory bridge) before building your runtime archive:

```bash
scripts/runtime/apply_vector_runtime_patchsets.sh \
  --wine-source /path/to/wine/source \
  --dry-run
```

Then apply for real:

```bash
scripts/runtime/apply_vector_runtime_patchsets.sh \
  --wine-source /path/to/wine/source
```

On Apple Silicon, Wine runtime builds need a PE cross-compilation toolchain.
Homebrew `llvm` provides `clang`, `lld`, and `llvm-dlltool`, but Wine also
needs the MinGW/PE runtime libraries. If configure fails with:

```text
PE cross-compilation is required for ARM64
```

install or provide an `llvm-mingw` toolchain and put its `bin` directory ahead
of `/usr/bin` before configuring Wine. Also put Homebrew bison ahead of
Apple's legacy `/usr/bin/bison`:

```bash
export PATH="/path/to/llvm-mingw/bin:/opt/homebrew/opt/llvm/bin:/opt/homebrew/opt/bison/bin:$PATH"
```

The runtime archive should only be published after `Wine/bin/vectorvmctl` is
present and `scripts/runtime/validate_runtime_archive.sh` passes.

## Package A Runtime Locally

Use `package_vector_runtime.sh` to build the archive that Vector expects to
install. It stages `Libraries/`, optionally inserts `vectorvmctl.exe`, records
build metadata, signs Mach-O binaries when an identity is provided, creates the
tarball, hashes it, and can generate the signed manifest in the same run.

```bash
PRIVATE_KEY_B64="$RUNTIME_MANIFEST_PRIVATE_KEY" \
scripts/runtime/package_vector_runtime.sh \
  --runtime-root "/path/to/runtime-root" \
  --output "/tmp/Libraries.tar.gz" \
  --version "2.6.0" \
  --archive-url "https://example.com/Libraries.tar.gz" \
  --wine-version "11.0" \
  --dxvk-version "2.x" \
  --d3dmetal-version "3.x" \
  --winetricks-version "20260125" \
  --wine-mono-version "latest" \
  --vectorvmctl "/path/to/vectorvmctl.exe" \
  --manifest-output "/tmp/manifest.json" \
  --runtime-channel stable
```

Installed runtimes write `VectorRuntimeInstallHealth.json` so Vector can show
whether core files and the memory bridge were present after extraction.

## Proton-style compatibility catalogs

Patchsets whose directory name does not start with `vector-*` are treated as
catalogs unless explicitly promoted. For example,
`runtime/Wine/patchsets/proton-style-media` tracks upstream Proton/Wine-GE
patches and dispatch rules, but its source patches are stored under
`upstream-patches/` and are not applied by `apply_vector_runtime_patchsets.sh`.

Promote only the specific patches that dry-run cleanly against the active
VectorKit Wine source tree.
