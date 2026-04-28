import { vecPatchBaseURL } from "@/lib/vecpatch";
import { noStoreHeaders } from "@/lib/server-security";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  return proxyAdmin(request, "/api/v1/admin/reports");
}

async function proxyAdmin(request: Request, path: string) {
  const token = request.headers.get("x-admin-token") ?? "";
  if (!token) {
    return Response.json(
      { error: "unauthorized", message: "Admin token required." },
      { status: 401, headers: noStoreHeaders() },
    );
  }

  const response = await fetch(`${vecPatchBaseURL}${path}`, {
    headers: {
      accept: "application/json",
      "x-admin-token": token,
    },
    cache: "no-store",
  }).catch(() => null);

  if (!response) {
    return Response.json(
      { error: "vecpatch_unavailable", message: "VecPatch admin API is unavailable." },
      { status: 503, headers: noStoreHeaders() },
    );
  }

  return Response.json(await response.json().catch(() => ({})), {
    status: response.status,
    headers: noStoreHeaders(),
  });
}
