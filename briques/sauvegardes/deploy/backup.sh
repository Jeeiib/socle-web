#!/usr/bin/env bash
# Sauvegarde la base : ./deploy/backup.sh (depuis le dossier de l'environnement, COMPOSE_FILE défini dans .env).
# Produit backups/<base>-AAAAMMJJ-HHMMSS.sql.gz (600), supprime celles de plus de 7 jours, refuse un dump vide.
set -euo pipefail

dossier="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$dossier/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

cd "$dossier"
umask 077
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# Nom de la base lu dans le conteneur : pas besoin d'analyser .env.
base="$(docker compose exec -T db sh -c 'printf %s "$POSTGRES_DB"')"
[ -n "$base" ] || { echo "Erreur : nom de la base introuvable (service db démarré ?)" >&2; exit 1; }

final="$BACKUP_DIR/$base-$(date +%Y%m%d-%H%M%S).sql.gz"
partiel="$final.partial"
# Un fichier incomplet ne doit jamais passer pour une sauvegarde.
trap 'rm -f "$partiel"' EXIT

echo "==> Sauvegarde vers $final"
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists' | gzip > "$partiel"

# gzip d'une entrée vide pèse ~20 octets : on contrôle le contenu décompressé, pas la taille du fichier.
gzip -t "$partiel"
if [ -z "$(gzip -dc "$partiel" | head -c 1)" ]; then
  echo "Erreur : la sauvegarde est vide, refusée" >&2
  exit 1
fi

chmod 600 "$partiel"
mv "$partiel" "$final"

echo "==> Rotation : suppression des sauvegardes de plus de $RETENTION_DAYS jours"
find "$BACKUP_DIR" -maxdepth 1 -name "$base-*.sql.gz" -mtime "+$RETENTION_DAYS" -print -delete

echo "==> Terminé : $(find "$BACKUP_DIR" -maxdepth 1 -name "$base-*.sql.gz" | wc -l | tr -d ' ') sauvegarde(s) conservée(s)"
