---
nom: staging-prod
prerequis: deploiement-serveur
remplace: .github/workflows/deploy.yml@500c65c46fec479db5480a860d585770d03081e162ffdd6f462ea12a2fe2d7d9
checks-requis:
---

# staging-prod

Le déploiement en deux temps : chaque version passe d'abord par un environnement `staging` où le smoke test la vérifie, puis part en `production` après approbation. Une release cassée est arrêtée avant les utilisateurs.

## Quand la prendre

- Une régression en production coûte cher (clients, données) et une approbation humaine avant la mise en ligne est voulue.
- On veut voir la version tourner dans les conditions du serveur (Nginx, TLS, variables) avant de la livrer.

## Quand ne pas la prendre

- Projet personnel ou outil interne : un seul environnement et un retour arrière rapide suffisent.
- Le serveur n'a pas de quoi faire tourner deux environnements côte à côte.
- La brique `iac-opentofu` est présente : les deux gèrent le même staging, il faut en choisir un.

## Prérequis

Brique `deploiement-serveur`. Son `deploy.yml` est remplacé : le script d'ajout refuse (code 4) si vous l'avez modifié, il faut alors reporter vos changements à la main.

## Fichiers apportés

- `.github/workflows/deploy.yml` : remplace celui de `deploiement-serveur`, toujours nommé `Déploiement` (la brique `dast-zap` le lit). Jobs `cadrer` (fixe tag et commit), `staging` (environnement `staging`, dossier `STAGING_DIR`, smoke test via `deploy.sh`), puis `production` (`needs: staging`, environnement `production`). Garde la sécurité du workflow d'origine : tag validé avant tout accès SSH, `known_hosts` exact, jeton transmis sur l'entrée standard seulement, déconnexion de ghcr.io dans `if: always()`, concurrence sans annulation. Il copie `compose*.yaml` (donc aussi `compose.postgres.yaml` de la brique `sauvegardes`).
- `compose.staging.yaml` : mêmes service, image et healthcheck que `compose.prod.yaml`. Projet et réseau `app-staging`, ports 8080 et 8443 par défaut.
- `.env.staging.example` : modèle du `.env` du staging (`COMPOSE_FILE=compose.staging.yaml`).

## Activation

1. Sur le serveur, créer le dossier de staging à côté de la prod, avec son propre `.env` (copie de `.env.staging.example`, `chmod 600`) et son certificat :
   ```bash
   mkdir -p /srv/app-staging && chown deploy: /srv/app-staging
   DOMAIN=staging.exemple.fr CERT_DIR=/srv/app-staging/certs ./deploy/gen-cert.sh
   ```
   Sans `COMPOSE_FILE` dans ce `.env`, `deploy.sh` viserait `compose.prod.yaml`.
2. Créer l'environnement `staging` et ses valeurs (la clé et l'empreinte peuvent être celles de la production) :
   ```bash
   gh api -X PUT repos/{owner}/{repo}/environments/staging
   gh variable set STAGING_HOST --env staging --body 203.0.113.10
   gh variable set DEPLOY_USER --env staging --body deploy
   gh variable set STAGING_DIR --env staging --body /srv/app-staging
   gh variable set STAGING_BASE_URL --env staging --body https://localhost:8443
   gh secret set DEPLOY_SSH_KEY --env staging < cle-deploiement
   gh secret set DEPLOY_KNOWN_HOSTS --env staging < known_hosts.txt
   ```
   `STAGING_HOST` peut valoir l'adresse du même serveur que la production ; `STAGING_BASE_URL` est l'adresse que le smoke test appelle depuis le serveur (port `HTTPS_PORT` du staging).
3. Protéger la production : approbation obligatoire et limitation à `main` et aux tags `v*`. Remplacer `ID_RELECTEUR` par l'identifiant numérique du relecteur (`gh api users/<login> --jq .id`) :
   ```bash
   gh api -X PUT repos/{owner}/{repo}/environments/production --input - <<'JSON'
   {"reviewers":[{"type":"User","id":ID_RELECTEUR}],"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}
   JSON
   gh api -X POST repos/{owner}/{repo}/environments/production/deployment-branch-policies -f name=main -f type=branch
   gh api -X POST repos/{owner}/{repo}/environments/production/deployment-branch-policies -f name='v*' -f type=tag
   ```
   Les relecteurs obligatoires ne sont disponibles sur un dépôt privé que sur les offres payantes ; sur un dépôt public ils sont gratuits.
4. Publier une version : `git tag v1.0.0 && git push origin v1.0.0`. Le staging part seul, la production attend l'approbation.

Rollback manuel : `gh workflow run deploy.yml -f tag=v0.9.0 -f environnement=production` (sans repasser par le staging), ou `-f environnement=staging` pour rejouer le staging seul. Le retour automatique sur smoke test rouge reste celui de `deploy.sh`.

Aucun check requis.

## Vérification

- `bash scripts/verifier-briques.sh staging-prod` : `actionlint` sur le workflow, `docker compose config` sur `compose.staging.yaml`.
- Après une release : le job `staging` vert, puis `production` en attente d'approbation dans l'onglet Actions.
- Sur le serveur : `docker compose ps` dans chaque dossier ; `docker network ls` montre `app-prod` et `app-staging`.

## Pièges connus

- Pour un push de tag, `workflow_run` s'exécute sur la branche par défaut : la restriction « branches et tags » de l'environnement voit `main`, pas le tag. Gardez `main` dans la liste.
- Le Nginx redirige `http` vers `https` sans conserver le port : sur 8080, la redirection mène vers 443 (la production). Sur le même hôte, ouvrir directement `https://<hôte>:8443` ; un sous-domaine seul n'y change rien, il pointe vers la même machine et la même redirection.
- Variables et secrets sont propres à chaque environnement : `DEPLOY_USER`, la clé et `known_hosts` doivent être posés sur `staging` ET `production`.
- Une production lancée à la main saute le staging : à réserver au retour arrière.
- Le staging et la production partagent un serveur : un staging gourmand ralentit la production. Surveiller la mémoire.
- Si le staging échoue, la production ne démarre pas (job ignoré) ; relancer le workflow après correction.
- `staging-prod` et `iac-opentofu` sont des alternatives : les deux gèrent le même staging, en choisir une seule.
