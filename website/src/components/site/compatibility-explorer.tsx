"use client";

import { useMemo, useState } from "react";
import { Search, SlidersHorizontal } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { CompatibilityTable } from "@/components/site/compatibility-table";
import type { CompatibilityEntry } from "@/lib/vecpatch";

const all = "all";

function unique(values: string[]) {
  return Array.from(new Set(values.filter(Boolean))).sort((first, second) => first.localeCompare(second));
}

type CompatibilityExplorerProps = {
  entries: CompatibilityEntry[];
};

export function CompatibilityExplorer({ entries }: CompatibilityExplorerProps) {
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState(all);
  const [backend, setBackend] = useState(all);
  const [trustClass, setTrustClass] = useState(all);

  const statusOptions = unique(entries.map((entry) => entry.status));
  const backendOptions = unique(entries.flatMap((entry) => [entry.backend, entry.fallbackBackend ?? ""]));
  const trustOptions = unique(entries.map((entry) => entry.trustClass));

  const filteredEntries = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();

    return entries.filter((entry) => {
      const matchesQuery = !normalizedQuery || [
        entry.game,
        entry.note,
        entry.steamAppId ?? "",
        entry.executableMatch ?? "",
        entry.backend,
        entry.fallbackBackend ?? "",
      ].join("\n").toLowerCase().includes(normalizedQuery);
      const matchesStatus = status === all || entry.status === status;
      const matchesBackend = backend === all || entry.backend.includes(backend) || entry.fallbackBackend === backend;
      const matchesTrust = trustClass === all || entry.trustClass === trustClass;

      return matchesQuery && matchesStatus && matchesBackend && matchesTrust;
    });
  }, [backend, entries, query, status, trustClass]);

  return (
    <div className="space-y-4">
      <Card className="border-white/10 bg-white/[0.035] p-4">
        <div className="grid gap-3 lg:grid-cols-[1fr_180px_180px_210px]">
          <label className="relative block">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search game, Steam ID, executable, backend..."
              className="h-11 border-white/10 bg-black/30 pl-10 text-white placeholder:text-muted-foreground"
            />
          </label>
          <FilterSelect label="Status" value={status} onChange={setStatus} options={statusOptions} />
          <FilterSelect label="Backend" value={backend} onChange={setBackend} options={backendOptions} />
          <FilterSelect label="Trust" value={trustClass} onChange={setTrustClass} options={trustOptions} />
        </div>
        <div className="mt-4 flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
          <SlidersHorizontal className="size-4" />
          <span>{filteredEntries.length} of {entries.length} entries</span>
          {status !== all ? <Badge className="bg-white/10 text-white hover:bg-white/10">{status}</Badge> : null}
          {backend !== all ? <Badge className="bg-white/10 text-white hover:bg-white/10">{backend}</Badge> : null}
          {trustClass !== all ? <Badge className="bg-white/10 text-white hover:bg-white/10">{trustClass}</Badge> : null}
        </div>
      </Card>
      <CompatibilityTable entries={filteredEntries} title="Live compatibility database" />
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
