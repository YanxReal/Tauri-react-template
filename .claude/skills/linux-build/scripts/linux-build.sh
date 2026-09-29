#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# linux-build.sh — compile (and optionally run + verify) the Tauri app for
# Linux over SSH to the Ubuntu-arm-docker dev box.
#
# SSH-ONLY by design. The box runs inside Docker on the host (macOS/Windows
# cannot run webkit2gtk + the Linux bundlers locally), but THIS script never
# manages containers and never clones the repo into the box: it rsyncs the
# sources (without .git) so node_modules/ and target/ stay cached on the box
# and rebuilds take seconds. The box repo is only referenced for its make
# targets (make install / make up / make status) when it is not running.
#
#   --remote [HOST]  SSH build box. Default: $LINUX_BUILD_REMOTE or `ubuntu-arm`
#                    (Ubuntu-arm-docker: https://github.com/YanxReal/Ubuntu-arm-docker,
#                    Ubuntu 26.04 + Cinnamon 6.4 on X11/Xvfb, user `admin`).
#                    Default dir: $LINUX_BUILD_DIR or
#                    `/workspace/Tauri-react-template` (the repo checkout; the
#                    binary name follows src-tauri/Cargo.toml [package] name).
#   --release        optimised, LTO, bundled                     (default)
#   --debug          no LTO, much faster; no bundle (--no-bundle)
#                    unless --bundles is given explicitly
#   --dev            `tauri dev` (Vite + app, hot reload); implies --debug
#   --run            after building, launch the app in the box's GUI session.
#                    Uses the box `dev` wrapper when present (injects
#                    DISPLAY=:1 + XAUTHORITY + DBUS_SESSION_BUS_ADDRESS);
#                    falls back to a plain DISPLAY launch. For DEBUG builds
#                    Vite is auto-started on the box (the binary loads
#                    devUrl :1420).
#   --verify         after --run: in the box run `assistant windows` (window
#                    list), `assistant shot` (PNG) and `assistant ocr` (text)
#                    over the launched app, then fetch the PNG to
#                    ./dist-linux/linux-verify.png. Real X11 capture/input —
#                    the CI-less visual gate for the Linux bundle.
#   --bundles LIST   deb | appimage | rpm | all        (release default: deb)
#   --target ARCH    aarch64 | x86_64 | <rust triple>; must match the box
#   --fetch          copy the built bundles back to ./dist-linux
#   --sync-only      only push the sources over SSH, do not build
#   --no-sync        build what is already on the remote
#   --logs           follow the remote dev/app log
#   --stop           kill the running app / dev server
#   -h, --help       this text
#
# Examples
#   ./linux-build.sh --remote --debug --run --verify    # daily fast loop
#   ./linux-build.sh --remote --release --fetch         # .deb bundle
#   ./linux-build.sh --remote --release --bundles all --fetch
#   ./linux-build.sh --remote --dev                     # hot reload (Vite)
#   ./linux-build.sh --remote --sync-only               # just push sources
#
# Platforms: macOS runs the .sh directly (needs bash + ssh + rsync|tar).
# Windows runs it from a Git Bash terminal (OpenSSH ships with Git for
# Windows; rsync optional — the script falls back to tar).
# ---------------------------------------------------------------------------
set -euo pipefail

# --- Platform detection (informational only: the build ALWAYS goes remote) --
OST="$(uname -s 2>/dev/null || echo unknown)"
IS_WINDOWS=0
case "$OST" in
  MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=1 ;;
esac

