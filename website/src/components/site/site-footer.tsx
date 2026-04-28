import Link from "next/link";

import { techStack } from "@/lib/site-data";

const footerLinks = [
  { label: "Download", href: "/download" },
  { label: "Compatibility", href: "/compatibility" },
  { label: "Install", href: "/install" },
  { label: "VecPatch", href: "/vecpatch" },
  { label: "Distribution JSON", href: "/api/distribution" },
];

export function SiteFooter() {
  return (
    <footer className="border-t border-white/10 bg-black/30">
      <div className="mx-auto grid w-full max-w-7xl gap-8 px-5 py-10 sm:px-8 md:grid-cols-[1fr_auto]">
        <div>
          <p className="text-sm font-semibold tracking-[0.22em] text-white">VECTOR</p>
          <p className="mt-3 max-w-xl text-sm leading-6 text-muted-foreground">
            A modern Mac compatibility layer interface for bottles, launchers, patch dispatch, runtime health, and honest protected multiplayer handling.
          </p>
        </div>
        <div className="flex flex-wrap gap-2 md:max-w-md md:justify-end">
          {techStack.map((item) => (
            <span key={item} className="rounded-full border border-white/10 bg-white/[0.035] px-3 py-1 text-xs text-muted-foreground">
              {item}
            </span>
          ))}
        </div>
        <div className="flex flex-wrap gap-5 text-xs text-muted-foreground md:col-span-2">
          {footerLinks.map((link) => (
            <Link key={link.href} href={link.href} className="hover:text-white">
              {link.label}
            </Link>
          ))}
        </div>
      </div>
    </footer>
  );
}
