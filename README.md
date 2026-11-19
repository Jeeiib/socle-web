# socle-web

Un socle Next.js (TypeScript) prêt à cloner, qui applique les bonnes pratiques DevOps et DevSecOps dès le premier commit.

[![CI](https://github.com/Jeeiib/socle-web/actions/workflows/ci.yml/badge.svg)](https://github.com/Jeeiib/socle-web/actions/workflows/ci.yml)
[![Sécurité](https://github.com/Jeeiib/socle-web/actions/workflows/security.yml/badge.svg)](https://github.com/Jeeiib/socle-web/actions/workflows/security.yml)
[![Licence MIT](https://img.shields.io/badge/licence-MIT-blue.svg)](LICENSE)

Le dépôt est un modèle GitHub : on l'utilise pour démarrer un projet qui a déjà sa CI, ses scans de sécurité, son image Docker durcie et ses règles de contribution. Il s'appuie sur le cours [formation-cda-devops](https://github.com/Foreach-Academy-France/formation-cda-devops) de Foreach Academy, dont il corrige aussi quelques incohérences (voir [Écarts assumés avec le cours](#écarts-assumés-avec-le-cours)).

## Ce que contient le socle

| Thème                | Outil                                                         | Fichier                                                      |
| -------------------- | ------------------------------------------------------------- | ------------------------------------------------------------ |
| Application          | Next.js 16, React 19, TypeScript strict                       | `src/`, `tsconfig.json`                                      |
| Santé                | Route `/api/health`                                           | `src/app/api/health/route.ts`, `src/lib/health.ts`           |
| Qualité              | ESLint, Prettier                                              | `eslint.config.mjs`, `.prettierrc.json`                      |
| Tests                | Vitest, seuil de couverture 80 %                              | `vitest.config.ts`                                           |
| Conventions          | Conventional Commits, hooks Git                               | `.githooks/commit-msg`, `.githooks/pre-commit`               |
| Protection de `main` | Ruleset GitHub versionné                                      | `.github/rulesets/main.json`, `scripts/appliquer-ruleset.sh` |
| Intégration continue | GitHub Actions                                                | `.github/workflows/ci.yml`                                   |
| Sécurité             | gitleaks, pnpm audit, Semgrep, CodeQL                         | `.github/workflows/security.yml`, `.gitleaks.toml`           |
| En-têtes HTTP        | CSP, HSTS, `nosniff`, `frame-ancestors` dans `next.config.ts` | `next.config.ts`, `src/lib/en-tetes-securite.ts`             |
| Image                | Docker multi-étapes, utilisateur `node`                       | `Dockerfile`, `compose.yaml`, `.dockerignore`                |
| Scan d'image         | Trivy                                                         | `.github/workflows/ci.yml`, `.trivyignore`                   |
| Livraison            | Release sur tag, image sur GHCR                               | `.github/workflows/release.yml`                              |
| Chaîne logicielle    | SBOM CycloneDX, attestations de provenance et de SBOM         | `.github/workflows/release.yml`                              |
| Briques              | Catalogue de briques optionnelles, job `briques` en CI        | `briques/`, `scripts/ajouter-brique.sh`                      |
| Mises à jour         | Dependabot                                                    | `.github/dependabot.yml`                                     |
| Revue                | CODEOWNERS (revue non bloquante), modèles de PR et d'issue    | `.github/CODEOWNERS`, `.github/pull_request_template.md`     |

## Démarrer en 5 minutes

Prérequis : Node 24 (voir `.nvmrc`) et pnpm 10 (via `corepack enable`).

1. Sur GitHub, cliquer sur **Use this template** puis **Create a new repository**.
2. Cloner votre nouveau dépôt :

   ```bash
   git clone git@github.com:<vous>/<votre-projet>.git
   cd <votre-projet>
   ```

3. Installer et lancer :

   ```bash
   pnpm install
   pnpm dev
   ```

   L'application répond sur <http://localhost:3000>, la santé sur <http://localhost:3000/api/health>.

Variante Docker, sans Node installé :

```bash
docker compose up --build
```

Pour finir la mise en place (ruleset, réglages du dépôt, briques, premier tag), suivre [docs/demarrer-un-projet.md](docs/demarrer-un-projet.md).

## Catalogue de briques

Une brique est un ensemble de fichiers optionnels (workflow, compose, scripts) avec une fiche `BRIQUE.md` qui dit quand la prendre et comment l'activer. Le socle ne les impose pas : on ajoute celles dont le projet a besoin.

```bash
SOCLE_DIR=<clone du socle> scripts/ajouter-brique.sh <nom>
```

| Brique                                                             | Rôle                                                                                 | Prérequis           |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------ | ------------------- |
| [postgres-ci](briques/postgres-ci/BRIQUE.md)                       | Job `integration` : tests d'intégration contre une vraie base PostgreSQL 16          | aucun               |
| [deploiement-serveur](briques/deploiement-serveur/BRIQUE.md)       | Déploiement de l'image sur un serveur par SSH, Nginx TLS, retour arrière automatique | aucun               |
| [staging-prod](briques/staging-prod/BRIQUE.md)                     | Déploiement en deux temps : staging, puis production après approbation               | deploiement-serveur |
| [sauvegardes](briques/sauvegardes/BRIQUE.md)                       | PostgreSQL à côté de l'application, dump avant chaque déploiement, restauration      | deploiement-serveur |
| [iac-opentofu](briques/iac-opentofu/BRIQUE.md)                     | Staging décrit en code avec OpenTofu, plan commenté sur les PR, détection de dérive  | deploiement-serveur |
| [ansible](briques/ansible/BRIQUE.md)                               | Playbook rejouable qui prépare le serveur de production                              | aucun               |
| [logs-metriques-next](briques/logs-metriques-next/BRIQUE.md)       | Journaux JSON et métriques Prometheus (RED) pour l'application Next.js               | aucun               |
| [logs-metriques-express](briques/logs-metriques-express/BRIQUE.md) | Journaux JSON et métriques Prometheus (RED) pour une API Express                     | aucun               |
| [monitoring](briques/monitoring/BRIQUE.md)                         | Prometheus, sonde blackbox, Alertmanager, Grafana, alertes sur le téléphone (ntfy)   | deploiement-serveur |
| [incidents](briques/incidents/BRIQUE.md)                           | Runbook d'incidents et modèle de post-mortem sans blâme                              | aucun               |
| [dast-zap](briques/dast-zap/BRIQUE.md)                             | Scan dynamique ZAP baseline du staging                                               | aucun               |

Détails du format, des codes de retour et de la vérification dans [briques/README.md](briques/README.md).

## Scripts

| Commande             | Rôle                                          |
| -------------------- | --------------------------------------------- |
| `pnpm dev`           | Serveur de développement                      |
| `pnpm build`         | Build de production                           |
| `pnpm start`         | Lance le build de production                  |
| `pnpm lint`          | ESLint                                        |
| `pnpm typecheck`     | Vérification TypeScript (`tsc --noEmit`)      |
| `pnpm format`        | Formate tout le dépôt avec Prettier           |
| `pnpm format:check`  | Vérifie le formatage sans écrire              |
| `pnpm test`          | Tests Vitest                                  |
| `pnpm test:coverage` | Tests avec couverture (seuil bloquant à 80 %) |

Avant de pousser : `pnpm lint && pnpm typecheck && pnpm format:check && pnpm test:coverage && pnpm build`.

## Arborescence

```text
.
├── .githooks/              Hooks Git (commit-msg, pre-commit), activés par `pnpm install`
├── .github/
│   ├── workflows/          ci.yml, security.yml, release.yml (les briques en ajoutent d'autres)
│   ├── rulesets/main.json  Règles de protection de la branche main
│   ├── dependabot.yml      Mises à jour automatiques
│   ├── CODEOWNERS          Relecteurs désignés (revue non bloquante : `require_code_owner_review` est à `false` dans le ruleset, à passer à `true` en équipe)
│   └── ISSUE_TEMPLATE/     Modèles d'issues
├── briques/                Catalogue de briques optionnelles (une fiche BRIQUE.md chacune)
├── docs/                   Guides détaillés
├── scripts/                appliquer-ruleset.sh, ajouter-brique.sh, verifier-briques.sh, tests
├── src/
│   ├── app/                Pages et route /api/health
│   └── lib/                health.ts et en-tetes-securite.ts, testés
├── Dockerfile              Image multi-étapes, non-root
├── compose.yaml            Lancement local durci
├── .gitleaks.toml          Configuration des scans de secrets
└── .trivyignore            Exceptions Trivy (vide à dessein)
```

## Pipeline

```mermaid
flowchart LR
    A[Branche et PR] --> B{Checks requis}
    B -->|qualite, tests, build, docker, actionlint, briques| C[Revue]
    B -.->|secrets, dependances, sast, codeql| C
    C --> D[Squash et merge]
    D --> E[main verte]
    E --> F[Tag vX.Y.Z]
    F --> G[Build, scan Trivy, push GHCR, SBOM et attestations]
    G --> H[Release GitHub]
```

Les six checks en trait plein sont requis par le ruleset de `main`. Le workflow Sécurité tourne aussi sur chaque PR, et chaque lundi pour détecter les CVE publiées entre deux commits. Détails dans [docs/ci-cd.md](docs/ci-cd.md).

## Documentation

| Guide                                                    | Contenu                                               |
| -------------------------------------------------------- | ----------------------------------------------------- |
| [Démarrer un projet](docs/demarrer-un-projet.md)         | Check-list après « Use this template »                |
| [Conventions Git](docs/conventions-git.md)               | Commits, branches, revue, que faire si un secret fuit |
| [CI/CD](docs/ci-cd.md)                                   | Chaque workflow, chaque job, les pièges               |
| [Docker](docs/docker.md)                                 | Chaque choix du Dockerfile et du compose              |
| [Sécurité](docs/securite.md)                             | Outils, étapes du pipeline, triage                    |
| [Contribuer](CONTRIBUTING.md) et [Sécurité](SECURITY.md) | Règles de contribution, signalement de vulnérabilité  |

## Écarts assumés avec le cours

Le socle suit le cours [formation-cda-devops](https://github.com/Foreach-Academy-France/formation-cda-devops) de Foreach Academy et s'en écarte volontairement sur les points suivants.

- **Toutes les actions sont épinglées par SHA complet, CI comprise.** Un tag peut être déplacé après coup, un SHA non : aucune exception, y compris pour les jobs de CI.
- **Non-root partout.** Le conteneur tourne avec l'utilisateur `node`, et le compose ajoute système de fichiers en lecture seule et `no-new-privileges`.
- **Next.js et Vercel** à la place d'Express et d'un VPS : l'hébergement de l'application est délégué, l'image Docker reste livrée pour qui veut l'auto-héberger.
- **IaC, monitoring et ZAP en briques, pas dans la base** : ils dépendent de l'infrastructure cible et s'ajoutent au projet qui en a besoin. L'IaC ne couvre que le staging, et `staging-prod` et `iac-opentofu` sont deux façons alternatives de le décrire (une seule des deux). Le `tofu apply` du staging se lance à la main : le cours l'appliquait en CI depuis un runner self-hosted, mais ici l'état est gardé sur le serveur, pour un seul opérateur.
- **Déploiement par SSH** au lieu d'un runner self-hosted : pas de machine qui écoute en permanence les jobs du dépôt.
- **Une seule application Next.js** au lieu d'une API et d'un front séparés. La brique Express existe pour qui garde une API distincte, et elle est en Express 5 (le cours utilisait Express 4).
- **pnpm** au lieu de npm, avec `--frozen-lockfile` en CI.
- **`/api/health`** au lieu de `/health` : la route vit dans l'application Next.js.
- **Release sur tag** (`vX.Y.Z`) au lieu d'une image à chaque push sur `main` : une version est un choix, pas un effet de bord d'une fusion.
- **HSTS ajouté** : le cours le recommande sans l'appliquer. Les en-têtes de sécurité sont posés par `next.config.ts`.
- **`actions/attest`** pour la provenance et le SBOM, à la place de `attest-build-provenance` et `attest-sbom`, devenus de simples enveloppes de l'action unique.

## Licence

[MIT](LICENSE), Jean-Baptiste Renart, 2026.