# This script lives at <repo>/.claude/skills/linux-build/scripts/ → 4 levels up.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
# Binary name = Cargo package name (rename-proof: follows branding.json
# propagation, so the box target dir + bundles + pkill patterns always match).
APP_NAME="$(grep -m1 '^name *=' "$ROOT/src-tauri/Cargo.toml" 2>/dev/null | sed -E 's/^name *= *"([^"]+)".*/\1/')"
[[ -n "$APP_NAME" ]] || APP_NAME="Tauri-react-template"

REMOTE_HOST="${LINUX_BUILD_REMOTE:-ubuntu-arm}"
REMOTE_DIR="${LINUX_BUILD_DIR:-/workspace/Tauri-react-template}"
BUNDLES="deb"
BUNDLES_SET=0
TARGET=""
PROFILE="release"
DEV=0
RUN=0
VERIFY=0
FETCH=0
SYNC_ONLY=0
NO_SYNC=0
LOGS=0
STOP=0
DISPLAY_NUM="${LINUX_BUILD_DISPLAY:-:1}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '3,/^set -euo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d'; }

# ---------------------------------------------------------------- arguments -
while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)
      if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then REMOTE_HOST="$2"; shift; fi ;;
    --docker)    die "--docker was removed: this skill builds over SSH only. Use --remote [HOST]." ;;
    --release)   PROFILE="release" ;;
    --debug)     PROFILE="debug" ;;
    --dev)       DEV=1; PROFILE="debug" ;;
    --run)       RUN=1 ;;
    --verify)    VERIFY=1; RUN=1 ;;
    --fetch)     FETCH=1 ;;
    --sync-only) SYNC_ONLY=1 ;;
    --no-sync)   NO_SYNC=1 ;;
    --logs)      LOGS=1 ;;
    --stop)      STOP=1 ;;
    --bundles)   BUNDLES="${2:?--bundles needs a value}"; BUNDLES_SET=1; shift ;;
    --target)    TARGET="${2:?--target needs a value}"; shift ;;
    --display)   DISPLAY_NUM="${2:?--display needs a value}"; shift ;;
    -h|--help)   usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

# ARCH shorthand -> rust triple
case "$TARGET" in
  "")                TRIPLE="" ;;
  aarch64|arm64)     TRIPLE="aarch64-unknown-linux-gnu" ;;
  x86_64|amd64)      TRIPLE="x86_64-unknown-linux-gnu" ;;
  *)                 TRIPLE="$TARGET" ;;
esac

# Build flags: release bundles by default; debug skips bundling for speed
# unless the user asked for bundles explicitly.
if [[ "$BUNDLES_SET" == "1" ]]; then
  BUILD_FLAGS="--bundles $BUNDLES"
elif [[ "$PROFILE" == "debug" ]]; then
  BUILD_FLAGS="--no-bundle"
else
  BUILD_FLAGS="--bundles $BUNDLES"
fi
[[ "$PROFILE" == "debug" ]] && BUILD_FLAGS="$BUILD_FLAGS --debug"
[[ -n "$TRIPLE" ]] && BUILD_FLAGS="$BUILD_FLAGS --target $TRIPLE"

