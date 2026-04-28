import { getVecPatchManifest } from "@/lib/vecpatch";

export const revalidate = 120;

export async function GET() {
  const manifest = await getVecPatchManifest();

  return Response.json(manifest, {
    headers: {
      "cache-control": "public, s-maxage=120, stale-while-revalidate=300",
    },
  });
}
