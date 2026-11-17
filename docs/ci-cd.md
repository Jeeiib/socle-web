# CI/CD

Trois workflows dans `.github/workflows/` : `ci.yml` (qualité), `security.yml` (sécurité) et `release.yml` (livraison). Principe commun : **shift-left**, on casse tôt, sur la PR, pas en production.

## Ce que fait chaque workflow

### `ci.yml`, nom « CI »

Se déclenche sur chaque PR, sur `main` (hors modifications de `**.md` et `docs/**`) et à la demande.

| Job          | Rôle                                                                    | Dépend de          |
| ------------ | ----------------------------------------------------------------------- | ------------------ |
| `actionlint` | Analyse les workflows (binaire officiel, somme de contrôle vérifiée)    | rien               |
| `qualite`    | `pnpm lint`, `pnpm typecheck`, `pnpm format:check`                      | rien               |
| `tests`      | `pnpm test:coverage` (seuil de 80 % de lignes bloquant), résumé de couverture dans le run | rien |
| `build`      | `pnpm build`                                                            | `qualite`, `tests` |
| `docker`     | Construit l'image, la scanne avec Trivy, la lance et teste `/api/health` | `qualite`, `tests` |

Les cinq noms sont les **checks requis** du ruleset (`.github/rulesets/main.json`). Ne les renommez pas, ne les passez pas en matrice : le nom affiché d'un job de matrice change, et le check requis ne serait plus jamais fourni (la PR resterait bloquée).

Le job `docker` teste l'image qui sera réellement livrée (`load: true`), pas un build parallèle.

### `security.yml`, nom « Sécurité »

Sur chaque PR, sur `main`, chaque lundi à 6 h UTC (pour détecter les CVE publiées entre deux commits) et à la demande. Jobs : `secrets`, `dependances`, `sast`, `codeql`. Détail dans [securite.md](securite.md).

### `release.yml`, nom « Release »

Se déclenche sur un tag `v*.*.*`.

1. Job `image` : calcule les tags (semver complet, `major.minor`, SHA), **construit l'image une seule fois**, la scanne avec Trivy, puis pousse sur GHCR exactement l'image scannée. Règle « build once » : si on reconstruisait entre le scan et la publication, on publierait ce qu'on n'a pas scanné.
2. Job `release` : crée la release GitHub avec les notes générées. Un tag avec un tiret (`v1.0.0-rc.1`) donne une pré-version, qui ne devient pas la dernière release.

Les tags ne se posent que depuis une `main` verte : le workflow ne revérifie pas la CI, c'est une règle à respecter.

## Pourquoi épingler les actions par SHA

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```

Un tag Git (`v7`) est mobile : son propriétaire, ou quelqu'un qui a pris son compte, peut le faire pointer vers un autre code, qui s'exécutera chez vous avec vos secrets. Un SHA de commit est immuable. Le commentaire `# vX.Y.Z` garde le workflow lisible, et Dependabot (écosystème `github-actions`) propose les mises à jour en les groupant dans une seule PR hebdomadaire.

Pour résoudre un SHA : `gh api repos/<owner>/<repo>/commits/<tag> -q .sha` (donne le commit même pour un tag annoté).

Les outils téléchargés (actionlint, gitleaks) le sont par version exacte avec vérification `sha256sum --check`, plutôt que par une action tierce de plus.

## Permissions minimales

Chaque workflow déclare `permissions: {}` en haut (aucun droit), puis chaque job demande le strict nécessaire : `contents: read` presque partout, `security-events: write` seulement pour `codeql`, `packages: write` seulement pour l'image de release, `contents: write` seulement pour créer la release. Pourquoi : si un job est compromis, le jeton `GITHUB_TOKEN` qu'il détient ne peut presque rien faire.

Autres durcissements : `persist-credentials: false` sur chaque `checkout` (le jeton n'est pas laissé dans `.git`), `timeout-minutes` sur chaque job (un job bloqué ne consomme pas des heures), `pnpm install --frozen-lockfile` (la CI échoue si le lockfile n'est pas à jour).

## Pas de `${{ }}` d'entrée utilisateur dans un `run:`

Une expression comme `${{ github.head_ref }}` est substituée **avant** l'exécution du shell : un nom de branche malicieux devient du code. On passe donc toujours par `env:` et on lit la variable shell :

```yaml
env:
  TAG: ${{ github.ref_name }}
run: gh release create "$TAG"
```

C'est ce que font les étapes de `release.yml`.

## Concurrency

```yaml
concurrency:
  group: ci-${{ github.workflow }}-${{ github.event_name == 'pull_request' && github.ref || github.sha }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

Sur une PR, un nouveau push annule l'exécution précédente (inutile de payer pour un état obsolète). Sur `main`, le groupe est par SHA et rien n'est annulé : chaque commit garde sa trace CI complète. La release n'annule jamais (`cancel-in-progress: false`) : un push d'image à moitié fait est pire qu'une attente.

## Les deux pièges du cours

**Un job sauté compte comme réussi.** Si un job est ignoré par une condition `if:` ou parce qu'une dépendance a été sautée, GitHub le marque « skipped », et un check requis « skipped » est considéré comme satisfait. Une PR peut donc passer alors que rien n'a tourné. Dans le socle, aucun job requis n'a de condition, et `build` et `docker` dépendent de `qualite` et `tests` (s'ils échouent, `build` et `docker` sont sautés, mais la PR reste bloquée par les checks en échec). Si vous ajoutez une condition à un job requis, vérifiez ce cas.

**Un filtre `paths` sur `pull_request` bloque la PR pour toujours.** Si le workflow ne se déclenche pas parce que les fichiers modifiés ne correspondent pas, le check requis n'est jamais fourni et la PR reste en attente. Voilà pourquoi `ci.yml` ne filtre pas sur `pull_request`. Le filtre `paths-ignore` n'est appliqué qu'au `push` sur `main`, où il n'y a rien à attendre.

## Ajouter ou modifier un workflow

Checklist : action épinglée par SHA complet avec `# vX.Y.Z`, `permissions` minimales, `timeout-minutes`, aucune expression `${{ }}` dans un `run:`, et le job `actionlint` doit rester vert.
