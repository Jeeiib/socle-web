# Démarrer un projet depuis le socle

Check-list à suivre une fois le dépôt créé avec **Use this template**. Comptez une demi-heure.

## 1. Renommer

Le socle porte son propre nom ; remplacez-le partout :

- `package.json` : champs `name` (et `version` si besoin) ;
- `README.md` : titre, description, et les deux badges CI et Sécurité (le badge de licence est local) (remplacer `Jeeiib/socle-web` par `<vous>/<votre-projet>`) ;
- `.github/CODEOWNERS` : remplacez `@Jeeiib` par votre identifiant GitHub ou votre équipe ;
- `src/app/page.tsx` : le titre `h1` et le lien vers `Jeeiib/socle-web#readme` ;
- `src/app/layout.tsx` : le `title` des métadonnées ;
- `LICENSE` : nom du titulaire et année ;
- `SECURITY.md` : adaptez-le si vous changez de processus de signalement.

Vous pouvez aussi **supprimer `docs/superpowers/`** : c'est l'historique de conception du modèle lui-même (spécification et plan), sans intérêt dans un projet dérivé.

## 2. Installer

```bash
pnpm install
```

`pnpm install` exécute le script `prepare`, qui active les hooks Git du dossier `.githooks` (`git config core.hooksPath .githooks`). Pourquoi : un message de commit non conforme est refusé avant d'arriver en CI, et le hook `pre-commit` lance gitleaks s'il est installé (`brew install gitleaks`).

Vérifiez que tout passe avant d'aller plus loin :

```bash
pnpm lint && pnpm typecheck && pnpm format:check && pnpm test:coverage && pnpm build
```

## 3. Pousser une première fois et laisser la CI tourner

Mieux vaut que les checks requis par le ruleset aient déjà tourné une fois : ils sont alors proposés dans l'interface et vous voyez qu'ils passent. Poussez donc `main` (ou ouvrez une première PR) avant d'appliquer le ruleset, qui interdira ensuite tout push direct.

## 4. Appliquer le ruleset de `main`

```bash
scripts/appliquer-ruleset.sh
```

Le script lit `.github/rulesets/main.json` et crée ou met à jour le ruleset `main` (il est idempotent). Il utilise `gh`, qui doit être connecté (`gh auth login`). Vous pouvez viser un autre dépôt : `scripts/appliquer-ruleset.sh <vous>/<votre-projet>`.

Effet : plus de push direct sur `main`, historique linéaire, fusion en squash uniquement, fils de revue résolus, et les cinq checks `qualite`, `tests`, `build`, `docker`, `actionlint` obligatoires et à jour avec `main`. Aucun contournement n'est prévu (`bypass_actors` vide).

## 5. Régler le dépôt

Dans **Settings** du dépôt :

| Réglage                                          | Où                               | Pourquoi                                                     |
| ------------------------------------------------ | -------------------------------- | ------------------------------------------------------------ |
| Squash seul, autres méthodes de fusion décochées | General, Pull Requests           | Un commit par PR, historique lisible                         |
| Suppression automatique des branches fusionnées  | General, Pull Requests           | Pas de branches mortes                                       |
| Dependabot alerts                                | Advanced Security                | Alerte sur les dépendances vulnérables                       |
| Secret scanning et push protection               | Advanced Security                | Bloque un secret avant qu'il n'entre dans l'historique       |
| Private vulnerability reporting                  | Advanced Security                | Rend effectif le signalement privé décrit dans `SECURITY.md` |
| **CodeQL default setup : laisser désactivé**     | Advanced Security, Code scanning | Voir ci-dessous                                              |

**Prérequis : dépôt public, ou GitHub Advanced Security activé sur un dépôt privé.** Sur un dépôt privé sans GHAS, le job `codeql` échoue, et secret scanning, push protection et signalement privé de vulnérabilité sont limités. Dans ce cas, supprimez le job `codeql` de `.github/workflows/security.yml` (il n'est pas un check requis du ruleset).

CodeQL tourne déjà via le workflow avancé `.github/workflows/security.yml` (job `codeql`). Si le « default setup » de GitHub est aussi actif, les deux publient des résultats pour le même langage et l'envoi du second est refusé : la CI échoue. Gardez donc **un seul** des deux, et ici c'est le workflow.

Dependabot ouvre ses PR avec les préfixes `build(deps)` et `ci(deps)` : ils respectent le hook de commit-msg.

## 6. Brancher Vercel

1. Sur Vercel, **Add New Project** puis importez le dépôt.
2. Gardez les réglages par défaut (framework Next.js détecté, gestionnaire pnpm détecté via `packageManager`).
3. Les PR obtiennent une préproduction, `main` la production.

Variables d'environnement : définissez-les dans Vercel, jamais dans le dépôt. Seul `.env.example` est versionné, avec des valeurs factices.

L'image Docker reste disponible si vous préférez auto-héberger (voir [docker.md](docker.md)).

## 7. Premier tag

Une fois `main` verte (jamais avant), cutez la première version :

```bash
git switch main && git pull
git tag v0.1.0
git push origin v0.1.0
```

Le workflow `release.yml` construit l'image, la scanne avec Trivy, la publie sur GHCR (`ghcr.io/<vous>/<votre-projet>`) et crée la release GitHub. Un tag avec un tiret (`v1.0.0-rc.1`) crée une pré-version.

Les tags ne se posent que depuis une `main` verte : le workflow ne revérifie pas la CI, c'est une règle d'équipe.

## Pour la suite

- [conventions-git.md](conventions-git.md) : commits, branches, revue.
- [ci-cd.md](ci-cd.md) : ce que fait chaque job.
- [securite.md](securite.md) : outils et triage.
