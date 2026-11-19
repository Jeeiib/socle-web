---
nom: iac-opentofu
prerequis: deploiement-serveur
remplace:
checks-requis:
---

# iac-opentofu

L'environnement de staging décrit en code avec OpenTofu : réseau, volume Postgres, base et application, créés et mis à jour par `tofu apply` plutôt que par des commandes tapées à la main. Le workflow `IaC` valide le code, commente le plan sur chaque PR et signale chaque semaine si le serveur a dérivé du code.

## Quand la prendre

- On veut pouvoir recréer le staging à l'identique, ou en voir le détail dans une PR avant de le changer.
- On veut être alerté quand quelqu'un modifie le serveur à la main.

## Quand ne pas la prendre

- Un seul serveur sans staging : `compose.prod.yaml` et `deploy.sh` suffisent, le code d'infrastructure ajouterait un outil de plus à maintenir.
- On utilise déjà `compose.staging.yaml` et personne ne souhaite le remplacer : les deux décrivent le même environnement, il faut en choisir un.

## Prérequis

Brique `deploiement-serveur` (clé SSH, empreinte du serveur, utilisateur `deploy`). Côté poste : OpenTofu `1.13.9` (`brew install opentofu`) pour lancer l'apply. L'image de l'application doit exister sur GHCR (`release.yml`).

Si la brique `staging-prod` est présente, l'IaC prend la place de son `compose.staging.yaml` : les noms sont les mêmes (projet et réseau `app-staging`, volume `app-staging_db-data`). Supprimer ce fichier et son usage dans `deploy.yml` à la main, aucun fichier n'est remplacé automatiquement.

## Fichiers apportés

