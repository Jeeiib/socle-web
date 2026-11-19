import client from "prom-client";

const BUCKETS_DUREE = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2];

// Requête sans route correspondante (404) : un seul label, sinon un robot qui
// teste 10 000 URL crée 10 000 séries.
const ROUTE_INCONNUE = "non_trouvee";

// Gabarit de la route (/api/taches/:id), jamais le chemin réel.
function etiquetteRoute(req) {
  if (!req.route) return ROUTE_INCONNUE;
  const route = `${req.baseUrl}${req.route.path}`;
  return route.length > 1 ? route.replace(/\/$/, "") : route;
}

// Un registre neuf à chaque appel : chaque test crée son application sans hériter des compteurs.
export function creerMetriques({
  version = "dev",
  metriquesParDefaut = true,
} = {}) {
  const registre = new client.Registry();
  if (metriquesParDefaut) client.collectDefaultMetrics({ register: registre });

  const requetes = new client.Counter({
    name: "http_requests_total",
    help: "Nombre de requêtes HTTP traitées",
    labelNames: ["method", "route", "status_code"],
    registers: [registre],
  });
  const duree = new client.Histogram({
    name: "http_request_duration_seconds",
    help: "Durée de traitement des requêtes HTTP, en secondes",
    labelNames: ["method", "route", "status_code"],
    buckets: BUCKETS_DUREE,
    registers: [registre],
  });
  new client.Gauge({
    name: "app_build_info",
    help: "Version de l'application en cours d'exécution (valeur toujours 1)",
    labelNames: ["version"],
    registers: [registre],
  }).set({ version }, 1);

  // À monter AVANT les routes : le code HTTP n'est connu qu'à la fin de la réponse.
  function middleware(req, res, next) {
    const arreterChrono = duree.startTimer();
    res.on("finish", () => {
      const labels = {
        method: req.method,
        route: etiquetteRoute(req),
        status_code: String(res.statusCode),
      };
      requetes.inc(labels);
      arreterChrono(labels);
    });
    next();
  }

  // À monter AVANT le middleware : les collectes de Prometheus ne sont ni comptées ni journalisées.
  async function handler(_req, res) {
    res.set("Content-Type", registre.contentType);
    res.send(await registre.metrics());
  }

  return Object.freeze({ registre, middleware, handler });
}
