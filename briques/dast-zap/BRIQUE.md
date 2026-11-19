---
nom: dast-zap
prerequis:
remplace:
checks-requis:
---

# dast-zap

Un scan dynamique (DAST) ZAP baseline de l'environnement de staging, lancé à la main ou après chaque déploiement réussi. Il observe l'application en marche, de l'extérieur, comme le ferait un attaquant passif.

## Quand la prendre

- Un environnement de staging est en ligne, avec une adresse HTTPS stable.
- On veut qu'une régression d'en-têtes de sécurité (CSP, anti-clickjacking, etc.) soit détectée sur l'application réellement servie.

## Quand ne pas la prendre

- Pas d'environnement de test accessible depuis internet : le scan part d'un runner GitHub.
- Ne jamais pointer ce scan vers la production ni vers un service qui n'est pas à soi.

## Prérequis

Aucune brique bloquante. Pour le déclenchement automatique, le workflow de déploiement du staging doit s'appeler `Déploiement` (nom donné par la brique `deploiement-serveur`).

## Fichiers apportés

- `.github/workflows/dast.yml` : job `zap-baseline`, sans droit d'écriture (`contents: read`). Déclenché par `workflow_dispatch` (entrée `url`) ou par `workflow_run` quand le workflow `Déploiement` se termine avec succès. L'URL passe par `env:` puis est validée (https obligatoire) avant d'être donnée à l'action `zaproxy/action-baseline`, épinglée par SHA.
- `.zap/rules.tsv` : décision pour chaque règle ZAP (`FAIL`, `WARN`, `INFO` ou `IGNORE`, séparateur tabulation). Les règles d'en-têtes sont en `FAIL`, les trois `IGNORE` sont des faux positifs ou informatifs, justifiés dans le fichier.

## Activation

1. Créer la variable de dépôt `DAST_URL` avec l'adresse du staging, par exemple `https://staging.exemple.fr` : `gh variable set DAST_URL --body https://staging.exemple.fr`. Elle sert au déclenchement automatique.
2. Lancer un premier scan à la main : `gh workflow run dast.yml -f url=https://staging.exemple.fr`.
3. Corriger ou classer chaque alerte du premier rapport dans `.zap/rules.tsv` ; chaque `IGNORE` est aussi inscrit dans le registre des exceptions de `docs/securite.md`.

Aucun check requis : le scan tourne après le déploiement, il ne peut pas bloquer une PR.

## Vérification

- Le run apparaît dans l'onglet Actions et téléverse le rapport `zap_scan` (artefact).
- Retirer un en-tête de sécurité sur le staging : le scan suivant échoue sur la règle `FAIL` correspondante.
- `awk -F'\t' '!/^#/ && NF < 3' .zap/rules.tsv` ne doit rien afficher (chaque ligne a bien trois colonnes séparées par tabulation).

## Pièges connus

- `.zap/rules.tsv` exige de vraies tabulations ; un éditeur qui les remplace par des espaces rend la règle muette.
- `workflow_run` ne s'exécute que depuis la branche par défaut : le workflow doit y être fusionné avant de tester le déclenchement automatique.
- Si le workflow de déploiement porte un autre nom que `Déploiement`, adapter `workflows:` dans `dast.yml`.
- `allow_issue_writing: false` : l'action ne crée pas d'issue (pas de droit `issues: write`) ; le rapport est lu dans l'artefact.
- Un baseline est passif : il n'attaque pas, il ne remplace ni un test d'intrusion ni la revue de code.
- Le staging peut être endormi ou protégé par une authentification : le scan ne verrait alors qu'une page d'erreur et passerait au vert à tort.
