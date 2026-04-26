# NT Memory Bridge (Vector)

This adds a low-level Wine process memory interface with two backends:

- `ntBridge`: JSON bridge utility (`vectorvmctl`) compiled into Wine runtime
- `debugger`: existing `winedbg` command fallback

`auto` mode will prefer `ntBridge` only when bridge capability handshake succeeds.

## Swift API

Implemented in:

- `VectorKit/Sources/VectorKit/Wine/WineProcessMemory.swift`

Main APIs:

- `openProcess(winePID:)`
- `closeHandle(_:)`
- `virtualQueryEx(handle:address:)`
- `readProcessMemory(handle:address:size:)`
- `writeProcessMemory(handle:address:data:autoAdjustProtection:)`
- `enumerateModules(handle:)`
- `getModuleBase(handle:moduleName:)`
- `listProcesses()`
- `transportStatus()`

Transport selection:

- constructor `preferredTransport: .auto | .ntBridge | .debugger`
- env override `VECTOR_MEMORY_TRANSPORT`

## CLI

Implemented in:

- `VectorCmd/Main.swift` (`memory` command)

Commands:

- `vectorcmd memory status <bottle> [--transport auto|ntBridge|debugger]`
- `vectorcmd memory processes <bottle> [--transport ...]`
- `vectorcmd memory modules <bottle> <pid> [--transport ...]`
- `vectorcmd memory query <bottle> <pid> <address> [--transport ...]`
- `vectorcmd memory read <bottle> <pid> <address> <size> [--transport ...]`
- `vectorcmd memory write <bottle> <pid> <address> <hex...> [--transport ...]`

## Runtime Patchset

Patchset path:

- `runtime/Wine/patchsets/vector-nt-memory-bridge`

Includes:

- `patches/0001-vectorvmctl-nt-memory-bridge.patch`
- `patchset.json`
- `PATCHES.txt`

Apply (dry-run):

```bash
scripts/runtime/apply_patchset.sh \
  --wine-source /path/to/wine/source \
  --patchset-dir runtime/Wine/patchsets/vector-nt-memory-bridge/patches \
  --dry-run
```

Apply:

```bash
scripts/runtime/apply_patchset.sh \
  --wine-source /path/to/wine/source \
  --patchset-dir runtime/Wine/patchsets/vector-nt-memory-bridge/patches
```

## Bridge binary discovery

Vector searches:

- `$VECTOR_WINE_MEMCTL_OVERRIDE`
- `<runtime-bin>/vectorvmctl`
- `<runtime-bin>/vector_memctl`

The bridge must answer:

- `vectorvmctl --json bridge capabilities`

and include capabilities:

- `process.list`
- `module.list`
- `memory.map`
- `memory.read`
- `memory.write`

If capability probe fails in `auto`, Vector falls back to debugger backend.