- `infra/versions.tf` : OpenTofu `>= 1.6`, fournisseurs `kreuzwerker/docker` et `hashicorp/random`, `backend "local" {}` (chemin donné à l'init).
- `infra/providers.tf` : fournisseur Docker sur `var.docker_host` (`unix:///var/run/docker.sock` par défaut, `ssh://deploy@203.0.113.10` pour un serveur distant), connexion SSH en `BatchMode`, authentification ghcr.io facultative.
- `infra/variables.tf` : variables validées (`image` en minuscules sans tag, `image_tag` = `1.2.3`, `1.2.3-rc.1` ou `latest`, `app_port` entre 1024 et 65535).
- `infra/main.tf` : réseau `app-staging`, volume `app-staging_db-data` (`ignore_changes = [labels]`), Postgres épinglé par digest, mot de passe `random_password` (32 caractères, sans caractères spéciaux), conteneurs `app-staging-db-1` et `app-staging-app-1`. L'application est en lecture seule, cache Next en tmpfs, healthcheck identique à celui du `Dockerfile`, publiée sur `127.0.0.1:<app_port>` (un proxy ou un tunnel SSH la joint ; ce module ne gère pas Nginx).
- `infra/outputs.tf`, `infra/terraform.tfvars.example`, `infra/.gitignore` (state, plans, `terraform.tfvars`).
- `infra/.terraform.lock.hcl` : versions et empreintes des fournisseurs pour linux, macOS et Windows ; mise à jour avec `tofu providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_arm64 -platform=darwin_amd64 -platform=windows_amd64`.
- `.github/workflows/iac.yml` : `iac-validate` (format, init sans backend, validate) et `iac-plan` (plan sur le serveur par SSH, commentaire de PR marqué `<!-- iac-plan -->`, dérive chaque lundi).

## Activation

1. Côté serveur, créer le dossier du state, lisible par `deploy` seul : `mkdir -m 700 /srv/iac-staging`.
2. Créer l'environnement `staging` (clé et empreinte : celles de `deploiement-serveur`) :
   ```bash
   gh api -X PUT repos/{owner}/{repo}/environments/staging
   gh variable set DEPLOY_HOST --env staging --body 203.0.113.10
   gh variable set DEPLOY_USER --env staging --body deploy
   gh variable set IAC_STATE_DIR --env staging --body /srv/iac-staging
   gh secret set DEPLOY_SSH_KEY --env staging < cle-deploiement
   gh secret set DEPLOY_KNOWN_HOSTS --env staging < known_hosts.txt
   ```
3. Reprendre un staging existant (sinon passer à l'étape 4) :
   ```bash
   # sur le serveur : arrêter l'ancien staging SANS -v, le volume garde les données
   cd /srv/app-staging && docker compose down
   # sur le poste
   cd infra && cp terraform.tfvars.example terraform.tfvars   # renseigner docker_host, image, image_tag
   tofu init -lockfile=readonly -backend-config="path=terraform.tfstate"
   tofu import docker_volume.pgdata app-staging_db-data
   ```
   Le mot de passe Postgres du volume existant doit être celui de `db_password` (`TF_VAR_db_password`), sinon l'application ne se connecte plus : Postgres ne le relit pas à chaque démarrage.
4. Créer ou mettre à jour l'environnement : `tofu apply`, puis envoyer le state au serveur :
   ```bash
   chmod 600 terraform.tfstate
   scp -p terraform.tfstate deploy@203.0.113.10:/srv/iac-staging/terraform.tfstate
   ```
5. Pour chaque apply suivant : récupérer le state (`scp` dans l'autre sens), `tofu apply`, le renvoyer. Le workflow ne fait jamais d'apply.

Aucun check requis : `iac-plan` a besoin des secrets du dépôt, il ne tourne pas pour les forks et ne doit pas bloquer une PR.

## Où vit le state

Le state contient le mot de passe de la base : il reste hors de Git, en `600`, sur le serveur (`/srv/iac-staging/terraform.tfstate`). Le job `iac-plan` le copie par SCP, travaille sur la copie et la supprime en fin de job ; il ne renvoie jamais rien. Conséquence : une seule personne applique à la fois (pas de verrou partagé), et le state se renvoie à la main après chaque apply. Pour plusieurs personnes ou pour automatiser l'apply, passer à un backend distant chiffré (S3 avec verrou, par exemple), ce qui change `backend "local" {}` et le job.

## Vérification

- `bash scripts/verifier-briques.sh iac-opentofu` : `tofu fmt -check`, `tofu init -backend=false -lockfile=readonly` et `tofu validate` dans un conteneur OpenTofu épinglé.
- Après un apply : `tofu plan -detailed-exitcode` rend 0 (rien à faire), `docker ps` montre les deux conteneurs `healthy`.
- Sur une PR touchant `infra/` : le commentaire `Plan OpenTofu : staging` apparaît et se met à jour à chaque push.

## Pièges connus

- Labels Compose d'un volume importé : Compose pose ses propres labels sur le volume qu'il crée ; sans `ignore_changes = [labels]`, OpenTofu veut le remplacer, donc supprimer les données.
- Label sur le réseau : un label modifié force le remplacement du réseau, donc de tous les conteneurs qui y sont attachés. Ne pas en ajouter.
- Tag Postgres qui bouge : `postgres:16-alpine` change sous le même nom ; l'image est épinglée par digest, à mettre à jour à la main (`docker buildx imagetools inspect postgres:16-alpine`).
- `wait` : `wait = true` fait échouer l'apply si le healthcheck reste rouge 90 s ; c'est voulu, un apply vert garantit une application saine.
- Un conteneur dont l'image ou les variables changent est recréé ; un `image_tag` qui change recrée donc `app` (coupure de quelques secondes) mais pas `db`.
- Le plan CI est lancé avec l'`image_tag` du state : un déploiement fait ailleurs ne se voit pas comme une dérive du tag, mais tout le reste oui.
- Le state et `terraform.tfvars` ne vont jamais dans Git (`infra/.gitignore`) ; `terraform.tfstate.backup` non plus.
- Jamais `StrictHostKeyChecking=no` : sans `DEPLOY_KNOWN_HOSTS` exact, le plan échoue, et c'est voulu.
- Dépôt public : `DEPLOY_HOST` est une variable d'environnement GitHub, jamais dans les fichiers de `infra/`.
