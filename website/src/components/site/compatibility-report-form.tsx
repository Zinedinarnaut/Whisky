"use client";

import { useState, useTransition } from "react";
import { Send, TriangleAlert } from "lucide-react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";

export function CompatibilityReportForm() {
  const [open, setOpen] = useState(false);
  const [isPending, startTransition] = useTransition();

  function submitReport(formData: FormData) {
    startTransition(async () => {
      const payload = Object.fromEntries(formData.entries());
      const response = await fetch("/api/compatibility-report", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        toast.error("Report was not accepted", {
          description: "Vector could not send the compatibility report. Try again after deployment is online.",
        });
        return;
      }

      toast.success("Compatibility report queued", {
        description: "Thanks. This feeds the VecPatch feedback loop without exposing personal data by default.",
      });
      setOpen(false);
    });
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="rounded-full bg-[var(--vector-signal)] text-black hover:bg-[var(--vector-signal)]/90">
          Submit report <Send className="ml-2 size-4" />
        </Button>
      </DialogTrigger>
      <DialogContent className="border-white/10 bg-[#101211] text-white sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>Submit compatibility report</DialogTitle>
          <DialogDescription className="text-muted-foreground">
            Send a compact report into VecPatch. Keep logs clean of account tokens, emails, and private paths where possible.
          </DialogDescription>
        </DialogHeader>
        <form action={submitReport} className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-2">
            <Input name="game" placeholder="Game name" required className="border-white/10 bg-black/30" />
            <Input name="steam_app_id" placeholder="Steam app ID" className="border-white/10 bg-black/30" />
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            <Input name="status" placeholder="Working / Playable / Blocked" required className="border-white/10 bg-black/30" />
            <Input name="graphics_backend" placeholder="DXVK / DXMT / D3DMetal" className="border-white/10 bg-black/30" />
          </div>
          <Input name="hardware" placeholder="Mac model, macOS version" className="border-white/10 bg-black/30" />
          <Textarea name="notes" placeholder="What happened? What fixed it? Paste short relevant log fragments only." required className="min-h-32 border-white/10 bg-black/30" />
          <div className="rounded-2xl border border-[var(--vector-warning)]/20 bg-[var(--vector-warning)]/10 p-3 text-sm leading-6 text-[var(--vector-warning)]">
            <TriangleAlert className="mr-2 inline size-4" />
            Do not submit cracked builds, auth tokens, or private URLs. Protected anti-cheat bypass requests are ignored.
          </div>
          <Button disabled={isPending} className="w-full bg-[var(--vector-signal)] text-black hover:bg-[var(--vector-signal)]/90">
            {isPending ? "Sending..." : "Send report"}
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}
