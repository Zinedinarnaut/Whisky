import { z } from "zod";

import { vecPatchBaseURL } from "@/lib/vecpatch";

const reportSchema = z.object({
  game: z.string().trim().min(1).max(120),
  steam_app_id: z.string().trim().max(32).optional().default(""),
  status: z.string().trim().min(1).max(40),
  graphics_backend: z.string().trim().max(40).optional().default(""),
  hardware: z.string().trim().max(180).optional().default(""),
  notes: z.string().trim().min(1).max(4000),
});

export async function POST(request: Request) {
  const parsed = reportSchema.safeParse(await request.json().catch(() => null));

  if (!parsed.success) {
    return Response.json(
      { error: "invalid_report", issues: parsed.error.flatten().fieldErrors },
      { status: 400 },
    );
  }

  const report = parsed.data;
  const payload = {
    game: report.game,
    status: report.status,
    steam_app_id: report.steam_app_id,
    graphics_backend: report.graphics_backend,
    hardware: report.hardware,
    notes: report.notes,
    source: "vector-website",
  };

  const reportResponse = await postVecPatch("/api/v1/compatibility-reports", payload);
  if (reportResponse.ok) {
    return Response.json(await reportResponse.json(), { status: 202 });
  }

  const telemetryResponse = await postVecPatch("/api/v1/telemetry", {
    event_type: "manual_feedback",
    success: report.status.toLowerCase().includes("working"),
    steam_app_id: report.steam_app_id,
    graphics_backend: report.graphics_backend,
    details: `${report.game}: ${report.notes}`,
    metadata: payload,
  });

  if (!telemetryResponse.ok) {
    return Response.json(
      { error: "report_not_accepted", upstream_status: telemetryResponse.status },
      { status: 502 },
    );
  }

  return Response.json(await telemetryResponse.json(), { status: 202 });
}

async function postVecPatch(path: string, payload: unknown) {
  return fetch(`${vecPatchBaseURL}${path}`, {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
    cache: "no-store",
  }).catch(() => new Response(null, { status: 503 }));
}
