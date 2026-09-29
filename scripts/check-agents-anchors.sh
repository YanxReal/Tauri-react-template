#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# check-agents-anchors.sh — maintainability guard for `file:line` citations.
#
# AGENTS.md and the docs cite code locations like `lib.rs:572`; those anchors
# DRIFT when files grow (measured: the invariant table was ~100 lines off).
# This script resolves every shortname `file:line` against its real path and
# fails when:
#   1. the line is out of range, or
#   2. the nearest backticked symbol next to the citation is DEFINED in the
#      target file but not within ±10 lines of the cited line (drifted anchor).
#
# Scope: AGENTS.md + docs/{en,es} EXCLUDING the changelogs — history cites
# lines from old code on purpose. The filename map below must be updated
# when a cited shortname moves.
# Usage: scripts/check-agents-anchors.sh      (exit 1 on any failure)
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
    'window-controls.tsx': 'apps/web/src/components/layout/window-controls.tsx',
    'native-chrome.ts': 'apps/web/src/components/layout/native-chrome.ts',
    'lib.rs': 'src-tauri/src/lib.rs',
    'build.rs': 'src-tauri/build.rs',
    'tauri.conf.json': 'src-tauri/tauri.conf.json',
    'tauri.macos.conf.json': 'src-tauri/tauri.macos.conf.json',
    'tauri.windows.conf.json': 'src-tauri/tauri.windows.conf.json',
    'tauri.linux.conf.json': 'src-tauri/tauri.linux.conf.json',
    'tauri.android.conf.json': 'src-tauri/tauri.android.conf.json',
    'capabilities/default.json': 'src-tauri/capabilities/default.json',
    'capabilities/windows.json': 'src-tauri/capabilities/windows.json',
    'vite.config.ts': 'apps/web/vite.config.ts',
    'Cargo.toml': 'src-tauri/Cargo.toml',
}
CITE = re.compile(r'([A-Za-z0-9_./-]+\.(?:rs|css|ts|tsx|json|html|toml)):(\d+)')
TOKEN = re.compile(r'`([A-Za-z_][A-Za-z0-9_]{4,})`')
NEAR = 10

DEF_PATTERNS = {
    '.rs': r'\b(?:fn|const|struct|enum|type|static|mod)\s+{sym}\b',
    '.toml': r'(?m)^\s*{sym}\s*=',
    '.json': r'"{sym}"\s*:',
    '.ts': r'\b(?:function|const|class|let)\s+{sym}\b',
    '.tsx': r'\b(?:function|const|class|let)\s+{sym}\b',
}

def is_defined(sym, real, text):
    pattern = DEF_PATTERNS.get(pathlib.Path(real).suffix)
    if not pattern:
        return False
    return re.search(pattern.format(sym=re.escape(sym)), text) is not None

files = [root / 'AGENTS.md'] + sorted((root / 'docs/en').glob('*.md')) + sorted((root / 'docs/es').glob('*.md'))
files = [f for f in files if f.name != 'changelog.md']
bad = 0
for f in files:
    text = f.read_text(errors='ignore')
    for m in CITE.finditer(text):
        name, ln = m.group(1), int(m.group(2))
        real = MAP.get(name) or MAP.get(name.rsplit('/', 1)[-1])
        if not real:
            continue
        p = root / real
        if not p.exists():
            bad += 1
            print(f'  {f.name}: {name}:{ln} -> {real} MISSING FILE')
            continue
        lines = p.read_text(errors='ignore').splitlines()
        if ln > len(lines):
            bad += 1
            print(f'  {f.name}: {name}:{ln} -> {real} OUT OF RANGE ({len(lines)} lines)')
            continue
        # tokens must live on the SAME line as the citation (table rows
        # otherwise leak the neighbouring row's symbol)
        line_start = text.rfind('\n', 0, m.start()) + 1
        line_end = text.find('\n', m.end())
        line_end = len(text) if line_end == -1 else line_end
        after = text[m.end():min(line_end, m.end() + 60)]
        before = text[max(line_start, m.start() - 60):m.start()]
        sym = None
        am = TOKEN.search(after)
        if am:
            # the token is ours only if no other citation claims it
            # (between us and it, or right after it)
            if not CITE.search(after[:am.start()]) and not CITE.search(
                after[am.end():am.end() + 20]
            ):
                sym = am.group(1)
        if sym is None:
            bms = list(TOKEN.finditer(before))
            if bms:
                last = bms[-1]
                if not CITE.search(before[last.end():]) and not CITE.search(
                    before[max(0, last.start() - 20):last.start()]
                ):
                    sym = last.group(1)
        if sym is None:
            continue
        file_text = '\n'.join(lines)
        if not is_defined(sym, real, file_text):
            continue
        lo, hi = max(0, ln - 1 - NEAR), min(len(lines), ln + NEAR)
        if not any(sym in line for line in lines[lo:hi]):
            bad += 1
            print(f'  {f.name}: {name}:{ln} -> `{sym}` defined in {real} but not within ±{NEAR} lines')
print(f'anchors: {"OK" if bad == 0 else f"{bad} problem(s)"}')
sys.exit(1 if bad else 0)
PY
[ $? -ne 0 ] && ec=1

[ "$ec" -eq 0 ] && printf '\033[1;32m==>\033[0m AGENTS/docs anchors OK\n'
exit $ec
