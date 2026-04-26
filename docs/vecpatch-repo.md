# VecPatch Repo Migration

The dispatch service has been extracted from this repository into its own standalone repo:

- `/Users/zinedinarnaut/Documents/Projects/vecpatch`

## What moved

- HTTP service (`src/server.mjs`)
- SQL schema and seed rules (`sql/schema.sql`)
- Local scripts (`scripts/*`)
- Vercel deployment target (`vercel/*`)

## Working in VecPatch

```bash
cd /Users/zinedinarnaut/Documents/Projects/vecpatch
npm install
npm run start
```

## Deploying VecPatch on Vercel

```bash
bash /Users/zinedinarnaut/.codex/skills/vercel-deploy/scripts/deploy.sh /Users/zinedinarnaut/Documents/Projects/vecpatch/vercel
```
