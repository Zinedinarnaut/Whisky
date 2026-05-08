export const vecPatchBaseURL = process.env.NEXT_PUBLIC_VECPATCH_API_URL ?? "https://vector.nanite.com.au";
const GITHUB_RELEASES_URL = "https://api.github.com/repos/Zinedinarnaut/Whisky/releases?per_page=20";
const GITHUB_REPO_URL = "https://github.com/Zinedinarnaut/Whisky";

export type PatchRiskLevel = "low" | "medium" | "high" | "blocked" | string;
export type GameTrustClass = "singlePlayer" | "moddingAllowed" | "protectedMultiplayer" | "blockedAntiCheat" | string;
export type PatchCoverageState = "blocked" | "remote-rule" | "local-profile" | "metadata-only" | "unknown" | string;

export type VecPatchRule = {
  id: string;
  name: string;
  executable_match: string;
  steam_app_id?: string;
  arguments?: string;
  environment?: Record<string, string>;
  enabled: boolean;
  channel: string;
  signature?: string;
  changelog?: string;
  priority?: number;
  rule_version?: number;
  graphics_backend?: string;
  fallback_graphics_backend?: string;
  trust_class?: GameTrustClass;
  risk_level?: PatchRiskLevel;
  official_support_required?: boolean;
  studio_approved?: boolean;
  local_profile?: string;
  dependency_repairs?: string[];
  fix_ids?: string[];
  recommended_action?: string;
  known_issues?: string[];
  tags?: string[];
  patch_state?: PatchCoverageState;
  support_policy?: string;
  updated_at?: string;
};

export type VecPatchManifest = {
  service: string;
  version: number;
  source: string;
  deployment_env?: string;
  commit_sha?: string;
  generated_at: string;
  changelog?: string;
  metadata?: {
    request_id?: string;
    channel?: string;
    limit?: number;
    include_disabled?: boolean;
    rule_count?: number;
    signature_mode?: string;
  };
  rules: VecPatchRule[];
  unavailable?: boolean;
};

type GitHubAsset = {
  name: string;
  size: number;
  digest?: string;
  download_count?: number;
  browser_download_url: string;
  content_type?: string;
  updated_at?: string;
};

type GitHubRelease = {
  tag_name: string;
  name: string;
  html_url: string;
  published_at: string;
  prerelease: boolean;
  assets: GitHubAsset[];
  zipball_url?: string;
};

type ReleaseManifest = {
  code_signing?: string;
};

export type DistributionAsset = {
  name: string;
  kind: "app" | "runtime" | "manifest" | "metadata" | "source";
  sizeLabel: string;
  digest?: string;
  downloadUrl: string;
  downloadCount?: number;
  contentType?: string;
};

export type DistributionMetadata = {
  channel: string;
  releaseName: string;
  tagName: string;
  publishedAt: string;
  releaseUrl: string;
  sourceUrl: string;
  hasSignedApp: boolean;
  trustLevel: "trusted" | "unsigned" | "source-only" | "unavailable";
  trustReason: string;
  codeSigning?: string;
  assets: DistributionAsset[];
  unavailable?: boolean;
};

export type CompatibilityEntry = {
  game: string;
  status: "Working" | "Playable" | "Needs Fix" | "Blocked";
  level: "Platinum" | "Gold" | "Silver" | "Blocked";
  backend: string;
  fallbackBackend?: string;
  steamAppId?: string;
  executableMatch?: string;
  trustClass: string;
  riskLevel: string;
  patchVersion: string;
  note: string;
  recommendedAction?: string;
  recommendedFixes: string[];
  knownIssues?: string[];
  fixIds: string[];
  hasLocalProfile: boolean;
  localProfile?: string;
  hasRemoteVecPatchRule: boolean;
  remoteRuleId?: string;
  hasDependencyRepairs: boolean;
  dependencyRepairs: string[];
  officialSupportRequired?: boolean;
  supportPolicy?: string;
  tags: string[];
  patchState: PatchCoverageState;
  source?: string;
  updatedAt?: string;
};

export type CompatibilityDatabase = {
  service: string;
  version: number;
  source?: string;
  generatedAt: string;
  metadata: {
    channel: string;
    entryCount: number;
    signatureMode?: string;
    requestId?: string;
    unavailable?: boolean;
  };
  entries: CompatibilityEntry[];
};

