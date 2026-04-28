import { getCompatibilityDatabase } from "@/lib/vecpatch";

export const revalidate = 120;

export async function GET() {
  const compatibility = await getCompatibilityDatabase();

  return Response.json(
    compatibility,
    {
      headers: {
        "cache-control": "public, s-maxage=120, stale-while-revalidate=300",
      },
    },
  );
}
