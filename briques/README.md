# Briques

Une brique est un ensemble de fichiers optionnels que l'on ajoute à un projet issu du socle, avec une fiche `BRIQUE.md` qui dit quand la prendre et comment l'activer.

`briques/` sert de catalogue : ce dossier est supprimé des projets dérivés (le script d'ajout le relit depuis le socle).

## Ajouter une brique

```bash
scripts/ajouter-brique.sh <nom> [dossier-projet]   # dossier par défaut : .
```

Source des briques : `$SOCLE_DIR/briques` si `SOCLE_DIR` est défini, sinon le dossier `briques/` à côté du script, sinon l'archive du dépôt `Jeeiib/socle-web` téléchargée dans un dossier temporaire.

Tous les contrôles passent avant la première copie. Le script copie tout sauf `BRIQUE.md`, inscrit la brique dans `.socle/briques` (une ligne par brique) et affiche la rubrique `## Activation`.

| Code | Sens                                                      |
| ---- | --------------------------------------------------------- |
| 0    | succès, ou brique déjà présente                           |
| 1    | usage incorrect ou brique inconnue                        |
| 2    | fichiers en conflit (déjà présents avec un autre contenu) |
| 3    | prérequis manquant                                        |
| 4    | fichier de `remplace:` modifié localement                 |

## Format de `BRIQUE.md`

En-tête lu par le script, une valeur par ligne, listes séparées par des espaces, valeur vide autorisée :

```
---
nom: <nom>
prerequis: <briques bloquantes>
remplace: <chemin>@<sha256> ...
checks-requis: <jobs à ajouter au ruleset, ou vide>
---
```

Puis les rubriques : `## Quand la prendre`, `## Quand ne pas la prendre`, `## Prérequis`, `## Fichiers apportés`, `## Activation`, `## Vérification`, `## Pièges connus`.

## Vérifier les briques

```bash
scripts/verifier-briques.sh [brique...]   # toutes par défaut
```

Contrôles génériques : `shellcheck`, `actionlint` sur les workflows des briques, `docker compose config -q` sur chaque `compose*.yaml`. Les outils tournent dans des conteneurs aux images épinglées par digest. Une brique ajoute ses propres contrôles en définissant une fonction `verifier_<nom>` dans le script (tirets remplacés par des underscores).

La CI exécute aussi `scripts/test-ajouter-brique.sh`, qui teste le script d'ajout sur un faux socle.

## Pièges communs

- `paths-ignore` : si un workflow ignore les fichiers `*.md` ou `docs/**` et que son job est un check requis, une PR de documentation reste bloquée en attente d'un check qui ne démarre jamais. Ne pas ajouter `paths-ignore` à un workflow dont un job est requis.
- Docker avec Colima sur Mac : si le socket est introuvable, exporter `DOCKER_HOST=unix://$HOME/.colima/default/docker.sock`. Colima ne monte que `/Users/<moi>` et `/Volumes/SSD-JB` : les dossiers temporaires montés dans un conteneur vivent sous `.verif-tmp/`.
