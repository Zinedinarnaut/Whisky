import Link from "next/link";
import { ArrowUpRight, Download, FileJson, Package, RadioTower, ShieldCheck } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { getDistributionMetadata, getVecPatchManifest, formatDate } from "@/lib/vecpatch";

export const revalidate = 300;

export const metadata = {
  title: "Vector Distribution Centre",
  description: "Download Vector artefacts, runtime payloads, release metadata, and VecPatch channel status.",
};

const assetIcons = {
  app: Package,
  runtime: Download,
  manifest: FileJson,
  metadata: ShieldCheck,
  source: Package,
};

export default async function DownloadPage() {
  const [distribution, manifest] = await Promise.all([getDistributionMetadata(), getVecPatchManifest()]);
  const runtimeAsset = distribution.assets.find((asset) => asset.kind === "runtime");
  const appAsset = distribution.assets.find((asset) => asset.kind === "app");
  const primaryAsset = appAsset ?? runtimeAsset ?? distribution.assets[0];

  return (
    <section className="vector-grid min-h-screen border-b border-white/10">
      <div className="mx-auto w-full max-w-7xl px-5 py-16 sm:px-8 sm:py-24">
        <div className="grid gap-10 lg:grid-cols-[0.9fr_1.1fr] lg:items-start">
          <div>
            <Badge className="bg-[var(--vector-signal)]/10 text-[var(--vector-signal)] hover:bg-[var(--vector-signal)]/10">
              Distribution Centre
            </Badge>
            <h1 className="mt-6 text-balance text-5xl font-semibold tracking-[-0.06em] text-white sm:text-7xl">
              Downloads with the boring metadata left intact.
            </h1>
            <p className="mt-5 text-lg leading-8 text-muted-foreground">
              The distribution centre exposes release channels, runtime artefacts, hashes, VecPatch state, and source links so Vector installs can be verified instead of guessed.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              {primaryAsset ? (
                <Button size="lg" className="rounded-full bg-[var(--vector-signal)] text-black hover:bg-[var(--vector-signal)]/90" asChild>
                  <Link href={primaryAsset.downloadUrl} target="_blank" rel="noreferrer">
                    Download {primaryAsset.kind === "app" ? "Vector" : primaryAsset.name}
                    <Download className="ml-2 size-4" />
                  </Link>
                </Button>
              ) : null}
              <Button size="lg" variant="outline" className="rounded-full border-white/15 bg-white/[0.03] text-white hover:bg-white/[0.08]" asChild>
                <Link href="/install">
                  Install guide <ArrowUpRight className="ml-2 size-4" />
                </Link>
              </Button>
              <Button size="lg" variant="ghost" className="rounded-full text-muted-foreground hover:text-white" asChild>
                <Link href={distribution.releaseUrl} target="_blank" rel="noreferrer">Open GitHub release</Link>
              </Button>
            </div>
            {!distribution.hasSignedApp ? (
              <p className="mt-4 max-w-xl text-sm leading-6 text-[var(--vector-warning)]">
                {distribution.trustReason}
              </p>
            ) : null}
          </div>

          <Card className="border-white/10 bg-[#0b0d0c]/90 shadow-2xl shadow-black/40">
            <CardHeader className="border-b border-white/10">
              <CardTitle className="flex items-center justify-between gap-4 text-white">
                <span>{distribution.releaseName}</span>
                <Badge variant="outline" className="border-[var(--vector-signal)]/30 bg-[var(--vector-signal)]/10 text-[var(--vector-signal)]">
                  {distribution.channel}
                </Badge>
              </CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              {[
                ["Release", distribution.tagName],
                ["Published", formatDate(distribution.publishedAt)],
                ["Code signing", distribution.codeSigning ?? "unknown"],
                ["Trust", distribution.trustLevel],
                ["VecPatch rules", String(manifest.metadata?.rule_count ?? manifest.rules.length)],
                ["Signature mode", manifest.metadata?.signature_mode ?? "unknown"],
                ["Dispatch commit", manifest.commit_sha?.slice(0, 12) ?? "unknown"],
              ].map(([label, value]) => (
                <div key={label} className="flex items-center justify-between border-b border-white/10 px-5 py-4">
                  <span className="text-sm text-muted-foreground">{label}</span>
                  <span className="font-mono text-xs uppercase tracking-[0.14em] text-white">{value}</span>
                </div>
              ))}
            </CardContent>
          </Card>
        </div>

        <div className="mt-14 grid gap-4 lg:grid-cols-3">
          {distribution.assets.map((asset) => {
            const Icon = assetIcons[asset.kind];
            return (
              <Card key={`${asset.kind}-${asset.name}`} className="border-white/10 bg-white/[0.035]">
                <CardHeader>
                  <div className="flex items-start justify-between gap-4">
                    <div className="grid size-10 place-items-center rounded-2xl bg-white/[0.06]">
                      <Icon className="size-5 text-[var(--vector-signal)]" />
                    </div>
                    <Badge variant="outline" className="border-white/10 bg-black/20 text-muted-foreground">
                      {asset.kind}
                    </Badge>
                  </div>
                  <CardTitle className="text-xl text-white">{asset.name}</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="grid gap-3 text-sm">
                    <div className="flex justify-between gap-3">
                      <span className="text-muted-foreground">Size</span>
                      <span className="font-mono text-white">{asset.sizeLabel}</span>
                    </div>
                    <div className="flex justify-between gap-3">
                      <span className="text-muted-foreground">Downloads</span>
                      <span className="font-mono text-white">{asset.downloadCount ?? "-"}</span>
                    </div>
                    {asset.digest ? (
                      <div>
                        <span className="text-muted-foreground">Digest</span>
                        <p className="mt-1 break-all font-mono text-xs leading-5 text-white/80">{asset.digest}</p>
                      </div>
                    ) : null}
                  </div>
                  <Separator className="my-5 bg-white/10" />
                  <Button variant="outline" className="w-full border-white/15 bg-black/20 text-white hover:bg-white/[0.08]" asChild>
                    <Link href={asset.downloadUrl} target="_blank" rel="noreferrer">
                      Download artefact <ArrowUpRight className="ml-2 size-4" />
                    </Link>
                  </Button>
                </CardContent>
              </Card>
            );
          })}
        </div>

        <Card className="mt-6 border-white/10 bg-[linear-gradient(145deg,rgba(124,231,223,0.10),rgba(255,255,255,0.035))] p-6">
          <RadioTower className="size-5 text-[var(--vector-aqua)]" />
          <h2 className="mt-4 text-2xl font-semibold tracking-[-0.04em] text-white">Distribution API shape</h2>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-muted-foreground">
            The website also exposes local JSON routes for consumers and future app update flows: <code className="text-white">/api/distribution</code>, <code className="text-white">/api/vecpatch</code>, and <code className="text-white">/api/compatibility</code>.
          </p>
        </Card>
      </div>
    </section>
  );
}
