"use client";

import { useMemo, useState } from "react";
import {
  CheckCircle2,
  RadioTower,
  Search,
  ShieldAlert,
  SlidersHorizontal,
  Wrench,
  type LucideIcon,
} from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import type { CompatibilityEntry } from "@/lib/vecpatch";

const all = "all";

const statusClass: Record<string, string> = {
  Working: "border-[var(--vector-signal)]/30 bg-[var(--vector-signal)]/10 text-[var(--vector-signal)]",
  Playable: "border-[var(--vector-aqua)]/30 bg-[var(--vector-aqua)]/10 text-[var(--vector-aqua)]",
  "Needs Fix": "border-[var(--vector-warning)]/30 bg-[var(--vector-warning)]/10 text-[var(--vector-warning)]",
  Blocked: "border-[var(--vector-danger)]/30 bg-[var(--vector-danger)]/10 text-[var(--vector-danger)]",
};

type CoverageFilter = "all" | "local" | "remote" | "repairs" | "blocked" | "metadata-only";

type CompatibilityExplorerProps = {
  entries: CompatibilityEntry[];
};

export function CompatibilityExplorer({ entries }: CompatibilityExplorerProps) {
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState(all);
  const [backend, setBackend] = useState(all);
  const [trustClass, setTrustClass] = useState(all);
  const [tag, setTag] = useState(all);
  const [coverage, setCoverage] = useState<CoverageFilter>("all");

  const statusOptions = unique(entries.map((entry) => entry.status));
  const backendOptions = unique(entries.flatMap((entry) => [entry.backend, entry.fallbackBackend ?? ""]));
  const trustOptions = unique(entries.map((entry) => entry.trustClass));
  const tagOptions = unique(entries.flatMap((entry) => entry.tags));

  const filteredEntries = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();

    return entries.filter((entry) => {
      const matchesQuery = !normalizedQuery || [
        entry.game,
        entry.note,
        entry.recommendedAction ?? "",
        entry.steamAppId ?? "",
        entry.executableMatch ?? "",
        entry.backend,
        entry.fallbackBackend ?? "",
        entry.localProfile ?? "",
        entry.remoteRuleId ?? "",
        entry.dependencyRepairs.join(" "),
        entry.tags.join(" "),
        entry.supportPolicy ?? "",
      ].join("\n").toLowerCase().includes(normalizedQuery);
      const matchesStatus = status === all || entry.status === status;
      const matchesBackend = backend === all || entry.backend.includes(backend) || entry.fallbackBackend === backend;
      const matchesTrust = trustClass === all || entry.trustClass === trustClass;
      const matchesTag = tag === all || entry.tags.includes(tag);
      const matchesCoverage = coverage === "all" || coverageMatches(entry, coverage);

      return matchesQuery && matchesStatus && matchesBackend && matchesTrust && matchesTag && matchesCoverage;
    });
  }, [backend, coverage, entries, query, status, tag, trustClass]);

  return (
    <div className="space-y-4">
      <Card className="border-white/10 bg-white/[0.035] p-4">
        <div className="grid gap-3 lg:grid-cols-[1fr_160px_170px_190px] xl:grid-cols-[1fr_150px_160px_175px_190px_190px]">
          <label className="relative block">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search game, Steam ID, tag, local profile, remote rule, repair..."
              className="h-11 border-white/10 bg-black/30 pl-10 text-white placeholder:text-muted-foreground"
            />
          </label>
          <FilterSelect label="Status" value={status} onChange={setStatus} options={statusOptions} />
          <FilterSelect label="Backend" value={backend} onChange={setBackend} options={backendOptions} />
          <FilterSelect label="Trust" value={trustClass} onChange={setTrustClass} options={trustOptions} />
          <FilterSelect label="Tag" value={tag} onChange={setTag} options={tagOptions} />
          <label className="block">
            <span className="sr-only">Coverage</span>
            <select
              value={coverage}
              onChange={(event) => setCoverage(event.target.value as CoverageFilter)}
              className="h-11 w-full rounded-xl border border-white/10 bg-black/30 px-3 text-sm text-white outline-none transition hover:bg-white/[0.06] focus:border-[var(--vector-signal)]/40"
            >
              <option value="all">Coverage: all</option>
              <option value="local">Has local profile</option>
              <option value="remote">Has remote rule</option>
              <option value="repairs">Has dependency repairs</option>
              <option value="blocked">Blocked / official support</option>
              <option value="metadata-only">Metadata only</option>
            </select>
          </label>
        </div>
        <div className="mt-4 flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
          <SlidersHorizontal className="size-4" />
          <span>{filteredEntries.length} of {entries.length} entries</span>
          {status !== all ? <Badge className="bg-white/10 text-white hover:bg-white/10">{status}</Badge> : null}
          {backend !== all ? <Badge className="bg-white/10 text-white hover:bg-white/10">{backend}</Badge> : null}
          {trustClass !== all ? <Badge className="bg-white/10 text-white hover:bg-white/10">{trustClass}</Badge> : null}
          {tag !== all ? <Badge className="bg-white/10 text-white hover:bg-white/10">{tag}</Badge> : null}
          {coverage !== "all" ? <Badge className="bg-white/10 text-white hover:bg-white/10">{coverage}</Badge> : null}
        </div>
      </Card>

      <Card className="overflow-hidden border-white/10 bg-white/[0.035]">
        <CardHeader className="border-b border-white/10">
          <CardTitle className="text-white">Live compatibility database</CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          <div className="grid grid-cols-[1.05fr_0.65fr_1.15fr_1.45fr] border-b border-white/10 px-5 py-3 text-xs uppercase tracking-[0.18em] text-muted-foreground max-lg:hidden">
            <span>Game</span>
            <span>Status</span>
            <span>Patch coverage</span>
            <span>Notes</span>
          </div>
          {filteredEntries.map((entry) => (
            <div
              key={`${entry.game}-${entry.patchVersion}-${entry.remoteRuleId ?? entry.localProfile ?? "metadata"}`}
              className="grid gap-4 border-b border-white/10 px-5 py-5 last:border-b-0 lg:grid-cols-[1.05fr_0.65fr_1.15fr_1.45fr] lg:items-start"
            >
              <div>
                <span className="font-medium text-white">{entry.game}</span>
                <div className="mt-1 flex flex-wrap gap-2 font-mono text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                  <span>{entry.level}</span>
                  <span>{entry.patchVersion}</span>
                  {entry.steamAppId ? <span>Steam {entry.steamAppId}</span> : null}
                </div>
                <div className="mt-3 flex flex-wrap gap-1.5">
                  {entry.tags.slice(0, 5).map((entryTag) => (
                    <Badge key={entryTag} variant="outline" className="border-white/10 bg-black/20 text-[10px] text-muted-foreground">
                      {entryTag}
                    </Badge>
                  ))}
                </div>
              </div>
              <span>
                <Badge variant="outline" className={statusClass[entry.status] ?? ""}>
                  {entry.status}
                </Badge>
              </span>
              <div className="space-y-2 text-sm text-muted-foreground">
                <CoverageLine icon={CheckCircle2} active={entry.hasLocalProfile} label="Local profile" value={entry.localProfile} />
                <CoverageLine icon={RadioTower} active={entry.hasRemoteVecPatchRule} label="Remote rule" value={entry.remoteRuleId} />
                <CoverageLine
                  icon={Wrench}
                  active={entry.hasDependencyRepairs}
                  label="Repairs"
                  value={entry.dependencyRepairs.length ? entry.dependencyRepairs.join(", ") : undefined}
                />
                {entry.officialSupportRequired ? (
                  <CoverageLine icon={ShieldAlert} active label="Policy" value={entry.supportPolicy ?? "Official support required"} danger />
                ) : null}
              </div>
              <div>
                <p className="text-sm leading-6 text-muted-foreground">{entry.note}</p>
                {entry.recommendedAction ? (
                  <p className="mt-2 text-xs leading-5 text-white/60">Action: {entry.recommendedAction}</p>
                ) : null}
                {entry.knownIssues?.length ? (
                  <p className="mt-2 text-xs leading-5 text-[var(--vector-warning)]/80">
                    Known issue: {entry.knownIssues.join(", ")}
                  </p>
                ) : null}
              </div>
            </div>
          ))}
        </CardContent>
      </Card>
    </div>
  );
}

