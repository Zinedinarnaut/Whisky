import { vecPatchBaseURL } from "@/lib/vecpatch";

export async function GET(request: Request) {
  const token = request.headers.get("x-admin-token") ?? "";
  const response = await fetch(`${vecPatchBaseURL}/api/v1/admin/report-suggestions`, {
    headers: {
      accept: "application/json",
      "x-admin-token": token,
    },
    cache: "no-store",
  });

  return Response.json(await response.json().catch(() => ({})), { status: response.status });
}
