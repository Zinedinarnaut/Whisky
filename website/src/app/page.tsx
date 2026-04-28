import Link from "next/link";
import { ArrowRight, Command, Download, RadioTower } from "lucide-react";

import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { CompatibilityTable } from "@/components/site/compatibility-table";
import { FeatureCard } from "@/components/site/feature-card";
import { RuntimePanel } from "@/components/site/runtime-panel";
import { SectionHeading } from "@/components/site/section-heading";
import { faqs, featureCards, heroStats, systemPrinciples, workflowSteps } from "@/lib/site-data";
import { getCompatibilityDatabase, getDistributionMetadata, getVecPatchManifest } from "@/lib/vecpatch";

export const revalidate = 120;

export default async function Home() {
  const [manifest, distribution, compatibility] = await Promise.all([
    getVecPatchManifest(),
    getDistributionMetadata(),
    getCompatibilityDatabase(),
  ]);
  const compatibilityPreview = compatibility.entries.slice(0, 5);
  const ruleCount = manifest.metadata?.rule_count ?? manifest.rules.length;

  return (
    <div className="overflow-hidden">
      <section className="vector-grid relative border-b border-white/10">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_20%,rgba(184,255,106,0.10),transparent_34rem)]" />
        <div className="relative mx-auto grid min-h-[calc(100svh-4rem)] w-full max-w-7xl items-center gap-12 px-5 py-20 sm:px-8 lg:grid-cols-[1.05fr_0.95fr]">
          <div>
            <Badge variant="outline" className="border-white/15 bg-white/[0.04] text-muted-foreground">
              Vector distribution + compatibility hub
            </Badge>
            <h1 className="mt-6 max-w-4xl text-balance text-5xl font-semibold tracking-[-0.07em] text-white sm:text-7xl lg:text-8xl">
              Mac gaming compatibility without the ritual sacrifice.
            </h1>
            <p className="mt-6 max-w-2xl text-pretty text-lg leading-8 text-muted-foreground">
              Vector gives bottles a clean control surface: patch dispatch, runtime health, dependency repair, graphics routing, and protected multiplayer honesty in one compact Mac-native utility.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Button size="lg" className="rounded-full bg-[var(--vector-signal)] px-6 text-black hover:bg-[var(--vector-signal)]/90" asChild>
                <Link href="/download">
                  Distribution Centre <Download className="ml-2 size-4" />
                </Link>
              </Button>
              <Button size="lg" variant="outline" className="rounded-full border-white/15 bg-white/[0.03] px-6 text-white hover:bg-white/[0.08]" asChild>
                <Link href="/compatibility">
                  View compatibility <ArrowRight className="ml-2 size-4" />
                </Link>
              </Button>
            </div>
            <div className="mt-10 grid gap-3 sm:grid-cols-3">
              {heroStats.map((stat) => (
                <div key={stat.label} className="rounded-2xl border border-white/10 bg-white/[0.035] p-4">
                  <p className="text-xs uppercase tracking-[0.18em] text-muted-foreground">{stat.label}</p>
                  <p className="mt-2 font-mono text-sm text-white">{stat.value}</p>
                </div>
              ))}
            </div>
          </div>
          <RuntimePanel
            ruleCount={ruleCount}
            signatureMode={manifest.metadata?.signature_mode}
            releaseTag={distribution.tagName}
            generatedAt={manifest.generated_at}
          />
        </div>
      </section>

      <section className="mx-auto w-full max-w-7xl px-5 py-24 sm:px-8">
        <SectionHeading
          eyebrow="Product architecture"
          title="A quieter control plane for a very loud problem."
          description="Vector should feel like a premium utility: compact, technical, safe by default, and direct about what it can and cannot run."
        />
        <div className="mt-12 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {featureCards.map((feature) => (
            <FeatureCard key={feature.title} {...feature} />
          ))}
        </div>
      </section>

      <section className="border-y border-white/10 bg-white/[0.025]" id="vecpatch">
        <div className="mx-auto grid w-full max-w-7xl gap-10 px-5 py-24 sm:px-8 lg:grid-cols-[0.85fr_1.15fr]">
          <div>
            <Badge className="bg-[var(--vector-aqua)]/10 text-[var(--vector-aqua)] hover:bg-[var(--vector-aqua)]/10">
              VecPatch dispatch
            </Badge>
            <h2 className="mt-5 text-balance text-4xl font-semibold tracking-[-0.05em] text-white sm:text-5xl">
              Patches that explain themselves before they touch your bottle.
            </h2>
            <p className="mt-5 text-base leading-7 text-muted-foreground">
              The site now reads the production VecPatch manifest directly: {ruleCount} rules, {manifest.metadata?.signature_mode ?? "signed"} delivery, and trust metadata for protected titles.
            </p>
            <Button variant="outline" className="mt-6 rounded-full border-white/15 bg-white/[0.03] text-white hover:bg-white/[0.08]" asChild>
              <Link href="/vecpatch">Open VecPatch page</Link>
            </Button>
          </div>
          <div className="grid gap-3">
            {workflowSteps.map((step) => (
              <Card key={step.label} className="border-white/10 bg-black/25">
                <CardContent className="flex gap-5 p-5">
                  <span className="font-mono text-sm text-[var(--vector-signal)]">{step.label}</span>
                  <div>
                    <h3 className="font-semibold text-white">{step.title}</h3>
                    <p className="mt-2 text-sm leading-6 text-muted-foreground">{step.description}</p>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </section>

      <section className="mx-auto w-full max-w-7xl px-5 py-24 sm:px-8" id="compatibility">
        <div className="grid gap-10 lg:grid-cols-[0.9fr_1.1fr] lg:items-start">
          <div>
            <Badge variant="outline" className="border-[var(--vector-warning)]/30 bg-[var(--vector-warning)]/10 text-[var(--vector-warning)]">
              Compatibility database
            </Badge>
            <h2 className="mt-5 text-balance text-4xl font-semibold tracking-[-0.05em] text-white sm:text-5xl">
              Clear statuses, not guesswork.
            </h2>
            <p className="mt-5 text-base leading-7 text-muted-foreground">
              The public database is derived from VecPatch rules and trimmed to the things users care about: status, compatibility level, backend, and known issues.
            </p>
            <Button variant="outline" className="mt-6 rounded-full border-white/15 bg-white/[0.03] text-white hover:bg-white/[0.08]" asChild>
              <Link href="/compatibility">Open full database</Link>
            </Button>
          </div>
          <CompatibilityTable entries={compatibilityPreview} compact />
        </div>
      </section>

      <section className="border-y border-white/10 bg-white/[0.025]">
        <div className="mx-auto w-full max-w-7xl px-5 py-24 sm:px-8">
          <SectionHeading
            eyebrow="Design principles"
            title="Modern, but still a tool."
            description="The visual system keeps the app serious: dense panels, low-noise typography, restrained highlights, and a Mac utility feel."
          />
          <div className="mt-12 grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            {systemPrinciples.map(({ icon: Icon, title, text }) => (
              <Card key={title} className="border-white/10 bg-white/[0.035] p-5">
                <Icon className="size-5 text-[var(--vector-signal)]" />
                <h3 className="mt-5 font-semibold text-white">{title}</h3>
                <p className="mt-2 text-sm leading-6 text-muted-foreground">{text}</p>
              </Card>
            ))}
          </div>
        </div>
      </section>

      <section className="mx-auto grid w-full max-w-7xl gap-8 px-5 py-24 sm:px-8 lg:grid-cols-[1fr_0.8fr]" id="download">
        <Card className="border-white/10 bg-[linear-gradient(145deg,rgba(184,255,106,0.12),rgba(255,255,255,0.035))] p-8">
          <Command className="size-8 text-[var(--vector-signal)]" />
          <h2 className="mt-8 max-w-2xl text-balance text-4xl font-semibold tracking-[-0.05em] text-white sm:text-5xl">
            A real distribution surface, not a dead download button.
          </h2>
          <p className="mt-4 max-w-2xl text-sm leading-6 text-muted-foreground">
            Current channel: <span className="font-mono text-white">{distribution.tagName}</span>. Runtime artefacts, hashes, source snapshots, and VecPatch metadata are all available from the Distribution Centre.
          </p>
          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <Button className="rounded-full bg-[var(--vector-signal)] text-black hover:bg-[var(--vector-signal)]/90" asChild>
              <Link href="/download">Open Distribution Centre</Link>
            </Button>
            <Button variant="outline" className="rounded-full border-white/15 bg-black/20 text-white hover:bg-white/[0.08]" asChild>
              <Link href="/api/distribution">View JSON</Link>
            </Button>
          </div>
        </Card>

        <Card className="border-white/10 bg-white/[0.035] p-6">
          <RadioTower className="size-5 text-[var(--vector-aqua)]" />
          <h3 className="mt-5 text-xl font-semibold text-white">Patch loop</h3>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            Live VecPatch source: <span className="font-mono text-white">{manifest.source}</span>
          </p>
          <Separator className="my-6 bg-white/10" />
          <Accordion type="single" collapsible className="w-full">
            {faqs.map((faq) => (
              <AccordionItem key={faq.question} value={faq.question} className="border-white/10">
                <AccordionTrigger className="text-left text-sm text-white hover:no-underline">{faq.question}</AccordionTrigger>
                <AccordionContent className="text-sm leading-6 text-muted-foreground">{faq.answer}</AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </Card>
      </section>
    </div>
  );
}
