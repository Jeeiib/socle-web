#!/usr/bin/env bash
# Attend que /api/health réponde 200 avec la version attendue (sans le « v » initial).
# Usage : ./deploy/smoke-test.sh <version>   Variables : BASE_URL (https://localhost), SMOKE_RETRIES (30), SMOKE_DELAY (2)
# La version est vérifiée pour ne pas valider l'ancienne qui répond encore. Certificat non vérifié (curl -k) : appel local.
set -euo pipefail

version="${1:?Usage: ./deploy/smoke-test.sh <version>}"
version="${version#v}"
url="${BASE_URL:-https://localhost}/api/health"
retries="${SMOKE_RETRIES:-30}"
delay="${SMOKE_DELAY:-2}"

body=""
for i in $(seq 1 "$retries"); do
  if body="$(curl -ksf --max-time 5 "$url" 2>&1)" && grep -qF "\"version\":\"$version\"" <<<"$body"; then
    echo "Smoke test OK ($i/$retries) : $body"
    exit 0
  fi
  echo "Essai $i/$retries : pas encore bon -> ${body:0:200}"
  sleep "$delay"
done

echo "Smoke test ÉCHOUÉ sur $url (version attendue : $version)" >&2
exit 1
