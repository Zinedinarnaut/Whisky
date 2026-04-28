import {
  Blocks,
  Cpu,
  DatabaseZap,
  Gauge,
  LockKeyhole,
  MonitorCog,
  PackageCheck,
  RadioTower,
  ScanSearch,
  ShieldCheck,
} from "lucide-react";

export const navItems = [
  { label: "Download", href: "/download" },
  { label: "Compatibility", href: "/compatibility" },
  { label: "VecPatch", href: "/vecpatch" },
];

export const heroStats = [
  { label: "Patch channels", value: "Stable / Beta / Lab" },
  { label: "Runtime posture", value: "Signed + auditable" },
  { label: "Game profiles", value: "Auto-resolved" },
];

export const featureCards = [
  {
    icon: PackageCheck,
    title: "One-click bottle prep",
    description:
      "Builds a tuned Windows environment with launcher installs, runtime checks, dependency repair, and sane rollback points.",
  },
  {
    icon: RadioTower,
    title: "VecPatch dispatch",
    description:
      "Fetches compatibility rules, backend preferences, safety policy, and patch metadata without burying users in config noise.",
  },
  {
    icon: MonitorCog,
    title: "Smart graphics routing",
    description:
      "Chooses DXVK, DXMT, D3DMetal, or WineD3D based on game profile, runtime support, and observed failure signatures.",
  },
  {
    icon: ShieldCheck,
    title: "Protected multiplayer guardrails",
    description:
      "Detects anti-cheat titles and locks down risky tooling instead of pretending unsupported games are safe to launch.",
  },
  {
    icon: ScanSearch,
    title: "Launch Doctor",
    description:
      "Classifies common failures like missing WebView2, DX11 feature issues, wineserver mismatch, and stale DLL overrides.",
  },
  {
    icon: DatabaseZap,
    title: "Compatibility hub",
    description:
      "Shows status, notes, known fixes, and recommended launch mode with enough detail for power users and normal people.",
  },
];

export const workflowSteps = [
  {
    label: "01",
    title: "Detect",
    description: "Vector reads the executable, bottle, runtime, launcher, app ID, graphics backend, and known anti-cheat markers.",
  },
  {
    label: "02",
    title: "Resolve",
    description: "VecPatch and local intelligence choose the safest rule set, dependency plan, and graphics translation path.",
  },
  {
    label: "03",
    title: "Prepare",
    description: "Vector snapshots the bottle, applies verified changes, fixes missing runtime pieces, and writes clear logs.",
  },
  {
    label: "04",
    title: "Launch",
    description: "Users get a compact launch view with backend visibility, health state, and a recovery path if the game fails.",
  },
];

export const systemPrinciples = [
  { icon: Blocks, title: "Compact panels", text: "Information is grouped into dense, readable modules instead of dashboard sprawl." },
  { icon: Gauge, title: "Status first", text: "Every surface answers: is it ready, what changed, and what should I do next?" },
  { icon: LockKeyhole, title: "Trust by default", text: "Protected titles, signed patches, and runtime attestation are treated as first-class product features." },
  { icon: Cpu, title: "Mac-native edge", text: "The visual language nods to Metal, runtime probes, and bottle health without becoming terminal spam." },
];

export const faqs = [
  {
    question: "Is Vector trying to bypass anti-cheat?",
    answer:
      "No. Protected multiplayer titles are detected and locked down. Vector can show fallback options and produce a review bundle, but it does not weaken anti-cheat.",
  },
  {
    question: "What makes VecPatch different from random launch args?",
    answer:
      "Rules carry metadata, trust class, backend intent, risk level, and rollback context so fixes can be audited and applied consistently.",
  },
  {
    question: "Why a dark compact interface?",
    answer:
      "Vector is a utility for runtime work. The interface should feel precise, quiet, and technical without becoming intimidating.",
  },
];

export const techStack = ["Next.js 16", "React 19", "TypeScript", "Tailwind CSS v4", "shadcn/ui", "Radix UI", "Lucide"];
