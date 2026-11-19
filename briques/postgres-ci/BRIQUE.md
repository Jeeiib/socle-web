---
nom: postgres-ci
prerequis:
remplace:
checks-requis: integration
---

# postgres-ci

Un job `integration` qui lance les tests d'intégration contre une vraie base PostgreSQL 16, démarrée comme service du job.

## Quand la prendre

- Le projet utilise PostgreSQL et certains comportements ne se testent qu'avec une vraie base (requêtes, migrations, contraintes, transactions).
- Les tests unitaires avec une base simulée ont déjà laissé passer un bug.

## Quand ne pas la prendre

- Pas de base de données, ou une base autre que PostgreSQL.
- Les tests unitaires suffisent : un job de plus allonge chaque PR.

## Prérequis

Aucune autre brique. Le projet doit avoir un script `pnpm test:integration` et lire `DATABASE_URL` pour se connecter.

## Fichiers apportés

- `.github/workflows/integration.yml` : job `integration` sur `pull_request` et sur `push` vers `main`. Service `postgres:16-alpine` épinglé par digest, contrôlé par `pg_isready`, joignable sur `localhost:5432`. Les identifiants (`app` / `ci-only`) sont jetables : la base n'existe que le temps du job.

## Activation

1. Ajouter le script au `package.json` : `"test:integration": "vitest run --config vitest.integration.config.ts"` (adapter la commande à l'outil de test du projet). Les tests d'intégration lisent `process.env.DATABASE_URL`.
2. Ajouter `integration` aux checks requis du ruleset : l'inscrire dans `.github/rulesets/main.json` (liste `required_status_checks`), puis `scripts/appliquer-ruleset.sh`.
3. Si les migrations doivent passer avant les tests, ajouter une étape `pnpm db:migrate` (ou l'équivalent) avant `pnpm test:integration`.

## Vérification

- Ouvrir une PR : le job `integration` apparaît et passe au vert.
- Casser volontairement une requête dans un test d'intégration : le job doit passer au rouge.
- En local : `docker run --rm -e POSTGRES_PASSWORD=ci-only -p 5432:5432 postgres:16-alpine`, puis `DATABASE_URL=postgres://postgres:ci-only@localhost:5432/postgres pnpm test:integration`.

## Pièges connus

- Un check requis dont le script est absent échoue : ajouter `test:integration` avant d'inscrire `integration` au ruleset.
- Ne pas ajouter `paths-ignore` à ce workflow : une PR de documentation resterait bloquée en attente du check.
- Le service démarre en quelques secondes ; sans le healthcheck, le premier test peut tomber sur une base pas encore prête.
- Le digest de l'image Postgres est mis à jour par Dependabot (écosystème `docker`) si le projet le configure ; sinon le revoir à la main de temps en temps.
