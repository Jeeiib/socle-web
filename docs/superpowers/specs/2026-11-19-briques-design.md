# Socle : catalogue de briques et skill aiguilleur

Date : 19/11/2026. Statut : validé le 19/11/2026.

## Intention

Le socle `Jeeiib/socle-web` a été posé le 17/11/2026, au jour 2 du cours DevOps CDA (Foreach Academy). Il couvre les
jours 1 et 2 et la sécurité du pipeline, mais pas le reste du cours : déploiement sur serveur avec staging et prod,
sauvegardes, IaC, monitoring, incidents, DAST, SBOM et signature.

Je veux que le socle porte **tout le cours**. Comme je vais faire des projets très différents (site vitrine sur Vercel,
SaaS avec base, app sur mon propre serveur, projets dans d'autres langages), tout ne doit pas arriver dans chaque
projet : le skill Claude `socle-repo` devient un **aiguilleur** qui sait quelle brique prendre selon le besoin, et qui
se déclenche aux bons moments (créer un projet, le mettre en ligne, ajouter une base, du monitoring, préparer une
release, auditer la sécurité, gérer un incident), pas seulement quand on parle de « dépôt ».

## Objectifs

1. Un dossier `briques/` dans le socle : chaque pratique du cours qui ne sert pas à tous les projets devient une brique
   prête à copier, avec une fiche qui dit quand la prendre.
2. La base du socle s'enrichit de ce qui sert à **tous** les projets.
3. La CI du socle teste les briques, pour qu'elles ne pourrissent pas.
4. Le skill `socle-repo` est réécrit en aiguilleur, avec des déclencheurs larges, puis testé sur des scénarios.
5. Le README et `docs/demarrer-un-projet.md` décrivent le catalogue.

## Non-objectifs

- Les équivalents Jenkins et GitLab CI du cours : le socle reste GitHub Actions seul.
- Loki/Promtail (bonus du cours) et les outils de pentest manuels (nmap, Burp, sqlmap) : pas de brique.
- Kubernetes, GitOps, PaaS autres que Vercel : cités dans le cours, hors périmètre.

## Anti-objectifs (ce qui serait un échec même si ça marche)

- Un nouveau projet Vercel qui démarre avec des workflows ou des fichiers de serveur dont il n'a pas besoin.
- Une brique qui ne fonctionne plus le jour où on la copie (d'où la CI des briques).
- Un skill qui ne se déclenche que si on prononce « socle » ou « dépôt ».
- Des fichiers truffés de longs commentaires : le code reste sobre, les explications vont dans les fiches.

## Approches considérées

- **A. Socle tout compris qu'on élague** : lourd, chaque projet démarre avec des workflows qui échouent tant qu'on n'a
  pas élagué, et un oubli laisse des briques mortes. Écarté.
- **B. Base légère + catalogue `briques/` dans le même dépôt** : retenu. Une seule source, testée par la CI du socle ;
  le skill fait le tri.
- **C. Plusieurs modèles** (`socle-web-vercel`, `socle-serveur`…) : duplication qui diverge. Écarté.

## Ce qui entre dans la base (utile à tous les projets)

| Ajout | Source dans le cours |
|---|---|
| En-têtes de sécurité dans `next.config.ts` (CSP, `nosniff`, `Referrer-Policy`, `Permissions-Policy`, COOP/CORP, HSTS) | `solution/front/nginx.conf`, slides jour 5 |
| SBOM CycloneDX et attestation de provenance de l'image dans `release.yml` | slides jour 5, bonus étape 5 |
| `docs/securite.md` : registre des exceptions (règle, justification, date de revue), modèle de menaces STRIDE à remplir, procédure « secret exposé » | `solution/docs/SECURITE.md`, slides jour 5 |
| Allowlists gitleaks étroites, `// nosemgrep: <id>` jamais nu | `solution/.gitleaks.toml`, slides jour 5 |
| Notes de release générées depuis les Conventional Commits (pas de CHANGELOG à la main) | exercice jour 2 |

## Le catalogue de briques

Chaque brique est un dossier `briques/<nom>/` qui contient :

- `BRIQUE.md` : quand la prendre, quand ne pas la prendre, prérequis (autres briques, serveur, base), fichiers apportés,
  étapes d'activation (y compris réglages GitHub : environments, secrets, variables), vérification ;
- ses fichiers, rangés **au chemin qu'ils auront dans le projet** (par exemple `briques/monitoring/monitoring/prometheus/prometheus.yml`).

Les workflows d'une brique vivent dans `briques/<nom>/.github/workflows/` : ils ne tournent pas dans le socle lui-même.

| Brique | Ce qu'elle apporte | Prérequis |
|---|---|---|
| `postgres-ci` | Job de tests d'intégration avec un service Postgres en CI | une base Postgres |
| `deploiement-serveur` | `compose.prod.yaml`, proxy Nginx TLS (HSTS inclus), `deploy.sh` idempotent avec `.previous_tag`, `smoke-test.sh` qui vérifie la version, `gen-cert.sh`, `.env.example`, workflow de déploiement par SSH (utilisateur `deploy`, `known_hosts` en secret) ; variante runner self-hosted documentée | un serveur avec Docker |
| `staging-prod` | Environments GitHub staging puis production (approbation, branche `main` seule), rollback par `workflow_dispatch` et automatique si le smoke test de prod échoue | `deploiement-serveur` |
| `sauvegardes` | `backup.sh` (pg_dump gzippé, rotation 7 jours), sauvegarde avant chaque mise en prod, procédure de restauration à tester | `deploiement-serveur`, Postgres |
| `iac-opentofu` | `infra/` (provider Docker, state hors Git, variables validées, import du volume, image Postgres épinglée par digest), `iac.yml` (validate, plan en commentaire de PR, détection de dérive hebdomadaire) | `deploiement-serveur` |
| `ansible` | Playbook idempotent qui prépare le dossier de prod (`.env` en 0600, mot de passe généré une fois, handlers) | un serveur |
| `logs-metriques-next` / `logs-metriques-express` | Logs JSON une ligne par requête, route `/metrics` (prom-client, RED, cardinalité maîtrisée), l'une pour Next.js, l'autre pour Express (décision 8) | app Node |
| `monitoring` | `compose.monitoring.yaml` (Prometheus, sonde blackbox, Alertmanager, Grafana provisionné), règles d'alerte RED avec tests `promtool`, dashboard en code, SLO de référence, alertes sur le téléphone par ntfy (voir décision 7) | `deploiement-serveur` (logs et métriques conseillés) |
| `incidents` | `docs/INCIDENTS.md` : runbook par alerte, méthode de diagnostic, modèle de post-mortem sans blâme | aucun (plus utile avec `monitoring`) |
| `dast-zap` | Workflow ZAP baseline contre une URL déployée (preview ou staging), politique de règles `.zap/rules.tsv` | une URL de test |

Les stratégies de déploiement (recreate, rolling, blue/green, canary, feature flags) et les migrations
expand/contract n'ont pas de code dans le cours : elles vont dans la fiche de `deploiement-serveur` et dans le skill,
comme règles de décision.

Les pièges vécus pendant le TP vont dans les fiches concernées : labels Compose sur un volume importé
(`ignore_changes`), label réseau qui force le remplacement de tout, healthcheck à aligner sur le Dockerfile, tag Postgres
qui bouge quand un autre pipeline fait un pull, `paths-ignore` qui bloque une PR de doc avec des checks requis, socket
Docker introuvable avec Colima (`DOCKER_HOST`).

## Ajouter une brique à un projet

Script `scripts/ajouter-brique.sh <nom> [dossier-du-projet]` : copie les fichiers de la brique (sans `BRIQUE.md`),
**refuse d'écraser** un fichier existant (il liste les conflits et s'arrête), vérifie que les briques prérequises sont
présentes, puis affiche les étapes d'activation de la fiche. Le skill l'utilise ; on peut aussi le lancer à la main.

Le script lit les briques dans le clone local du socle (`/Volumes/SSD-JB/Dev/socle-web`), ou à défaut les télécharge
depuis `Jeeiib/socle-web` sur GitHub (pour un autre poste ou une autre personne).

À la création d'un projet depuis le modèle, `briques/` est supprimé du nouveau projet (étape de
`docs/demarrer-un-projet.md`) : la seule source des briques reste le socle, pour qu'aucun projet ne garde une copie
périmée.

