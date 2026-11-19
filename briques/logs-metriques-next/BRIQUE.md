---
nom: logs-metriques-next
prerequis:
remplace:
checks-requis:
---

# logs-metriques-next

Journaux JSON sur stdout et métriques Prometheus (méthode RED) pour une application Next.js du socle : un enveloppeur `avecObservabilite` à poser sur les route handlers, et une route `GET /api/metrics`.

## Quand la prendre

- L'application tourne sur un serveur et on veut voir son taux de requêtes, ses erreurs et ses durées (Prometheus, Grafana).
- On veut des journaux filtrables (`docker logs | jq`) plutôt que du texte libre.

## Quand ne pas la prendre

- Hébergement serverless (Vercel) : chaque instance a son propre registre et Prometheus ne peut pas les lire en « pull ». Préférer le service de métriques de l'hébergeur.
- Backend Express séparé : prendre `logs-metriques-express`.

## Prérequis

Aucune brique. Elle se combine avec `monitoring` (qui lit `/api/metrics` sur `app:3000`) et avec `deploiement-serveur` (dont Nginx bloque `/api/metrics` côté public).

## Fichiers apportés

- `src/lib/observabilite/journal.ts` : `journal(entree)` écrit une ligne JSON sur stdout (`time` ISO, `level`, champs fournis). Les clés `authorization` et `cookie` sont toujours écartées.
- `src/lib/observabilite/metriques.ts` : `registre` (prom-client) avec les métriques par défaut du processus, `http_requests_total{method,route,status_code}`, `http_request_duration_seconds{method,route}` (buckets 5 ms à 2 s) et `app_build_info{version}` (valeur 1, version lue dans `APP_VERSION`). Enregistrement unique via `globalThis` : le rechargement à chaud de `next dev` ne le duplique pas.
- `src/lib/observabilite/avec-observabilite.ts` : `avecObservabilite(route, handler)`. `route` est le gabarit (`/api/taches/[id]`), jamais le chemin réel. Mesure la durée, compte le statut, journalise `{method, route, status, duree_ms}`. Une exception est comptée comme 500 puis relancée.
- `src/app/api/metrics/route.ts` : `GET /api/metrics` (`runtime = "nodejs"`, `dynamic = "force-dynamic"`), format texte Prometheus.
- `src/lib/observabilite/observabilite.test.ts` : tests de la brique.

## Activation

1. Ajouter la dépendance : `pnpm add prom-client@^15`.
2. Envelopper les route handlers : `export const GET = avecObservabilite("/api/taches", async () => Response.json(...))`. Pour un segment dynamique, typer le contexte : `avecObservabilite<{ params: Promise<{ id: string }> }>("/api/taches/[id]", async (req, { params }) => { ... })`. Le premier argument est toujours le gabarit.
3. Ne pas exposer `/api/metrics` : avec `deploiement-serveur`, Nginx répond déjà 404 sur ce chemin côté public. Prometheus le lit en interne (`app:3000` sur le réseau Docker `app-prod`). Sans cette brique de déploiement, bloquer le chemin dans le reverse proxy.
4. Faire passer la version : l'image doit définir `APP_VERSION` (le Dockerfile du socle le fait via `--build-arg APP_VERSION`).

Aucun check requis.

## Vérification

- `bash scripts/verifier-briques.sh logs-metriques-next` : applique la brique à une copie du socle, ajoute `prom-client`, lance `pnpm test`, `pnpm typecheck` et `pnpm lint`.
- Dans le projet : `curl localhost:3000/api/metrics | grep http_requests_total` après quelques appels, `docker logs <conteneur> | jq .`.

## Pièges connus

- Le label `route` doit être le gabarit : un chemin réel (`/api/taches/42`) crée une série par identifiant et fait exploser la cardinalité.
- Une route non enveloppée n'est ni comptée ni journalisée.
- Ne mettre dans `journal` ni mot de passe, ni jeton, ni donnée personnelle : seuls `authorization` et `cookie` sont écartés d'office, au premier niveau de l'objet.
- Le registre est par processus : plusieurs réplicas de l'application donnent plusieurs séries, Prometheus les distingue par instance.
- `/api/metrics` n'est pas enveloppé (pas de mesure de ses propres lectures) : voulu, pour ne pas compter les collectes.
