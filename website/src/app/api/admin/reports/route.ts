import { vecPatchBaseURL } from "@/lib/vecpatch";

export async function GET(request: Request) {
  return proxyAdmin(request, "/api/v1/admin/reports");
}

async function proxyAdmin(request: Request, path: string) {
  const token = request.headers.get("x-admin-token") ?? "";
  const response = await fetch(`${vecPatchBaseURL}${path}`, {
    headers: {
      accept: "application/json",
      "x-admin-token": token,
    },
    cache: "no-store",
  });

  return Response.json(await response.json().catch(() => ({})), { status: response.status });
}
