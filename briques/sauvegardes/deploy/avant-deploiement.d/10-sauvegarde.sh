#!/usr/bin/env bash
# Sauvegarde la base avant chaque déploiement ; un échec arrête le déploiement (voir deploy.sh).
# Seul cas ignoré : la base n'a jamais existé (ni conteneur ni volume), donc premier déploiement.
set -euo pipefail

cd "$(dirname "$0")/../.."
fail() { echo "Sauvegarde impossible : $1" >&2; exit 1; }

# Une erreur de compose (fichier manquant, démon arrêté) arrête tout : pas de redirection d'erreurs.
definis="$(docker compose config --services)" || fail "docker compose config a échoué"
grep -qx db <<<"$definis" || fail "service db absent de COMPOSE_FILE (ajouter compose.postgres.yaml)"
actifs="$(docker compose ps --status running --services)" || fail "docker compose ps a échoué"
if grep -qx db <<<"$actifs"; then
  exec ./deploy/backup.sh
fi

existants="$(docker compose ps -a --services)" || fail "docker compose ps -a a échoué"
grep -qx db <<<"$existants" && fail "le conteneur db existe mais ne tourne pas"
projet="$(docker compose config | sed -n 's/^name: //p')"
volumes="$(docker volume ls -q --filter "label=com.docker.compose.project=$projet" --filter "label=com.docker.compose.volume=db-data")" || fail "docker volume ls a échoué"
[ -z "$volumes" ] || fail "le volume de données db existe mais la base ne tourne pas"
echo "Base jamais créée : sauvegarde ignorée (premier déploiement)"
