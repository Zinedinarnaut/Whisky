# Vector Website

A modern Next.js website for Vector with a public distribution centre, live compatibility database, and VecPatch dispatch pages.

## Routes

- `/` — polished landing page
- `/download` — Distribution Centre with GitHub release artefacts, runtime metadata, and local JSON endpoint links
- `/install` — macOS requirements and first launch guide
- `/compatibility` — compatibility database derived from live VecPatch rules
- `/vecpatch` — production VecPatch manifest, rule metadata, trust classes, signatures, and backend intent
- `/api/distribution` — distribution + VecPatch metadata JSON
- `/api/compatibility` — compatibility entries JSON
- `/api/vecpatch` — proxied VecPatch manifest JSON
- `/api/compatibility-report` — compatibility report intake proxy

## Stack

- Next.js 16 App Router
- React 19
- TypeScript
- Tailwind CSS v4
- shadcn/ui with Radix primitives
- Lucide icons

## Commands

```bash
npm run dev
npm run build
npm run lint
```
