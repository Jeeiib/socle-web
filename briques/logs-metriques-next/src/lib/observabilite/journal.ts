// En-têtes qui ne doivent jamais atteindre les journaux.
const CLES_INTERDITES = new Set(["authorization", "cookie"]);

// Une ligne JSON par évènement sur stdout : `docker logs` la récupère, `jq` la filtre.
export function journal(entree: Record<string, unknown>): void {
  const champs = Object.fromEntries(
    Object.entries(entree).filter(
      ([cle]) => !CLES_INTERDITES.has(cle.toLowerCase()),
    ),
  );
  process.stdout.write(
    `${JSON.stringify({ time: new Date().toISOString(), level: "info", ...champs })}\n`,
  );
}
