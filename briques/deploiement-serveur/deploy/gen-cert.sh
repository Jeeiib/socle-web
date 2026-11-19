#!/usr/bin/env bash
# Certificat HTTPS auto-signé (lab, test, premier démarrage). En production réelle : Let's Encrypt.
# Usage (dans le dossier de prod) : DOMAIN=exemple.fr ./deploy/gen-cert.sh
# Résultat : certs/app.crt et certs/app.key (clé en 600).
set -euo pipefail

CERT_DIR="${CERT_DIR:-certs}"
DOMAIN="${DOMAIN:-localhost}"
DAYS="${DAYS:-365}"

mkdir -p "$CERT_DIR"
if [[ -f "$CERT_DIR/app.crt" && -f "$CERT_DIR/app.key" && "${FORCE:-0}" != 1 ]]; then
  echo "Certificat déjà présent dans $CERT_DIR/ (FORCE=1 pour le régénérer)."
  exit 0
fi

args=(req -x509 -nodes -newkey rsa:2048 -days "$DAYS"
  -subj "/CN=$DOMAIN"
  -addext "subjectAltName=DNS:$DOMAIN,DNS:localhost,IP:127.0.0.1")

if command -v openssl >/dev/null 2>&1; then
  openssl "${args[@]}" -keyout "$CERT_DIR/app.key" -out "$CERT_DIR/app.crt" 2>/dev/null
else
  # Sans openssl local : un conteneur Alpine écrit les fichiers dans le dossier monté.
  docker run --rm -v "$(cd "$CERT_DIR" && pwd):/out" docker.io/library/alpine:3.21 \
    sh -c "apk add --no-cache openssl >/dev/null && openssl ${args[*]@Q} -keyout /out/app.key -out /out/app.crt 2>/dev/null"
fi

chmod 600 "$CERT_DIR/app.key"
chmod 644 "$CERT_DIR/app.crt"
echo "Certificat créé dans $CERT_DIR/ (valable $DAYS jours, pour $DOMAIN)"
