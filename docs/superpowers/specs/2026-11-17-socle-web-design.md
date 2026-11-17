# socle-web : conception

Date : 17/11/2026. Validé par JB (« tu peux y aller »).

## Intention

Dépôt modèle GitHub (template repository) qui sert de base à mes futurs projets web (SaaS, sites clients).
Il applique dès le premier commit les bonnes pratiques du cours DevOps CDA (Foreach Academy,
`Foreach-Academy-France/formation-cda-devops`) : conventions Git, protection de branche, CI qui teste,
image Docker durcie, sécurité dans le pipeline. Il doit être **beau et documenté** : un nouveau projet se
démarre en lisant le README.

## Approches considérées

- A. Fidèle au cours (API Node + Postgres + Docker sur VPS) : bonne révision, mais pas ma façon de déployer.
- B. Calé sur Vercel sans Docker : proche de mes projets, perd la moitié du cours.
- **C. Retenue : Next.js, Vercel par défaut, Docker-ready.** Une seule base ; l'image existe, testée et scannée
  à chaque PR, pour le jour où un client veut s'auto-héberger.

## Objectifs

- Next.js (App Router) en TypeScript strict, pnpm, Node 24 (`.nvmrc`, `engines`, `packageManager`).
- Qualité : ESLint, Prettier, `tsc --noEmit`, Vitest avec seuil de couverture bloquant (80 % lignes).
- Route `GET /api/health` : JSON `{ status: "ok", version, env, time }`, utilisée par le HEALTHCHECK Docker
  et le smoke test CI.
- Docker : multi-stage, sortie `standalone` de Next, utilisateur non-root, HEALTHCHECK, `.dockerignore`,
  image de base en tag précis, `ARG APP_VERSION`. `compose.yaml` pour lancer l'image en local.
- GitHub : ruleset de `main` versionné en JSON + script pour l'appliquer (PR obligatoire, squash seul,
  pas de force-push, checks requis, 0 approbation car je travaille seul), Conventional Commits vérifiés par
  un hook `commit-msg` (`core.hooksPath` posé par le script `prepare`), branches `<type>/<sujet>`,
  template de PR, templates d'issue, CODEOWNERS actif, Dependabot (npm, docker, github-actions, hebdo, groupé).
- CI (`ci.yml`) : lint, typecheck, tests + couverture (résumé dans `$GITHUB_STEP_SUMMARY`), build, build de
  l'image + scan Trivy (CRITICAL/HIGH, ignore-unfixed) + smoke test `/api/health` sur le conteneur.
- Sécurité (`security.yml`, PR + cron hebdo) : gitleaks sur tout l'historique (binaire vérifié par sha256),
  `pnpm audit --audit-level high`, Semgrep, CodeQL.
- Release (`release.yml`, tag `v*.*.*`) : build once, scan Trivy, push GHCR (tags SemVer + SHA court),
  release GitHub avec notes générées.
- Corrections des incohérences du cours : **toutes** les actions épinglées par SHA + commentaire de version,
  `permissions` minimales (vide au niveau workflow, droits par job), `timeout-minutes` partout,
  `concurrency` (annule sur PR, jamais sur main), `pull_request` sans filtre `paths`, entrées passées par
  `env:` jamais interpolées dans `run:`, `pnpm install --frozen-lockfile`, actionlint dans la CI.
- Documentation en français : README soigné (badges, démarrage en 5 minutes, arborescence, commandes),
  `CONTRIBUTING.md`, `SECURITY.md`, `docs/` (conventions Git, CI/CD, Docker, sécurité, check-list
  « nouveau projet depuis le socle »).

## Non-objectifs

- Pas d'IaC (OpenTofu/Ansible), pas de Prometheus/Grafana, pas de DAST ZAP : trop lourds pour un modèle.
- Pas de base de données (mes projets utilisent Supabase ou autre, au cas par cas). Choix du constructeur :
  `/api/health` ne dépend de rien.
- Pas de déploiement automatisé vers un serveur ; Vercel se branche par son intégration GitHub.
- Pas de Playwright (YAGNI) : le smoke test du conteneur couvre le bout en bout minimal.

## Anti-objectifs

- Un modèle qui ne passe pas sa propre CI dès le premier push.
- Une doc qui décrit autre chose que ce que fait le dépôt.

## Contraintes

- Commits en Conventional Commits, description en français, aucune mention de Claude.
- Pas d'emoji dans le code ni les commits.
- Dépôt GitHub `Jeeiib/socle-web`, public (recommandé, à confirmer par JB au moment du push), marqué template.
- Emplacement local : `/Volumes/SSD-JB/Dev/socle-web`.

## Laissé au constructeur

Versions exactes (dernières stables au 17/11/2026), contenu des templates d'issue, mise en page du README.
