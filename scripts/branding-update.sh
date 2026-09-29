#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# branding-update.sh — propagate every identity value from branding.json (repo
# root) to all consumers. SINGLE SOURCE OF TRUTH: edit branding.json, run this,
# and the name / version / identifier / binary / icons / bundle meta / authors
# / description are synced everywhere. Xcode + Android Studio icons/schemes
# are NOT managed here.
#
# Usage:
#   make rebrand      # or: scripts/branding-update.sh
#   scripts/branding-update.sh --dry-run   # show what would change, no write
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRAND="$ROOT/branding.json"
DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1

[[ -f "$BRAND" ]] || { echo "error: $BRAND not found" >&2; exit 1; }
command -v python3 >/dev/null || { echo "error: python3 required" >&2; exit 1; }

read_brand() {
  python3 -c "import json;d=json.load(open('$BRAND'));print(d$1)"
}
NAME="$(read_brand "['name']")"
VER="$(read_brand "['version']")"
DESC="$(read_brand "['description']")"
CRATE="$(read_brand "['rust']['crate']")"
LIB="$(read_brand "['rust']['lib']")"
BINARY="$(read_brand "['rust']['binary']")"
PRODUCT="$(read_brand "['tauri']['productName']")"
IDENTIFIER="$(read_brand "['tauri']['identifier']")"
WTITLE="$(read_brand "['tauri']['windowTitle']")"
CATEGORY="$(read_brand "['bundle']['category']")"
COPYRIGHT="$(read_brand "['bundle']['copyright']")"
STARTMENU="$(read_brand "['bundle']['startMenuFolder']")"
PUBLISHER="$(read_brand "['bundle']['publisher']")"
HOMEPAGE="$(read_brand "['bundle']['homepage']")"
ICONS_JSON="$(python3 -c "import json;d=json.load(open('$BRAND'))['icons']['set'];print(json.dumps(d))")"
AUTHORS_JSON="$(python3 -c "import json,shlex;d=json.load(open('$BRAND'))['authors'];print(json.dumps(d))")"
AUTHOR_FIRST="$(python3 -c "import json;d=json.load(open('$BRAND'))['authors'];print(d[0] if d else '')")"

# set_json_field FILE DOTPATH JSONLITERAL — set one nested JSON value, preserve rest.
# Supports dict keys and numeric list indices in the dot-path (e.g. app.windows.0.title).
set_json_field() {
  local f="$1" k="$2" v="$3"
  if [[ "$DRY" == "1" ]]; then
    echo "  [dry-run] set $k = $v in $f"
    return 0
  fi
  python3 - "$f" "$k" "$v" <<'PY'
import json, sys, pathlib
f, k, v = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(f, encoding="utf-8"))
parts = k.split(".")

def setpath(node, parts, val):
    head, rest = parts[0], parts[1:]
    if isinstance(node, list) and head.isdigit():
        idx = int(head)
        if not rest:
            node[idx] = val
        else:
            setpath(node[idx], rest, val)
    else:
        if not rest:
            node[head] = val
        else:
            child = node.get(head)
            if child is None:
                child = {}
                node[head] = child
            setpath(child, rest, val)

setpath(d, parts, json.loads(v))
pathlib.Path(f).write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"  set {k} = {v} in {f}")
PY
}

echo "==> rebrand from branding.json (name=$NAME, version=$VER)"
[[ "$DRY" == "1" ]] && echo "    DRY-RUN mode — no files modified."

set_json_field "$ROOT/src-tauri/tauri.conf.json" "productName" "\"$PRODUCT\""
set_json_field "$ROOT/src-tauri/tauri.conf.json" "version" "\"$VER\""
set_json_field "$ROOT/src-tauri/tauri.conf.json" "identifier" "\"$IDENTIFIER\""
set_json_field "$ROOT/src-tauri/tauri.conf.json" "app.windows.0.title" "\"$WTITLE\""
set_json_field "$ROOT/src-tauri/tauri.conf.json" "bundle.category" "\"$CATEGORY\""
set_json_field "$ROOT/src-tauri/tauri.conf.json" "bundle.copyright" "\"$COPYRIGHT\""
set_json_field "$ROOT/src-tauri/tauri.conf.json" "bundle.icon" "$ICONS_JSON"

for os in macos windows linux; do
  set_json_field "$ROOT/src-tauri/tauri.$os.conf.json" "app.windows.0.title" "\"$WTITLE\""
done
set_json_field "$ROOT/src-tauri/tauri.windows.conf.json" "bundle.publisher" "\"$PUBLISHER\""
set_json_field "$ROOT/src-tauri/tauri.windows.conf.json" "bundle.homepage" "\"$HOMEPAGE\""
set_json_field "$ROOT/src-tauri/tauri.windows.conf.json" "bundle.copyright" "\"$COPYRIGHT\""
set_json_field "$ROOT/src-tauri/tauri.windows.conf.json" "bundle.category" "\"$CATEGORY\""
set_json_field "$ROOT/src-tauri/tauri.windows.conf.json" "bundle.windows.nsis.startMenuFolder" "\"$STARTMENU\""

