import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { CompatibilityEntry } from "@/lib/vecpatch";

const statusClass: Record<string, string> = {
  Working: "border-[var(--vector-signal)]/30 bg-[var(--vector-signal)]/10 text-[var(--vector-signal)]",
  Playable: "border-[var(--vector-aqua)]/30 bg-[var(--vector-aqua)]/10 text-[var(--vector-aqua)]",
  "Needs Fix": "border-[var(--vector-warning)]/30 bg-[var(--vector-warning)]/10 text-[var(--vector-warning)]",
  Blocked: "border-[var(--vector-danger)]/30 bg-[var(--vector-danger)]/10 text-[var(--vector-danger)]",
};

type CompatibilityTableProps = {
  entries: CompatibilityEntry[];
  title?: string;
  compact?: boolean;
};

export function CompatibilityTable({ entries, title = "Compatibility snapshot", compact }: CompatibilityTableProps) {
  return (
    <Card className="overflow-hidden border-white/10 bg-white/[0.035]">
      <CardHeader className="border-b border-white/10">
        <CardTitle className="text-white">{title}</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        <div className="grid grid-cols-[1.15fr_0.7fr_0.75fr_1.4fr] border-b border-white/10 px-5 py-3 text-xs uppercase tracking-[0.18em] text-muted-foreground max-md:hidden">
          <span>Game</span>
          <span>Status</span>
          <span>Backend</span>
          <span>Notes</span>
        </div>
        {entries.map((entry) => (
          <div
            key={`${entry.game}-${entry.patchVersion}`}
            className="grid gap-3 border-b border-white/10 px-5 py-4 last:border-b-0 md:grid-cols-[1.15fr_0.7fr_0.75fr_1.4fr] md:items-center"
          >
            <div>
              <span className="font-medium text-white">{entry.game}</span>
              <div className="mt-1 flex flex-wrap gap-2 font-mono text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                <span>{entry.level}</span>
                <span>{entry.patchVersion}</span>
                {entry.steamAppId ? <span>Steam {entry.steamAppId}</span> : null}
              </div>
            </div>
            <span>
              <Badge variant="outline" className={statusClass[entry.status] ?? ""}>
                {entry.status}
              </Badge>
            </span>
            <span className="font-mono text-xs uppercase tracking-[0.14em] text-muted-foreground">
              {entry.backend}
            </span>
            <span className={compact ? "line-clamp-2 text-sm text-muted-foreground" : "text-sm text-muted-foreground"}>
              {entry.note}
            </span>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