function CoverageLine({
  icon: Icon,
  active,
  label,
  value,
  danger,
}: {
  icon: LucideIcon;
  active: boolean;
  label: string;
  value?: string;
  danger?: boolean;
}) {
  const color = danger ? "text-[var(--vector-danger)]" : active ? "text-[var(--vector-signal)]" : "text-muted-foreground";

  return (
    <div className="flex gap-2">
      <Icon className={`mt-0.5 size-3.5 shrink-0 ${color}`} />
      <span>
        <span className="text-white/70">{label}: </span>
        <span className={color}>{value ?? (active ? "available" : "not present")}</span>
      </span>
    </div>
  );
}

function FilterSelect({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: string[];
}) {
  return (
    <label className="block">
      <span className="sr-only">{label}</span>
      <select
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="h-11 w-full rounded-xl border border-white/10 bg-black/30 px-3 text-sm text-white outline-none transition hover:bg-white/[0.06] focus:border-[var(--vector-signal)]/40"
      >
        <option value={all}>{label}: all</option>
        {options.map((option) => (
          <option key={option} value={option}>{option}</option>
        ))}
      </select>
    </label>
  );
}

function coverageMatches(entry: CompatibilityEntry, coverage: CoverageFilter) {
  switch (coverage) {
    case "local":
      return entry.hasLocalProfile;
    case "remote":
      return entry.hasRemoteVecPatchRule;
    case "repairs":
      return entry.hasDependencyRepairs;
    case "blocked":
      return entry.status === "Blocked" || Boolean(entry.officialSupportRequired);
    case "metadata-only":
      return !entry.hasLocalProfile && !entry.hasRemoteVecPatchRule;
    default:
      return true;
  }
}

function unique(values: string[]) {
  return Array.from(new Set(values.filter(Boolean))).sort((first, second) => first.localeCompare(second));
}
