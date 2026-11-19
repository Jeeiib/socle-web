#!/usr/bin/env bash
# Valide un tag de version : vX.Y.Z ou vX.Y.Z-prerelease. Code 0 si valide, 1 sinon.
set -euo pipefail

tag="${1-}"
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  echo "Tag invalide : '${tag}' (attendu : vX.Y.Z ou vX.Y.Z-rc.1)" >&2
  exit 1
fi
