#!/usr/bin/env bash
# Ajoute une brique du socle à un projet : scripts/ajouter-brique.sh <nom> [dossier-projet]
# Codes : 0 ok ou déjà présente, 1 usage ou brique inconnue, 2 fichiers en conflit,
# 3 prérequis manquant, 4 fichier remplacé modifié localement.
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage : $0 <nom> [dossier-projet]" >&2
  exit 1
fi
nom="$1"
projet="${2:-.}"

case "$nom" in
  ''|-*|*[!a-z0-9-]*) echo "Nom de brique invalide : $nom" >&2; exit 1 ;;
esac
if [ ! -d "$projet" ]; then
  echo "Dossier projet introuvable : $projet" >&2
  exit 1
fi
projet="$(cd "$projet" && pwd)"

sha() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi
}

# Source des briques : SOCLE_DIR, sinon briques/ à côté du script, sinon archive GitHub.
ici="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${SOCLE_DIR:-}" ]; then
  source_briques="$SOCLE_DIR/briques"
elif [ -d "$ici/../briques" ]; then
  source_briques="$ici/../briques"
else
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -sSfL "https://codeload.github.com/Jeeiib/socle-web/tar.gz/main" | tar -xz -C "$tmp" \
    || { echo "Téléchargement impossible" >&2; exit 1; }
  source_briques="$(echo "$tmp"/*/briques)"
fi

dossier="$source_briques/$nom"
if [ ! -f "$dossier/BRIQUE.md" ]; then
  echo "Brique inconnue : $nom" >&2
  exit 1
fi

# Valeur d'une clé de l'en-tête (entre les deux lignes ---).
entete() {
  awk -v cle="$1" '
    /^---[[:space:]]*$/ { n++; next }
    n == 1 && index($0, cle ":") == 1 { sub("^" cle ":[[:space:]]*", ""); print; exit }
  ' "$dossier/BRIQUE.md"
}

registre="$projet/.socle/briques"
if [ -f "$registre" ] && grep -qx -- "$nom" "$registre"; then
  echo "Brique $nom déjà présente."
  exit 0
fi

# 1. Prérequis
manquants=""
for p in $(entete prerequis); do
  if ! { [ -f "$registre" ] && grep -qx -- "$p" "$registre"; }; then
    manquants="$manquants $p"
  fi
done
if [ -n "$manquants" ]; then
  echo "Prérequis manquants :$manquants. Ajoute-les d'abord." >&2
  exit 3
fi

# 2. Fichiers remplacés : doivent être identiques à ceux du socle
remplace="$(entete remplace)"
modifies=""
for r in $remplace; do
  chemin="${r%@*}"
  attendu="${r##*@}"
  if [ -f "$projet/$chemin" ] && [ "$(sha "$projet/$chemin")" != "$attendu" ]; then
    modifies="$modifies $chemin"
  fi
done
if [ -n "$modifies" ]; then
  echo "Fichiers modifiés localement, remplacement refusé :$modifies" >&2
  exit 4
fi

# 3. Conflits : fichier déjà présent avec un autre contenu
liste="$(cd "$dossier" && find . -type f ! -path ./BRIQUE.md | sed 's|^\./||' | sort)"
conflits=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  est_remplace=0
  for r in $remplace; do
    [ "${r%@*}" = "$f" ] && est_remplace=1
  done
  [ "$est_remplace" = 1 ] && continue
  if [ -e "$projet/$f" ] && ! cmp -s "$dossier/$f" "$projet/$f"; then
    conflits="$conflits
  $f"
  fi
done <<EOT
$liste
EOT
if [ -n "$conflits" ]; then
  echo "Fichiers en conflit (déjà présents avec un autre contenu) :$conflits" >&2
  exit 2
fi

# Copie
while IFS= read -r f; do
  [ -z "$f" ] && continue
  mkdir -p "$projet/$(dirname "$f")"
  cp -p "$dossier/$f" "$projet/$f"
done <<EOT
$liste
EOT
mkdir -p "$projet/.socle"
echo "$nom" >>"$registre"

echo "Brique $nom ajoutée."
echo
awk '/^## Activation/ { on = 1; next } /^## / { on = 0 } on' "$dossier/BRIQUE.md"
