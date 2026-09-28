#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# detect-locales.sh — enumerate ALL i18n locales in a target repo and split
# them into the template's own (en, es) vs user-owned (anything else).
#
# Used by the template-adopt skill to know which languages are user-owned and
# therefore MUST NOT be touched (see references/i18n-protection.md).
#
# Usage:
#   scripts/detect-locales.sh [REPO_DIR]   (default: current dir)
# Output: JSON { "locales": [...], "templateOwned": ["en","es"], "userOwned": [...] }
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="${1:-$PWD}"
LOCALES_DIR="$ROOT/apps/web/src/i18n/locales"

if [[ ! -d "$LOCALES_DIR" ]]; then
  # No conventional i18n dir — report empty rather than erroring.
  cat <<JSON
{
  "found": false,
  "locales": [],
  "templateOwned": ["en","es"],
  "userOwned": []
}
JSON
  exit 0
fi

locales=()
for f in "$LOCALES_DIR"/*.json; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f" .json)"
  locales+=("$base")
done

# Order canonical: en, es first, then the rest alphabetically.
en_es=("en" "es")
user=()
for l in "${locales[@]}"; do
  if [[ "$l" != "en" && "$l" != "es" ]]; then
    user+=("$l")
  fi
done

# JSON-array writer; safely handles zero items under `set -u`.
arr() {
  if [[ "$#" -eq 0 ]]; then
    printf '[]'
  else
    printf '[%s]' "$(printf '"%s",' "$@" | sed 's/,$//')"
  fi
}

cat <<JSON
{
  "found": true,
  "locales": $(arr "${locales[@]}" 2>/dev/null || printf '[]'),
  "templateOwned": $(arr "${en_es[@]}"),
  "userOwned": $(arr "${user[@]+"${user[@]}"}")
}
JSON