const fallbackManifest: VecPatchManifest = {
  service: "vecpatch",
  version: 1,
  source: vecPatchBaseURL,
  deployment_env: "offline-fallback",
  generated_at: new Date(0).toISOString(),
  metadata: {
    channel: "stable",
    rule_count: 4,
    signature_mode: "ed25519",
  },
  unavailable: true,
  rules: [
    {
      id: "fallback-minecraft-dungeons",
      name: "Minecraft Dungeons",
      executable_match: "dungeons-win64-shipping.exe",
      steam_app_id: "1672970",
      enabled: true,
      channel: "stable",
      rule_version: 2,
      graphics_backend: "d3dMetal",
      fallback_graphics_backend: "dxvk",
      trust_class: "singlePlayer",
      risk_level: "low",
      local_profile: "Auto: Minecraft Dungeons",
      dependency_repairs: ["WebView2 auth repair", "media playback compatibility", "Proton-style media/auth markers"],
      fix_ids: ["repairMediaPlayback", "reapplyVecPatch"],
      recommended_action: "Run the sign-in/media repair path if auth or intro video fails.",
      known_issues: ["Microsoft sign-in path can require WebView2/auth cache repair"],
      tags: ["D3D11", "Microsoft Auth", "Media", "local-profile", "remote-rule"],
      patch_state: "remote-rule",
      changelog: "Steam build launches with a D3D12/D3DMetal profile; Microsoft auth remains the known fragile area.",
    },
    {
      id: "fallback-content-warning",
      name: "Content Warning",
      executable_match: "content warning.exe",
      steam_app_id: "2881650",
      enabled: true,
      channel: "stable",
      rule_version: 2,
      graphics_backend: "dxvk",
      fallback_graphics_backend: "d3dMetal",
      trust_class: "singlePlayer",
      risk_level: "low",
      local_profile: "Auto: Content Warning",
      dependency_repairs: ["DXVK payload repair", "runtime DLL mirror validation"],
      fix_ids: ["reapplyVecPatch"],
      recommended_action: "Apply the local or VecPatch D3D11 profile.",
      tags: ["D3D11", "DXVK", "Steam", "local-profile", "remote-rule"],
      patch_state: "remote-rule",
      changelog: "DXVK-first D3D11 startup profile.",
    },
    {
      id: "fallback-parcel-simulator",
      name: "Parcel Simulator",
      executable_match: "parcel-win64-shipping.exe",
      steam_app_id: "2424010",
      enabled: true,
      channel: "stable",
      rule_version: 1,
      graphics_backend: "dxvk",
      fallback_graphics_backend: "d3dMetal",
      trust_class: "singlePlayer",
      risk_level: "low",
      local_profile: "Auto: Parcel Simulator",
      dependency_repairs: ["DXVK payload repair", "runtime DLL mirror validation"],
      fix_ids: ["reapplyVecPatch"],
      recommended_action: "Apply the local or VecPatch D3D11 profile.",
      tags: ["D3D11", "DXVK", "Steam", "local-profile", "remote-rule"],
      patch_state: "remote-rule",
      changelog: "UE profile with launcher-safe overrides.",
    },
    {
      id: "fallback-arc-raiders",
      name: "ARC Raiders",
      executable_match: "arcraiders.exe",
      steam_app_id: "1808500",
      enabled: true,
      channel: "stable",
      rule_version: 1,
      graphics_backend: "protected",
      trust_class: "blockedAntiCheat",
      risk_level: "blocked",
      official_support_required: true,
      studio_approved: true,
      fix_ids: ["exportDiagnosticBundle"],
      recommended_action: "Use Remote Play, Steam Deck/SteamOS Proton, Moonlight/Sunshine, or Windows PC.",
      known_issues: ["Official anti-cheat support required"],
      tags: ["EAC", "Protected", "Blocked", "official-support-required", "remote-rule"],
      patch_state: "blocked",
      support_policy: "Blocked locally. Official anti-cheat support required.",
      changelog: "Blocked locally until official Embark/EAC support exists.",
    },
  ],
};

type KnownCompatibilityMetadata = {
  game: string;
  status: CompatibilityEntry["status"];
  level: CompatibilityEntry["level"];
  note: string;
  backend: string;
  fallbackBackend?: string;
  steamAppId?: string;
  executableMatch?: string;
  trustClass?: GameTrustClass;
  riskLevel?: PatchRiskLevel;
  localProfile?: string;
  remoteRuleId?: string;
  dependencyRepairs?: string[];
  fixIds?: string[];
  tags: string[];
  recommendedAction?: string;
  knownIssues?: string[];
  officialSupportRequired?: boolean;
  supportPolicy?: string;
};

