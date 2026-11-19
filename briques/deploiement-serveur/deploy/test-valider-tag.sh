#!/usr/bin/env bash
# Teste valider-tag.sh : tags acceptés et refusés.
set -euo pipefail

dir="$(cd "$(dirname "$0")" && pwd)"
echecs=0

attendre() {
  local code="$1" tag="$2" reel=0
  "$dir/valider-tag.sh" "$tag" >/dev/null 2>&1 || reel=$?
  if [ "$reel" -eq "$code" ]; then
    echo "OK    '$tag' -> $code"
  else
    echo "ECHEC '$tag' : attendu $code, obtenu $reel"
    echecs=$((echecs + 1))
  fi
}

attendre 0 "v1.2.3"
attendre 0 "v1.2.3-rc.1"
attendre 0 "v10.20.30"
attendre 1 "1.2.3"
attendre 1 "v1.2"
attendre 1 "v1.2.3; rm -rf /"
# shellcheck disable=SC2016 # la chaîne littérale est le cas testé
attendre 1 '$(id)'
attendre 1 ""

# Sans argument : usage, code 1
reel=0
"$dir/valider-tag.sh" >/dev/null 2>&1 || reel=$?
[ "$reel" -eq 1 ] || { echo "ECHEC sans argument : obtenu $reel"; echecs=$((echecs + 1)); }

[ "$echecs" -eq 0 ] || { echo "$echecs cas en échec."; exit 1; }
echo "Tous les cas passent."
