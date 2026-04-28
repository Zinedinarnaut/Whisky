import Link from "next/link";
import { Apple, CheckCircle2, Download, HardDrive, ShieldCheck, TerminalSquare } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { getDistributionMetadata, formatDate } from "@/lib/vecpatch";

export const revalidate = 300;

export const metadata = {
  title: "Install Vector",
  description: "Install guide, macOS requirements, and first launch steps for Vector.",
};

const requirements = [
  "Apple Silicon Mac recommended",
  "macOS 14 or newer recommended",
  "Rosetta 2 installed for x86 Windows games",
  "At least 20 GB free disk space for bottles and runtimes",
  "A Steam/Epic/GOG account for owned games",
];

const steps = [
  {
    icon: Download,
    title: "Download Vector",
    text: "Use the Distribution Centre. If the current channel only exposes runtime artefacts, wait for the signed app release pipeline to publish Vector.dmg or Vector.zip.",
  },
  {
    icon: ShieldCheck,
    title: "Open and approve macOS security",
    text: "Move Vector to Applications. If Gatekeeper asks, open System Settings → Privacy & Security and approve Vector once.",
  },
  {
    icon: HardDrive,
    title: "Pick bottle storage",
    text: "Create bottles on your internal drive or external storage. Fast SSD storage is strongly recommended for games.",
  },
  {
    icon: TerminalSquare,
    title: "Let Vector prepare runtimes",
    text: "Vector downloads runtime payloads, checks Wine/wineserver consistency, installs missing dependencies, and syncs VecPatch rules.",
  },
];

export default async function InstallPage() {
  const distribution = await getDistributionMetadata();
  const appAsset = distribution.assets.find((asset) => asset.kind === "app");

  return (
    <section className="mx-auto w-full max-w-7xl px-5 py-16 sm:px-8 sm:py-24">
      <div className="grid gap-10 lg:grid-cols-[0.85fr_1.15fr] lg:items-start">
        <div>
          <Badge className="bg-[var(--vector-signal)]/10 text-[var(--vector-signal)] hover:bg-[var(--vector-signal)]/10">
            Install Guide
          </Badge>
          <h1 className="mt-6 text-balance text-5xl font-semibold tracking-[-0.06em] text-white sm:text-7xl">
            First launch should feel boring. That is the point.
          </h1>
          <p className="mt-5 text-lg leading-8 text-muted-foreground">
            This page keeps the consumer path clear: download, approve macOS security once, choose bottle storage, then let Vector handle runtime setup and VecPatch sync.
          </p>
          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <Button className="rounded-full bg-[var(--vector-signal)] text-black hover:bg-[var(--vector-signal)]/90" asChild>
              <Link href={appAsset?.downloadUrl ?? "/download"} target={appAsset ? "_blank" : undefined} rel={appAsset ? "noreferrer" : undefined}>
                {appAsset ? "Download app" : "Open Distribution Centre"}
              </Link>
            </Button>
            <Button variant="outline" className="rounded-full border-white/15 bg-black/20 text-white hover:bg-white/[0.08]" asChild>
              <Link href="/compatibility">Check games first</Link>
            </Button>
          </div>
        </div>

        <Card className="border-white/10 bg-white/[0.035] p-6">
          <Apple className="size-6 text-[var(--vector-signal)]" />
          <h2 className="mt-5 text-2xl font-semibold tracking-[-0.04em] text-white">Current channel</h2>
          <div className="mt-5 grid gap-3">
            {[
              ["Release", distribution.tagName],
              ["Published", formatDate(distribution.publishedAt)],
              ["App artefact", appAsset ? appAsset.name : "Not published yet"],
              ["Channel", distribution.channel],
            ].map(([label, value]) => (
              <div key={label} className="flex items-center justify-between rounded-2xl border border-white/10 bg-black/20 px-4 py-3">
                <span className="text-sm text-muted-foreground">{label}</span>
                <span className="font-mono text-xs uppercase tracking-[0.14em] text-white">{value}</span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <div className="mt-14 grid gap-4 lg:grid-cols-4">
        {steps.map(({ icon: Icon, title, text }) => (
          <Card key={title} className="border-white/10 bg-white/[0.035] p-5">
            <Icon className="size-5 text-[var(--vector-signal)]" />
            <h2 className="mt-5 font-semibold text-white">{title}</h2>
            <p className="mt-2 text-sm leading-6 text-muted-foreground">{text}</p>
          </Card>
        ))}
      </div>

      <Card className="mt-8 border-white/10 bg-[#0b0d0c]/90 p-6">
        <h2 className="text-2xl font-semibold tracking-[-0.04em] text-white">Requirements</h2>
        <div className="mt-5 grid gap-3 md:grid-cols-2">
          {requirements.map((requirement) => (
            <div key={requirement} className="flex gap-3 rounded-2xl border border-white/10 bg-white/[0.035] p-4">
              <CheckCircle2 className="mt-0.5 size-4 shrink-0 text-[var(--vector-signal)]" />
              <span className="text-sm leading-6 text-muted-foreground">{requirement}</span>
            </div>
          ))}
        </div>
      </Card>
    </section>
  );
}