const knownCompatibilityMatrix: KnownCompatibilityMetadata[] = [
  {
    game: "High On Life 2",
    status: "Needs Fix",
    level: "Silver",
    backend: "d3dMetal",
    fallbackBackend: "dxvk",
    steamAppId: "2069250",
    executableMatch: "highonlife2-win64-shipping.exe",
    localProfile: "Auto: High On Life 2",
    dependencyRepairs: ["FSR/NGX shim validation", "app-scoped D3D override repair"],
    fixIds: ["reapplyVecPatch"],
    tags: ["UE5", "D3D12", "FSR", "NGX", "local-profile"],
    note: "Local profile exists for the D3D12/D3DMetal path; compatibility remains marked needs-fix until more launch evidence is available.",
    recommendedAction: "Use the local profile and verify the FSR/NGX shim path before treating this as playable.",
  },
  {
    game: "Parcel Simulator",
    status: "Working",
    level: "Platinum",
    backend: "dxvk",
    fallbackBackend: "d3dMetal",
    steamAppId: "2424010",
    executableMatch: "parcel-win64-shipping.exe",
    localProfile: "Auto: Parcel Simulator",
    remoteRuleId: "fallback-parcel-simulator",
    dependencyRepairs: ["DXVK payload repair", "runtime DLL mirror validation"],
    fixIds: ["reapplyVecPatch"],
    tags: ["D3D11", "DXVK", "Steam", "local-profile", "remote-rule"],
    note: "Known working with the stable D3D11 profile and launcher-safe overrides.",
    recommendedAction: "Apply the local or VecPatch D3D11 profile.",
  },
  {
    game: "Minecraft Dungeons",
    status: "Playable",
    level: "Gold",
    backend: "dxvk",
    fallbackBackend: "wined3d",
    steamAppId: "1672970",
    executableMatch: "dungeons-win64-shipping.exe",
    localProfile: "Auto: Minecraft Dungeons",
    remoteRuleId: "proton-style-minecraft-dungeons-media-auth-v1",
    dependencyRepairs: ["WebView2 auth repair", "media playback compatibility", "Proton-style media/auth markers"],
    fixIds: ["repairMediaPlayback", "reapplyVecPatch"],
    tags: ["D3D11", "Microsoft Auth", "Media", "auth-repair", "local-profile", "remote-rule"],
    note: "Steam build launches; Microsoft/Xbox auth and WebView plumbing remain the fragile areas.",
    recommendedAction: "Apply the profile and run the sign-in/media repair path if auth or intro video fails.",
    knownIssues: ["Microsoft sign-in path can require WebView2/auth cache repair"],
  },
  {
    game: "Content Warning",
    status: "Playable",
    level: "Gold",
    backend: "dxvk",
    fallbackBackend: "d3dMetal",
    steamAppId: "2881650",
    executableMatch: "content warning.exe",
    localProfile: "Auto: Content Warning",
    remoteRuleId: "fallback-content-warning",
    dependencyRepairs: ["DXVK payload repair", "runtime DLL mirror validation"],
    fixIds: ["reapplyVecPatch"],
    tags: ["D3D11", "DXVK", "Steam", "local-profile", "remote-rule"],
    note: "Uses a DXVK-first D3D11 profile with dependency checks for startup stability.",
    recommendedAction: "Apply the local or VecPatch D3D11 profile.",
  },
  {
    game: "Silent Hill f",
    status: "Needs Fix",
    level: "Silver",
    backend: "dxvk",
    steamAppId: "2947440",
    executableMatch: "silenthillf-win64-shipping.exe",
    localProfile: "Auto: Silent Hill f",
    dependencyRepairs: ["DXVK payload repair"],
    fixIds: ["reapplyVecPatch"],
    tags: ["D3D11", "DXVK", "Steam", "boots", "local-profile"],
    note: "Known to boot on the forced DX11 path; DX12 is unstable and this is not advertised as fully playable.",
    recommendedAction: "Use the local DX11 profile and keep expectations at boots/needs-fix until verified.",
    knownIssues: ["DX12 path is unstable on Apple Silicon"],
  },
  {
    game: "WeMod (Wand Runtime)",
    status: "Needs Fix",
    level: "Silver",
    backend: "wined3d",
    executableMatch: "wemod.exe",
    localProfile: "Auto: WeMod / Wand",
    dependencyRepairs: ["compatibility Wine/wineserver pair", "Electron GPU fallback"],
    fixIds: ["repairRuntime", "killMismatchedWineserver"],
    tags: ["Electron", "launcher", "runtime-pair", "local-profile", "dependency-repair"],
    note: "Electron UI rendering can still fail; the local profile only captures the safest known launch flags.",
    recommendedAction: "Use the compatibility runtime pair and disable Electron GPU compositing.",
  },
  {
    game: "ARC Raiders",
    status: "Blocked",
    level: "Blocked",
    backend: "protected",
    steamAppId: "1808500",
    executableMatch: "arcraiders.exe",
    trustClass: "blockedAntiCheat",
    riskLevel: "blocked",
    remoteRuleId: "fallback-arc-raiders",
    fixIds: ["exportDiagnosticBundle"],
    tags: ["EAC", "Protected", "Blocked", "official-support-required", "remote-rule"],
    note: "Protected multiplayer title. Local launch is blocked until official Embark/EAC support exists.",
    recommendedAction: "Use Remote Play, Steam Deck/SteamOS Proton, Moonlight/Sunshine, or Windows PC.",
    knownIssues: ["Official anti-cheat support required"],
    officialSupportRequired: true,
    supportPolicy: "Blocked locally. Official Embark/EAC support is required.",
  },
  {
    game: "Tom Clancy's Rainbow Six Extraction",
    status: "Blocked",
    level: "Blocked",
    backend: "protected",
    executableMatch: "rainbowsix.exe",
    trustClass: "blockedAntiCheat",
    riskLevel: "blocked",
    fixIds: ["exportDiagnosticBundle"],
    tags: ["BattlEye", "Protected", "Blocked", "official-support-required"],
    note: "BattlEye-protected launch is blocked for local Vector play unless official support is provided.",
    recommendedAction: "Use a supported Windows host or official remote-play path.",
    knownIssues: ["Official anti-cheat support required"],
    officialSupportRequired: true,
    supportPolicy: "Blocked locally. Official BattlEye support is required.",
  },
  {
    game: "Forza Horizon 6",
    status: "Needs Fix",
    level: "Silver",
    backend: "d3dMetal",
    fallbackBackend: "dxvk",
    steamAppId: "2483190",
    executableMatch: "forzahorizon6.exe",
    localProfile: "Auto: Forza Horizon 6",
    fixIds: ["reapplyVecPatch"],
    tags: ["DX12", "D3DMetal", "release-dependent", "local-profile"],
    note: "Profile metadata is prepared for the DX12/D3DMetal path, but support is release-build dependent and not claimed as verified.",
    recommendedAction: "Treat as profile metadata only until a released build is tested.",
  },
  {
    game: "Titanfall 2",
    status: "Needs Fix",
    level: "Silver",
    backend: "dxvk",
    steamAppId: "1237970",
    executableMatch: "titanfall2.exe",
    localProfile: "Auto: Titanfall 2",
    dependencyRepairs: ["EA App bootstrap repair", "compatibility Wine/wineserver pair"],
    fixIds: ["repairLauncherDependencies", "killMismatchedWineserver"],
    tags: ["D3D11", "EA App", "launcher", "local-profile", "dependency-repair"],
    note: "Local profile exists, but EA App bootstrap remains the launch risk.",
    recommendedAction: "Repair the EA App bootstrap before treating game launch failures as renderer issues.",
    knownIssues: ["EA App bootstrap can stall before game launch"],
  },
  {
    game: "EA App / Origin Bootstrap",
    status: "Needs Fix",
    level: "Silver",
    backend: "wined3d",
    executableMatch: "eadesktop.exe",
    localProfile: "Auto: EA App",
    dependencyRepairs: ["launcher dependency repair", "compatibility Wine/wineserver pair"],
    fixIds: ["repairLauncherDependencies", "killMismatchedWineserver"],
    tags: ["EA App", "Origin", "launcher", "local-profile", "dependency-repair"],
    note: "Launcher entry for games that require EA/Origin handoff; it is not a game support claim.",
    recommendedAction: "Run the launcher dependency repair path when the installer or sign-in window fails.",
  },
  {
    game: "Lethal Company",
    status: "Working",
    level: "Platinum",
    backend: "dxvk",
    steamAppId: "1966720",
    executableMatch: "lethal company.exe",
    localProfile: "Auto: Lethal Company",
    fixIds: ["reapplyVecPatch"],
    tags: ["DXVK", "Steam", "Verified", "local-profile"],
    note: "Known working baseline profile.",
    recommendedAction: "Use the local baseline profile.",
  },
  {
    game: "Hydroneer",
    status: "Working",
    level: "Platinum",
    backend: "dxvk",
    steamAppId: "1106840",
    executableMatch: "hydroneer-win64-shipping.exe",
    localProfile: "Auto: Hydroneer",
    fixIds: ["reapplyVecPatch"],
    tags: ["DXVK", "Steam", "Verified", "local-profile"],
    note: "Known working baseline profile.",
    recommendedAction: "Use the local baseline profile.",
  },
  {
    game: "Satisfactory",
    status: "Playable",
    level: "Gold",
    backend: "dxvk",
    steamAppId: "526870",
    executableMatch: "factorygamesteam.exe",
    localProfile: "Auto: Satisfactory",
    dependencyRepairs: ["Unreal dependency preset"],
    fixIds: ["reapplyVecPatch"],
    tags: ["D3D11", "Fullscreen", "Steam", "Verified", "local-profile"],
    note: "DX11 fallback profile for reliable startup.",
    recommendedAction: "Use the local DX11 profile and native fullscreen when possible.",
  },
  {
    game: "Escape the Backrooms",
    status: "Playable",
    level: "Gold",
    backend: "dxvk",
    steamAppId: "1943950",
    executableMatch: "escapethebackrooms.exe",
    localProfile: "Auto: Escape the Backrooms",
    dependencyRepairs: ["Unreal dependency preset"],
    fixIds: ["reapplyVecPatch"],
    tags: ["D3D11", "Unreal", "Steam", "Verified", "local-profile"],
    note: "Unreal DX11 fallback profile.",
    recommendedAction: "Use the local DX11 profile and Unreal dependency preset if first launch is unstable.",
  },
];

