#!/usr/bin/env bash
# Tests de scripts/ajouter-brique.sh sur un faux socle ; sans réseau ni Docker.
set -euo pipefail

ici="$(cd "$(dirname "$0")" && pwd)"
script="$ici/ajouter-brique.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

socle="$tmp/socle"
export SOCLE_DIR="$socle"

sha() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi
}

fiche() { # nom prerequis remplace
  printf -- '---\nnom: %s\nprerequis: %s\nremplace: %s\nchecks-requis:\n---\n\n## Activation\n\nActiver %s.\n' "$1" "$2" "$3" "$1"
}

mkdir -p "$socle/briques/a/dir" "$socle/briques/b" "$socle/briques/c"
fiche a "" "" >"$socle/briques/a/BRIQUE.md"
echo "a1" >"$socle/briques/a/fichier-a.txt"
echo "a2" >"$socle/briques/a/dir/sous.sh"
chmod +x "$socle/briques/a/dir/sous.sh"
fiche b "a" "" >"$socle/briques/b/BRIQUE.md"
echo "b1" >"$socle/briques/b/fichier-b.txt"
printf 'original\n' >"$tmp/original.txt"
orig_sha="$(sha "$tmp/original.txt")"
fiche c "" "fichier.txt@$orig_sha" >"$socle/briques/c/BRIQUE.md"
echo "nouveau" >"$socle/briques/c/fichier.txt"

ok() { echo "OK $1"; }
echec() { echo "ÉCHEC $1"; exit 1; }

# lance le script ; remplit $code et $sortie
lancer() {
  set +e
  sortie="$(bash "$script" "$@" 2>&1)"
  code=$?
  set -e
}

nouveau_projet() { rm -rf "$tmp/p"; mkdir -p "$tmp/p"; }

# a s'applique
nouveau_projet
lancer a "$tmp/p"
cas="a s'applique"
{ [ "$code" = 0 ] && [ -f "$tmp/p/fichier-a.txt" ] && [ -f "$tmp/p/dir/sous.sh" ] \
  && [ ! -e "$tmp/p/BRIQUE.md" ] && grep -qx a "$tmp/p/.socle/briques" \
  && [ -x "$tmp/p/dir/sous.sh" ] && echo "$sortie" | grep -q "Activer a."; } || echec "$cas"; ok "$cas"

# a réappliquée
lancer a "$tmp/p"
cas="a réappliquée"
[ "$code" = 0 ] && echo "$sortie" | grep -q "déjà présente" && [ "$(grep -cx a "$tmp/p/.socle/briques")" = 1 ] || echec "$cas"; ok "$cas"

# b sans a
nouveau_projet
lancer b "$tmp/p"
cas="b sans prérequis a"
[ "$code" = 3 ] && [ ! -e "$tmp/p/fichier-b.txt" ] || echec "$cas"; ok "$cas"

# b avec a
lancer a "$tmp/p"
lancer b "$tmp/p"
cas="b avec prérequis a"
[ "$code" = 0 ] && [ -f "$tmp/p/fichier-b.txt" ] || echec "$cas"; ok "$cas"

# conflit
nouveau_projet
echo "autre" >"$tmp/p/fichier-a.txt"
lancer a "$tmp/p"
cas="fichier en conflit"
[ "$code" = 2 ] && echo "$sortie" | grep -q "fichier-a.txt" && [ ! -e "$tmp/p/dir" ] && [ ! -e "$tmp/p/.socle" ] || echec "$cas"; ok "$cas"

# c remplace, fichier original
nouveau_projet
printf 'original\n' >"$tmp/p/fichier.txt"
lancer c "$tmp/p"
cas="c remplace un fichier original"
[ "$code" = 0 ] && [ "$(cat "$tmp/p/fichier.txt")" = nouveau ] || echec "$cas"; ok "$cas"

# c remplace, fichier modifié
nouveau_projet
echo "modifié" >"$tmp/p/fichier.txt"
lancer c "$tmp/p"
cas="c refuse un fichier modifié"
[ "$code" = 4 ] && [ "$(cat "$tmp/p/fichier.txt")" = "modifié" ] && [ ! -e "$tmp/p/.socle" ] || echec "$cas"; ok "$cas"

# brique inconnue
nouveau_projet
lancer inconnue "$tmp/p"
cas="brique inconnue"
[ "$code" = 1 ] || echec "$cas"; ok "$cas"

# usage
lancer
cas="usage sans argument"
[ "$code" = 1 ] || echec "$cas"; ok "$cas"
