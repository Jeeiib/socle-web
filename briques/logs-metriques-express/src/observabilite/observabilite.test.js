import express from "express";
import request from "supertest";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { creerJournalDeRequetes, ecrireJournal } from "./journal.js";
import { creerMetriques } from "./metriques.js";

async function valeur(metriques, nom, labels = {}) {
  const metrique = await metriques.registre.getSingleMetric(nom).get();
  const echantillon = metrique.values.find((v) =>
    Object.entries(labels).every(([cle, attendu]) => v.labels[cle] === attendu),
  );
  return echantillon ? echantillon.value : 0;
}

describe("métriques Prometheus", () => {
  let app;
  let metriques;
  let journal;

  beforeEach(() => {
    journal = vi.fn();
    metriques = creerMetriques({ version: "1.2.3", metriquesParDefaut: false });
    app = express();
    app.get("/metrics", metriques.handler);
    app.use(creerJournalDeRequetes(journal));
    app.use(metriques.middleware);
    app.post("/api/taches", (_req, res) => res.status(201).json({}));
    app.get("/api/taches/:id", (_req, res) => res.json({}));
    app.get("/api/panne", (_req, res) => res.status(500).json({}));
  });

  it("GET /metrics répond au format texte Prometheus", async () => {
    const res = await request(app).get("/metrics");

    expect(res.status).toBe(200);
    expect(res.headers["content-type"]).toContain("text/plain");
    expect(res.text).toContain("# TYPE http_requests_total counter");
    expect(res.text).toContain(
      "# TYPE http_request_duration_seconds histogram",
    );
    expect(res.text).toContain('app_build_info{version="1.2.3"} 1');
  });

  it("compte par méthode, route en gabarit et code HTTP", async () => {
    await request(app).post("/api/taches").send({});
    await request(app).get("/api/taches/42");
    await request(app).get("/api/taches/43");

    const { text } = await request(app).get("/metrics");
    expect(text).toContain(
      'http_requests_total{method="POST",route="/api/taches",status_code="201"} 1',
    );
    expect(text).toContain(
      'http_requests_total{method="GET",route="/api/taches/:id",status_code="200"} 2',
    );
    expect(text).not.toContain("/api/taches/42");
  });

  it("regroupe les routes inconnues sous un seul label", async () => {
    await request(app).get("/une/url/inconnue");
    await request(app).get("/une/autre");

    expect(
      await valeur(metriques, "http_requests_total", {
        route: "non_trouvee",
        status_code: "404",
      }),
    ).toBe(2);
  });

  it("mesure les erreurs 5xx", async () => {
    await request(app).get("/api/panne");

    expect(
      await valeur(metriques, "http_requests_total", { status_code: "500" }),
    ).toBe(1);
  });

  it("ne journalise ni ne compte les collectes de Prometheus", async () => {
    await request(app).get("/metrics");

    expect(journal).not.toHaveBeenCalled();
    expect(await valeur(metriques, "http_requests_total")).toBe(0);
  });

  it("expose les métriques par défaut du processus quand elles sont actives", async () => {
    const complet = express();
    const m = creerMetriques();
    complet.get("/metrics", m.handler);

    const { text } = await request(complet).get("/metrics");
    expect(text).toContain("process_cpu_seconds_total");
    expect(text).toContain("nodejs_eventloop_lag_seconds");
  });
});

describe("journal JSON", () => {
  it("journalise méthode, chemin sans query, statut et durée", async () => {
    const journal = vi.fn();
    const app = express();
    app.use(creerJournalDeRequetes(journal));
    app.get("/api/x", (_req, res) => res.sendStatus(204));

    await request(app).get("/api/x?jeton=secret");

    expect(journal).toHaveBeenCalledTimes(1);
    const ligne = journal.mock.calls[0][0];
    expect(ligne).toMatchObject({
      level: "info",
      method: "GET",
      path: "/api/x",
      status: 204,
    });
    expect(typeof ligne.duree_ms).toBe("number");
    expect(JSON.stringify(ligne)).not.toContain("secret");
  });

  it("ecrireJournal écrit une ligne JSON sans authorization ni cookie", () => {
    const ecrit = vi.spyOn(process.stdout, "write").mockReturnValue(true);

    ecrireJournal({ message: "test", authorization: "x", cookie: "y" });

    const ligne = JSON.parse(ecrit.mock.calls[0][0]);
    expect(ligne.message).toBe("test");
    expect(new Date(ligne.time).toISOString()).toBe(ligne.time);
    expect(ligne).not.toHaveProperty("authorization");
    expect(ligne).not.toHaveProperty("cookie");
    ecrit.mockRestore();
  });
});
