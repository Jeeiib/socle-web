---
nom: ansible
prerequis:
remplace:
checks-requis:
---

# ansible

Un playbook qui prépare le serveur de production : dossier de déploiement, dossier `certs/` et fichier `.env` en `0600`, avec un mot de passe Postgres généré une fois. Rejouable sans effet de bord : un second passage ne change rien.

## Quand la prendre

- On prépare plus d'un serveur, ou on veut pouvoir refaire le serveur de production à l'identique.
- On veut que le `.env` (donc les secrets) soit produit par un outil et non copié à la main.

## Quand ne pas la prendre

- Un seul serveur, installé une fois : les trois commandes de la fiche `deploiement-serveur` sont plus courtes que le playbook.
- Le `.env` est déjà géré par un autre outil (gestionnaire de secrets, plateforme).

## Prérequis

Aucune brique bloquante. Prévue pour accompagner `deploiement-serveur` (même dossier, mêmes noms) : le playbook prépare ce que sa fiche fait à la main. Côté poste : `ansible-core` (`pipx install ansible-core`) et un accès SSH au serveur ; sur le serveur, un utilisateur pouvant `sudo` (pour créer `/srv/app`) et Python 3.

## Fichiers apportés

- `ansible/preparer-prod.yml` : crée `prod_dir` (`/srv/app`, `0750`) et `certs/` (`0700`) au nom de `app_user`, écrit `.env` (`0600`) depuis le modèle, vérifie les variables avant d'agir. Si le `.env` change et qu'une stack tourne, un handler la recrée avec la version en place (lue dans `.deployed_tag`) ; sinon il ne fait rien.
- `ansible/templates/env.j2` : modèle du `.env` (`COMPOSE_FILE`, `IMAGE`, `IMAGE_TAG`, `APP_ENV`, `DATABASE_URL`, variables Postgres).
- `ansible/inventory.ini.example` : un groupe `prod` avec un serveur.

## Activation

1. Copier `ansible/inventory.ini.example` en `ansible/inventory.ini` et y mettre l'adresse du serveur et un administrateur qui a `sudo` (pas `deploy`, qui n'en a pas ; sinon passer `-K` pour saisir le mot de passe sudo).
2. Simuler : `ansible-playbook -i inventory.ini preparer-prod.yml -e image=ghcr.io/mon-organisation/mon-projet --check --diff`.
3. Appliquer sans `--check`. Variables utiles (`-e`) : `prod_dir`, `app_user`, `app_become=false` (si la connexion se fait déjà avec le propriétaire du dossier), `compose_file` (`compose.prod.yaml:compose.postgres.yaml` avec la brique `sauvegardes`), `password_file`.
4. Poser le certificat (`deploy/gen-cert.sh` ou Let's Encrypt) puis déployer comme décrit dans `deploiement-serveur`.

Aucun check requis : le playbook se lance à la main.

## Vérification

- `ansible-playbook --syntax-check -i inventory.ini.example preparer-prod.yml -e image=ghcr.io/exemple/projet`
- `bash scripts/verifier-briques.sh ansible` : syntaxe, puis deux passages réels en connexion locale dans un conteneur à `ansible-core` épinglé ; le second doit afficher `changed=0`, le `.env` doit être en `0600`.
- Sur le serveur : `stat -c %a /srv/app/.env` affiche `600`.

## Pièges connus

- Mot de passe : `lookup('password', ...)` s'exécute sur le poste qui lance Ansible, pas sur le serveur. Le fichier (`~/.config/socle/postgres-password`, `0600`) reste hors du dépôt ; le perdre génère un nouveau mot de passe qui n'ouvre plus une base déjà créée. Le sauvegarder, ou reprendre l'ancien avant de relancer.
- `ansible_facts['env']['HOME']` et non `ansible_env` : la variable injectée est dépréciée et disparaît dans les versions récentes d'`ansible-core`.
- Le `.env` est écrasé à chaque passage : ne pas y ajouter de lignes à la main, elles seraient perdues. Ajouter la variable au modèle.
- `IMAGE_TAG` du `.env` n'est qu'une valeur initiale : `deploy.sh` passe le vrai tag dans l'environnement du déploiement, le playbook ne la change donc jamais en production.
- La brique ne copie pas `compose.prod.yaml` ni `deploy/` : c'est le rôle du workflow de déploiement.
