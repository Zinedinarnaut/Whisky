import { ShieldCheck } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { AdminConsole } from "@/components/site/admin-console";

export const metadata = {
  title: "Vector Admin",
  description: "Internal VecPatch report review and compatibility suggestion console.",
  robots: { index: false, follow: false },
};

export default function AdminPage() {
  return (
    <section className="mx-auto w-full max-w-7xl px-5 py-16 sm:px-8 sm:py-24">
      <div className="mb-10 max-w-3xl">
        <Badge className="bg-[var(--vector-danger)]/10 text-[var(--vector-danger)] hover:bg-[var(--vector-danger)]/10">
          Internal
        </Badge>
        <h1 className="mt-6 text-balance text-5xl font-semibold tracking-[-0.06em] text-white sm:text-7xl">
          VecPatch review console.
        </h1>
        <p className="mt-5 text-lg leading-8 text-muted-foreground">
          Token-gated report review for turning compatibility submissions into structured suggestions. This page is intentionally not linked in public navigation.
        </p>
      </div>
      <Card className="mb-6 border-[var(--vector-warning)]/20 bg-[var(--vector-warning)]/10 p-4 text-sm leading-6 text-[var(--vector-warning)]">
        <ShieldCheck className="mr-2 inline size-4" /> Requires <code>VECPATCH_ADMIN_TOKEN</code> on the VecPatch deployment.
      </Card>
      <AdminConsole />
    </section>
  );
}