export async function getVecPatchManifest(): Promise<VecPatchManifest> {
  try {
    const response = await fetch(`${vecPatchBaseURL}/api/v1/patches?limit=200`, {
      next: { revalidate: 120 },
      headers: { accept: "application/json" },
    });

    if (!response.ok) {
      return fallbackManifest;
    }

    return (await response.json()) as VecPatchManifest;
  } catch {
    return fallbackManifest;
  }
}

export async function getCompatibilityDatabase(): Promise<CompatibilityDatabase> {
  try {
    const response = await fetch(`${vecPatchBaseURL}/api/v1/compatibility?limit=200`, {
      next: { revalidate: 120 },
      headers: { accept: "application/json" },
    });

    if (response.ok) {
      const payload = await response.json() as {
        service?: string;
        version?: number;
        source?: string;
        generated_at?: string;
        metadata?: {
          channel?: string;
          entry_count?: number;
          signature_mode?: string;
          request_id?: string;
        };
        entries?: unknown[];
      };

      const manifest = await getVecPatchManifest();
      const entries = mergeCompatibilityEntries(
        (payload.entries ?? []).map(normalizeRemoteCompatibilityEntry),
        manifest,
      );
      return {
        service: payload.service ?? "vecpatch",
        version: payload.version ?? 1,
        source: payload.source,
        generatedAt: payload.generated_at ?? new Date().toISOString(),
        metadata: {
          channel: payload.metadata?.channel ?? "stable",
          entryCount: entries.length,
          signatureMode: payload.metadata?.signature_mode,
          requestId: payload.metadata?.request_id,
        },
        entries,
      };
    }
  } catch {
    // Fall through to the patch-rule derived compatibility view.
  }

  const manifest = await getVecPatchManifest();
  const entries = deriveCompatibilityEntries(manifest);
  return {
    service: "vecpatch",
    version: 1,
    source: manifest.source,
    generatedAt: manifest.generated_at,
    metadata: {
      channel: manifest.metadata?.channel ?? "stable",
      entryCount: entries.length,
      signatureMode: manifest.metadata?.signature_mode,
      requestId: manifest.metadata?.request_id,
      unavailable: manifest.unavailable,
    },
    entries,
  };
}

export async function getDistributionMetadata(): Promise<DistributionMetadata> {
  try {
    const response = await fetch(GITHUB_RELEASES_URL, {
      next: { revalidate: 300 },
      headers: { accept: "application/vnd.github+json" },
    });

    if (!response.ok) {
      return fallbackDistribution();
    }

    const releases = (await response.json()) as GitHubRelease[];
    const release = selectDistributionRelease(releases);
    if (!release) {
      return fallbackDistribution();
    }

    const assets = release.assets.map(mapReleaseAsset);
    const codeSigning = await fetchCodeSigningState(assets);
    const hasSignedApp = codeSigning?.startsWith("developer-id") ?? false;
    const trust = releaseTrustState(assets, hasSignedApp);

    if (release.zipball_url) {
      assets.push({
        name: "Source snapshot",
        kind: "source",
        sizeLabel: "GitHub archive",
        downloadUrl: release.zipball_url,
        contentType: "application/zip",
      });
    }

    return {
      channel: release.prerelease ? "preview" : "stable",
      releaseName: release.name,
      tagName: release.tag_name,
      publishedAt: release.published_at,
      releaseUrl: release.html_url,
      sourceUrl: GITHUB_REPO_URL,
      hasSignedApp,
      trustLevel: trust.level,
      trustReason: trust.reason,
      codeSigning,
      assets,
    };
  } catch {
    return fallbackDistribution();
  }
}

