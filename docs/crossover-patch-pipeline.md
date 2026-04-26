# CrossOver Patch Pipeline (Vector Runtime)

This is the safe workflow to reuse CrossOver source deltas in our Wine runtime work.

## What this gives us

- A reproducible patchset generated from:
  - upstream Wine source tree
  - CrossOver source tree (`sources/wine`)
- A machine-readable patch manifest
- A deterministic apply step with `--dry-run` support

This avoids hand-editing huge source deltas and makes rollback/testing straightforward.

## Inputs you need

- Upstream Wine source tree (same era/version as the CrossOver source you compare against)
- CrossOver source tree (`.../sources/wine`)

You can also use `winecx` as the CrossOver-source input if you clone:

- <https://github.com/Gcenx/winecx>

Or generate directly from remote refs:

```bash
cd /Users/zinedinarnaut/Documents/Projects/whiskey

scripts/runtime/generate_winecx_patchset.sh \
  --output-dir runtime/Wine/patchsets/winecx-master \
  --wine-ref master \
  --winecx-ref master
```

You currently have:

- CrossOver source: `/Users/zinedinarnaut/Downloads/sources/wine`

## 1) Generate patchset from source delta

```bash
cd /Users/zinedinarnaut/Documents/Projects/whiskey

scripts/runtime/generate_crossover_patchset.sh \
  --base-wine-source /path/to/upstream/wine \
  --crossover-wine-source /Users/zinedinarnaut/Downloads/sources/wine \
  --output-dir runtime/Wine/patchsets/crossover-23.7.1 \
  --label crossover \
  --version 23.7.1
```

Outputs:

- `runtime/Wine/patchsets/crossover-23.7.1/patchset.json`
- `runtime/Wine/patchsets/crossover-23.7.1/PATCHES.txt`
- `runtime/Wine/patchsets/crossover-23.7.1/patches/*.patch`

## 2) Dry-run apply patchset

```bash
cd /Users/zinedinarnaut/Documents/Projects/whiskey

scripts/runtime/apply_patchset.sh \
  --wine-source /path/to/our/wine/source \
  --patchset-dir runtime/Wine/patchsets/crossover-23.7.1/patches \
  --dry-run
```

If dry-run is clean, apply for real:

```bash
scripts/runtime/apply_patchset.sh \
  --wine-source /path/to/our/wine/source \
  --patchset-dir runtime/Wine/patchsets/crossover-23.7.1/patches
```

## 3) Reverse (unapply) if needed

```bash
scripts/runtime/apply_patchset.sh \
  --wine-source /path/to/our/wine/source \
  --patchset-dir runtime/Wine/patchsets/crossover-23.7.1/patches \
  --reverse
```

## Notes

- `crossover-sources-23.7.1` is older than modern CrossOver runtime builds, so expect conflicts if base source doesn’t match.
- Best practice is to start with specific components (`dlls`, `server`, `programs`) and validate with real game smoke tests after each batch.
