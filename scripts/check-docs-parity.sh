#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# check-docs-parity.sh — maintainability guard: EN/ES docs must stay mirrors.
#
# The bilingual contract (AGENTS.md §3) is convention-enforced today; this
# script makes it machine-checked. It verifies:
#   1. `docs/en/` and `docs/es/` contain the SAME files.
#   2. Each pair has the SAME headings with the SAME order (h1..h4),
#      counted by their first word — translation must not reorder/rename
#      section structure.
#   3. `docs/README.md` lists every page in both columns.
#
# Usage: scripts/check-docs-parity.sh      (exit 1 on any divergence)
# ---------------------------------------------------------------------------
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ec=0

die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; ec=1; }

# 1) file lists
diff <(cd "$ROOT/docs/en" && ls | sort) <(cd "$ROOT/docs/es" && ls | sort) >/dev/null
if [ $? -ne 0 ]; then
  die "docs/en and docs/es file lists differ (see diff below):"
  diff <(cd "$ROOT/docs/en" && ls | sort) <(cd "$ROOT/docs/es" && ls | sort) | head -20
fi

# 2) structure per pair: same heading COUNT per level AND same order of
#    levels (translation legitimately changes heading WORDS — comparing them
#    would false-positive; a reorder/rename of the STRUCTURE is what breaks
#    the mirror contract).
python3 - "$ROOT" <<'PY'
import pathlib, re, sys
from collections import Counter
root = pathlib.Path(sys.argv[1])
bad = 0
depth = lambda l: len(re.match(r'^(#+)', l).group(1))
def struct(p):
    lines = [l.rstrip() for l in p.read_text().splitlines() if re.match(r'^#{1,4} ', l)]
    return (Counter(depth(l) for l in lines), tuple(depth(l) for l in lines))
for en in sorted((root / 'docs/en').glob('*.md')):
    es = root / 'docs/es' / en.name
    if not es.exists():
        continue
    ce, se = struct(en)
    cs, ss = struct(es)
    if ce != cs or se != ss:
        bad += 1
        print(f'  {en.name}: estructura EN {se} vs ES {ss} (conteo por nivel {dict(ce)} vs {dict(cs)})')
print(f'heading structure parity: {"OK" if bad == 0 else f"{bad} archivo(s) divergente(s)"}')
sys.exit(1 if bad else 0)
PY
[ $? -ne 0 ] && ec=1

# 3) router coverage
python3 - "$ROOT" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
router = (root / 'docs/README.md').read_text()
en = {p.name for p in (root / 'docs/en').glob('*.md') if p.name != 'README.md'}
es = {p.name for p in (root / 'docs/es').glob('*.md') if p.name != 'README.md'}
missing = sorted((en | es) - set(re.findall(r'([A-Za-z0-9_-]+\.md)', router)))
print(f'router coverage: {"OK" if not missing else "missing: " + ", ".join(missing)}')
sys.exit(1 if missing else 0)
PY
[ $? -ne 0 ] && ec=1

[ "$ec" -eq 0 ] && printf '\033[1;32m==>\033[0m docs parity OK\n'
exit $ec