# --------------------------------------------------------------- SSH setup --
ssh_probe() {
  ssh -o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=accept-new \
      "$REMOTE_HOST" true >/dev/null 2>&1
}
if ! ssh_probe; then
  die "SSH build box '$REMOTE_HOST' is unreachable.
     It runs inside Docker on this host (see the box repo's README):
       cd <Ubuntu-arm-docker checkout> && make install   # or: make up
     Then re-run, or point at another box:
       $0 --remote <host>              # e.g. --remote ubuntu-arm
       LINUX_BUILD_REMOTE=<host> $0    # or set the default once"
fi

# Box toolchain lives outside PATH for non-interactive SSH (rustup shim at
# /usr/local/cargo/bin, node/pnpm at /usr/local/bin), so every remote cargo
# invocation needs this prefix. Verified against Ubuntu-arm-docker 2026-09.
REMOTE_ENV='export CARGO_HOME=/usr/local/cargo RUSTUP_HOME=/usr/local/rustup PATH=/usr/local/cargo/bin:$PATH'
remote_ssh() { ssh -o StrictHostKeyChecking=accept-new "$REMOTE_HOST" "$@"; }
# Detached variant: `-f` forks after auth, so the caller never blocks waiting
# for the remote channel to close while a background process holds it.
remote_ssh_bg() { ssh -f -o StrictHostKeyChecking=accept-new "$REMOTE_HOST" "$@"; }

# No clone on the box: rsync the sources only (no .git — the box is a build
# target, not a repo). node_modules/ + target/ stay cached remotely, so these
# excludes never delete anything the box needs; rebuilds are incremental.
RSYNC_EXCLUDES=(
  --exclude .git --exclude node_modules --exclude target --exclude dist
  --exclude .turbo --exclude src-tauri/gen --exclude '*.log'
  --exclude dist-linux
)

target_dir() { # relative cargo output dir for the chosen profile/triple
  local d="src-tauri/target"
  [[ -n "$TRIPLE" ]] && d="$d/$TRIPLE"
  d="$d/$PROFILE"
  echo "$d"
}

# ================================================================ remote ====
sync_sources() {
  remote_ssh "mkdir -p '$REMOTE_DIR'"
  if command -v rsync >/dev/null 2>&1 && remote_ssh 'command -v rsync >/dev/null 2>&1'; then
    log "rsync (incremental, no .git) $ROOT/ -> $REMOTE_HOST:$REMOTE_DIR/"
    rsync -az --delete "${RSYNC_EXCLUDES[@]}" \
      -e "ssh -o StrictHostKeyChecking=accept-new" \
      "$ROOT/" "$REMOTE_HOST:$REMOTE_DIR/"
  else
    warn "rsync missing on one end — falling back to tar (no stale-file cleanup)"
    tar -C "$ROOT" \
      --exclude=./.git --exclude=./node_modules --exclude=./src-tauri/target \
      --exclude=./dist --exclude=./.turbo --exclude=./src-tauri/gen \
      --exclude=./dist-linux --exclude='*.log' \
      -czf - . | remote_ssh "tar -xzf - -C '$REMOTE_DIR'"
  fi
}

remote_stop() {
  log "stopping app / dev server on $REMOTE_HOST"
  # Bracket trick + precise patterns: the pattern must not match the pkill
  # command's own cmdline (it would kill its own shell), and matching the
  # bare app name would also hit any shell whose cmdline contains the
  # checkout dir. `vite` needs two forms: the node bin and the shim.
  local apppat="[${APP_NAME:0:1}]${APP_NAME:1}"
  remote_ssh "for p in '[t]auri.js dev' '[p]npm tauri dev' '[v]ite.js' '[v]ite --port' \
                     'target/[d]ebug/$APP_NAME' 'target/[r]elease/$APP_NAME' '$apppat'; do \
                pkill -f \"\$p\" >/dev/null 2>&1 || true; \
              done; echo stopped"
}

remote_logs() {
  remote_ssh "tail -n 60 -f /tmp/tauri-dev.log /tmp/$APP_NAME.log 2>/dev/null"
}

remote_launch_binary() {
  local bin; bin="$(target_dir)/$APP_NAME"
  log "launching $bin (remote, GUI session)"
  remote_ssh "pkill -f '[${APP_NAME:0:1}]${APP_NAME:1}' >/dev/null 2>&1 || true"
  # A debug binary loads the dev server (devUrl :1420) — start Vite on the
  # box when it is not already answering, so the window actually paints.
  if [[ "$PROFILE" == "debug" ]]; then
    ensure_vite
  fi
  if remote_ssh 'command -v dev >/dev/null 2>&1'; then
    # Box session wrapper: injects DISPLAY=:1 + XAUTHORITY + DBUS_SESSION_BUS.
    # A plain DISPLAY launch shows nothing without it. Works on any box that
    # ships such a wrapper (X11 or Wayland). Compositing stays ENABLED — the
    # box turns it on for live window drag.
    # NOTE: the binary path must be ABSOLUTE — `dev` execs the args verbatim
    # from the SSH login cwd (/home/admin), a relative path would not resolve.
    remote_ssh_bg "cd '$REMOTE_DIR' && exec setsid dev '$REMOTE_DIR/$bin' \
      >/tmp/$APP_NAME.log 2>&1 </dev/null"
  else
    # Plain X11 box: classic DISPLAY launch.
    remote_ssh_bg "cd '$REMOTE_DIR' && $REMOTE_ENV && export DISPLAY='$DISPLAY_NUM' && \
      exec setsid '$bin' >/tmp/$APP_NAME.log 2>&1 </dev/null"
  fi
  log "launched — follow with: $0 --remote --logs"
}

ensure_vite() {
  # `devUrl` is http://localhost:1420 for debug builds (vite.config.ts has
  # host:true — the Vite box listener is reachable from inside the box).
  if remote_ssh 'curl -sf http://localhost:1420 >/dev/null 2>&1'; then
    return 0
  fi
  log "starting Vite on the box (debug binary needs :1420)"
  remote_ssh_bg "cd '$REMOTE_DIR' && exec setsid pnpm --filter web dev \
    >/tmp/vite-linux.log 2>&1 </dev/null"
  local i
  for i in $(seq 1 30); do
    remote_ssh 'curl -sf http://localhost:1420 >/dev/null 2>&1' && return 0
    sleep 2
  done
  warn "Vite did not answer on :1420 — the debug window may stay blank (see /tmp/vite-linux.log)"
}

remote_dev() {
  log "pnpm tauri dev (remote, detached, GUI session)"
  remote_stop >/dev/null
  if remote_ssh 'command -v dev >/dev/null 2>&1'; then
    remote_ssh_bg "cd '$REMOTE_DIR' && exec setsid dev pnpm tauri dev \
      >/tmp/tauri-dev.log 2>&1 </dev/null"
  else
    remote_ssh_bg "cd '$REMOTE_DIR' && $REMOTE_ENV && export DISPLAY='$DISPLAY_NUM' && \
      exec setsid pnpm tauri dev >/tmp/tauri-dev.log 2>&1 </dev/null"
  fi
  log "started — follow with: $0 --remote --logs"
}

remote_verify() {
  log "verifying on the box: assistant windows + shot + ocr"
  # The window can take a few seconds to map under llvmpipe — poll up to 3x.
  remote_ssh "
    if command -v assistant >/dev/null 2>&1; then
      try=1
      while [ \$try -le 3 ]; do
        sleep 5
        W=\$(assistant windows 2>/dev/null | grep -v 'mutter guard\|Desktop\|cinnamon' || true)
        [ -n \"\$W\" ] && break
        try=\$((try+1))
      done
      echo '--- assistant windows ---'; echo \"\$W\" | head -8
      echo '--- assistant shot ---'; assistant shot /workspace/ai/linux-verify.png || true
      echo '--- assistant ocr ---'; assistant ocr /workspace/ai/linux-verify.png 2>/dev/null | head -30 || true
    else echo 'assistant CLI missing on box'; fi"
  # Bring the shot home so a human (or the agent) can eyeball/pixel-scan it.
  mkdir -p "$ROOT/dist-linux"
  if command -v rsync >/dev/null 2>&1 && remote_ssh 'command -v rsync >/dev/null 2>&1'; then
    rsync -az -e "ssh -o StrictHostKeyChecking=accept-new" \
      "$REMOTE_HOST:/workspace/ai/linux-verify.png" "$ROOT/dist-linux/" 2>/dev/null || true
  else
    remote_ssh "cat /workspace/ai/linux-verify.png 2>/dev/null" > "$ROOT/dist-linux/linux-verify.png" 2>/dev/null || true
  fi
  [[ -s "$ROOT/dist-linux/linux-verify.png" ]] \
    && log "verify shot: $ROOT/dist-linux/linux-verify.png" \
    || warn "verify shot unavailable (assistant missing or capture failed)"
}

fetch_bundles() {
  if [[ "$PROFILE" == "debug" && "$BUNDLES_SET" == "0" ]]; then
    warn "debug build has no bundle — pass --bundles to bundle it"
    return
  fi
  local d; d="$(target_dir)/bundle"
  log "fetching bundles -> $ROOT/dist-linux/"
  mkdir -p "$ROOT/dist-linux"
  if command -v rsync >/dev/null 2>&1 && remote_ssh 'command -v rsync >/dev/null 2>&1'; then
    rsync -az -e "ssh -o StrictHostKeyChecking=accept-new" \
      "$REMOTE_HOST:$REMOTE_DIR/$d/" "$ROOT/dist-linux/"
  else
    remote_ssh "tar -C '$REMOTE_DIR/$d' -czf - ." | tar -xzf - -C "$ROOT/dist-linux"
  fi
  list_bundles
}

list_bundles() {
  find "$ROOT/dist-linux" -type f \
    \( -name '*.deb' -o -name '*.AppImage' -o -name '*.rpm' \) \
    -exec ls -lh {} \; 2>/dev/null || true
}

build_remote() {
  [[ "$LOGS" == "1" ]] && { remote_logs; return; }
  [[ "$STOP" == "1" ]] && { remote_stop; return; }

  [[ "$NO_SYNC" != "1" ]] && sync_sources
  [[ "$SYNC_ONLY" == "1" ]] && { log "sync-only: done"; return; }

  log "pnpm install (remote, frozen-lockfile)"
  remote_ssh "cd '$REMOTE_DIR' && $REMOTE_ENV && pnpm install --frozen-lockfile"

  if [[ "$DEV" == "1" ]]; then
    remote_dev
    return
  fi

  log "pnpm tauri build $BUILD_FLAGS [$PROFILE] (remote)"
  # shellcheck disable=SC2086
  remote_ssh "cd '$REMOTE_DIR' && $REMOTE_ENV && pnpm tauri build $BUILD_FLAGS"

  [[ "$FETCH" == "1" ]] && fetch_bundles
  [[ "$RUN" == "1" ]] && remote_launch_binary
  [[ "$VERIFY" == "1" ]] && remote_verify
  log "done — artifacts on $REMOTE_HOST:$REMOTE_DIR/$(target_dir)/bundle/"
}

# -------------------------------------------------------------------- run ---
[[ "$IS_WINDOWS" == "1" ]] && log "Windows detected — running from Git Bash"
build_remote