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
      docker rmi -f socle-verif:0.0.0-test socle-verif:0.0.1-test socle-verif:0.0.2-test >/dev/null 2>&1 || true
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

    echo "-- /api/metrics refusé au public"
    code="$(curl -ks -o /dev/null -w '%{http_code}' "$BASE_URL/api/metrics")"
    [ "$code" = 404 ] || { echo "/api/metrics attendu 404, obtenu $code"; exit 1; }

    echo "-- seconde version réussie : .previous_tag = première"
    docker build -q --build-arg APP_VERSION=0.0.2-test -t socle-verif:0.0.2-test . >/dev/null || exit 1
    (cd "$srv" && ./deploy/deploy.sh v0.0.2-test) || exit 1
    [ "$(cat "$srv/.previous_tag")" = v0.0.0-test ] || { echo ".previous_tag attendu : v0.0.0-test"; exit 1; }

    echo "-- déploiement en échec : retour automatique attendu"
    if (cd "$srv" && SMOKE_RETRIES=3 SMOKE_DELAY=1 ./deploy/deploy.sh v0.0.1-test); then
      echo "Le déploiement d'une version erronée aurait dû échouer"
      exit 1
    fi
    [ "$(cat "$srv/.deployed_tag")" = v0.0.2-test ] || { echo "rollback : .deployed_tag attendu v0.0.2-test"; exit 1; }
    [ "$(cat "$srv/.previous_tag")" = v0.0.0-test ] || { echo "rollback : .previous_tag doit rester v0.0.0-test"; exit 1; }
    "$brique/deploy/smoke-test.sh" 0.0.2-test >/dev/null || { echo "rollback : service non rétabli"; exit 1; }

    echo "-- échec sur le tag déjà en place : aucun retour arrière"
    docker tag socle-verif:0.0.0-test socle-verif:0.0.2-test
    sortie="$(cd "$srv" && SMOKE_RETRIES=3 SMOKE_DELAY=1 ./deploy/deploy.sh v0.0.2-test 2>&1)" && { echo "Le redéploiement erroné aurait dû échouer"; exit 1; }
    case "$sortie" in *"Retour automatique"*) echo "Retour arrière inattendu sur le tag en place"; exit 1 ;; esac
    [ "$(cat "$srv/.deployed_tag")" = v0.0.2-test ] || { echo ".deployed_tag modifié à tort"; exit 1; }
    [ "$(cat "$srv/.previous_tag")" = v0.0.0-test ] || { echo ".previous_tag modifié à tort"; exit 1; }
    echo "-- tag invalide refusé"
    if (cd "$srv" && ./deploy/deploy.sh '1.2.3' >/dev/null 2>&1); then
      echo "Un tag invalide aurait dû être refusé"
      exit 1
    fi
  )
}

# --- sauvegardes : Postgres réel, sauvegarde, suppression d'une table, restauration, rotation, dump vide refusé.
verifier_sauvegardes() {
  local brique="briques/sauvegardes"
  local srv="$tmp/serveur-sauvegardes"
  (
    # shellcheck disable=SC2329 # appelée par le trap
    nettoyer() { (cd "$srv" 2>/dev/null && docker compose down -v --remove-orphans >/dev/null 2>&1) || true; }
    trap nettoyer EXIT

    mkdir -p "$srv"
    cp -R "$brique/compose.postgres.yaml" "$brique/deploy" "$srv/"
    printf 'COMPOSE_PROJECT_NAME=socle-verif-sauv\nCOMPOSE_FILE=compose.postgres.yaml\nPOSTGRES_USER=app\nPOSTGRES_DB=appdb\nPOSTGRES_PASSWORD=verif-seulement\n' > "$srv/.env"
    cd "$srv"
    sql() { docker compose exec -T db psql -qtA -U app -d appdb -c "$1"; }

    echo "-- hook sans base démarrée : ignoré sans erreur"
    ./deploy/avant-deploiement.d/10-sauvegarde.sh || exit 1

    docker compose up -d --wait --wait-timeout 60 || exit 1
    sql "CREATE TABLE note (id int, texte text); INSERT INTO note VALUES (1, 'avant-sauvegarde');" >/dev/null

    echo "-- sauvegarde par le hook"
    ./deploy/avant-deploiement.d/10-sauvegarde.sh || exit 1
    dump="$(find backups -name 'appdb-*.sql.gz' | head -n 1)"
    [ -n "$dump" ] || { echo "aucune sauvegarde produite"; exit 1; }
    [ -n "$(find "$dump" -perm 600)" ] || { echo "$dump doit être en 600"; exit 1; }

    echo "-- restauration après suppression de la table"
    sql "DROP TABLE note;" >/dev/null
    ./deploy/restaurer.sh --oui "$dump" || exit 1
    [ "$(sql "SELECT texte FROM note WHERE id = 1;")" = avant-sauvegarde ] || { echo "ligne non restaurée"; exit 1; }

    echo "-- restauration sans --oui : refusée sur une réponse autre que oui"
    if echo non | ./deploy/restaurer.sh "$dump" >/dev/null 2>&1; then echo "restauration sans confirmation"; exit 1; fi

    echo "-- rotation : une sauvegarde de plus de 7 jours disparaît"
    ancien=backups/appdb-19990101-000000.sql.gz
    cp "$dump" "$ancien"
    touch -t 199901010000 "$ancien"
    ./deploy/backup.sh >/dev/null || exit 1
    [ ! -e "$ancien" ] || { echo "rotation : $ancien conservé"; exit 1; }

    echo "-- dump vide refusé (pg_dump simulé sans sortie)"
    mkdir -p "$srv/faux"
    cat > "$srv/faux/docker" <<EOS
#!/usr/bin/env bash
case "\$*" in *pg_dump*) exit 0 ;; esac
exec "$(command -v docker)" "\$@"
EOS
    chmod +x "$srv/faux/docker"
    avant="$(find backups -name 'appdb-*.sql.gz' | wc -l)"
    if PATH="$srv/faux:$PATH" ./deploy/backup.sh >/dev/null 2>&1; then echo "un dump vide aurait dû être refusé"; exit 1; fi
    [ "$(find backups -name 'appdb-*.sql.gz*' | wc -l)" = "$avant" ] || { echo "fichier laissé par un dump vide"; exit 1; }
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
