#!/usr/bin/env bash
# Vérifie les briques : scripts/verifier-briques.sh [brique...] (toutes par défaut).
# Outils lancés par `docker run --rm`, images épinglées par digest.
# Une brique ajoute ses contrôles en définissant verifier_<nom> (tirets -> underscores).
set -euo pipefail

IMAGE_SHELLCHECK="koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d"
IMAGE_ACTIONLINT="rhysd/actionlint:1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667"
IMAGE_COMPOSE="docker:29.0.0-cli@sha256:87858a6dd14149240f4a2c33e0ec0f32a5ac1bb2548c04f5a20694ea25cb6157"

racine="$(cd "$(dirname "$0")/.." && pwd)"
cd "$racine"

# Dossier temporaire sous le dépôt : seul chemin monté par Colima sur Mac.
tmp="$racine/.verif-tmp"
rm -rf "$tmp"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

erreurs=0
echec() { echo "ÉCHEC $1"; erreurs=$((erreurs + 1)); }
reussi() { echo "OK $1"; }

# Liste des briques à vérifier
selection=""
if [ $# -gt 0 ]; then
  for b in "$@"; do
    if [ ! -d "briques/$b" ]; then
      echo "Brique inconnue : $b" >&2
      exit 1
    fi
    selection="$selection $b"
  done
else
  for d in briques/*/; do
    [ -d "$d" ] && selection="$selection $(basename "$d")"
  done
fi

# --- shellcheck : scripts du socle et scripts des briques sélectionnées
fichiers_sh="$(find scripts -name '*.sh' | sort)"
for b in $selection; do
  fichiers_sh="$fichiers_sh
$(find "briques/$b" -name '*.sh' | sort)"
done
fichiers_sh="$(echo "$fichiers_sh" | sed '/^$/d')"
if [ -n "$fichiers_sh" ]; then
  # shellcheck disable=SC2086 # une liste de chemins sans espace, découpée volontairement
  if docker run --rm -v "$racine:/repo:ro" -w /repo "$IMAGE_SHELLCHECK" $fichiers_sh; then
    reussi "shellcheck"
  else
    echec "shellcheck"
  fi
fi

# --- actionlint : workflows apportés par les briques
workflows=""
for b in $selection; do
  for w in "briques/$b"/.github/workflows/*.yml "briques/$b"/.github/workflows/*.yaml; do
    [ -f "$w" ] && workflows="$workflows $w"
  done
done
if [ -n "$workflows" ]; then
  # shellcheck disable=SC2086
  if docker run --rm -v "$racine:/repo:ro" -w /repo "$IMAGE_ACTIONLINT" -color $workflows; then
    reussi "actionlint"
  else
    echec "actionlint"
  fi
fi

# --- docker compose config : copie de la brique, .env factice à côté de chaque .env.example,
# commande lancée dans le dossier de chaque compose*.yaml (les chemins relatifs y résolvent).
for b in $selection; do
  copie="$tmp/$b"
  mkdir -p "$copie"
  cp -R "briques/$b/." "$copie/"
  while IFS= read -r e; do
    [ -z "$e" ] && continue
    cp "$e" "$(dirname "$e")/.env"
  done <<EOT
$(find "$copie" -name '.env*example')
EOT
  while IFS= read -r c; do
    [ -z "$c" ] && continue
    rel="${c#"$copie"/}"
    if docker run --rm -v "$(dirname "$c"):/brique:ro" -w /brique "$IMAGE_COMPOSE" compose -f "$(basename "$c")" config -q; then
      reussi "compose $b/$rel"
    else
      echec "compose $b/$rel"
    fi
  done <<EOT
$(find "$copie" -name 'compose*.yaml' | sort)
EOT
done

# --- deploiement-serveur : test du validateur de tag, puis déploiement de bout en bout
# (image du socle, Nginx TLS, smoke test, rollback automatique) sur des ports non privilégiés.
verifier_deploiement_serveur() {
  local brique="briques/deploiement-serveur"
  bash "$brique/deploy/test-valider-tag.sh" || return 1

  local srv="$tmp/serveur-deploiement"
  (
    export COMPOSE_PROJECT_NAME=socle-verif HTTP_PORT=18080 HTTPS_PORT=18443 BASE_URL=https://localhost:18443
    # shellcheck disable=SC2329 # appelée par le trap
    nettoyer() {
      (cd "$srv" 2>/dev/null && docker compose down -v --remove-orphans >/dev/null 2>&1) || true
      docker rmi -f socle-verif:0.0.0-test socle-verif:0.0.1-test >/dev/null 2>&1 || true
    }
    trap nettoyer EXIT

    mkdir -p "$srv"
    cp -R "$brique/compose.prod.yaml" "$brique/deploy" "$srv/"
    sed -e 's#^IMAGE=.*#IMAGE=socle-verif#' "$brique/.env.prod.example" > "$srv/.env"

    docker build -q --build-arg APP_VERSION=0.0.0-test -t socle-verif:0.0.0-test . >/dev/null || exit 1
    # Même image sous un second tag : sa version (0.0.0-test) ne correspond pas au tag, le smoke test doit échouer.
    docker tag socle-verif:0.0.0-test socle-verif:0.0.1-test
    (cd "$srv" && CERT_DIR=certs bash deploy/gen-cert.sh >/dev/null) || exit 1

    echo "-- déploiement nominal"
    (cd "$srv" && ./deploy/deploy.sh v0.0.0-test) || exit 1
    [ "$(cat "$srv/.deployed_tag")" = v0.0.0-test ] || { echo ".deployed_tag attendu : v0.0.0-test"; exit 1; }
    echo "-- relance du même tag (idempotence)"
    (cd "$srv" && ./deploy/deploy.sh v0.0.0-test) || exit 1

    echo "-- déploiement en échec : retour automatique attendu"
    if (cd "$srv" && SMOKE_RETRIES=3 SMOKE_DELAY=1 ./deploy/deploy.sh v0.0.1-test); then
      echo "Le déploiement d'une version erronée aurait dû échouer"
      exit 1
    fi
    [ "$(cat "$srv/.deployed_tag")" = v0.0.0-test ] || { echo "rollback : .deployed_tag attendu v0.0.0-test"; exit 1; }
    "$brique/deploy/smoke-test.sh" 0.0.0-test >/dev/null || { echo "rollback : service non rétabli"; exit 1; }
    echo "-- tag invalide refusé"
    if (cd "$srv" && ./deploy/deploy.sh '1.2.3' >/dev/null 2>&1); then
      echo "Un tag invalide aurait dû être refusé"
      exit 1
    fi
  )
}

# --- contrôles propres à chaque brique
for b in $selection; do
  fonction="verifier_$(echo "$b" | tr '-' '_')"
  if [ "$(type -t "$fonction")" = function ]; then
    if "$fonction"; then reussi "$b"; else echec "$b"; fi
  fi
done

if [ "$erreurs" -gt 0 ]; then
  echo "$erreurs contrôle(s) en échec."
  exit 1
fi
echo "Toutes les briques vérifiées."
