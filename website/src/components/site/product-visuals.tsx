import {
  Boxes,
  CheckCircle2,
  CircleAlert,
  Download,
  Gamepad2,
  HardDrive,
  RadioTower,
  ShieldCheck,
  Sparkles,
  type LucideIcon,
} from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";

type ProductVisualsProps = {
  ruleCount: number;
  releaseTag?: string;
};

const bottleRows = [
  { name: "Gaming", state: "Ready", backend: "Auto", score: 96 },
  { name: "Steam Library", state: "Syncing", backend: "DXMT", score: 88 },
  { name: "Protected Test", state: "Blocked", backend: "Policy", score: 100 },
];

const patchRows = [
  { title: "Minecraft Dungeons", tag: "Media + sign-in repair", state: "Applied" },
  { title: "Content Warning", tag: "Unity profile", state: "Available" },
  { title: "ARC Raiders", tag: "Protected multiplayer", state: "Blocked" },
];

export function ProductVisuals({ ruleCount, releaseTag = "latest" }: ProductVisualsProps) {
  return (
    <div className="grid gap-4 lg:grid-cols-[1.1fr_0.9fr]">
      <Card className="overflow-hidden border-white/10 bg-[#0b0d0c]/95 shadow-2xl shadow-black/40">
        <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
          <div className="flex items-center gap-2">
            <span className="size-2.5 rounded-full bg-[#ff6b6b]" />
            <span className="size-2.5 rounded-full bg-[#ffd36a]" />
            <span className="size-2.5 rounded-full bg-[var(--vector-signal)]" />
          </div>
          <span className="font-mono text-[11px] uppercase tracking-[0.18em] text-muted-foreground">
            Vector home
          </span>
        </div>

        <div className="grid gap-4 p-5 md:grid-cols-[0.9fr_1.1fr]">
          <div className="rounded-3xl border border-white/10 bg-white/[0.035] p-5">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs uppercase tracking-[0.18em] text-muted-foreground">Bottle health</p>
                <h3 className="mt-2 text-2xl font-semibold tracking-[-0.04em] text-white">Control room</h3>
              </div>
              <Badge className="rounded-full bg-[var(--vector-signal)] text-black hover:bg-[var(--vector-signal)]">
                Live
              </Badge>
            </div>

            <div className="mt-6 grid gap-3">
              {bottleRows.map((bottle) => (
                <div key={bottle.name} className="rounded-2xl border border-white/10 bg-black/25 p-4">
                  <div className="flex items-center justify-between gap-3">
                    <div className="flex items-center gap-3">
                      <div className="grid size-9 place-items-center rounded-xl bg-white/[0.06]">
                        <Gamepad2 className="size-4 text-[var(--vector-signal)]" />
                      </div>
                      <div>
                        <p className="text-sm font-medium text-white">{bottle.name}</p>
                        <p className="font-mono text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                          {bottle.backend}
                        </p>
                      </div>
                    </div>
                    <span className="font-mono text-xs text-white">{bottle.score}</span>
                  </div>
                  <div className="mt-4 h-1.5 overflow-hidden rounded-full bg-white/[0.08]">
                    <div
                      className="h-full rounded-full bg-[linear-gradient(90deg,var(--vector-signal),var(--vector-aqua))]"
                      style={{ width: `${bottle.score}%` }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="grid gap-4">
            <div className="rounded-3xl border border-white/10 bg-[linear-gradient(145deg,rgba(184,255,106,0.12),rgba(255,255,255,0.035))] p-5">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="text-xs uppercase tracking-[0.18em] text-muted-foreground">Release channel</p>
                  <p className="mt-2 font-mono text-sm uppercase tracking-[0.14em] text-white">{releaseTag}</p>
                </div>
                <Download className="size-5 text-[var(--vector-signal)]" />
              </div>
            </div>

            <div className="rounded-3xl border border-white/10 bg-white/[0.035] p-5">
              <div className="flex items-center justify-between">
                <h3 className="font-semibold text-white">Patch Center</h3>
                <Badge variant="outline" className="border-white/10 bg-black/20 text-muted-foreground">
                  {ruleCount} rules
                </Badge>
              </div>
              <div className="mt-5 grid gap-3">
                {patchRows.map((patch) => (
                  <div key={patch.title} className="flex items-center justify-between gap-4 rounded-2xl bg-black/25 px-4 py-3">
                    <div>
                      <p className="text-sm font-medium text-white">{patch.title}</p>
                      <p className="mt-1 text-xs text-muted-foreground">{patch.tag}</p>
                    </div>
                    <PatchState state={patch.state} />
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </Card>

      <div className="grid gap-4">
        <MiniPanel
          icon={ShieldCheck}
          label="Protected multiplayer"
          title="EAC/BattlEye titles lock down risky tools automatically."
          detail="No trainers, no memory bridge, no unsigned local mutation."
        />
        <MiniPanel
          icon={RadioTower}
          label="VecPatch loop"
          title="Reports become reviewable compatibility suggestions."
          detail="Admin-only intake keeps public rules clean."
        />
        <MiniPanel
          icon={HardDrive}
          label="External bottles"
          title="Bottles can live on fast external storage."
          detail="Vector keeps runtime paths and repair scripts consistent."
        />
      </div>
    </div>
  );
}

function PatchState({ state }: { state: string }) {
  if (state === "Blocked") {
    return (
      <span className="flex items-center gap-1.5 font-mono text-[11px] uppercase tracking-[0.14em] text-[var(--vector-warning)]">
        <CircleAlert className="size-3" /> {state}
      </span>
    );
  }

  return (
    <span className="flex items-center gap-1.5 font-mono text-[11px] uppercase tracking-[0.14em] text-[var(--vector-signal)]">
      <CheckCircle2 className="size-3" /> {state}
    </span>
  );
}

function MiniPanel({
  icon: Icon,
  label,
  title,
  detail,
}: {
  icon: LucideIcon;
  label: string;
  title: string;
  detail: string;
}) {
  return (
    <Card className="group overflow-hidden border-white/10 bg-white/[0.035] p-5 transition-colors hover:bg-white/[0.055]">
      <div className="flex items-start justify-between gap-4">
        <div className="grid size-10 place-items-center rounded-2xl bg-white/[0.06] transition-colors group-hover:bg-[var(--vector-signal)]/10">
          <Icon className="size-5 text-[var(--vector-signal)]" />
        </div>
        <Boxes className="size-4 text-white/20" />
      </div>
      <p className="mt-6 text-xs uppercase tracking-[0.18em] text-muted-foreground">{label}</p>
      <h3 className="mt-2 text-lg font-semibold tracking-[-0.03em] text-white">{title}</h3>
      <p className="mt-2 text-sm leading-6 text-muted-foreground">{detail}</p>
      <div className="mt-5 flex items-center gap-2 text-xs text-muted-foreground">
        <Sparkles className="size-3 text-[var(--vector-aqua)]" />
        Product-grade surface
      </div>
    </Card>
  );
}
