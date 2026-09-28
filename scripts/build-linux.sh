#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# build-linux.sh — compile (and optionally run) the Tauri app for Linux.
#
# Two build backends, chosen explicitly or inferred from the host:
#
#   --remote [HOST]  push the sources over SSH to a Linux dev box and build
#                    there. Default host: $LINUX_BUILD_REMOTE or `ubuntu-arm`
#                    (Ubuntu-arm-docker: https://github.com/YanxReal/Ubuntu-arm-docker,
#                    Ubuntu 26.04 + GNOME 50 Wayland, user `admin`).
#                    Default dir: $LINUX_BUILD_DIR or
#                    `/workspace/Tauri-react-template` (capital T: the repo
#                    checkout; the binary itself stays lowercase, see below).
#                    Full featured: build, run, dev, logs, stop. This is the
#                    path for macOS.
#   --native         build on this machine (must be Linux — aborts elsewhere).
#
# With no mode flag: native on Linux, remote when the dev box answers. If the
# box is unreachable the script stops with instructions — it never builds
# anywhere else.
#
# Platforms: the Linux build ALWAYS happens in the Ubuntu-arm-docker box via
# SSH (macOS and Windows cannot run webkit2gtk + the Linux bundlers locally).
#   macOS  run `scripts/build-linux.sh` directly (needs bash + ssh + rsync|tar).
#   Windows run `scripts\build-linux.cmd` (locates Git Bash) or the .sh from
#           a Git Bash terminal; OpenSSH is included with Git for Windows, and
#           rsync is optional (the script falls back to tar).
#
# Build profile
#   --release         optimised, LTO, small       (default)
#   --debug           no LTO, much faster         (best for testing)
#
# Options
#   --dev             `tauri dev` (Vite + app, hot reload); implies --debug
#   --run             after building, launch the app on the target display.
#                     NOTE: Ubuntu-arm-docker is Wayland-only, so a plain
#                     DISPLAY launch may show nothing — prefer `dev <binary>`
#                     in the box (software rendering, see docs/en/scripts.md).
#   --bundles LIST    deb | appimage | rpm | all            (default: deb)
#   --target ARCH     aarch64 | x86_64 | <rust triple>; must match the box
#   --display :N      X display for --dev/--run             (default: :1)
#   --fetch           copy the built bundles back to ./dist-linux
#   --sync-only       only push the sources over SSH, do not build
#   --no-sync         build what is already on the remote
#   --logs            follow the remote dev/app log (remote only)
#   --stop            kill the running app / dev server (remote only)
#   -h, --help        this text
#
# Examples
#   ./scripts/build-linux.sh --remote --dev          # compile + run (hot reload)
#   ./scripts/build-linux.sh --remote --debug --run  # fast build, then launch
#   ./scripts/build-linux.sh --remote --release --run --fetch
#   ./scripts/build-linux.sh --remote --bundles all
#   ./scripts/build-linux.sh                         # auto: remote, or native on Linux
#   ./scripts/build-linux.sh --native                # force a local Linux build
# ---------------------------------------------------------------------------
set -euo pipefail

# --- Platform detection ------------------------------------------------------
# This script's job is building Linux. On macOS/Windows it goes REMOTE (SSH to
# the Ubuntu-arm-docker box); only on an actual Linux host does it build native.
# Git Bash on Windows reports MINGW*/MSYS*/CYGWIN* — not "Linux" — so it falls
# to remote, which is correct. Detect for clearer messaging + a --native guard.
OST="$(uname -s 2>/dev/null || echo unknown)"
IS_LINUX_NATIVE=0
IS_WINDOWS=0
IS_MACOS_OR_OTHER=0
case "$OST" in
  Linux) IS_LINUX_NATIVE=1 ;;
  MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=1 ;;
  *) IS_MACOS_OR_OTHER=1 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Binary name (lowercase by rule: Cargo package name, `productName` slug,
# target dir, pkill patterns). Never capitalise this: the repo checkout is
# `Tauri-react-template` (capital T) but the built binary is lowercase.
APP_NAME="tauri-react-template"

MODE=""
REMOTE_HOST="${LINUX_BUILD_REMOTE:-ubuntu-arm}"
REMOTE_DIR="${LINUX_BUILD_DIR:-/workspace/Tauri-react-template}"
BUNDLES="deb"
TARGET=""
PROFILE="release"
DEV=0
RUN=0
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
      MODE="remote"
      if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then REMOTE_HOST="$2"; shift; fi ;;
    --native)    MODE="native" ;;
    --docker)    die "--docker was removed: builds run over SSH. Use --remote [HOST]." ;;
    --release)   PROFILE="release" ;;
    --debug)     PROFILE="debug" ;;
    --dev)       DEV=1; PROFILE="debug" ;;
    --run)       RUN=1 ;;
    --fetch)     FETCH=1 ;;
    --sync-only) SYNC_ONLY=1 ;;
    --no-sync)   NO_SYNC=1 ;;
    --logs)      LOGS=1 ;;
    --stop)      STOP=1 ;;
    --bundles)   BUNDLES="${2:?--bundles needs a value}"; shift ;;
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

