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
#   scripts/install-skills.sh --dry-run      # show what would be copied, change nothing
# ---------------------------------------------------------------------------
set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SELF/.." && pwd)"
SRC="$REPO/.claude/skills"
CLAUDE_GLOBAL="$HOME/.claude/skills"
OPENCODE_GLOBAL="$HOME/.config/opencode/skills"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

MODE="project"   # project | global | dest
DEST=""
DRY=0
LIST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)      MODE="global" ;;
    --dest)        MODE="dest"; DEST="${2:?--dest needs a value}"; shift ;;
    --list)        LIST=1 ;;
    --dry-run)     DRY=1 ;;
    -h|--help)     sed -n '2,/^set -euo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d'; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

[[ -d "$SRC" ]] || die "skills source not found: $SRC"

# ------------------------------------------------------- list mode ----------
if [[ "$LIST" == "1" ]]; then
  echo "Skills in $SRC:"
  for d in "$SRC"/*/; do
    [[ -d "$d" ]] && echo "  - $(basename "$d") ($(basename "$d")/SKILL.md)"
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

# -------------------------------------------------------------- copy ---------
for dest in "${DESTS[@]}"; do
  [[ -n "$dest" ]] || continue
  mkdir -p "$dest"
  # Copy the ENTIRE .claude/skills tree (each skill is a folder with SKILL.md).
  for d in "$SRC"/*/; do
    [[ -d "$d" ]] || continue
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
  done
done

[[ "$DRY" == "1" ]] && { log "dry-run complete (nothing changed)"; exit 0; }
log "done. Reload the skill in your tool if it was already open."