export function deriveCompatibilityEntries(manifest: VecPatchManifest): CompatibilityEntry[] {
  return mergeCompatibilityEntries([], manifest);
}

function mergeCompatibilityEntries(remoteEntries: CompatibilityEntry[], manifest: VecPatchManifest): CompatibilityEntry[] {
  const enabledRules = [...manifest.rules]
    .filter((rule) => rule.enabled)
    .sort((first, second) => (first.priority ?? 999) - (second.priority ?? 999));
  const remoteByKey = new Map<string, CompatibilityEntry>();

  for (const entry of remoteEntries) {
    remoteByKey.set(compatibilityKey(entry.game, entry.steamAppId), entry);
  }

  const entries = knownCompatibilityMatrix.map((known) => {
    const matchedRule = findMatchingRule(known, enabledRules);
    const remoteEntry = findMatchingRemoteEntry(known, remoteByKey);
    return mergeKnownCompatibilityEntry(known, remoteEntry, matchedRule);
  });

  for (const rule of enabledRules) {
    if (entries.some((entry) => ruleMatchesEntry(rule, entry))) {
      continue;
    }
    entries.push(compatibilityEntryFromRule(rule));
  }

  for (const entry of remoteEntries) {
    if (entries.some((known) => entriesMatch(known, entry))) {
      continue;
    }
    entries.push(entry);
  }

  return entries.sort(compareCompatibilityEntries);
}

function mergeKnownCompatibilityEntry(
  known: KnownCompatibilityMetadata,
  remoteEntry?: CompatibilityEntry,
  rule?: VecPatchRule,
): CompatibilityEntry {
  const hasRemoteVecPatchRule = Boolean(rule || remoteEntry?.hasRemoteVecPatchRule || known.remoteRuleId);
  const remoteRuleId = rule?.id ?? remoteEntry?.remoteRuleId ?? known.remoteRuleId;
  const localProfile = known.localProfile ?? remoteEntry?.localProfile ?? rule?.local_profile;
  const dependencyRepairs = uniqueStrings([
    ...(known.dependencyRepairs ?? []),
    ...(remoteEntry?.dependencyRepairs ?? []),
    ...(rule?.dependency_repairs ?? []),
  ]);
  const blocked = isBlockedRule(rule) || known.status === "Blocked" || remoteEntry?.status === "Blocked";
  const officialSupportRequired = Boolean(
    known.officialSupportRequired || remoteEntry?.officialSupportRequired || rule?.official_support_required || blocked,
  );
  const tags = coverageTags({
    tags: [...known.tags, ...(remoteEntry?.tags ?? []), ...(rule?.tags ?? [])],
    hasLocalProfile: Boolean(localProfile),
    hasRemoteVecPatchRule,
    hasDependencyRepairs: dependencyRepairs.length > 0,
    officialSupportRequired,
    blocked,
  });
  const fixIds = uniqueStrings([
    ...(known.fixIds ?? []),
    ...(remoteEntry?.fixIds ?? []),
    ...(rule?.fix_ids ?? []),
  ]);
  const recommendedAction = blocked
    ? protectedRecommendedAction(known, remoteEntry)
    : remoteEntry?.recommendedAction ?? rule?.recommended_action ?? known.recommendedAction;
  const knownIssues = blocked
    ? uniqueStrings([
      ...(known.knownIssues ?? []),
      ...(remoteEntry?.knownIssues ?? []),
      ...(rule?.known_issues ?? []),
      "Official anti-cheat support required",
    ])
    : uniqueStrings([
      ...(known.knownIssues ?? []),
      ...(remoteEntry?.knownIssues ?? []),
      ...(rule?.known_issues ?? []),
    ]);

  return {
    game: known.game,
    status: blocked ? "Blocked" : (remoteEntry?.status ?? known.status),
    level: blocked ? "Blocked" : (remoteEntry?.level ?? known.level),
    backend: readableBackend(rule?.graphics_backend ?? remoteEntry?.backend ?? known.backend, rule?.fallback_graphics_backend ?? remoteEntry?.fallbackBackend ?? known.fallbackBackend),
    fallbackBackend: rule?.fallback_graphics_backend ?? remoteEntry?.fallbackBackend ?? known.fallbackBackend,
    steamAppId: known.steamAppId ?? remoteEntry?.steamAppId ?? rule?.steam_app_id,
    executableMatch: known.executableMatch ?? remoteEntry?.executableMatch ?? rule?.executable_match,
    trustClass: known.trustClass ?? remoteEntry?.trustClass ?? rule?.trust_class ?? "singlePlayer",
    riskLevel: blocked ? "blocked" : (known.riskLevel ?? remoteEntry?.riskLevel ?? rule?.risk_level ?? "low"),
    patchVersion: rule?.rule_version ? `v${rule.rule_version}` : remoteEntry?.patchVersion ?? "local",
    note: blocked ? officialSupportNote(known, remoteEntry, rule) : remoteEntry?.note ?? known.note,
    recommendedAction,
    recommendedFixes: recommendedFixesFor(recommendedAction, dependencyRepairs, fixIds),
    knownIssues,
    fixIds,
    hasLocalProfile: Boolean(localProfile),
    localProfile: localProfile || undefined,
    hasRemoteVecPatchRule,
    remoteRuleId: remoteRuleId || undefined,
    hasDependencyRepairs: dependencyRepairs.length > 0,
    dependencyRepairs,
    officialSupportRequired,
    supportPolicy: blocked
      ? known.supportPolicy ?? remoteEntry?.supportPolicy ?? rule?.support_policy ?? "Blocked locally. Official support required."
      : known.supportPolicy ?? remoteEntry?.supportPolicy ?? rule?.support_policy,
    tags,
    patchState: blocked
      ? "blocked"
      : hasRemoteVecPatchRule
        ? "remote-rule"
        : localProfile
          ? "local-profile"
          : "metadata-only",
    source: sourceLabel(remoteEntry, rule),
    updatedAt: rule?.updated_at ?? remoteEntry?.updatedAt,
  };
}