# `--debug`/`--dev` flag for `pnpm tauri build`
BUILD_FLAGS="--bundles $BUNDLES"
[[ "$PROFILE" == "debug" ]] && BUILD_FLAGS="$BUILD_FLAGS --debug"
[[ -n "$TRIPLE" ]] && BUILD_FLAGS="$BUILD_FLAGS --target $TRIPLE"

# `--native` only makes sense on an actual Linux host. macOS/Windows have no
# local Linux toolchain (webkit2gtk + Linux bundlers) — always abort clearly.
if [[ "$MODE" == "native" && "$IS_LINUX_NATIVE" != "1" ]]; then
  die "--native requires a Linux host. On macOS/Windows use --remote (the
       Ubuntu-arm-docker box) instead: $0 --remote ubuntu-arm --debug --fetch"
fi

# ------------------------------------------------------------- mode picking -
ssh_probe() {
  ssh -o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=accept-new \
      "$1" true >/dev/null 2>&1
}
if [[ -z "$MODE" ]]; then
  if [[ "$IS_LINUX_NATIVE" == "1" ]]; then
    MODE="native"
  elif ssh_probe "$REMOTE_HOST"; then
    MODE="remote"
  else
    die "SSH build box '$REMOTE_HOST' is unreachable.
     Start it (Ubuntu-arm-docker: make install in that repo), or point the
     script at another box:
       $0 --remote <host>              # e.g. --remote ubuntu-arm
       LINUX_BUILD_REMOTE=<host> $0    # or set the default once
     To build on this very machine instead (Linux only): $0 --native"
  fi
fi

RSYNC_EXCLUDES=(
  --exclude node_modules --exclude target --exclude dist
  --exclude .turbo --exclude src-tauri/gen --exclude '*.log'
  --exclude dist-linux
)

target_dir() { # relative cargo output dir for the chosen profile/triple
  local d="src-tauri/target"
  [[ -n "$TRIPLE" ]] && d="$d/$TRIPLE"
  d="$d/$PROFILE"
  echo "$d"
}

# =============================================================== remote =====
# Box toolchain lives outside PATH for non-interactive SSH (rustup shim at
# /usr/local/cargo/bin, node/pnpm at /usr/local/bin), so every remote cargo
# invocation needs this prefix. Verified against Ubuntu-arm-docker 2026-09.
REMOTE_ENV='export CARGO_HOME=/usr/local/cargo RUSTUP_HOME=/usr/local/rustup PATH=/usr/local/cargo/bin:$PATH'
remote_ssh() { ssh -o StrictHostKeyChecking=accept-new "$REMOTE_HOST" "$@"; }
# Detached variant: `-f` forks after auth, so the caller never blocks waiting
# for the remote channel to close while a background process holds it.
remote_ssh_bg() { ssh -f -o StrictHostKeyChecking=accept-new "$REMOTE_HOST" "$@"; }

sync_sources() {
  remote_ssh "mkdir -p '$REMOTE_DIR'"
  if command -v rsync >/dev/null 2>&1 && remote_ssh 'command -v rsync >/dev/null 2>&1'; then
    log "rsync (incremental) $ROOT/ -> $REMOTE_HOST:$REMOTE_DIR/"
    rsync -az --delete "${RSYNC_EXCLUDES[@]}" \
      -e "ssh -o StrictHostKeyChecking=accept-new" \
      "$ROOT/" "$REMOTE_HOST:$REMOTE_DIR/"
  else
    warn "rsync missing on one end — falling back to tar (no stale-file cleanup)"
    tar -C "$ROOT" \
      --exclude=./node_modules --exclude=./src-tauri/target \
      --exclude=./dist --exclude=./.turbo --exclude=./src-tauri/gen \
      --exclude=./dist-linux --exclude='*.log' \
      -czf - . | remote_ssh "tar -xzf - -C '$REMOTE_DIR'"
  fi
}

