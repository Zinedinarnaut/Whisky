import Link from "next/link";
import { DatabaseZap, ShieldAlert, Sparkles } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { CompatibilityReportForm } from "@/components/site/compatibility-report-form";
import { getCompatibilityDatabase, formatDate } from "@/lib/vecpatch";
import { CompatibilityExplorer } from "./compatibility-explorer";

export const revalidate = 120;

export const metadata = {
  title: "Vector Compatibility Database",
  description: "Live Vector compatibility statuses derived from VecPatch rules.",
};

export default async function CompatibilityPage() {
  const compatibility = await getCompatibilityDatabase();
  const entries = compatibility.entries;
  const working = entries.filter((entry) => entry.status === "Working").length;
  const playable = entries.filter((entry) => entry.status === "Playable").length;
  const blocked = entries.filter((entry) => entry.status === "Blocked").length;
  const localProfiles = entries.filter((entry) => entry.hasLocalProfile).length;
  const remoteRules = entries.filter((entry) => entry.hasRemoteVecPatchRule).length;
  const dependencyRepairs = entries.filter((entry) => entry.hasDependencyRepairs).length;
  const fixAware = entries.filter((entry) => entry.recommendedFixes.length || entry.fixIds.length).length;
  const knownIssues = entries.filter((entry) => entry.knownIssues?.length).length;

  return (
    <section className="mx-auto w-full max-w-7xl px-5 py-16 sm:px-8 sm:py-24">
      <div className="grid gap-10 lg:grid-cols-[0.8fr_1.2fr] lg:items-start">
        <div>
          <Badge className="bg-[var(--vector-aqua)]/10 text-[var(--vector-aqua)] hover:bg-[var(--vector-aqua)]/10">
            Compatibility Database
          </Badge>
          <h1 className="mt-6 text-balance text-5xl font-semibold tracking-[-0.06em] text-white sm:text-7xl">
            Game status without the forum archaeology.
          </h1>
          <p className="mt-5 text-lg leading-8 text-muted-foreground">
            This page merges live VecPatch rules with the local known-game matrix. It separates
            local profiles, remote rules, backend intent, fix metadata, and known issues so
            metadata does not become a fake support claim.
          </p>
          <div className="mt-8 grid gap-3 sm:grid-cols-3 lg:grid-cols-1 xl:grid-cols-3">
            {[
              ["Working", working, "var(--vector-signal)"],
              ["Playable", playable, "var(--vector-aqua)"],
              ["Blocked", blocked, "var(--vector-danger)"],
            ].map(([label, value, color]) => (
              <Card key={String(label)} className="border-white/10 bg-white/[0.035] p-4">
                <p className="text-xs uppercase tracking-[0.18em] text-muted-foreground">{label}</p>
                <p className="mt-2 font-mono text-3xl text-white" style={{ color: String(color) }}>{value}</p>
              </Card>
            ))}
          </div>
          <div className="mt-6 flex flex-col gap-3 sm:flex-row">
            <CompatibilityReportForm />
            <Button variant="outline" className="rounded-full border-white/15 bg-black/20 text-white hover:bg-white/[0.08]" asChild>
              <Link href="/install">Install guide</Link>
            </Button>
          </div>
        </div>

        <CompatibilityExplorer entries={entries} />
      </div>

      <div className="mt-8 grid gap-4 lg:grid-cols-3">
        <Card className="border-white/10 bg-white/[0.035] p-5">
          <DatabaseZap className="size-5 text-[var(--vector-aqua)]" />
          <h2 className="mt-5 font-semibold text-white">Backed by VecPatch</h2>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            {remoteRules} entries expose a remote rule. Backend preference, risk level, and trust class are pulled from <code className="text-white">/api/v1/patches</code> when available.
          </p>
        </Card>
        <Card className="border-white/10 bg-white/[0.035] p-5">
          <Sparkles className="size-5 text-[var(--vector-signal)]" />
          <h2 className="mt-5 font-semibold text-white">Local profile aware</h2>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            {localProfiles} entries have a local Vector profile, {dependencyRepairs} expose dependency repair guidance, and {fixAware} publish explicit fix metadata.
          </p>
        </Card>
        <Card className="border-white/10 bg-white/[0.035] p-5">
          <ShieldAlert className="size-5 text-[var(--vector-warning)]" />
          <h2 className="mt-5 font-semibold text-white">Known issues stay visible</h2>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            {knownIssues} entries expose known issue metadata. {blocked} protected or blocked entries require official support before local play. Last generated: {formatDate(compatibility.generatedAt)}.
          </p>
          <Button variant="outline" className="mt-5 border-white/15 bg-black/20 text-white hover:bg-white/[0.08]" asChild>
            <Link href="/vecpatch">Inspect patch rules</Link>
          </Button>
        </Card>
      </div>
    </section>
  );
}