function compatibilityEntryFromRule(rule: VecPatchRule): CompatibilityEntry {
  const blocked = isBlockedRule(rule);
  const dependencyRepairs = uniqueStrings(rule.dependency_repairs ?? []);
  const fixIds = uniqueStrings(rule.fix_ids ?? []);
  const recommendedAction = blocked
    ? rule.recommended_action
      ?? "Use Remote Play, Steam Deck/SteamOS Proton, Moonlight/Sunshine, or Windows PC."
    : rule.recommended_action ?? "Apply the VecPatch rule, then verify launch before treating this as supported.";
  const knownIssues = blocked
    ? uniqueStrings([...(rule.known_issues ?? []), "Official anti-cheat support required"])
    : uniqueStrings(rule.known_issues ?? []);
  const hasLocalProfile = Boolean(rule.local_profile);
  const tags = coverageTags({
    tags: rule.tags ?? [],
    hasLocalProfile,
    hasRemoteVecPatchRule: true,
    hasDependencyRepairs: dependencyRepairs.length > 0,
    officialSupportRequired: Boolean(rule.official_support_required || blocked),
    blocked,
  });

  return {
    game: rule.name,
    status: blocked ? "Blocked" : "Needs Fix",
    level: blocked ? "Blocked" : "Silver",
    backend: readableBackend(rule.graphics_backend, rule.fallback_graphics_backend),
    fallbackBackend: rule.fallback_graphics_backend,
    steamAppId: rule.steam_app_id,
    executableMatch: rule.executable_match,
    trustClass: rule.trust_class ?? "singlePlayer",
    riskLevel: blocked ? "blocked" : rule.risk_level ?? "low",
    patchVersion: `v${rule.rule_version ?? 1}`,
    note: blocked
      ? rule.changelog || "Protected multiplayer rule is blocked locally until official support exists."
      : rule.changelog || "VecPatch rule exists; compatibility level has not been human-reviewed.",
    recommendedAction,
    recommendedFixes: recommendedFixesFor(recommendedAction, dependencyRepairs, fixIds),
    knownIssues,
    fixIds,
    hasLocalProfile,
    localProfile: rule.local_profile,
    hasRemoteVecPatchRule: true,
    remoteRuleId: rule.id,
    hasDependencyRepairs: dependencyRepairs.length > 0,
    dependencyRepairs,
    officialSupportRequired: Boolean(rule.official_support_required || blocked),
    supportPolicy: blocked ? rule.support_policy ?? "Blocked locally. Official support required." : rule.support_policy,
    tags,
    patchState: blocked ? "blocked" : rule.patch_state ?? "remote-rule",
    source: "remote-rule-derived",
    updatedAt: rule.updated_at,
  };
}

function findMatchingRule(known: KnownCompatibilityMetadata, rules: VecPatchRule[]) {
  return rules.find((rule) => {
    if (known.remoteRuleId && rule.id === known.remoteRuleId) {
      return true;
    }
    if (known.steamAppId && rule.steam_app_id === known.steamAppId) {
      return true;
    }
    return normalizeName(rule.name) === normalizeName(known.game);
  });
}

function findMatchingRemoteEntry(
  known: KnownCompatibilityMetadata,
  remoteByKey: Map<string, CompatibilityEntry>,
) {
  return remoteByKey.get(compatibilityKey(known.game, known.steamAppId))
    ?? remoteByKey.get(compatibilityKey(known.game))
    ?? (known.steamAppId ? remoteByKey.get(compatibilityKey("", known.steamAppId)) : undefined);
}

function ruleMatchesEntry(rule: VecPatchRule, entry: CompatibilityEntry) {
  if (entry.remoteRuleId && rule.id === entry.remoteRuleId) {
    return true;
  }
  if (entry.steamAppId && rule.steam_app_id === entry.steamAppId) {
    return true;
  }
  return normalizeName(rule.name) === normalizeName(entry.game);
}

function entriesMatch(first: CompatibilityEntry, second: CompatibilityEntry) {
  return compatibilityKey(first.game, first.steamAppId) === compatibilityKey(second.game, second.steamAppId);
}

function compareCompatibilityEntries(first: CompatibilityEntry, second: CompatibilityEntry) {
  const statusRank: Record<CompatibilityEntry["status"], number> = {
    Working: 0,
    Playable: 1,
    "Needs Fix": 2,
    Blocked: 3,
  };
  const rankDelta = statusRank[first.status] - statusRank[second.status];
  if (rankDelta !== 0) {
    return rankDelta;
  }
  return first.game.localeCompare(second.game);
}

function isBlockedRule(rule?: VecPatchRule) {
  return rule?.trust_class === "blockedAntiCheat"
    || rule?.trust_class === "protectedMultiplayer"
    || rule?.risk_level === "blocked"
    || rule?.graphics_backend === "protected";
}

function officialSupportNote(
  known: KnownCompatibilityMetadata,
  remoteEntry?: CompatibilityEntry,
  rule?: VecPatchRule,
) {
  return known.note
    || remoteEntry?.note
    || rule?.changelog
    || "Protected anti-cheat title is blocked locally until official support exists.";
}

