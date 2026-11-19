---
nom: deploiement-serveur
prerequis:
remplace:
checks-requis:
---

# deploiement-serveur

Le déploiement de l'image du socle sur un serveur Linux par SSH : Nginx en frontal TLS, smoke test sur la version, retour automatique à la version précédente si le smoke test échoue. L'image est celle que `release.yml` a construite, scannée et publiée sur GHCR : le serveur ne construit rien.

## Quand la prendre

- On a un serveur (VPS, machine du bureau) avec Docker et un accès SSH.
- On veut qu'un tag `vX.Y.Z` mette l'application en ligne sans geste manuel, avec une approbation possible sur l'environnement `production`.
- On veut un retour arrière en une commande ou un clic.

## Quand ne pas la prendre

- L'hébergement est une plateforme qui déploie seule (Vercel, Fly, Railway) : elle remplace cette brique.
- Plusieurs serveurs ou un orchestrateur (Kubernetes, Swarm) : ce déploiement vise une seule machine.
- Pas de serveur à soi : la brique ne se teste qu'avec un vrai hôte SSH.

## Prérequis

Aucune brique bloquante. Le workflow `Release` du socle (tags `vX.Y.Z`, image sur GHCR) doit être en place. Côté serveur : Docker avec le plugin Compose, et un accès SSH.

## Fichiers apportés

- `compose.prod.yaml` : service `app` (image `${IMAGE}:${IMAGE_TAG}`, système de fichiers en lecture seule avec tmpfs pour `/tmp` et `/app/.next/cache`, healthcheck identique à celui du `Dockerfile`) et service `proxy` (Nginx épinglé par digest, seul à publier les ports 80 et 443). Projet et réseau nommés `app-prod`.
- `.env.prod.example` : modèle du `.env` du serveur (`COMPOSE_FILE`, `IMAGE`, `IMAGE_TAG`).
- `deploy/deploy.sh` : valide le tag, lance les scripts de `deploy/avant-deploiement.d/` (ordre alphabétique, un échec arrête tout), tire l'image, démarre, recharge Nginx, lance le smoke test. Smoke test rouge : retour à la version précédente, puis code 1. Écrit `.previous_tag` et `.deployed_tag`.
- `deploy/smoke-test.sh` : attend jusqu'à 60 s que `/api/health` réponde 200 avec la bonne version. Variable `BASE_URL` (défaut `https://localhost`).
- `deploy/valider-tag.sh` et `deploy/test-valider-tag.sh` : le tag doit valoir `vX.Y.Z` ou `vX.Y.Z-rc.1`, rien d'autre n'atteint un shell.
- `deploy/gen-cert.sh` : certificat auto-signé (`certs/app.crt`, `certs/app.key`).
- `deploy/nginx/app.conf` : redirection 80 vers 443, TLS 1.2 minimum, HSTS, `/api/metrics` refusé au public (404), proxy vers `app:3000`.
- `deploy/avant-deploiement.d/` : point d'extension, vide au départ (la brique sauvegardes y dépose son script).
- `.github/workflows/deploy.yml` : workflow `Déploiement`, job `deployer`, environnement `production`.

## Activation

1. Préparer le serveur :
   - créer l'utilisateur `deploy` dans le groupe `docker` (`sudo adduser deploy && sudo usermod -aG docker deploy`) ; ce groupe donne un accès équivalent à root, d'où un utilisateur dédié ;
   - générer une clé dédiée à ce seul usage : `ssh-keygen -t ed25519 -f cle-deploiement -C deploiement` ; mettre `cle-deploiement.pub` dans `~deploy/.ssh/authorized_keys` ;
   - créer le dossier de prod : `mkdir -p /srv/app && chown deploy: /srv/app` ;
   - y copier `.env.prod.example` en `.env`, renseigner `IMAGE` (nom en minuscules, ex. `ghcr.io/mon-organisation/mon-projet`), puis `chmod 600 .env` ;
   - créer le certificat : `DOMAIN=exemple.fr ./deploy/gen-cert.sh` (auto-signé, le navigateur avertit), ou poser le certificat Let's Encrypt dans `certs/app.crt` et `certs/app.key`. Le premier envoi de `deploy/` se fait par le workflow ; pour le certificat avant, copier `deploy/gen-cert.sh` à la main.
2. Relever l'empreinte du serveur : `ssh-keyscan -t ed25519 203.0.113.10` ; vérifier qu'elle correspond à celle affichée sur le serveur (`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`).
3. Créer l'environnement et ses valeurs :
   ```bash
   gh api -X PUT repos/{owner}/{repo}/environments/production
   gh variable set DEPLOY_HOST --env production --body 203.0.113.10
   gh variable set DEPLOY_USER --env production --body deploy
   gh variable set DEPLOY_DIR --env production --body /srv/app
   gh secret set DEPLOY_SSH_KEY --env production < cle-deploiement
   gh secret set DEPLOY_KNOWN_HOSTS --env production < known_hosts.txt
   ```
   Ajouter des relecteurs obligatoires à l'environnement (Settings, Environments) pour une livraison avec approbation.
