import Link from "next/link";
import { DatabaseZap, ShieldAlert, Sparkles } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { CompatibilityExplorer } from "@/components/site/compatibility-explorer";
import { CompatibilityReportForm } from "@/components/site/compatibility-report-form";
import { getCompatibilityDatabase, formatDate } from "@/lib/vecpatch";

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
            This page is generated from live VecPatch rules, then layered with a tiny human-readable status map so the database stays useful instead of turning into raw launch arguments.
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
            Rule count, backend preference, risk level, and trust class are pulled from <code className="text-white">/api/v1/patches</code>.
          </p>
        </Card>
        <Card className="border-white/10 bg-white/[0.035] p-5">
          <Sparkles className="size-5 text-[var(--vector-signal)]" />
          <h2 className="mt-5 font-semibold text-white">Consumer readable</h2>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            The public table avoids dumping every override. It focuses on status, compatibility level, backend, and the one note that matters.
          </p>
        </Card>
        <Card className="border-white/10 bg-white/[0.035] p-5">
          <ShieldAlert className="size-5 text-[var(--vector-warning)]" />
          <h2 className="mt-5 font-semibold text-white">Last generated</h2>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">{formatDate(compatibility.generatedAt)}</p>
          <Button variant="outline" className="mt-5 border-white/15 bg-black/20 text-white hover:bg-white/[0.08]" asChild>
            <Link href="/vecpatch">Inspect patch rules</Link>
          </Button>
        </Card>
      </div>
    </section>
  );
}
