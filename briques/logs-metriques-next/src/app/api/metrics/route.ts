import { registre } from "@/lib/observabilite/metriques";

// prom-client dépend de Node (process, perf_hooks) : pas d'exécution Edge.
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  return new Response(await registre.metrics(), {
    headers: {
      "Content-Type": registre.contentType,
      "Cache-Control": "no-store",
    },
  });
}
