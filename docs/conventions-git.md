# Conventions Git

Des conventions strictes rendent l'historique lisible, les versions automatisables et les revues rapides.

## Conventional Commits

Format : `type(portée optionnelle)!: description`. La description est en français, le type en anglais.

| Type       | Usage                                      |
| ---------- | ------------------------------------------ |
| `feat`     | Nouvelle fonctionnalité                    |
| `fix`      | Correction de bug                          |
| `docs`     | Documentation seule                        |
| `style`    | Formatage, sans effet sur le code          |
| `refactor` | Réécriture sans changement de comportement |
| `perf`     | Amélioration de performance                |
| `test`     | Ajout ou correction de tests               |
| `build`    | Dépendances, outillage de build, Docker    |
| `ci`       | Workflows GitHub Actions                   |
| `chore`    | Tâches diverses                            |
| `revert`   | Annulation d'un commit                     |

Un `!` après le type (ou la portée) signale un changement incompatible : `feat(api)!: renomme la route de santé`.

Le hook `.githooks/commit-msg` refuse tout autre format, et `scripts/test-commit-msg.sh` vérifie le hook lui-même :

```bash
scripts/test-commit-msg.sh
```

## Branches : GitHub Flow

`main` est toujours livrable et protégée. Tout passe par une branche courte, nommée `<type>/<sujet>` :

```text
feat/page-contact
fix/healthcheck-docker
docs/guide-docker
```

Le cycle : brancher depuis `main`, committer, pousser, ouvrir une PR, passer la revue et les checks, fusionner, supprimer la branche. On ne pousse jamais sur `main`.

## Squash

Les PR sont fusionnées en **squash** (c'est la seule méthode autorisée par le ruleset). Conséquence : le titre de la PR devient le message du commit sur `main`, il doit donc suivre les Conventional Commits. Les commits intermédiaires de la branche peuvent être imparfaits, mais le hook les valide quand même.

## Revue : conventional comments

Préfixez chaque remarque pour que l'auteur sache quoi en faire :

| Préfixe       | Sens                                            |
| ------------- | ----------------------------------------------- |
| `nitpick:`    | Détail de style, facultatif                     |
| `suggestion:` | Proposition, à discuter                         |
| `question:`   | Besoin de comprendre, pas de changement demandé |
| `issue:`      | Problème à corriger avant de fusionner          |
| `praise:`     | Ce qui est bien fait                            |

Le ruleset exige que tous les fils de revue soient résolus avant la fusion.

## Réécrire sa branche sans écraser le travail des autres

Après un rebase ou un amend sur votre branche, n'utilisez jamais `git push --force`. Utilisez :

```bash
git push --force-with-lease
```

L'option refuse de pousser si quelqu'un d'autre a poussé entre-temps. Sur `main`, aucune réécriture n'est possible (`non_fast_forward` dans le ruleset).

## Un secret a fuité : l'ordre compte

1. **Révoquer d'abord.** Désactivez la clé, le jeton ou le mot de passe chez le fournisseur, puis générez-en un nouveau. Tant que ce n'est pas fait, le secret est exploitable, et il peut déjà avoir été copié par des robots.
2. **Ensuite seulement, purger l'historique** (`git filter-repo`, puis push forcé coordonné avec l'équipe), pour ne pas laisser traîner un secret mort.
3. Vérifier avec `gitleaks git` que l'historique est propre, et chercher dans les journaux d'accès du fournisseur toute utilisation suspecte.

Purger sans révoquer ne sert à rien : le secret est déjà compromis. Voir aussi [securite.md](securite.md).
