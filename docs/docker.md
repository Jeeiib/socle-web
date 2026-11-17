# Docker

Le `Dockerfile` produit une image durcie en trois étapes. Chaque choix a une raison.

## Les choix du Dockerfile

| Choix                                                                     | Pourquoi                                                                                                                                                                                    |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Build multi-étapes (`deps`, `build`, `runner`)                            | L'image finale ne contient ni sources, ni devDependencies, ni pnpm : plus petite, moins de surface d'attaque                                                                                |
| `node:24.22-alpine`, jamais `latest`                                      | Tag précis avec le numéro mineur : build reproductible. Dependabot propose les mises à jour                                                                                                 |
| Copie de `package.json`, lockfile et `pnpm-workspace.yaml` avant le reste | Ordre des couches : tant que les dépendances ne changent pas, l'étape `pnpm install` est en cache. `pnpm-workspace.yaml` porte `ignoredBuiltDependencies`, sans quoi l'install s'interrompt |
| `corepack enable`                                                         | Utilise la version de pnpm figée dans `packageManager`                                                                                                                                      |
| `RUN apk upgrade --no-cache` dans `runner`                                | Applique les correctifs Alpine publiés depuis la sortie de l'image de base                                                                                                                  |
| Sortie `standalone` de Next.js uniquement                                 | Seul ce qui sert à l'exécution est copié (`.next/standalone`, `.next/static`, `public/`)                                                                                                    |
| `USER node`                                                               | Principe du moindre privilège : un attaquant qui compromet le processus n'est pas root                                                                                                      |
| `HEALTHCHECK` avec `node -e fetch(...)`                                   | Pas de `curl` dans l'image (moins de binaires) ; interroge `/api/health`                                                                                                                    |
| `CMD ["node", "server.js"]` en forme exec                                 | Node est le PID 1 et reçoit directement `SIGTERM` : arrêt propre                                                                                                                            |
| `ARG APP_VERSION`                                                         | La version (le tag Git en release) est lue par `/api/health`                                                                                                                                |
| `NEXT_TELEMETRY_DISABLED=1`                                               | Pas de télémétrie sortante                                                                                                                                                                  |

Le `.dockerignore` garde hors du contexte de build les `.env*` (sauf `.env.example`), `.git`, `node_modules`, les clés `*.pem` et les fichiers de CI : un secret local ne peut pas se retrouver dans une couche de l'image.

## Commandes

Construire et lancer à la main :

```bash
docker build -t socle-web --build-arg APP_VERSION=local .
docker run --rm -p 3000:3000 socle-web
curl http://localhost:3000/api/health
```

Avec Compose (construit et lance) :

```bash
docker compose up --build
docker compose down
```

La route de santé répond `{"status":"ok","version":"...","env":"production","time":"..."}`. L'état du healthcheck se lit avec `docker inspect -f '{{.State.Health.Status}}' <conteneur>`.

## Durcissement du `compose.yaml`

| Option                              | Effet                                                                                                                                                          |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `read_only: true`                   | Système de fichiers du conteneur en lecture seule                                                                                                              |
| `tmpfs: /tmp` et `/app/.next/cache` | Seuls endroits inscriptibles. Next écrit son cache dans `.next/cache` ; un tmpfs appartient à root par défaut, d'où `uid=1000,gid=1000` (l'utilisateur `node`) |
| `security_opt: no-new-privileges`   | Interdit l'élévation de privilèges (setuid, etc.)                                                                                                              |
| `restart: unless-stopped`           | Redémarre après un crash ou un redémarrage de la machine                                                                                                       |
| `APP_VERSION: ${APP_VERSION:-dev}`  | La version peut être passée au build, `dev` par défaut                                                                                                         |

## Scan et livraison

La CI (`job docker`) et la release scannent l'image avec Trivy (gravités `CRITICAL,HIGH`, correctifs disponibles seulement, échec si trouvé). Les exceptions vont dans `.trivyignore`, qui reste vide à dessein : une CVE n'y entre qu'avec un commentaire (laquelle, pourquoi inexploitable, date de revue, propriétaire). Voir [securite.md](securite.md).

À la release, l'image est publiée sur GHCR : `ghcr.io/<propriétaire>/<dépôt>:<version>`, avec les tags semver complet, `major.minor` (sauf pré-version) et SHA court. Il n'y a volontairement pas de tag `latest` : un tag mobile n'est pas reproductible.

```bash
docker pull ghcr.io/jeeiib/socle-web:0.1.0
```
