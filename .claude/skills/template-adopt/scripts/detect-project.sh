#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# detect-project.sh — classify whether a target repo is an "up-in-place" clone
# of this template (shares structure/identifiers) or an independent "greenfield"
# Tauri app. Used by the template-adopt skill to pick the adoption strategy.
#
# Usage:
#   scripts/detect-project.sh [REPO_DIR]   (default: current dir)
# Output: JSON { "case": "up-in-place" | "greenfield", "signals": {...} }
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="${1:-$PWD}"

[[ -d "$ROOT" ]] || { echo "error: no dir $ROOT" >&2; exit 1; }

json_has() { # $1 = path-relative (no trailing slash)
  [[ -e "$ROOT/$1" ]] && echo true || echo false
}

has_skills=false
[[ -d "$ROOT/.claude/skills" ]] && has_skills=true

has_template_version=false
[[ -f "$ROOT/TEMPLATE_VERSION" ]] && has_template_version=true

has_packages_ui=false
[[ -d "$ROOT/packages/ui" ]] && has_packages_ui=true

# Identity signal: does the project still carry template identifiers?
crate="${ROOT}/src-tauri/Cargo.toml"
id_tpl=false
if [[ -f "$crate" ]] && command -v grep >/dev/null; then
  grep -qi 'tauri-react-template' "$crate" 2>/dev/null && id_tpl=true
fi

# Count of signals pointing to a template lineage.
score=0
$has_skills && score=$((score+1))
$has_template_version && score=$((score+1))
$has_packages_ui && score=$((score+1))
$id_tpl && score=$((score+1))

if [[ "$score" -ge 2 ]]; then
  case_json="up-in-place"
else
  case_json="greenfield"
fi

cat <<JSON
{
  "case": "$case_json",
  "score": $score,
  "signals": {
    "hasSkillsDir": $has_skills,
    "hasTemplateVersion": $has_template_version,
    "hasPackagesUi": $has_packages_ui,
    "usesTemplateIdentifiers": $id_tpl
  }
}
JSON