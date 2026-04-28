import type { LucideIcon } from "lucide-react";

import { Card, CardContent } from "@/components/ui/card";

interface FeatureCardProps {
  icon: LucideIcon;
  title: string;
  description: string;
}

export function FeatureCard({ icon: Icon, title, description }: FeatureCardProps) {
  return (
    <Card className="group border-white/10 bg-white/[0.035] transition duration-300 hover:-translate-y-1 hover:bg-white/[0.055]">
      <CardContent className="p-5">
        <div className="mb-5 grid size-11 place-items-center rounded-2xl border border-white/10 bg-black/30 text-[var(--vector-signal)] transition group-hover:border-[var(--vector-signal)]/40">
          <Icon className="size-5" />
        </div>
        <h3 className="text-lg font-semibold tracking-[-0.02em] text-white">{title}</h3>
        <p className="mt-3 text-sm leading-6 text-muted-foreground">{description}</p>
      </CardContent>
    </Card>
  );
}
