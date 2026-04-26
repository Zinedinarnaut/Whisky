# Vector Security & Anti-Cheat Policy

Vector is being designed toward a studio-reviewable protected multiplayer posture. This document defines what Vector does, what it refuses to do, and what evidence it can export for a studio or anti-cheat vendor review.

## Non-bypass commitment

Vector does not bypass, disable, emulate, weaken, or hide from protected anti-cheat systems. If a game requires an anti-cheat provider such as Easy Anti-Cheat or BattlEye and the studio has not approved Vector's runtime profile, Vector treats local online launch as blocked.

ARC Raiders is the flagship protected multiplayer case. Until Embark and the anti-cheat provider explicitly approve a Vector runtime profile, Vector marks ARC Raiders as blocked and offers safe fallback options instead of local launch tweaks.

## Trust classes

Vector classifies games and patch rules into four trust classes:

- `singlePlayer`: normal compatibility patches are allowed.
- `moddingAllowed`: modding-oriented patches may be allowed when the game/community expects them.
- `protectedMultiplayer`: strict policy applies; only signed, approved, non-risky rules are accepted.
- `blockedAntiCheat`: local launch is blocked unless official support exists.

Protected games always receive the strictest applicable policy. Bottle-level preferences cannot downgrade this policy.

## Protected Multiplayer Mode

When Vector detects a protected title or anti-cheat artifact, it applies hard lockdown:

- Memory APIs are unavailable.
- Trainer launches are unavailable.
- Local VecPatch overrides are unavailable.
- Unsigned patch rules are unavailable.
- Debug tooling is unavailable.
- Custom launch mutations are unavailable.
- Risky DLL overrides are blocked.
- Local launch is blocked when official anti-cheat support is required.

Memory tooling is gated behind Developer Mode and records JSON-lines audit events in each bottle at `.vector-memory-audit.jsonl`. Reads, writes, module enumeration, handle open/close, and VirtualQueryEx-style probes are logged with Wine PID, address, byte counts, transport, and result.

Detected ARC Raiders and generic protected anti-cheat launchers show a clear blocked message and point users to supported alternatives. Vector scans for Easy Anti-Cheat, EOS Anti-Cheat, BattlEye, Ricochet-like service markers, Vanguard, EQU8, Xigncode, Wellbia, nProtect/GameGuard, and FaceIt-style artifacts.

## Host security capability probe

Vector now records host security posture as part of diagnostics and studio-review exports. The probe is intentionally read-only and checks:

- Full, Reduced, permissive, or unknown security posture from SIP/authenticated-root/NVRAM evidence.
- Startup Security policy evidence from `bputil` when macOS allows it.
- SIP and authenticated root state.
- System Extension and DriverKit host availability.
- Whether the app has DriverKit-related entitlements.
- Rosetta and translated-process state.
- Metal device availability.
- GPTK/D3DMetal payload availability.
- Vector runtime installation state.

Reduced Security does not loosen protected multiplayer rules. It only allows Vector to unlock deeper single-player diagnostics when Developer Mode is also enabled.

Export command:

```sh
vectorcmd security host
```

## VecPatch protected rule model

VecPatch rules include security metadata:

- `trust_class`
- `risk_level`
- `protected_title_policy`
- `official_support_required`
- `allowed_override_keys`
- `studio_approved`

For protected titles, Vector accepts only block/preflight/remote-play metadata unless the rule is signed and explicitly approved. Rules that mutate executable arguments, environment variables, graphics backends, or DLL overrides are rejected under hard lockdown.

Remote VecPatch rules are verified with Ed25519 when signed-rule enforcement is enabled. Placeholder strings such as `vector-signature-*` are not considered valid signatures.

## Runtime attestation

Vector can export a studio-review bundle containing:

- Runtime binary paths and SHA-256 hashes.
- Host security capabilities and advanced diagnostics state.
- Vector runtime attestation schema v2 with app code-signing identifier, team identifier, signing authorities, entitlements, notarization assessment, hardened-runtime state, and patchset digest.
- Vector version metadata.
- Wine, DXVK, D3DMetal, Winetricks, and Wine Mono version metadata where available.
- Bottle path and launch policy state.
- Protected launch assessment and detected anti-cheat artifacts.
- VecPatch endpoint/channel/signature policy and manifest digest.
- Safe multiplayer and trainer mode state.

Export command:

```sh
vectorcmd security export "Gaming Bottle" 1808500
```

The output is JSON so it can be attached to a studio support thread, issue tracker, or anti-cheat review request.

## Telemetry boundaries

Vector's protected multiplayer policy does not require invasive telemetry. If telemetry is enabled in the future, it should remain opt-in and limited to compatibility outcomes, crash signatures, rule IDs, runtime versions, and non-personal system/runtime metadata. It must not collect gameplay data, private account data, tokens, or memory contents.

## Studio review brief

A studio or anti-cheat vendor reviewing Vector should expect these guarantees:

- Protected titles are blocked locally unless official support is present.
- Vector's memory/trainer/debug facilities are isolated from protected multiplayer flows.
- Patch rules are risk-classified and signature-gated.
- Runtime hashes and launch policy are exportable and reproducible.
- Vector prioritizes Remote Play, Steam Deck/SteamOS, Windows PC, or other officially supported paths for blocked anti-cheat games.

## ARC Raiders status

Current status: `Blocked: Official anti-cheat support required`.

Detected markers include:

- `EasyAntiCheat`
- `EOS_AntiCheat`
- `start_protected_game`
- `EmbarkGameBoot`
- Steam app ID `1808500`

Fallback options shown by Vector:

- Steam Remote Play from a Windows PC.
- Steam Deck or SteamOS with official Proton/EAC support.
- Moonlight/Sunshine from a trusted Windows host.
- Cloud streaming if ARC Raiders is available there.
