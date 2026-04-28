"use client";

import { useState, useTransition } from "react";
import { Copy, KeyRound, RefreshCw } from "lucide-react";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";

type AdminReport = {
  id: string;
  created_at: string;
  game: string;
  status: string;
  steam_app_id: string;
  graphics_backend: string;
  hardware: string;
  notes: string;
  source: string;
};

type ReportSuggestion = {
  game: string;
  status: string;
  steam_app_id: string;
  graphics_backend: string;
  report_count: number;
  latest_report_at: string;
  sample_notes: string[];
  suggested_entry: Record<string, unknown>;
};

export function AdminConsole() {
  const [token, setToken] = useState("");
  const [reports, setReports] = useState<AdminReport[]>([]);
  const [suggestions, setSuggestions] = useState<ReportSuggestion[]>([]);
  const [error, setError] = useState("");
  const [isPending, startTransition] = useTransition();

  function refresh() {
    setError("");
    startTransition(async () => {
      const [reportsResponse, suggestionsResponse] = await Promise.all([
        fetch("/api/admin/reports", { headers: { "x-admin-token": token } }),
        fetch("/api/admin/report-suggestions", { headers: { "x-admin-token": token } }),
      ]);

      if (!reportsResponse.ok || !suggestionsResponse.ok) {
        setError("Admin token rejected or VecPatch admin endpoints are not configured.");
        return;
      }

      const reportsPayload = await reportsResponse.json();
      const suggestionsPayload = await suggestionsResponse.json();
      setReports(reportsPayload.reports ?? []);
      setSuggestions(suggestionsPayload.suggestions ?? []);
      toast.success("Admin data refreshed");
    });
  }

  function copySuggestion(suggestion: ReportSuggestion) {
    navigator.clipboard.writeText(JSON.stringify(suggestion.suggested_entry, null, 2));
    toast.success("Suggested entry copied");
  }

  return (
    <div className="space-y-6">
      <Card className="border-white/10 bg-white/[0.035] p-5">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end">
          <label className="flex-1">
            <span className="mb-2 flex items-center gap-2 text-sm font-medium text-white">
              <KeyRound className="size-4 text-[var(--vector-signal)]" /> VecPatch admin token
            </span>
            <Input
              value={token}
              onChange={(event) => setToken(event.target.value)}
              type="password"
              placeholder="Paste VECPATCH_ADMIN_TOKEN"
              className="border-white/10 bg-black/30"
            />
          </label>
          <Button disabled={!token || isPending} onClick={refresh} className="bg-[var(--vector-signal)] text-black hover:bg-[var(--vector-signal)]/90">
            <RefreshCw className="mr-2 size-4" /> {isPending ? "Loading..." : "Load reports"}
          </Button>
        </div>
        {error ? <p className="mt-4 text-sm text-[var(--vector-danger)]">{error}</p> : null}
      </Card>

      <div className="grid gap-6 lg:grid-cols-[0.9fr_1.1fr]">
        <section className="space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-semibold tracking-[-0.03em] text-white">Reports</h2>
            <Badge variant="outline" className="border-white/10 bg-black/20 text-muted-foreground">{reports.length}</Badge>
          </div>
          {reports.map((report) => (
            <Card key={report.id} className="border-white/10 bg-white/[0.035] p-4">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <h3 className="font-semibold text-white">{report.game}</h3>
                <Badge className="bg-white/10 text-white hover:bg-white/10">{report.status}</Badge>
              </div>
              <p className="mt-2 text-sm leading-6 text-muted-foreground">{report.notes}</p>
              <div className="mt-3 flex flex-wrap gap-2 font-mono text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                {report.steam_app_id ? <span>Steam {report.steam_app_id}</span> : null}
                {report.graphics_backend ? <span>{report.graphics_backend}</span> : null}
                {report.hardware ? <span>{report.hardware}</span> : null}
              </div>
            </Card>
          ))}
        </section>

        <section className="space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-semibold tracking-[-0.03em] text-white">Suggestions</h2>
            <Badge variant="outline" className="border-white/10 bg-black/20 text-muted-foreground">{suggestions.length}</Badge>
          </div>
          {suggestions.map((suggestion) => (
            <Card key={`${suggestion.game}-${suggestion.status}-${suggestion.graphics_backend}`} className="border-white/10 bg-white/[0.035] p-4">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h3 className="font-semibold text-white">{suggestion.game}</h3>
                  <p className="mt-1 text-xs text-muted-foreground">{suggestion.report_count} matching report(s)</p>
                </div>
                <Button size="sm" variant="outline" className="border-white/15 bg-black/20 text-white hover:bg-white/[0.08]" onClick={() => copySuggestion(suggestion)}>
                  <Copy className="mr-2 size-3" /> Copy JSON
                </Button>
              </div>
              <Textarea
                readOnly
                value={JSON.stringify(suggestion.suggested_entry, null, 2)}
                className="mt-4 min-h-44 border-white/10 bg-black/30 font-mono text-xs"
              />
            </Card>
          ))}
        </section>
      </div>
    </div>
  );
}
