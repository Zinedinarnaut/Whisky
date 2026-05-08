import Link from "next/link";
import {
  ArrowUpRight,
  CheckCircle2,
  LockKeyhole,
  RadioTower,
  RotateCcw,
  ShieldAlert,
  ShieldCheck,
  Wrench,
  type LucideIcon,
} from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { getVecPatchManifest, formatDate } from "@/lib/vecpatch";

export const revalidate = 120;

export const metadata = {
  title: "VecPatch Dispatch",
  description: "Live Vector patch dispatch rules, signatures, trust classes, and backend metadata.",
};

const riskClass: Record<string, string> = {
  low: "border-[var(--vector-signal)]/30 bg-[var(--vector-signal)]/10 text-[var(--vector-signal)]",
  medium: "border-[var(--vector-warning)]/30 bg-[var(--vector-warning)]/10 text-[var(--vector-warning)]",
  high: "border-[var(--vector-danger)]/30 bg-[var(--vector-danger)]/10 text-[var(--vector-danger)]",
  blocked: "border-[var(--vector-danger)]/30 bg-[var(--vector-danger)]/10 text-[var(--vector-danger)]",
};

const trustCards: { icon: LucideIcon; title: string; text: string }[] = [
  {
    icon: ShieldCheck,
    title: "Signed rules",
    text: "Rules expose signature mode and per-rule signatures so Vector can refuse unknown mutation paths.",
  },
  {
    icon: LockKeyhole,
    title: "Protected policy",
    text: "Anti-cheat titles can ship block/preflight guidance without allowing unsafe local overrides.",
  },
  {
    icon: RotateCcw,
    title: "Rollback ready",
    text: "Rule versions, priority, and backend intent are visible enough for safe update and rollback flows.",
  },
];

