#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# install-skills.sh — install the repo's Agent Skills into the tools that read
# them (Claude Code, OpenAI Codex, OpenCode), either for this project or globally.
#
# Skills live in the source-of-truth folder `<repo>/.claude/skills`, the
# Anthropic "Agent Skills" format. That one format is read natively by BOTH
# Claude Code and OpenAI Codex (both consume `.claude/skills` natively), and
# OpenCode loads it too as a compatibility source. So a single copy works in
# all three tools.
#
# Default: install into the CURRENT project (this repo already carries the
# folder, so this is mostly a no-op / self-check). Use --global to install for
# the current user across all their projects.
#
# Usage:
#   scripts/install-skills.sh                # install into this project (self-check)
#   scripts/install-skills.sh --global       # install into ~/.claude/skills + ~/.config/opencode/skills
#   scripts/install-skills.sh --dest DIR     # custom destination (copies <repo>/.claude/skills into DIR)
#   scripts/install-skills.sh --list         # show which skills are installed where
#   scripts/install-skills.sh --verify       # content-aware: hash-compare EVERY file
#                                             # of every skill vs the source (MISSING/STALE/EXTRA)
#   scripts/install-skills.sh --dry-run      # show what would be copied, change nothing
#
# Platforms:
#   macOS / Linux  run the .sh directly (needs bash).
#   Windows        run `scripts\install-skills.cmd` from cmd/PowerShell, or
#                  run the .sh from a Git Bash / MSYS2 / Cygwin terminal.
# ---------------------------------------------------------------------------
set -euo pipefail

# --- Platform detection ------------------------------------------------------
# This is a bash script. On Windows it must run under a bash environment
# (Git Bash / MSYS2 / Cygwin — all shipped with Git for Windows). We detect
# those so we can (a) tell the user and (b) keep $HOME resolution correct
# (Git Bash maps $HOME to the Windows user profile, which is exactly where
# Claude Code / Codex / OpenCode read skills on Windows).
OST="$(uname -s 2>/dev/null || echo unknown)"
case "$OST" in
  MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=1 ;;
  *) IS_WINDOWS=0 ;;
esac
if [[ "$IS_WINDOWS" == "1" ]]; then
  # Bash detected under MSYS/Git Bash on Windows: paths via $HOME are correct,
  # but chmod has no real effect here — just informational.
  :
fi

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SELF/.." && pwd)"
SRC="$REPO/.claude/skills"
# Windows note: in Git Bash, $HOME already maps to the Windows user profile
# (C:\Users\<user>), which is exactly where Claude Code / Codex / OpenCode
# read skills on Windows — so the same paths below are correct on all OSes.
CLAUDE_GLOBAL="$HOME/.claude/skills"
OPENCODE_GLOBAL="$HOME/.config/opencode/skills"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

MODE="project"   # project | global | dest
DEST=""
DRY=0
LIST=0
VERIFY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)      MODE="global" ;;
    --dest)        MODE="dest"; DEST="${2:?--dest needs a value}"; shift ;;
    --list)        LIST=1 ;;
    --verify)      VERIFY=1 ;;
    --dry-run)     DRY=1 ;;
    -h|--help)     sed -n '2,/^set -euo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d'; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

[[ -d "$SRC" ]] || die "skills source not found: $SRC"