function protectedRecommendedAction(known: KnownCompatibilityMetadata, remoteEntry?: CompatibilityEntry) {
  return known.recommendedAction
    ?? remoteEntry?.recommendedAction
    ?? "Use Remote Play, Steam Deck/SteamOS Proton, Moonlight/Sunshine, or Windows PC.";
}

function sourceLabel(remoteEntry?: CompatibilityEntry, rule?: VecPatchRule) {
  if (remoteEntry && rule) {
    return "known-and-remote";
  }
  if (rule) {
    return "patch-rule-derived";
  }
  if (remoteEntry) {
    return remoteEntry.source ?? "vecpatch";
  }
  return "known-local-metadata";
}

function coverageTags({
  tags,
  hasLocalProfile,
  hasRemoteVecPatchRule,
  hasDependencyRepairs,
  officialSupportRequired,
  blocked,
}: {
  tags: string[];
  hasLocalProfile: boolean;
  hasRemoteVecPatchRule: boolean;
  hasDependencyRepairs: boolean;
  officialSupportRequired: boolean;
  blocked: boolean;
}) {
  return uniqueStrings([
    ...tags,
    hasLocalProfile ? "local-profile" : "no-local-profile",
    hasRemoteVecPatchRule ? "remote-rule" : "no-remote-rule",
    hasDependencyRepairs ? "dependency-repair" : "no-dedicated-repair",
    officialSupportRequired ? "official-support-required" : "",
    blocked ? "blocked" : "",
  ]);
}

function recommendedFixesFor(
  recommendedAction: string | undefined,
  dependencyRepairs: string[],
  fixIds: string[],
) {
  return uniqueStrings([
    ...(recommendedAction ? [recommendedAction] : []),
    ...dependencyRepairs,
    ...fixIds.map(readableFixId),
  ]);
}

function readableFixId(fixId: string) {
  const labels: Record<string, string> = {
    exportDiagnosticBundle: "Export diagnostics",
    killMismatchedWineserver: "Reset mismatched Wine services",
    repairLauncherDependencies: "Repair launcher dependencies",
    repairMediaPlayback: "Repair media playback",
    repairRuntime: "Repair runtime DLL mirror",
    reapplyVecPatch: "Reapply VecPatch rule",
  };
  return labels[fixId] ?? fixId.replace(/([a-z0-9])([A-Z])/g, "$1 $2");
}

function compatibilityKey(game: string, steamAppId?: string) {
  const appId = steamAppId?.trim();
  return appId ? `steam:${appId}` : `name:${normalizeName(game)}`;
}

function normalizeName(value: string) {
  return value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
}

function uniqueStrings(values: string[]) {
  return Array.from(new Set(values.map((value) => value.trim()).filter(Boolean)));
}

export function formatDate(value?: string) {
  if (!value) return "Unknown";

  return new Intl.DateTimeFormat("en-AU", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "Australia/Sydney",
  }).format(new Date(value));
}

export function formatBytes(bytes: number) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "Unknown size";

  const units = ["B", "KB", "MB", "GB"];
  let size = bytes;
  let unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }

  return `${size.toFixed(unitIndex === 0 ? 0 : 1)} ${units[unitIndex]}`;
}

function mapReleaseAsset(asset: GitHubAsset): DistributionAsset {
  const lowerName = asset.name.toLowerCase();
  const kind: DistributionAsset["kind"] = lowerName.endsWith(".dmg") || lowerName.endsWith(".zip")
    ? "app"
    : lowerName.includes("manifest")
      ? "manifest"
      : lowerName.includes("plist")
        ? "metadata"
        : "runtime";

  return {
    name: asset.name,
    kind,
    sizeLabel: formatBytes(asset.size),
    digest: asset.digest,
    downloadUrl: asset.browser_download_url,
    downloadCount: asset.download_count,
    contentType: asset.content_type,
  };
}

function selectDistributionRelease(releases: GitHubRelease[]) {
  return releases.find((release) => release.assets.some(isAppReleaseAsset)) ?? releases[0];
}

function isAppReleaseAsset(asset: GitHubAsset) {
  const lowerName = asset.name.toLowerCase();
  return lowerName === "vector.dmg" || lowerName === "vector.zip";
}

async function fetchCodeSigningState(assets: DistributionAsset[]) {
  const manifestAsset = assets.find((asset) => asset.name.toLowerCase() === "manifest.json");
  if (!manifestAsset) {
    return undefined;
  }

  try {
    const response = await fetch(manifestAsset.downloadUrl, {
      next: { revalidate: 300 },
      headers: { accept: "application/json" },
    });
    if (!response.ok) {
      return undefined;
    }

    const manifest = (await response.json()) as ReleaseManifest;
    return manifest.code_signing;
  } catch {
    return undefined;
  }
}

function fallbackDistribution(): DistributionMetadata {
  return {
    channel: "stable",
    releaseName: "Runtime 2.5.0",
    tagName: "runtime-v2.5.0",
    publishedAt: "2026-02-25T23:40:25Z",
    releaseUrl: `${GITHUB_REPO_URL}/releases/tag/runtime-v2.5.0`,
    sourceUrl: GITHUB_REPO_URL,
    hasSignedApp: false,
    trustLevel: "unavailable",
    trustReason: "GitHub release metadata could not be reached.",
    unavailable: true,
    assets: [
      {
        name: "Runtime metadata unavailable",
        kind: "metadata",
        sizeLabel: "Offline fallback",
        downloadUrl: `${GITHUB_REPO_URL}/releases`,
      },
    ],
  };
}