export default async function VecPatchPage() {
  const manifest = await getVecPatchManifest();
  const rules = [...manifest.rules].sort((first, second) => (first.priority ?? 999) - (second.priority ?? 999));
  const protectedRules = rules.filter((rule) => rule.trust_class === "blockedAntiCheat" || rule.trust_class === "protectedMultiplayer").length;
  const rulesWithRepairs = rules.filter((rule) => rule.dependency_repairs?.length).length;
  const rulesWithLocalProfiles = rules.filter((rule) => rule.local_profile).length;

  return (
    <section className="mx-auto w-full max-w-7xl px-5 py-16 sm:px-8 sm:py-24">
      <div className="grid gap-10 lg:grid-cols-[0.9fr_1.1fr] lg:items-start">
        <div>
          <Badge className="bg-[var(--vector-signal)]/10 text-[var(--vector-signal)] hover:bg-[var(--vector-signal)]/10">
            VecPatch Dispatch
          </Badge>
          <h1 className="mt-6 text-balance text-5xl font-semibold tracking-[-0.06em] text-white sm:text-7xl">
            Patch rules with signatures and receipts.
          </h1>
          <p className="mt-5 text-lg leading-8 text-muted-foreground">
            VecPatch is the public dispatch layer for compatibility rules. The website reads the production manifest directly and renders channel, risk, backend, and trust metadata.
          </p>
          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <Button className="rounded-full bg-[var(--vector-signal)] text-black hover:bg-[var(--vector-signal)]/90" asChild>
              <Link href="https://vector.nanite.com.au/api/v1/patches" target="_blank" rel="noreferrer">
                Open manifest <ArrowUpRight className="ml-2 size-4" />
              </Link>
            </Button>
            <Button variant="outline" className="rounded-full border-white/15 bg-white/[0.03] text-white hover:bg-white/[0.08]" asChild>
              <Link href="/api/vecpatch">Local JSON</Link>
            </Button>
          </div>
        </div>

        <Card className="border-white/10 bg-[#0b0d0c]/90">
          <CardHeader className="border-b border-white/10">
            <CardTitle className="text-white">Manifest metadata</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-0 p-0">
            {[
              ["Service", manifest.service],
              ["Environment", manifest.deployment_env ?? "unknown"],
              ["Channel", manifest.metadata?.channel ?? "stable"],
              ["Rule count", String(manifest.metadata?.rule_count ?? rules.length)],
              ["Protected rules", String(protectedRules)],
              ["Local profile hints", String(rulesWithLocalProfiles)],
              ["Repair-aware rules", String(rulesWithRepairs)],
              ["Signature mode", manifest.metadata?.signature_mode ?? "unknown"],
              ["Generated", formatDate(manifest.generated_at)],
              ["Commit", manifest.commit_sha?.slice(0, 12) ?? "unknown"],
            ].map(([label, value]) => (
              <div key={label} className="flex items-center justify-between border-b border-white/10 px-5 py-4 last:border-b-0">
                <span className="text-sm text-muted-foreground">{label}</span>
                <span className="font-mono text-xs uppercase tracking-[0.14em] text-white">{value}</span>
              </div>
            ))}
          </CardContent>
        </Card>
      </div>

      <div className="mt-14 grid gap-4 lg:grid-cols-3">
        {trustCards.map(({ icon: Icon, title, text }) => (
          <Card key={title} className="border-white/10 bg-white/[0.035] p-5">
            <Icon className="size-5 text-[var(--vector-signal)]" />
            <h2 className="mt-5 font-semibold text-white">{title}</h2>
            <p className="mt-2 text-sm leading-6 text-muted-foreground">{text}</p>
          </Card>
        ))}
      </div>

      <div className="mt-8 grid gap-4">
        {rules.map((rule) => (
          <Card key={rule.id} className="border-white/10 bg-white/[0.035]">
            <CardHeader>
              <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
                <div>
                  <CardTitle className="text-white">{rule.name}</CardTitle>
                  <p className="mt-2 font-mono text-xs uppercase tracking-[0.14em] text-muted-foreground">
                    {rule.executable_match} {rule.steam_app_id ? `· Steam ${rule.steam_app_id}` : ""}
                  </p>
                </div>
                <div className="flex flex-wrap gap-2">
                  <Badge variant="outline" className={riskClass[rule.risk_level ?? "low"] ?? riskClass.low}>
                    {rule.risk_level ?? "low"}
                  </Badge>
                  <Badge variant="outline" className="border-white/10 bg-black/20 text-muted-foreground">
                    {rule.trust_class ?? "singlePlayer"}
                  </Badge>
                  <Badge variant="outline" className="border-white/10 bg-black/20 text-muted-foreground">
                    {rule.patch_state ?? (rule.official_support_required ? "blocked" : "remote-rule")}
                  </Badge>
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <div className="grid gap-4 md:grid-cols-4">
                <Meta label="Priority" value={String(rule.priority ?? "-")} />
                <Meta label="Version" value={`v${rule.rule_version ?? 1}`} />
                <Meta label="Backend" value={rule.graphics_backend || "auto"} />
                <Meta label="Fallback" value={rule.fallback_graphics_backend || "auto"} />
              </div>
              <div className="mt-4 grid gap-3 md:grid-cols-3">
                <Signal
                  icon={CheckCircle2}
                  label="Local profile"
                  value={rule.local_profile ?? "not advertised"}
                  active={Boolean(rule.local_profile)}
                />
                <Signal icon={RadioTower} label="Remote rule" value={rule.id} active />
                <Signal
                  icon={Wrench}
                  label="Dependency repairs"
                  value={rule.dependency_repairs?.length ? rule.dependency_repairs.join(", ") : "none declared"}
                  active={Boolean(rule.dependency_repairs?.length)}
                />
              </div>
              <Separator className="my-5 bg-white/10" />
              <p className="text-sm leading-6 text-muted-foreground">{rule.changelog || "Stable compatibility profile."}</p>
              {rule.official_support_required ? (
                <div className="mt-4 rounded-2xl border border-[var(--vector-danger)]/25 bg-[var(--vector-danger)]/10 p-4">
                  <div className="flex gap-3">
                    <ShieldAlert className="mt-0.5 size-4 shrink-0 text-[var(--vector-danger)]" />
                    <p className="text-sm leading-6 text-[var(--vector-danger)]/90">
                      Protected anti-cheat entry. Local launch is blocked until official support exists.
                      {rule.support_policy ? ` ${rule.support_policy}` : ""}
                    </p>
                  </div>
                </div>
              ) : null}
              {rule.tags?.length ? (
                <div className="mt-4 flex flex-wrap gap-2">
                  {rule.tags.map((tag) => (
                    <Badge key={tag} variant="outline" className="border-white/10 bg-black/20 text-muted-foreground">
                      {tag}
                    </Badge>
                  ))}
                </div>
              ) : null}
              {rule.signature ? (
                <p className="mt-4 break-all font-mono text-[11px] leading-5 text-white/55">{rule.signature}</p>
              ) : null}
            </CardContent>
          </Card>
        ))}
      </div>
    </section>
  );
}

function Meta({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
      <p className="text-xs uppercase tracking-[0.18em] text-muted-foreground">{label}</p>
      <p className="mt-2 font-mono text-xs uppercase tracking-[0.14em] text-white">{value}</p>
    </div>
  );
}

function Signal({
  icon: Icon,
  label,
  value,
  active,
}: {
  icon: LucideIcon;
  label: string;
  value: string;
  active: boolean;
}) {
  return (
    <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
      <div className="flex items-center gap-2">
        <Icon className={active ? "size-4 text-[var(--vector-signal)]" : "size-4 text-muted-foreground"} />
        <p className="text-xs uppercase tracking-[0.18em] text-muted-foreground">{label}</p>
      </div>
      <p className="mt-2 text-xs leading-5 text-white/70">{value}</p>
    </div>
  );
}
