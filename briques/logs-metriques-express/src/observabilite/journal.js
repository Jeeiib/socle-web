// En-têtes qui ne doivent jamais atteindre les journaux.
const CLES_INTERDITES = new Set(["authorization", "cookie"]);

// Une ligne JSON par évènement sur stdout : `docker logs` la récupère, `jq` la filtre.
export function ecrireJournal(entree) {
  const champs = Object.fromEntries(
    Object.entries(entree).filter(
      ([cle]) => !CLES_INTERDITES.has(cle.toLowerCase()),
    ),
  );
  process.stdout.write(
    `${JSON.stringify({ time: new Date().toISOString(), level: "info", ...champs })}\n`,
  );
}

// Middleware Express : journalise chaque requête une fois la réponse terminée.
// `journal` est injectable pour les tests.
export function creerJournalDeRequetes(journal = ecrireJournal) {
  return function journalDeRequetes(req, res, next) {
    const debut = process.hrtime.bigint();
    res.on("finish", () => {
      const duree_ms = Number(process.hrtime.bigint() - debut) / 1e6;
      journal({
        level: "info",
        method: req.method,
        path: req.originalUrl.split("?")[0],
        status: res.statusCode,
        duree_ms: Math.round(duree_ms * 10) / 10,
      });
    });
    next();
  };
}
