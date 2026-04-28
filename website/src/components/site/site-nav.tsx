import Link from "next/link";
import { Code2, TerminalSquare } from "lucide-react";

import { Button } from "@/components/ui/button";
import { navItems } from "@/lib/site-data";

export function SiteNav() {
  return (
    <header className="sticky top-0 z-50 border-b border-white/10 bg-background/80 backdrop-blur-xl">
      <div className="mx-auto flex h-16 w-full max-w-7xl items-center justify-between px-5 sm:px-8">
        <Link href="/" className="group flex items-center gap-3" aria-label="Vector home">
          <span className="grid size-9 place-items-center rounded-xl border border-white/10 bg-white/[0.04] shadow-[0_0_30px_rgba(184,255,106,0.08)]">
            <TerminalSquare className="size-4 text-[var(--vector-signal)]" />
          </span>
          <span className="flex flex-col leading-none">
            <span className="text-sm font-semibold tracking-[0.24em] text-white">VECTOR</span>
            <span className="mt-1 text-[10px] uppercase tracking-[0.22em] text-muted-foreground">Mac runtime control</span>
          </span>
        </Link>

        <nav className="hidden items-center gap-1 rounded-full border border-white/10 bg-white/[0.035] p-1 md:flex">
          {navItems.map((item) => (
            <Link
              key={item.label}
              href={item.href}
              className="rounded-full px-4 py-2 text-sm text-muted-foreground transition hover:bg-white/[0.06] hover:text-white"
            >
              {item.label}
            </Link>
          ))}
        </nav>

        <div className="flex items-center gap-2">
          <Button variant="ghost" size="icon" className="hidden rounded-full border border-white/10 bg-white/[0.03] md:inline-flex" asChild>
            <Link href="https://github.com/Zinedinarnaut/Whisky" target="_blank" rel="noreferrer" aria-label="GitHub">
              <Code2 className="size-4" />
            </Link>
          </Button>
          <Button className="rounded-full bg-[var(--vector-signal)] px-5 text-black hover:bg-[var(--vector-signal)]/90" asChild>
            <Link href="/download">Get Vector</Link>
          </Button>
        </div>
      </div>
    </header>
  );
}