# package.json: npm name must be lowercase; keep it as the brand lowercased.
NPM_NAME="$(echo "$NAME" | tr '[:upper:]' '[:lower:]')"
set_json_field "$ROOT/package.json" "name" "\"$NPM_NAME\""
set_json_field "$ROOT/package.json" "version" "\"$VER\""
set_json_field "$ROOT/package.json" "description" "\"$DESC\""
if [[ -n "$AUTHOR_FIRST" ]]; then
  set_json_field "$ROOT/package.json" "author" "\"$AUTHOR_FIRST\""
fi

# Cargo.toml: package name, version, description, authors, [[bin]] name, [lib] name.
if [[ "$DRY" == "1" ]]; then
  echo "  [dry-run] would update Cargo.toml [package]/[[bin]]/[lib] + version + description + authors"
else
  python3 - "$ROOT/src-tauri/Cargo.toml" "$CRATE" "$VER" "$LIB" "$BINARY" "$DESC" "$AUTHORS_JSON" <<'PY'
import re, sys, pathlib, json
f, crate, ver, lib, binary, desc, authors_json = sys.argv[1:8]
p = pathlib.Path(f); s = p.read_text(encoding="utf-8")

def set_block(regex, value):
    global s
    s = re.sub(r'(?ms)^(' + regex + r'\s*\n\s*name\s*=\s*")[^"]+(")',
               lambda m: m.group(1) + value + m.group(2), s, count=1)

set_block(r'\[package\]', crate)
set_block(r'\[\[bin\]\]', binary)
set_block(r'\[lib\]', lib)
s = re.sub(r'(?m)^\s*version\s*=\s*"[^"]+"', f'version = "{ver}"', s, count=1)
s = re.sub(r'(?m)^\s*description\s*=\s*"[^"]*"', f'description = "{desc}"', s, count=1)
authors = json.loads(authors_json)
if authors:
    toml_authors = '[' + ', '.join('"' + a.replace('"', r'\"') + '"' for a in authors) + ']'
    s = re.sub(r'(?m)^\s*authors\s*=\s*\[[^\]]*\]', f'authors = {toml_authors}', s, count=1)
p.write_text(s, encoding="utf-8")
print("  updated Cargo.toml [package]/[[bin]]/[lib] names + version + description + authors")
PY
fi

# src/main.rs: lib call identifier.
if [[ "$DRY" == "1" ]]; then
  echo "  [dry-run] would update src/main.rs lib call to $LIB"
else
  sed -i '' "s/^    [A-Za-z_][A-Za-z_0-9]*_lib::run()/    ${LIB}::run()/" \
    "$ROOT/src-tauri/src/main.rs"
  grep -q "${LIB}::run()" "$ROOT/src-tauri/src/main.rs" || {
    echo "warning: lib call not confirmed in main.rs" >&2; }
fi

# Linux builds: the `linux-build` skill's script derives APP_NAME from
# Cargo.toml [package] at runtime, so the box binary/pkill patterns follow
# the rebrand automatically via the Cargo.toml update above. Nothing to patch
# here (scripts/build-linux.sh was absorbed into the skill).

# --- Mobile (Xcode / Android) -------------------------------------------------
# The mobile app NAME and identifier are resolved by the vendored CLI at
# `tauri ios|android init` time (the `gen/` tree is gitignored autogen). So a
# branding change cannot rewrite `gen/apple` / `gen/android` in place — they
# must be REGENERATED from the template. Xcode + Android icons and schemes are
# NOT managed here by design. We detect whether the project has mobile targets
# and warn with the exact regeneration command.
have_apple=false; have_android=false
[[ -d "$ROOT/src-tauri/gen/apple" ]] && have_apple=true
[[ -d "$ROOT/src-tauri/gen/android" ]] && have_android=true

if $have_apple || $have_android; then
  echo ""
  echo "==> mobile targets detected (gen/ present). The app name/identifier in"
  echo "    Xcode (iOS/macOS) and Android are resolved at CLI init time, not in"
  echo "    place by rebrand. To apply the new branding there, REGENERATE:"
  echo ""
  $have_apple && echo "    iOS/macOS:  cargo tauri ios init   (vendored CLI — make install-tauri-cli first)"
  $have_android && echo "    Android:    cargo tauri android init"
  echo ""
  echo "    Iconos de Xcode/Android usan los suyos propios (Assets/ic_launcher):"
  echo "    no se tocan desde branding.json. Ver README/docs si falta."
fi

echo "==> done. Run the gates (pnpm typecheck/test/build; cargo check/clippy) to verify."