#!/usr/bin/env bash
# Déploie une version : ./deploy/deploy.sh vX.Y.Z (depuis le dossier de prod, qui contient .env et certs/).
# Étapes : validation du tag, scripts de deploy/avant-deploiement.d/, pull, up, smoke test.
# Smoke test rouge : retour à la version précédente, puis code 1 (le job reste rouge). Relançable sans risque.
set -euo pipefail

dossier="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:?Usage: ./deploy/deploy.sh <tag>  (ex : v1.2.3)}"
"$dossier/deploy/valider-tag.sh" "$TAG"

cd "$dossier"
[ -f .env ] || { echo ".env absent de $dossier : il se crée à la main (jamais dans Git)" >&2; exit 1; }
# COMPOSE_FILE vient de .env (une brique peut y ajouter un fichier) ; défaut seulement s'il est absent partout.
if [ -z "${COMPOSE_FILE:-}" ] && ! grep -q '^COMPOSE_FILE=' .env; then
  export COMPOSE_FILE=compose.prod.yaml
fi

# Point d'extension : sauvegarde, migrations... Un échec arrête le déploiement.
for script in deploy/avant-deploiement.d/*; do
  if [ -f "$script" ] && [ -x "$script" ]; then
    echo "==> Avant déploiement : $script"
    "$script"
  fi
done

deployer() {
  local tag="$1"
  echo "==> Déploiement de $tag"
  IMAGE_TAG="${tag#v}" docker compose pull --quiet --policy missing
  IMAGE_TAG="${tag#v}" docker compose up -d --remove-orphans --wait --wait-timeout 120
  # Le proxy a résolu l'adresse de l'application au démarrage : on le recharge sans coupure.
  IMAGE_TAG="${tag#v}" docker compose exec -T proxy nginx -s reload
  "$dossier/deploy/smoke-test.sh" "$tag"
}

actuel=""
[ -f .deployed_tag ] && actuel="$(cat .deployed_tag)"
if deployer "$TAG"; then
  # .previous_tag = version qui tournait avant ce déploiement réussi (cible d'un retour arrière manuel).
  if [ -n "$actuel" ] && [ "$actuel" != "$TAG" ]; then
    echo "$actuel" > .previous_tag
  fi
  echo "$TAG" > .deployed_tag
  docker image prune -f >/dev/null || echo "Avertissement : nettoyage des images impossible (déploiement réussi)." >&2
  echo "==> Déployé : $TAG (précédent : $(cat .previous_tag 2>/dev/null || echo aucun))"
  exit 0
fi

echo "ÉCHEC du déploiement de $TAG" >&2
if [ -z "$actuel" ]; then
  echo "Aucune version précédente connue : intervention manuelle." >&2
  exit 1
fi
if [ "$actuel" = "$TAG" ]; then
  # Redéployer une version plus ancienne ici serait un retour arrière silencieux.
  echo "$TAG était déjà la version en place : pas de retour automatique, intervention manuelle." >&2
  exit 1
fi
echo "==> Retour automatique à $actuel" >&2
if deployer "$actuel"; then
  echo "Service rétabli sur $actuel ; le déploiement de $TAG reste en échec." >&2
else
  echo "Le retour à $actuel a aussi échoué : intervention manuelle." >&2
fi
exit 1
