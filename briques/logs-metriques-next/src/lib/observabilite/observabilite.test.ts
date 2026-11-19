import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { GET } from "@/app/api/metrics/route";
import { avecObservabilite } from "./avec-observabilite";
import { journal } from "./journal";
import { registre } from "./metriques";

type Ctx = { params: Promise<{ id: string }> };

const requete = (id: string, methode = "POST") =>
  new Request(`http://localhost/api/taches/${id}`, {
    method: methode,
    headers: { authorization: "Bearer secret", cookie: "sid=secret" },
  });
const ctx = (id: string): Ctx => ({ params: Promise.resolve({ id }) });

describe("observabilité", () => {
  let lignes: string[];

  beforeEach(() => {
    registre.resetMetrics();
    lignes = [];
    vi.spyOn(process.stdout, "write").mockImplementation((morceau) => {
      lignes.push(String(morceau));
      return true;
    });
  });
  afterEach(() => vi.restoreAllMocks());

  it("compte une requête sous la route en gabarit", async () => {
    const handler = avecObservabilite<Ctx>(
      "/api/taches/[id]",
      async () => new Response(null, { status: 201 }),
    );
    await handler(requete("42"), ctx("42"));

    expect(await registre.metrics()).toContain(
      'http_requests_total{method="POST",route="/api/taches/[id]",status_code="201"} 1',
    );
  });

  it("ne crée qu'une série pour deux identifiants différents", async () => {
    const handler = avecObservabilite<Ctx>(
      "/api/taches/[id]",
      async () => new Response(null, { status: 200 }),
    );
    await handler(requete("1", "GET"), ctx("1"));
    await handler(requete("2", "GET"), ctx("2"));

    const sortie = await registre.metrics();
    expect(sortie).toContain(
      'http_requests_total{method="GET",route="/api/taches/[id]",status_code="200"} 2',
    );
    expect(sortie).not.toContain("/api/taches/1");
    expect(sortie).not.toContain("/api/taches/2");
  });

  it("compte une exception comme 500 et la relance", async () => {
    const handler = avecObservabilite<Ctx>("/api/taches/[id]", async () => {
      throw new Error("panne");
    });

    await expect(handler(requete("1"), ctx("1"))).rejects.toThrow("panne");
    expect(await registre.metrics()).toContain(
      'http_requests_total{method="POST",route="/api/taches/[id]",status_code="500"} 1',
    );
    expect(JSON.parse(lignes[0]).status).toBe(500);
  });

  it("journalise une ligne JSON sans en-têtes sensibles", async () => {
    const handler = avecObservabilite<Ctx>(
      "/api/taches/[id]",
      async () => new Response(null, { status: 204 }),
    );
    await handler(requete("7"), ctx("7"));

    expect(lignes).toHaveLength(1);
    const ligne = JSON.parse(lignes[0]);
    expect(ligne).toMatchObject({
      level: "info",
      method: "POST",
      route: "/api/taches/[id]",
      status: 204,
    });
    expect(typeof ligne.duree_ms).toBe("number");
    expect(lignes[0]).not.toMatch(/authorization|cookie|secret/i);
  });

  it("journal écarte authorization et cookie et fixe time et level", () => {
    journal({ message: "test", authorization: "x", cookie: "y" });

    const ligne = JSON.parse(lignes[0]);
    expect(ligne.message).toBe("test");
    expect(ligne.level).toBe("info");
    expect(new Date(ligne.time).toISOString()).toBe(ligne.time);
    expect(ligne).not.toHaveProperty("authorization");
    expect(ligne).not.toHaveProperty("cookie");
  });

  it("GET /api/metrics répond en texte Prometheus", async () => {
    const res = await GET();

    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toContain("text/plain");
    expect(await res.text()).toContain("app_build_info");
  });
});
