import {
  Counter,
  Gauge,
  Histogram,
  Registry,
  collectDefaultMetrics,
} from "prom-client";

const BUCKETS_DUREE = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2];

type Metriques = {
  registre: Registry;
  requetes: Counter<"method" | "route" | "status_code">;
  duree: Histogram<"method" | "route">;
};

function creer(): Metriques {
  const registre = new Registry();
  collectDefaultMetrics({ register: registre });

  const requetes = new Counter({
    name: "http_requests_total",
    help: "Nombre de requêtes HTTP traitées",
    labelNames: ["method", "route", "status_code"] as const,
    registers: [registre],
  });
  const duree = new Histogram({
    name: "http_request_duration_seconds",
    help: "Durée de traitement des requêtes HTTP, en secondes",
    labelNames: ["method", "route"] as const,
    buckets: BUCKETS_DUREE,
    registers: [registre],
  });
  new Gauge({
    name: "app_build_info",
    help: "Version de l'application en cours d'exécution (valeur toujours 1)",
    labelNames: ["version"] as const,
    registers: [registre],
  }).set({ version: process.env.APP_VERSION || "dev" }, 1);

  return { registre, requetes, duree };
}

// Un seul jeu de métriques par processus, même si le module est rechargé (next dev).
const global = globalThis as typeof globalThis & { __metriquesApp?: Metriques };
const metriques = (global.__metriquesApp ??= creer());

export const registre = metriques.registre;
export const requetesTotal = metriques.requetes;
export const dureeRequetes = metriques.duree;
