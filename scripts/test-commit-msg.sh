#!/usr/bin/env bash
# Teste le hook commit-msg : messages valides acceptés, invalides refusés.
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/.githooks/commit-msg"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
echec=0

verifier() {
  attendu="$1"
  message="$2"
  printf '%s\n' "$message" > "$TMP"
  if [ -x "$HOOK" ] && "$HOOK" "$TMP" >/dev/null 2>&1; then obtenu=ok; else obtenu=ko; fi
  if [ "$obtenu" = "$attendu" ]; then
    echo "OK    [$attendu] $message"
  else
    echo "ECHEC [attendu $attendu, obtenu $obtenu] $message"
    echec=1
  fi
}

verifier ok 'feat: ajoute X'
verifier ok 'fix(api): corrige Y'
verifier ok 'feat!: casse Z'
verifier ok "Merge branch 'x'"
verifier ok 'Revert "feat: x"'
verifier ko 'update stuff'
verifier ko 'Feat: x'
verifier ko 'feature: x'
verifier ko 'feat:x'
verifier ko 'feat: '
verifier ok 'fixup! feat: ajoute X'
verifier ok 'squash! fix: y'
verifier ok 'amend! fix: y'
verifier ok 'feat(ci/docker): x'
verifier ko 'feat(Api): x'

exit "$echec"
