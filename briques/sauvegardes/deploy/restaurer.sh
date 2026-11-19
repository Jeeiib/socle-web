#!/usr/bin/env bash
# Restaure un dump dans la base : ./deploy/restaurer.sh [--oui] backups/<fichier>.sql.gz
# Écrase les données actuelles (le dump contient DROP ... IF EXISTS) : faire d'abord ./deploy/backup.sh,
# arrêter l'application pendant la restauration. Confirmation demandée sauf avec --oui.
set -euo pipefail

oui=0
fichier=""
for arg in "$@"; do
  case "$arg" in
    --oui) oui=1 ;;
    *)
      [ -z "$fichier" ] || { echo "Un seul fichier à la fois" >&2; exit 1; }
      fichier="$arg"
      ;;
  esac
done
[ -n "$fichier" ] || { echo "Usage : ./deploy/restaurer.sh [--oui] <fichier.sql.gz>" >&2; exit 1; }
[ -f "$fichier" ] || { echo "Fichier introuvable : $fichier" >&2; exit 1; }
gzip -t "$fichier" || { echo "Archive corrompue : $fichier" >&2; exit 1; }
fichier="$(cd "$(dirname "$fichier")" && pwd)/$(basename "$fichier")"

cd "$(dirname "$0")/.."

if [ "$oui" != 1 ]; then
  printf 'Restaurer %s ? Les données actuelles seront écrasées. Taper oui : ' "$fichier"
  read -r reponse
  [ "$reponse" = oui ] || { echo "Annulé."; exit 1; }
fi

echo "==> Restauration de $fichier"
gzip -dc "$fichier" | docker compose exec -T db sh -c 'psql -q -o /dev/null -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 --single-transaction'
echo "==> Restauration terminée"
