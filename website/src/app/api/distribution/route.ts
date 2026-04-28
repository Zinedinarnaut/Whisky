import { getDistributionMetadata, getVecPatchManifest } from "@/lib/vecpatch";

export const revalidate = 300;

export async function GET() {
  const [distribution, vecpatch] = await Promise.all([getDistributionMetadata(), getVecPatchManifest()]);

  return Response.json(
    {
      generated_at: new Date().toISOString(),
      distribution,
      vecpatch: {
        source: vecpatch.source,
        commit_sha: vecpatch.commit_sha,
        rule_count: vecpatch.metadata?.rule_count ?? vecpatch.rules.length,
        signature_mode: vecpatch.metadata?.signature_mode,
        generated_at: vecpatch.generated_at,
      },
    },
    {
      headers: {
        "cache-control": "public, s-maxage=300, stale-while-revalidate=600",
      },
    },
  );
}
