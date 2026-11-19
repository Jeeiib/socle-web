---
nom: logs-metriques-express
prerequis:
remplace:
checks-requis:
---

# logs-metriques-express

Journaux JSON sur stdout et métriques Prometheus (méthode RED) pour une API Express : deux middlewares et un handler `/metrics`.

## Quand la prendre

- L'API Express tourne sur un serveur et on veut voir son taux de requêtes, ses erreurs et ses durées (Prometheus, Grafana).
- On veut des journaux filtrables (`docker logs | jq`).

## Quand ne pas la prendre

- Application Next.js : prendre `logs-metriques-next`.
- Hébergement serverless : Prometheus ne peut pas lire chaque instance en « pull ».

## Prérequis

Aucune brique. Elle se combine avec `monitoring` (qui lit `/metrics` en interne) et `deploiement-serveur`.

## Fichiers apportés

- `src/observabilite/journal.js` : `ecrireJournal(entree)` (une ligne JSON, `time` ISO, `level`, champs fournis ; `authorization` et `cookie` toujours écartés) et `creerJournalDeRequetes(journal)`, middleware qui journalise `{method, path, status, duree_ms}` sans la query string.
- `src/observabilite/metriques.js` : `creerMetriques({ version, metriquesParDefaut })` renvoie `{ registre, middleware, handler }`. Métriques : `http_requests_total{method,route,status_code}`, `http_request_duration_seconds{method,route,status_code}` (buckets 5 ms à 2 s), `app_build_info{version}`, plus les métriques par défaut du processus. Les routes sans correspondance (404) sont regroupées sous `route="non_trouvee"`.
- `src/observabilite/observabilite.test.js` : tests de la brique (supertest).

## Activation

1. Ajouter les dépendances : `pnpm add prom-client@^15` (et `pnpm add -D supertest vitest` si absents). Le projet doit être en ES modules (`"type": "module"`).
2. Dans l'application, avant les routes :

   ```js
   import { creerJournalDeRequetes } from "./observabilite/journal.js";
   import { creerMetriques } from "./observabilite/metriques.js";

   const metriques = creerMetriques({ version: process.env.APP_VERSION });
   app.get("/metrics", metriques.handler); // avant les deux middlewares : collectes non comptées
   app.use(creerJournalDeRequetes());
   app.use(metriques.middleware);
   ```

3. Ne pas exposer `/metrics` au public : le reverse proxy ne doit pas le relayer, Prometheus le lit en interne sur le réseau Docker.

Aucun check requis.

## Vérification

- `bash scripts/verifier-briques.sh logs-metriques-express` : projet temporaire (Express 5, prom-client 15, vitest, supertest) avec les sources de la brique, puis `vitest run`.
- Dans le projet : `curl localhost:3000/metrics | grep http_requests_total`.

## Pièges connus

- Le label `route` est le gabarit Express (`/api/taches/:id`) : ne jamais le remplacer par `req.path`, une série par identifiant fait exploser la cardinalité.
- Le middleware de métriques doit être monté avant les routes, sinon rien n'est compté.
- `ecrireJournal` ne retire que `authorization` et `cookie` au premier niveau : ne pas y mettre de mot de passe ni de donnée personnelle.
- Express 5 : `req.route` reste vide pour une 404, d'où le label `non_trouvee`.