remote_stop() {
  log "stopping app / dev server on $REMOTE_HOST"
  # Bracket trick + precise patterns: the pattern must not match the pkill
  # command's own cmdline (it would kill its own shell), and matching the bare
  # app name would also hit any shell whose cmdline contains the checkout dir.
  # `vite` needs two forms: the node bin (`vite.js`) and the shim (`sh -c vite`).
  remote_ssh "for p in '[t]auri.js dev' '[p]npm tauri dev' '[v]ite.js' '[v]ite --port' \
                     'target/[d]ebug/tauri-react-template' 'target/[r]elease/tauri-react-template'; do \
                pkill -f \"\$p\" >/dev/null 2>&1 || true; \
              done; echo stopped"
}

remote_logs() {
  remote_ssh "tail -n 60 -f /tmp/tauri-dev.log /tmp/$APP_NAME.log 2>/dev/null"
}

remote_launch_binary() {
  local bin; bin="$(target_dir)/$APP_NAME"
  log "launching $bin on DISPLAY $DISPLAY_NUM (remote)"
  remote_ssh "pkill -f '[t]auri-react-template' >/dev/null 2>&1 || true"
  remote_ssh_bg "cd '$REMOTE_DIR' && $REMOTE_ENV && export DISPLAY='$DISPLAY_NUM' && \
    exec setsid '$bin' >/tmp/$APP_NAME.log 2>&1 </dev/null"
  log "launched — follow with: $0 --remote --logs"
}

remote_dev() {
  log "pnpm tauri dev on DISPLAY $DISPLAY_NUM (remote, detached)"
  remote_stop >/dev/null
  remote_ssh_bg "cd '$REMOTE_DIR' && $REMOTE_ENV && export DISPLAY='$DISPLAY_NUM' && \
    exec setsid pnpm tauri dev >/tmp/tauri-dev.log 2>&1 </dev/null"
  log "started — follow with: $0 --remote --logs"
}

fetch_bundles() {
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

  log "pnpm install (remote)"
  remote_ssh "cd '$REMOTE_DIR' && $REMOTE_ENV && pnpm install --frozen-lockfile"

  if [[ "$DEV" == "1" ]]; then
    remote_dev
    return
  fi

  log "pnpm tauri build $BUILD_FLAGS [$PROFILE] (remote)"
  remote_ssh "cd '$REMOTE_DIR' && $REMOTE_ENV && pnpm tauri build $BUILD_FLAGS"

  [[ "$FETCH" == "1" ]] && fetch_bundles
  [[ "$RUN" == "1" ]] && remote_launch_binary
  log "done — artifacts on $REMOTE_HOST:$REMOTE_DIR/$(target_dir)/bundle/"
}

# =============================================================== native =====
build_native() {
  cd "$ROOT"
  [[ "$SYNC_ONLY" == "1" || "$NO_SYNC" == "1" ]] && warn "sync flags are remote-only"

  if [[ "$STOP" == "1" ]]; then
    log "stopping app / dev server"
    pkill -f "[t]auri dev" >/dev/null 2>&1 || true
    pkill -f "[t]auri-react-template" >/dev/null 2>&1 || true
    return
  fi
  if [[ "$LOGS" == "1" ]]; then
    tail -n 60 -f /tmp/tauri-dev.log /tmp/$APP_NAME.log 2>/dev/null || true
    return
  fi

  log "pnpm install"
  pnpm install --frozen-lockfile

  if [[ "$DEV" == "1" ]]; then
    log "pnpm tauri dev"
    exec pnpm tauri dev
  fi

  log "pnpm tauri build $BUILD_FLAGS [$PROFILE]"
  # shellcheck disable=SC2086
  pnpm tauri build $BUILD_FLAGS

  if [[ "$RUN" == "1" ]]; then
    log "launching $(target_dir)/$APP_NAME on DISPLAY $DISPLAY_NUM"
    DISPLAY="$DISPLAY_NUM" setsid nohup "./$(target_dir)/$APP_NAME" \
      >/tmp/$APP_NAME.log 2>&1 </dev/null &
  fi
  log "done — see $(target_dir)/bundle/"
}

# -------------------------------------------------------------------- run ---
case "$MODE" in
  remote) build_remote ;;
  native) build_native ;;
  *) die "unreachable mode: $MODE" ;;
esac
