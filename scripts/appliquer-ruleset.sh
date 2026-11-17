#!/usr/bin/env bash
# Crée ou met à jour le ruleset « main » d'un dépôt (idempotent).
# Usage : scripts/appliquer-ruleset.sh [owner/repo]
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"
fichier="$racine/.github/rulesets/main.json"
depot="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

id="$(gh api "repos/$depot/rulesets" -q '.[] | select(.name == "main") | .id' | head -n 1)"

if [ -n "$id" ]; then
  echo "Mise à jour du ruleset main (id $id) sur $depot"
  gh api --method PUT "repos/$depot/rulesets/$id" --input "$fichier" >/dev/null
else
  echo "Création du ruleset main sur $depot"
  gh api --method POST "repos/$depot/rulesets" --input "$fichier" >/dev/null
fi
echo "Ruleset appliqué."
