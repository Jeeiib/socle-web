#!/usr/bin/env bash
# Sauvegarde la base avant chaque déploiement ; un échec arrête le déploiement (voir deploy.sh).
set -euo pipefail

cd "$(dirname "$0")/../.."
# Premier déploiement : la base n'existe pas encore, rien à sauvegarder.
if ! docker compose ps --status running --services 2>/dev/null | grep -qx db; then
  echo "Base non démarrée : sauvegarde ignorée (premier déploiement ?)"
  exit 0
fi
./deploy/backup.sh
