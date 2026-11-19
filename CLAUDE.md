@AGENTS.md

# Conventions du dépôt (agents de code)

Ce dépôt est un socle DevOps : ces règles sont contraignantes. Détails dans `docs/`.

## Git

- Commits en Conventional Commits : `type(portée): description en français`. Types : feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert. Un hook (`.githooks/commit-msg`) refuse le reste.
- Branches nommées `<type>/<sujet>` (ex. `feat/page-contact`).
- Ne jamais pousser sur `main` : branche, PR, fusion en squash (le titre de la PR suit les Conventional Commits).

## Avant de pousser

```bash
pnpm lint && pnpm typecheck && pnpm format:check && pnpm test:coverage && pnpm build
```

## CI

- Ne jamais renommer les jobs `qualite`, `tests`, `build`, `docker`, `actionlint` : ce sont des checks requis du ruleset.
- Toute nouvelle action : épinglée par SHA complet de 40 caractères + commentaire `# vX.Y.Z`, `permissions` minimales, `timeout-minutes`.
- Aucun `${{ }}` d'entrée utilisateur dans un `run:` : passer par `env:`.
- Pas de filtre `paths` sur `pull_request` (le check requis ne serait jamais fourni).

## Briques

`briques/` est le catalogue de briques optionnelles (fiche `BRIQUE.md` par brique, voir `briques/README.md`). Après toute modification : `bash scripts/test-ajouter-brique.sh && bash scripts/verifier-briques.sh` (le job `briques`, requis, les rejoue en CI).

## Docker et secrets

- L'image reste non-root (`USER node`), base en tag précis, jamais `latest`.
- Aucun secret dans le dépôt : seul `.env.example` est versionné.

## Documentation

`docs/ci-cd.md`, `docs/docker.md`, `docs/securite.md`, `docs/conventions-git.md`, `docs/demarrer-un-projet.md`.
Style : français avec accents, pas d'emoji, pas de tiret long.