## La CI des briques

Un job `briques` dans `ci.yml` du socle, toujours lancé (pas de filtre `paths`, règle du socle) :

- `actionlint` sur les workflows des briques ;
- `tofu fmt -check` et `tofu validate` sur `iac-opentofu` ;
- `promtool check rules` et `promtool test rules` sur `monitoring` ;
- `ansible-playbook --syntax-check` sur `ansible` ;
- `shellcheck` sur tous les scripts ;
- `docker compose config` sur chaque fichier Compose ;
- test du script `ajouter-brique.sh` (copie dans un dossier temporaire, refus d'écrasement, prérequis manquant).

Les tests des briques de logs et métriques tournent dans un projet temporaire (décision 2).

## Le skill `socle-repo`

`SKILL.md` reste court et sert d'aiguilleur :

- **description** élargie pour se déclencher quand on crée un projet ou un dépôt, qu'on veut mettre en ligne ou
  déployer, ajouter une base de données, un staging, une sauvegarde, du monitoring, des logs, des alertes ou des notifications sur le téléphone, préparer
  une release, auditer la sécurité, gérer un incident ou un post-mortem, ou qu'on écrit un workflow, un Dockerfile, un
  compose ou un ruleset ;
- un **tableau « besoin → briques »** (ex. « site vitrine » → base seule ; « SaaS Next + Supabase » → base +
  `logs-metriques-next` + `dast-zap` ; « app sur mon serveur avec Postgres » → base + `deploiement-serveur` +
  `staging-prod` + `sauvegardes` + `monitoring` + `incidents`) ;
- la règle « le socle fait foi » : pour le détail, le skill lit `briques/<nom>/BRIQUE.md` dans le socle plutôt que de
  dupliquer le contenu ;
- ce qu'il faut reproduire quand le projet n'est pas en Node (logs JSON sur stdout, `/metrics`, healthcheck) ;
- les pièges actuels du skill, conservés.

**Test du skill** à la fin, avec la méthode du skill `writing-skills` : des scénarios donnés à des sous-agents sans
contexte (« je lance un site pour un restaurant », « je veux mettre mon API Express sur un VPS avec une base »,
« ajoute des alertes à mon projet », « j'ai eu une panne hier », « prépare la v1.0.0 »…), en vérifiant que le skill se
déclenche et choisit les bonnes briques.

## Documentation

- README : nouvelle section « Catalogue de briques » (tableau nom, rôle, prérequis) et mise à jour du tableau « Ce que
  contient le socle » pour les ajouts de la base.
- `docs/demarrer-un-projet.md` : étape « choisir ses briques » et suppression de `briques/`.
- La section « Écarts assumés avec le cours » s'enrichit : pnpm au lieu de npm, `/api/health` au lieu de `/health`,
  release sur tag au lieu de chaque push sur `main`, HSTS ajouté (le cours le recommande sans l'appliquer).

## Contraintes

- Les règles actuelles du socle s'appliquent aux briques : actions épinglées par SHA, `permissions` minimales,
  `timeout-minutes`, pas de `${{ github.event.* }}` dans `run:`, images de base à version précise, conteneurs
  non-root.
- Le socle est public : aucun secret, aucune donnée personnelle dans les briques.
- Travail sur une branche et PR : le ruleset du socle interdit le push direct sur `main`.

## Décisions prises après la relecture (mes choix, à vérifier par JB)

1. **Une brique qui complète une autre** : pas de fusion automatique de fichiers.
   - Points d'extension posés par `deploiement-serveur` : `deploy.sh` lance, s'ils existent, les scripts de
     `deploy/avant-deploiement.d/` (la brique `sauvegardes` y dépose `10-sauvegarde.sh`) ; le compose de monitoring
     reste un fichier à part qui rejoint le réseau de prod en `external`.
   - Quand une brique doit changer un fichier d'une autre (le workflow de déploiement par `staging-prod`), elle le
     déclare dans l'en-tête de `BRIQUE.md` (`remplace:`). Le script n'accepte de le remplacer que si le fichier en place
     est encore identique à la version d'origine de la brique (empreinte SHA-256) ; sinon il s'arrête et liste le
     conflit, à fusionner à la main.
   - `iac-opentofu` remplace le compose du **staging** seulement, jamais celui de la prod (comme dans le cours).
2. **Code et tests des briques de logs et métriques** : le code et ses tests restent dans la brique (variante Next.js et
   variante Express, chacune avec ses tests). La base n'ajoute pas `prom-client`. Le job `briques` de la CI crée un
   projet temporaire à partir de la base, y applique la brique avec `ajouter-brique.sh`, installe les dépendances et
   lance les tests : ça teste à la fois la brique et le script.
3. **CSP de la base** : un niveau compatible avec les pages statiques de Next.js et avec Vercel : `default-src 'self'`,
   `script-src 'self' 'unsafe-inline'` (sans `unsafe-eval` en production), `object-src 'none'`,
   `frame-ancestors 'none'`, `base-uri 'self'`, `form-action 'self'`, plus les autres en-têtes. La CSP stricte à nonce
   (qui force le rendu dynamique) est décrite dans `docs/securite.md` comme option pour les apps qui le justifient.
4. **Récupération de l'image par le serveur** : le déploiement se déclenche après la release (tag `v*.*.*`, même
   image scannée), par SSH. Le job se connecte au serveur, y fait `docker login ghcr.io` avec le `GITHUB_TOKEN` du job
   passé sur l'entrée standard, `docker pull` du tag exact, puis `docker logout`. Pas de build sur le serveur. La
   variante runner self-hosted du cours est documentée dans la fiche.
5. **Checks requis** : seuls les jobs lancés sur **chaque** PR deviennent des checks requis. Les workflows de brique
   déclenchés sur un chemin (`iac.yml`), un horaire ou un déploiement ne le sont jamais ; chaque `BRIQUE.md` dit
   explicitement quels checks ajouter au ruleset (souvent aucun).
6. **Livraison du skill** : `SKILL.md` vit dans `~/.claude/skills/socle-repo/` (synchronisé entre le Mac et le PC par
   `claude-config`), hors du dépôt `socle-web`. Les tests du skill chargent cette version.

7. **Alertes sur le téléphone (ntfy)** : le récepteur par défaut de la brique `monitoring` envoie les alertes à
   ntfy, appli gratuite (iOS, Android) qui reçoit des notifications push.
   - Alertmanager n'a pas de récepteur ntfy natif : on utilise son `webhook_configs` générique vers
     `https://<serveur ntfy>/<sujet>?template=alertmanager`. Le modèle `alertmanager` est intégré à ntfy et met en
     forme les alertes (déclenchée, résolue) sans pont à maintenir.
   - L'adresse est lue par `url_file` et le jeton par `http_config.authorization.credentials_file`, deux fichiers
     du serveur en 600, hors de Git. Le sujet n'apparaît donc jamais dans le dépôt public.
   - Deux options décrites dans la fiche : ntfy.sh (rien à héberger, sujet long et impossible à deviner, gratuit)
     ou ntfy auto-hébergé dans le compose de monitoring (sujet protégé par jeton). Par défaut : ntfy.sh, le plus
     simple pour démarrer.
   - La fiche indique comment tester la chaîne de bout en bout : une alerte de test envoyée avec `amtool` doit
     arriver sur le téléphone, puis sa résolution.
   - Les autres récepteurs (e-mail, Discord, Slack) restent possibles par le même `webhook_configs` ; la fiche en
     donne un exemple sans les mettre par défaut.

8. **Deux briques de logs et métriques au lieu d'une** : `logs-metriques-next` (route `/api/metrics`, enveloppe
   `avecObservabilite()` des route handlers, logs JSON) et `logs-metriques-express` (middleware du cours). Une seule
   brique à variantes obligerait le script à trier des fichiers ; deux briques gardent la règle « on copie tout ».
   `monitoring` ne les exige pas (un projet dans un autre langage expose `/metrics` autrement) : sa fiche les
   conseille, seul `deploiement-serveur` est un prérequis bloquant.
9. **IaC sans runner self-hosted** : le provider Docker d'`iac-opentofu` vise `var.docker_host`
   (`unix:///var/run/docker.sock` par défaut, `ssh://deploy@<serveur>` en CI avec la clé de déploiement), pour rester
   cohérent avec le déploiement par SSH. La variante runner self-hosted du cours est décrite dans la fiche.
10. **Les outils de vérification tournent en conteneurs épinglés** (`scripts/verifier-briques.sh`) : la même commande
    marche sur le Mac (Colima) et en CI, sans rien installer.

## Laissé au constructeur

- Le contenu exact de chaque fichier, à partir de la solution du TP (`tp/fil-rouge-taskflow/solution/`) et des
  exercices, adapté à Next.js et pnpm.
- Le découpage en commits et en PR.
- Le format précis de `BRIQUE.md`, du moment qu'il couvre les rubriques listées plus haut.
