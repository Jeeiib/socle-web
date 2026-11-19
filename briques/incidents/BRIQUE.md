---
nom: incidents
prerequis:
remplace:
checks-requis:
---

# incidents

Un runbook de gestion des incidents : une section par alerte, une méthode de diagnostic et un modèle de post-mortem sans blâme.

## Quand la prendre

- Le projet est en production avec de vrais utilisateurs.
- On veut que la personne d'astreinte sache quoi regarder en premier, sans réinventer la méthode à 3 h du matin.

## Quand ne pas la prendre

- Projet sans production ni supervision : le document décrirait des alertes qui n'existent pas.

## Prérequis

Aucune brique bloquante. Les noms d'alertes (`ServiceInjoignable`, `TauxErreurs5xxEleve`, `LatenceP95Elevee`, `CertificatExpireBientot`) sont ceux de la brique `monitoring` : sans elle, adapter les sections aux alertes réellement en place.

## Fichiers apportés

- `docs/INCIDENTS.md` : supervision en place, runbook par alerte (chaque titre est une ancre stable, par exemple `docs/INCIDENTS.md#serviceinjoignable`, utilisable comme lien `runbook` dans les alertes), méthode de diagnostic (USE et RED, du symptôme à la cause) et modèle de post-mortem sans blâme.

## Activation

1. Remplacer les adresses d'exemple (`exemple.fr`, ports) du tableau « Supervision en place » par celles du projet.
2. Pour chaque alerte du projet, vérifier que la section correspond à la règle réelle (seuil, durée).
3. Lier le runbook depuis les alertes : annotation `runbook: https://github.com/<propriétaire>/<dépôt>/blob/main/docs/INCIDENTS.md#serviceinjoignable`.
4. Ajouter chaque post-mortem au-dessus du marqueur en fin de fichier, du plus récent au plus ancien.

## Vérification

- Chaque alerte définie dans la supervision a sa section, et inversement.
- Les liens `#ancre` s'ouvrent sur la bonne section dans GitHub.
- Faire un exercice : couper le service en staging, suivre le runbook, vérifier que la section aurait suffi.

## Pièges connus

- Les ancres GitHub sont le titre en minuscules, sans espace ni ponctuation : renommer un titre casse les liens qui y pointent.
- Un runbook jamais relu pourrit : le revoir après chaque incident et après chaque changement de seuil.
- Un post-mortem décrit des processus et des systèmes, jamais une personne ; sans au moins une action suivie (issue), il ne sert à rien.
