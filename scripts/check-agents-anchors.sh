#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# check-agents-anchors.sh — maintainability guard for `file:line` citations.
#
# AGENTS.md and the docs cite code locations like `lib.rs:572`; those anchors
# DRIFT when files grow (measured: the invariant table was ~100 lines off).
# This script resolves every shortname `file:line` against its real path and
# fails when the line is out of range.
#
# Scope: AGENTS.md + docs/{en,es} EXCLUDING the changelogs — history cites
# lines from old code on purpose. The filename map below must be updated
# when a cited shortname moves.
# Usage: scripts/check-agents-anchors.sh      (exit 1 on any out-of-range ref)
# ---------------------------------------------------------------------------
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ec=0

python3 - "$ROOT" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
MAP = {
    'App.tsx': 'apps/web/src/App.tsx',
    'main.tsx': 'apps/web/src/main.tsx',
    'config.ts': 'apps/web/src/i18n/config.ts',
    'index.html': 'apps/web/index.html',
    'globals.css': 'packages/ui/src/styles/globals.css',
    'header.tsx': 'apps/web/src/components/layout/header.tsx',
    'lib.rs': 'src-tauri/src/lib.rs',
    'tauri.conf.json': 'src-tauri/tauri.conf.json',
    'tauri.macos.conf.json': 'src-tauri/tauri.macos.conf.json',
    'tauri.windows.conf.json': 'src-tauri/tauri.windows.conf.json',
    'tauri.linux.conf.json': 'src-tauri/tauri.linux.conf.json',
    'vite.config.ts': 'apps/web/vite.config.ts',
    'Cargo.toml': 'src-tauri/Cargo.toml',
}
files = [root / 'AGENTS.md'] + sorted((root / 'docs/en').glob('*.md')) + sorted((root / 'docs/es').glob('*.md'))
files = [f for f in files if f.name != 'changelog.md']
bad = 0
for f in files:
    for name, ln in set(re.findall(r'([A-Za-z0-9_-]+\.(?:rs|css|ts|tsx|json|html|toml)):(\d+)', f.read_text(errors='ignore'))):
        real = MAP.get(name)
        if not real:
            continue
        p = root / real
        total = len(p.read_text(errors='ignore').splitlines())
        if int(ln) > total:
            bad += 1
            print(f'  {f.name}: {name}:{ln} -> {real} FUERA DE RANGO ({total} líneas)')
print(f'anchors: {"OK" if bad == 0 else f"{bad} fuera de rango"}')
sys.exit(1 if bad else 0)
PY
[ $? -ne 0 ] && ec=1

[ "$ec" -eq 0 ] && printf '\033[1;32m==>\033[0m AGENTS/docs anchors OK\n'
exit $ec