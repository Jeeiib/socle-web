import { journal } from "./journal";
import { dureeRequetes, requetesTotal } from "./metriques";

// `route` est le gabarit (/api/taches/[id]) et jamais le chemin réel : une valeur
// de label par identifiant ferait exploser le nombre de séries.
export function avecObservabilite<C = unknown>(
  route: string,
  handler: (req: Request, ctx: C) => Promise<Response>,
): (req: Request, ctx: C) => Promise<Response> {
  return async (req, ctx) => {
    const debut = performance.now();
    let status = 500;
    try {
      const reponse = await handler(req, ctx);
      status = reponse.status;
      return reponse;
    } finally {
      const duree_ms = performance.now() - debut;
      const { method } = req;
      requetesTotal.inc({ method, route, status_code: String(status) });
      dureeRequetes.observe({ method, route }, duree_ms / 1000);
      journal({
        method,
        route,
        status,
        duree_ms: Math.round(duree_ms * 10) / 10,
      });
    }
  };
}