4. Publier une version : `git tag v1.0.0 && git push origin v1.0.0`. Le workflow `Release` puis `Déploiement` se suivent. Retour arrière : `gh workflow run deploy.yml -f tag=v0.9.0`.

Aucun check requis : le déploiement part après la release, il ne se joue pas sur une PR.

## Variante : runner self-hosted

Si le serveur ne peut pas recevoir de SSH depuis internet, y installer un runner GitHub self-hosted (étiquette `deploy`) et mettre `runs-on: [self-hosted, deploy]` dans `deploy.yml`. Les étapes SSH deviennent des commandes locales (`docker login`, `./deploy/deploy.sh "$TAG"` dans `DEPLOY_DIR`) et les secrets SSH disparaissent. Contrepartie : le runner exécute le code du dépôt sur le serveur ; ne jamais l'attacher à un dépôt public qui accepte des PR de forks.

## Stratégies de déploiement

La brique fait un `recreate` : l'ancien conteneur est remplacé par le nouveau, avec une coupure de quelques secondes. Suffisant pour la plupart des projets de ce socle.

| Stratégie     | Principe                                         | Quand elle vaut le coût                                           |
| ------------- | ------------------------------------------------ | ----------------------------------------------------------------- |
| recreate      | arrêt de l'ancienne, démarrage de la nouvelle    | coupure tolérée, une seule instance (cas par défaut)              |
| rolling       | remplacement instance par instance               | plusieurs instances derrière un répartiteur                       |
| blue/green    | deux environnements, bascule du trafic d'un coup | retour arrière instantané exigé, budget pour doubler l'infra      |
| canary        | un faible pourcentage du trafic sur la nouvelle  | gros trafic, besoin de mesurer avant de généraliser               |
| feature flags | code livré éteint, activé par configuration      | séparer livraison et mise en service, tester sur un public réduit |

## Migrations de base : expand/contract

Un retour arrière rend l'ancien code, pas l'ancien schéma. Pour que les deux versions cohabitent :

1. Expand : ajouter la colonne ou la table, sans rien retirer. L'ancien et le nouveau code fonctionnent.
2. Migrer le code et les données vers le nouveau schéma, en deux déploiements si besoin.
3. Contract : retirer l'ancienne colonne dans une version ultérieure, quand plus aucun retour arrière ne la réclame.

Une migration destructrice dans le même déploiement que le code qui l'utilise interdit le rollback. Les sauvegardes avant déploiement se branchent dans `deploy/avant-deploiement.d/`.

## Vérification

- `bash scripts/verifier-briques.sh deploiement-serveur` : tests du validateur, puis déploiement complet en local (image du socle, Nginx TLS sur le port 18443, rollback sur version erronée, tag invalide refusé).
- Sur le serveur : `cat .deployed_tag .previous_tag`, `docker compose ps`, `curl -k https://localhost/api/health`.
- Depuis l'extérieur : `curl -I http://exemple.fr` répond 301 vers HTTPS, et l'en-tête `Strict-Transport-Security` est présent sur HTTPS.

## Pièges connus

- `deploy.yml` s'appelle `Déploiement` : la brique `dast-zap` le déclenche par ce nom.
- `workflow_run` ne s'exécute que depuis la branche par défaut, et `head_branch` contient le nom du tag pour un push de tag. Le workflow doit être fusionné sur `main` avant le premier test.
- Le smoke test compare la version sans le `v` initial : les images sont taguées `1.2.3`, pas `v1.2.3`. `APP_VERSION` est passé au build par `release.yml` ; sans lui `/api/health` répondrait `dev`.
- Le healthcheck de `compose.prod.yaml` est copié du `Dockerfile` : en modifier un sans l'autre fausse `--wait`.
- Jamais `StrictHostKeyChecking=no` : sans `DEPLOY_KNOWN_HOSTS` exact, la connexion échoue, et c'est voulu.
- Nginx résout `app` au démarrage : `deploy.sh` recharge le proxy après chaque déploiement, sinon il garde l'ancienne adresse.
- `docker compose pull --policy missing` : une version déjà présente sur le serveur n'est pas re-téléchargée. Les tags de version sont immuables ; ne jamais republier un tag.
- Le rollback automatique ne restaure pas les données : une migration destructrice reste à votre charge (voir expand/contract).
- Colima sur Mac : si le socket est introuvable, `export DOCKER_HOST=unix://$HOME/.colima/default/docker.sock`. Le dossier de test est créé sous `.verif-tmp/`, seul chemin monté.
- `read_only: true` : le démarrage de Next avec ce mode a été vérifié, il n'écrit que dans `/tmp` et `.next/cache` (tmpfs). Une dépendance qui écrit ailleurs échouera avec une erreur de système de fichiers en lecture seule.
- Le `.env` est transmis tel quel à l'application : n'y mettre que ce dont elle a besoin.
