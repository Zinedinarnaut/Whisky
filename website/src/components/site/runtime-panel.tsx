import { Activity, CheckCircle2, CircleDashed, ShieldAlert } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";

type RuntimePanelProps = {
  ruleCount?: number;
  signatureMode?: string;
  releaseTag?: string;
  generatedAt?: string;
};

export function RuntimePanel({ ruleCount = 12, signatureMode = "ed25519", releaseTag = "runtime-v2.5.0" }: RuntimePanelProps) {
  const rows = [
    { label: "Distribution", value: releaseTag, status: "healthy" },
    { label: "Patchset", value: `${ruleCount} live rules`, status: "synced" },
    { label: "Signatures", value: signatureMode, status: "verified" },
    { label: "Protected mode", value: "Auto-lock", status: "guarded" },
  ];

  return (
    <div className="relative overflow-hidden rounded-[2rem] border border-white/10 bg-[linear-gradient(145deg,rgba(255,255,255,0.09),rgba(255,255,255,0.025))] p-3 shadow-2xl shadow-black/50">
      <div className="absolute inset-x-10 top-0 h-px bg-gradient-to-r from-transparent via-[var(--vector-signal)]/70 to-transparent" />
      <div className="rounded-[1.45rem] border border-white/10 bg-[#0b0d0c]/95 p-5">
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.24em] text-muted-foreground">Launch readiness</p>
            <h3 className="mt-2 text-2xl font-semibold tracking-[-0.04em] text-white">Vector control panel</h3>
          </div>
          <Badge className="rounded-full bg-[var(--vector-signal)] text-black hover:bg-[var(--vector-signal)]">
            Live
          </Badge>
        </div>

        <div className="mt-6 grid gap-3">
          {rows.map((row) => (
            <div key={row.label} className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/[0.035] px-4 py-3">
              <div className="flex items-center gap-3">
                <CheckCircle2 className="size-4 text-[var(--vector-signal)]" />
                <span className="text-sm text-muted-foreground">{row.label}</span>
              </div>
              <span className="font-mono text-xs uppercase tracking-[0.16em] text-white">{row.value}</span>
            </div>
          ))}
        </div>

        <Separator className="my-5 bg-white/10" />

        <div className="grid gap-3 sm:grid-cols-3">
          <div className="rounded-2xl bg-[var(--vector-signal)]/10 p-4">
            <Activity className="size-4 text-[var(--vector-signal)]" />
            <p className="mt-3 font-mono text-xl text-white">96</p>
            <p className="text-xs text-muted-foreground">Health score</p>
          </div>
          <div className="rounded-2xl bg-[var(--vector-aqua)]/10 p-4">
            <CircleDashed className="size-4 text-[var(--vector-aqua)]" />
            <p className="mt-3 font-mono text-xl text-white">{ruleCount}</p>
            <p className="text-xs text-muted-foreground">Patch rules</p>
          </div>
          <div className="rounded-2xl bg-[var(--vector-warning)]/10 p-4">
            <ShieldAlert className="size-4 text-[var(--vector-warning)]" />
            <p className="mt-3 font-mono text-xl text-white">0</p>
            <p className="text-xs text-muted-foreground">Unsafe rules</p>
          </div>
        </div>
      </div>
    </div>
  );
}
