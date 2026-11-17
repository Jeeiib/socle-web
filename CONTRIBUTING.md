# Contribuer

Merci de votre intérêt. Les règles tiennent en quelques lignes, le détail est dans les guides.

1. **Une branche par sujet**, nommée `<type>/<sujet>` (ex. `feat/page-contact`). On ne pousse jamais sur `main`.
2. **Commits en Conventional Commits** : `type(portée): description en français`. Un hook local refuse les autres. Voir [docs/conventions-git.md](docs/conventions-git.md).
3. **Avant de pousser** :

   ```bash
   pnpm lint && pnpm typecheck && pnpm format:check && pnpm test:coverage && pnpm build
   ```

4. **Ouvrir une PR** avec le modèle fourni. Elle est fusionnée en squash, donc son titre suit aussi les Conventional Commits.
5. **Les checks doivent être verts** : `qualite`, `tests`, `build`, `docker`, `actionlint`. Voir [docs/ci-cd.md](docs/ci-cd.md).
6. **Aucun secret dans le dépôt** : seul `.env.example` est versionné. Une faille se signale en privé, voir [SECURITY.md](SECURITY.md).
