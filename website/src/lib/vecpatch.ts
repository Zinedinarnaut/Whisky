export const vecPatchBaseURL = process.env.NEXT_PUBLIC_VECPATCH_API_URL ?? "https://vector.nanite.com.au";
const GITHUB_RELEASE_URL = "https://api.github.com/repos/Zinedinarnaut/Whisky/releases/latest";
const GITHUB_REPO_URL = "https://github.com/Zinedinarnaut/Whisky";

export type PatchRiskLevel = "low" | "medium" | "high" | "blocked" | string;
export type GameTrustClass = "singlePlayer" | "moddingAllowed" | "protectedMultiplayer" | "blockedAntiCheat" | string;

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
  knownIssues?: string[];
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
      changelog: "Blocked locally until official Embark/EAC support exists.",
    },
  ],
};

const compatibilityNotes: Record<string, Partial<CompatibilityEntry>> = {
  "ARC Raiders": {
    status: "Blocked",
    level: "Blocked",
    note: "Protected multiplayer title. Local launch is blocked until official Embark/EAC support exists.",
  },
  "Minecraft Dungeons": {
    status: "Playable",
    level: "Gold",
    note: "Steam build launches; Microsoft/Xbox auth and WebView plumbing are the remaining rough edges.",
  },
  "Content Warning": {
    status: "Playable",
    level: "Gold",
    note: "Uses a DXVK-first D3D11 profile with dependency checks for startup stability.",
  },
  "Parcel Simulator": {
    status: "Working",
    level: "Platinum",
    note: "Known working with the stable UE profile and launcher-safe overrides.",
  },
  "Lethal Company": {
    status: "Working",
    level: "Platinum",
    note: "Known working baseline profile.",
  },
  Hydroneer: {
    status: "Working",
    level: "Platinum",
    note: "Known working baseline profile.",
  },
  Satisfactory: {
    status: "Playable",
    level: "Gold",
    note: "DX11 fallback profile for reliable startup.",
  },
  "Escape the Backrooms": {
    status: "Playable",
    level: "Gold",
    note: "Unreal DX11 fallback profile.",
  },
};

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

      const entries = (payload.entries ?? []).map(normalizeRemoteCompatibilityEntry);
      return {
        service: payload.service ?? "vecpatch",
        version: payload.version ?? 1,
        source: payload.source,
        generatedAt: payload.generated_at ?? new Date().toISOString(),
        metadata: {
          channel: payload.metadata?.channel ?? "stable",
          entryCount: payload.metadata?.entry_count ?? entries.length,
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
    const response = await fetch(GITHUB_RELEASE_URL, {
      next: { revalidate: 300 },
      headers: { accept: "application/vnd.github+json" },
    });

    if (!response.ok) {
      return fallbackDistribution();
    }

    const release = (await response.json()) as GitHubRelease;
    const assets = release.assets.map(mapReleaseAsset);
    const hasSignedApp = assets.some((asset) => asset.kind === "app");

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
      assets,
    };
  } catch {
    return fallbackDistribution();
  }
}

export function deriveCompatibilityEntries(manifest: VecPatchManifest): CompatibilityEntry[] {
  return [...manifest.rules]
    .filter((rule) => rule.enabled)
    .sort((first, second) => (first.priority ?? 999) - (second.priority ?? 999))
    .map((rule) => {
      const override = compatibilityNotes[rule.name] ?? {};
      const blocked = rule.trust_class === "blockedAntiCheat" || rule.risk_level === "blocked";
      const status = override.status ?? (blocked ? "Blocked" : "Playable");
      const level = override.level ?? (blocked ? "Blocked" : "Silver");

      return {
        game: rule.name,
        status,
        level,
        backend: readableBackend(rule.graphics_backend, rule.fallback_graphics_backend),
        fallbackBackend: rule.fallback_graphics_backend,
        steamAppId: rule.steam_app_id,
        executableMatch: rule.executable_match,
        trustClass: rule.trust_class ?? "singlePlayer",
        riskLevel: rule.risk_level ?? "low",
        patchVersion: `v${rule.rule_version ?? 1}`,
        note: override.note ?? rule.changelog ?? "Stable VecPatch profile available.",
        recommendedAction: blocked ? "Use Remote Play, Steam Deck, or a Windows PC until official support exists." : "Apply the recommended VecPatch profile in Vector.",
        knownIssues: blocked ? ["Official anti-cheat support required"] : [],
        source: "patch-rule-derived",
        updatedAt: rule.updated_at,
      };
    });
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

function fallbackDistribution(): DistributionMetadata {
  return {
    channel: "stable",
    releaseName: "Runtime 2.5.0",
    tagName: "runtime-v2.5.0",
    publishedAt: "2026-02-25T23:40:25Z",
    releaseUrl: `${GITHUB_REPO_URL}/releases/tag/runtime-v2.5.0`,
    sourceUrl: GITHUB_REPO_URL,
    hasSignedApp: false,
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

  return {
    game: stringField(entry.game) || stringField(entry.name) || "Unknown game",
    status,
    level,
    backend: stringField(entry.recommended_backend) || stringField(entry.backend) || "auto",
    fallbackBackend: stringField(entry.fallback_backend),
    steamAppId: stringField(entry.steam_app_id),
    executableMatch: stringField(entry.executable_match),
    trustClass: stringField(entry.trust_class) || "singlePlayer",
    riskLevel: stringField(entry.risk_level) || "low",
    patchVersion: ruleVersion ? `v${ruleVersion}` : stringField(entry.patch_version) || "v1",
    note: stringField(entry.notes) || stringField(entry.note) || "Stable VecPatch profile available.",
    recommendedAction: stringField(entry.recommended_action),
    knownIssues: arrayField(entry.known_issues),
    source: stringField(entry.source) || "vecpatch",
    updatedAt: stringField(entry.updated_at),
  };
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

function arrayField(value: unknown) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((entry) => String(entry ?? "")).filter(Boolean);
}
