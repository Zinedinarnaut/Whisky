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
2. Generate and sign `runtime/Wine/manifest.json`
3. Update `runtime/Wine/VectorWineVersion.plist`
4. Commit metadata back to `main`

Optional:

- Set `publish_release=true` to also upload `Libraries.tar.gz`, plist, and manifest to a release tag `runtime-v<version>`.

## Local Overrides

```bash
# One shell session
export VECTOR_RUNTIME_BASE_URL="https://raw.githubusercontent.com/Zinedinarnaut/Vector/main/runtime/Wine"

# Persist for app launches
defaults write com.isaacmarovitz.Vector vectorWineRuntimeBaseURL -string "https://raw.githubusercontent.com/Zinedinarnaut/Vector/main/runtime/Wine"
```
