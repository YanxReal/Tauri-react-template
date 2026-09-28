#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# detect-identifiers.sh — print the DOWNSTREAM app's current identifiers as JSON.
#
# Used by the Template Update skill to know what the user renamed, so an update
# never re-introduces the template's own identifiers (tauri-react-template) nor
# rebrands the user's app. Read the durable sources only (Cargo.toml +
# tauri.conf.json); if they are absent, report an error instead of guessing.
#
# Script lives at <repo>/.claude/skills/template-update/scripts/ → root is 4 levels up.
# Usage:
#   scripts/detect-identifiers.sh [REPO_ROOT]
# ---------------------------------------------------------------------------
set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DEFAULT="$(cd "$SELF/../../../.." && pwd)"
ROOT="${1:-$ROOT_DEFAULT}"

CARGO="$ROOT/src-tauri/Cargo.toml"
CONF="$ROOT/src-tauri/tauri.conf.json"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -f "$CARGO" ]] || die "no $CARGO"
[[ -f "$CONF" ]] || die "no $CONF"

command -v python3 >/dev/null || die "python3 required"

python3 - "$CARGO" "$CONF" <<'PY'
import json, re, sys

cargo, conf_path = sys.argv[1], sys.argv[2]

# --- Cargo.toml ------------------------------------------------------------
crate = lib = bin = None
section = "package"
for line in open(cargo, encoding="utf-8"):
    s = line.strip()
    if s.startswith("[["):
        section = "bin"
        continue
    if s.startswith("["):
        section = s[1:-1].strip().lower()
        continue
    m = re.match(r'^name\s*=\s*"([^"]+)"', s)
    if not m:
        continue
    if section == "package":
        crate = m.group(1)
    elif section == "lib":
        lib = m.group(1)
    elif section == "bin":
        bin = m.group(1)

conf = json.load(open(conf_path, encoding="utf-8"))
product = conf.get("productName", "")
identifier = conf.get("identifier", "")
titles = [w.get("title") for w in conf.get("app", {}).get("windows", []) if w.get("title")]
title = titles[0] if titles else product

# binary: explicit [[bin]] name wins (matches productName/installer); fall back
# to the package name if no [[bin]] block.
binary = bin or crate or ""
lib_name = lib or re.sub(r"-", "_", binary)
# android package: dots stay, hyphens -> underscores (Tauri norm)
android_package = identifier.replace("-", "_") if identifier else ""

base = binary or "app"
apple_scheme = f"{base}_Apple"

ids = {
    "crate": crate,
    "libName": lib_name,
    "productName": product,
    "identifier": identifier,
    "windowTitle": title,
    "binary": binary,
    "appleScheme": apple_scheme,
    "androidPackage": android_package,
    "isTemplateDefault": bool(
        (crate == "Tauri-react-template" or crate == "tauri-react-template")
        and identifier and identifier == "com.tauri-react-template.app"
    ),
}

print(json.dumps(ids, indent=2, ensure_ascii=False))
PY