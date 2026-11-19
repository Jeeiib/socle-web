---
nom: sauvegardes
prerequis: deploiement-serveur
remplace:
checks-requis:
---

# sauvegardes

Une base PostgreSQL à côté de l'application, sauvegardée automatiquement avant chaque déploiement, avec un script de restauration. Un déploiement qui échoue après une migration laisse au moins un dump récent.

## Quand la prendre

- L'application garde des données qu'on ne peut pas recréer (clients, commandes).
- On veut pouvoir revenir d'une migration ratée : le retour arrière automatique rend le code, pas les données.

## Quand ne pas la prendre

- Pas de base, ou base gérée par un service qui sauvegarde déjà (Supabase, RDS) : s'en remettre à ses sauvegardes.
- Base autre que PostgreSQL : adapter `backup.sh` et `restaurer.sh`.

## Prérequis

Brique `deploiement-serveur` (point d'extension `deploy/avant-deploiement.d/`). Docker Compose sur le serveur.

## Fichiers apportés

- `compose.postgres.yaml` : service `db` (PostgreSQL 16 épinglé par digest), volume nommé `db-data`, healthcheck `pg_isready`, aucun port publié. Identifiants lus dans `.env`.
- `.env.postgres.example` : variables à ajouter au `.env` (`POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_PASSWORD`).
- `deploy/backup.sh` : `pg_dump` dans le conteneur `db`, compression, fichier `backups/<base>-AAAAMMJJ-HHMMSS.sql.gz` en mode 600 (dossier en 700). Supprime les sauvegardes de plus de 7 jours (`RETENTION_DAYS`). Refuse un dump vide et ne laisse aucun fichier partiel.
- `deploy/restaurer.sh <fichier>` : demande de taper `oui` (sauf `--oui`), puis restaure dans une seule transaction. Écrase les données actuelles.
- `deploy/avant-deploiement.d/10-sauvegarde.sh` : appelle `backup.sh` avant chaque déploiement ; un échec arrête le déploiement. Si la base ne tourne pas encore (premier déploiement), il passe sans rien sauvegarder.

## Activation

1. Joindre la base au compose de l'environnement : dans le `.env` du serveur, `COMPOSE_FILE=compose.prod.yaml:compose.postgres.yaml`, et ajouter les variables de `.env.postgres.example` (mot de passe fort). Avec `staging-prod`, faire de même pour le staging avec `compose.staging.yaml`, une base et des identifiants distincts.
2. L'application lit sa base via `DATABASE_URL` dans le même `.env` (hôte `db`, ex. `postgres://app:<mot-de-passe>@db:5432/app`).
3. Envoyer `compose.postgres.yaml` sur le serveur. Le workflow de `deploiement-serveur` ne copie que `compose.prod.yaml` : copier ce fichier à la main une fois (`scp compose.postgres.yaml deploy@203.0.113.10:/srv/app/`), ou adapter l'étape de copie en `compose*.yaml` (c'est déjà le cas avec `staging-prod`).
4. Premier déploiement : `deploy.sh` démarre la base. Dès le suivant, le hook sauvegarde avant de toucher à quoi que ce soit.
5. Sauvegarde nocturne en plus (cron du serveur) : `0 3 * * * cd /srv/app && ./deploy/backup.sh >> backups/backup.log 2>&1`.

Restauration : `./deploy/restaurer.sh backups/app-20261119-030000.sql.gz` dans le dossier de l'environnement.

Aucun check requis.

## Vérification

- `bash scripts/verifier-briques.sh sauvegardes` : lance un vrai PostgreSQL, crée une ligne, sauvegarde, supprime la table, restaure et relit la ligne ; contrôle les droits 600, la rotation et le refus d'un dump vide.
- Sur le serveur : `ls -l backups/`, puis un essai de restauration sur le staging avant d'en avoir besoin.

## Pièges connus

- Une sauvegarde jamais restaurée ne prouve rien : tester `restaurer.sh` sur le staging.
- Les sauvegardes sont sur le même disque que la base : elles ne protègent ni d'une panne du serveur ni d'un vol. Les copier ailleurs (`rsync`, stockage objet) hors de cette brique.
- `COMPOSE_FILE` doit lister `compose.postgres.yaml`, sinon `docker compose exec db` échoue : le hook l'ignore alors comme un premier déploiement. Vérifier que `backups/` se remplit après le deuxième déploiement.
- Le dump est fait avec `--clean --if-exists` : la restauration supprime puis recrée les tables du dump ; les tables absentes du dump ne sont pas touchées.
- Un dump vide pèse déjà une vingtaine d'octets une fois compressé : `backup.sh` contrôle le contenu décompressé, pas la taille du fichier.
- `scp -r` ne supprime rien : retirer le hook du dépôt ne le retire pas du serveur.
- Les dumps contiennent toutes les données : ne jamais les mettre dans Git (le dossier `backups/` n'existe que sur le serveur).
- Changer de version majeure de PostgreSQL ne se fait pas en changeant l'image : restaurer un dump dans un volume neuf.