function releaseTrustState(assets: DistributionAsset[], hasSignedApp: boolean) {
  if (hasSignedApp) {
    return {
      level: "trusted" as const,
      reason: "Signed macOS app artefact is published with Developer ID metadata.",
    };
  }

  if (assets.some((asset) => asset.kind === "app")) {
    return {
      level: "unsigned" as const,
      reason: "An app artefact is published, but the release manifest does not prove Developer ID signing.",
    };
  }

  return {
    level: "source-only" as const,
    reason: "No app artefact is published yet; release exposes source/runtime artefacts only.",
  };
}

function readableBackend(primary?: string, fallback?: string) {
  const primaryLabel = primary?.trim() ? primary : "auto";
  const fallbackLabel = fallback?.trim() ? fallback : "fallback auto";

  if (primaryLabel === fallbackLabel || primaryLabel === "protected") {
    return primaryLabel;
  }

  return `${primaryLabel} / ${fallbackLabel}`;
}

function normalizeRemoteCompatibilityEntry(raw: unknown): CompatibilityEntry {
  const entry = raw && typeof raw === "object" ? raw as Record<string, unknown> : {};
  const status = normalizeStatus(stringField(entry.status));
  const level = normalizeLevel(stringField(entry.compatibility_level) || stringField(entry.level));
  const ruleVersion = numberField(entry.rule_version);
  const dependencyRepairs = arrayField(entry.dependency_repairs);
  const fixIds = uniqueStrings([
    ...arrayField(entry.fix_ids),
    ...arrayField(entry.fixIds),
  ]);
  const localProfile = stringField(entry.local_profile) || stringField(entry.localProfile);
  const remoteRuleId = stringField(entry.remote_rule_id) || stringField(entry.remoteRuleId) || stringField(entry.rule_id);
  const trustClass = stringField(entry.trust_class) || "singlePlayer";
  const riskLevel = stringField(entry.risk_level) || "low";
  const blocked = status === "Blocked" || trustClass === "blockedAntiCheat" || riskLevel === "blocked";
  const hasLocalProfile = booleanField(entry.has_local_profile) || booleanField(entry.hasLocalProfile) || Boolean(localProfile);
  const hasRemoteVecPatchRule = booleanField(entry.has_remote_vecpatch_rule)
    || booleanField(entry.hasRemoteVecPatchRule)
    || Boolean(remoteRuleId);
  const hasDependencyRepairs = booleanField(entry.has_dependency_repairs)
    || booleanField(entry.hasDependencyRepairs)
    || dependencyRepairs.length > 0;
  const officialSupportRequired = booleanField(entry.official_support_required)
    || booleanField(entry.officialSupportRequired)
    || blocked;
  const tags = coverageTags({
    tags: arrayField(entry.tags),
    hasLocalProfile,
    hasRemoteVecPatchRule,
    hasDependencyRepairs,
    officialSupportRequired,
    blocked,
  });

  return {
    game: stringField(entry.game) || stringField(entry.name) || "Unknown game",
    status: blocked ? "Blocked" : status,
    level: blocked ? "Blocked" : level,
    backend: stringField(entry.recommended_backend) || stringField(entry.backend) || "auto",
    fallbackBackend: stringField(entry.fallback_backend),
    steamAppId: stringField(entry.steam_app_id),
    executableMatch: stringField(entry.executable_match),
    trustClass,
    riskLevel: blocked ? "blocked" : riskLevel,
    patchVersion: ruleVersion ? `v${ruleVersion}` : stringField(entry.patch_version) || "v1",
    note: stringField(entry.notes) || stringField(entry.note) || "Stable VecPatch profile available.",
    recommendedAction: stringField(entry.recommended_action),
    recommendedFixes: recommendedFixesFor(stringField(entry.recommended_action), dependencyRepairs, fixIds),
    knownIssues: uniqueStrings([
      ...arrayField(entry.known_issues),
      ...arrayField(entry.knownIssues),
    ]),
    fixIds,
    hasLocalProfile,
    localProfile,
    hasRemoteVecPatchRule,
    remoteRuleId,
    hasDependencyRepairs,
    dependencyRepairs,
    officialSupportRequired,
    supportPolicy: stringField(entry.support_policy) || stringField(entry.supportPolicy),
    tags,
    patchState: stringField(entry.patch_state) || stringField(entry.patchState) || (blocked ? "blocked" : "unknown"),
    source: stringField(entry.source) || "vecpatch",
    updatedAt: stringField(entry.updated_at),
  };
}

function recommendedFixesFor(action: string | undefined, dependencyRepairs: string[], fixIds: string[]) {
  return uniqueStrings([
    ...dependencyRepairs,
    ...fixIds.map(readableFixId),
    action ?? "",
  ]).slice(0, 4);
}

function readableFixId(value: string) {
  const labels: Record<string, string> = {
    repairRuntime: "Runtime repair",
    killMismatchedWineserver: "Wineserver reset",
    reapplyVecPatch: "Reapply VecPatch",
    repairMediaPlayback: "Media playback repair",
    repairLauncherDependencies: "Launcher dependency repair",
    exportDiagnosticBundle: "Diagnostic export",
  };
  return labels[value] ?? value;
}

function normalizeStatus(value: string): CompatibilityEntry["status"] {
  if (value === "Working" || value === "Playable" || value === "Needs Fix" || value === "Blocked") {
    return value;
  }
  return "Playable";
}

function normalizeLevel(value: string): CompatibilityEntry["level"] {
  if (value === "Platinum" || value === "Gold" || value === "Silver" || value === "Blocked") {
    return value;
  }
  return "Silver";
}

function stringField(value: unknown) {
  return typeof value === "string" ? value : "";
}

function numberField(value: unknown) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function booleanField(value: unknown) {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "string") {
    return value.toLowerCase() === "true";
  }
  return false;
}

function arrayField(value: unknown) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((entry) => String(entry ?? "")).filter(Boolean);
}