# --------------------------------------------------------- collect skills ---
# Every entry must be a directory containing SKILL.md (Agent Skills format).
# Directories without a SKILL.md are not skills and are skipped with a warning.
skills=()
for d in "$SRC"/*/; do
  [[ -d "$d" ]] || continue
  if [[ -f "$d/SKILL.md" ]]; then
    skills+=("$d")
  else
    warn "skipping $d (no SKILL.md)"
  fi
done

if [[ ${#skills[@]} -eq 0 ]]; then
  die "no skills (dirs with SKILL.md) found under $SRC"
fi

# ------------------------------------------------------- list mode ----------
if [[ "$LIST" == "1" ]]; then
  echo "Skills in $SRC (${#skills[@]}):"
  for d in "${skills[@]}"; do
    name="$(basename "$d")"
    extra="$(find "$d" -mindepth 1 -not -name SKILL.md -type d 2>/dev/null | wc -l | tr -d ' ')"
    echo "  - $name (SKILL.md${extra:+ + $extra ref/script dirs})"
  done
  echo "Discovery targets:"
  [[ -d "$CLAUDE_GLOBAL" ]] && echo "  ✓ ~/.claude/skills        (Claude Code/Codex global — native Agent Skills)"
  [[ -d "$OPENCODE_GLOBAL" ]] && echo "  ✓ ~/.config/opencode/skills (OpenCode global)"
  echo "  ✓ project: $REPO/.claude/skills (this repo — always present)"
  exit 0
fi

# ----------------------------------------------------- resolve destinations --
DESTS=()
case "$MODE" in
  global) DESTS=("$CLAUDE_GLOBAL" "$OPENCODE_GLOBAL") ;;
  dest)   DESTS=("$DEST") ;;
  project) DESTS=("$SRC") ;;   # already where it should be; self-check
esac

# ---------------------------------------------------- verify mode (read-only) --
# Content-aware: every file of every skill must exist AND match the source
# hash (not just SKILL.md presence). Reported: MISSING / STALE / EXTRA.
file_hash() { # portable md5: macOS `md5 -q`, Linux/Git Bash `md5sum`
  if command -v md5 >/dev/null 2>&1; then md5 -q "$1" 2>/dev/null
  else md5sum "$1" 2>/dev/null | cut -d' ' -f1; fi
}

skill_dir_mismatches() {
  local src="$1" dest="$2" name bad=0
  src="${src%/}"   # the discovery glob adds a trailing slash; normalize
  name="$(basename "$src")"
  local destdir="$dest/$name"
  if [[ ! -d "$destdir" ]]; then
    log "verify: $name — MISSING en $dest"
    return 1
  fi
  local rel
  while IFS= read -r f; do
    rel="${f#"$src"/}"
    if [[ ! -e "$destdir/$rel" ]]; then
      bad=1
      log "verify: $name/$rel — MISSING en $dest"
    elif [[ "$(file_hash "$f")" != "$(file_hash "$destdir/$rel")" ]]; then
      bad=1
      log "verify: $name/$rel — STALE (diffiere del source; re-run install)"
    fi
  done < <(find "$src" -type f | sort)
  while IFS= read -r f; do
    rel="${f#"$destdir"/}"
    if [[ ! -e "$src/$rel" ]]; then
      log "verify: $name/$rel — EXTRA en $dest (ya no está en el source)"
    fi
  done < <(find "$destdir" -type f 2>/dev/null | sort)
  [[ "$bad" == "0" ]] && log "verify: $name — ✓ sincronizada"
  return $bad
}

verify_dest() {
  local dest="$1" ec=0
  [[ -d "$dest" ]] || { log "verify: $dest — MISSING ($(basename "$dest") no instaladas)"; return 1; }
  for d in "${skills[@]}"; do
    skill_dir_mismatches "$d" "$dest" || ec=1
  done
  [[ "$ec" == "0" ]] && log "verify: ${#skills[@]} skills sincronizadas en $dest ✓"
  return $ec
}

if [[ "$VERIFY" == "1" ]]; then
  ec=0
  case "$MODE" in
    global) verify_dest "$CLAUDE_GLOBAL" || ec=1; verify_dest "$OPENCODE_GLOBAL" || ec=1 ;;
    dest)   verify_dest "$DEST" || ec=1 ;;
    project) verify_dest "$SRC" || ec=1 ;;
  esac
  exit $ec
fi

# -------------------------------------------------------------- copy ---------
total=0
for dest in "${DESTS[@]}"; do
  [[ -n "$dest" ]] || continue
  mkdir -p "$dest"
  for d in "${skills[@]}"; do
    name="$(basename "$d")"
    target="$dest/$name"
    # Project self-check: installing into the source dir itself is a no-op
    # (the folder already lives here and is the source of truth).
    if [[ "$(cd "$dest" && pwd)" == "$(cd "$SRC" && pwd)" ]]; then
      [[ "$DRY" == "1" ]] || log "project skill already present: $name (source is the project)"
      continue
    fi
    if [[ "$DRY" == "1" ]]; then
      log "dry-run: would copy $d → $target"
      continue
    fi
    rm -rf "$target"
    cp -R "$d" "$target"
    # keep helper scripts executable (Codex runs <skill>/scripts/*)
    find "$target" -name '*.sh' -exec chmod +x {} +
    log "installed $name → $target"
    total=$((total+1))
  done
done

[[ "$DRY" == "1" ]] && { log "dry-run complete (${#skills[@]} skills, nothing changed)"; exit 0; }
[[ "$total" -gt 0 ]] && log "installed $total skill dir(s) (${#skills[@]} total)."
log "done. Reload the skill in your tool if it was already open."