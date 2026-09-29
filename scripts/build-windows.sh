#!/usr/bin/env bash
# Build the Windows x64 bundle from macOS/Linux via cargo-xwin.
# Usage: ./scripts/build-windows.sh [--bundles nsis] [extra `tauri build` args]
# Example: ./scripts/build-windows.sh
#          ./scripts/build-windows.sh --bundles nsis --debug
#
# Requirements (one time):
#   brew install llvm lld makensis        # macOS: clang-cl/llvm-rc + lld-link + NSIS
#   sudo apt install llvm lld nsis        # Linux (Debian/Ubuntu)
#   cargo install cargo-xwin --locked
#   rustup target add x86_64-pc-windows-msvc
# MSI (WiX) can only be packaged on a Windows host — use `--bundles nsis` here.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUNDLES="nsis"
EXTRA=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundles) BUNDLES="${2:?--bundles needs a value}"; shift 2;;
    -h|--help)
      sed -n '2,/^set -euo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d'
      echo ""
      echo "Defaults: --bundles $BUNDLES (nsis | msi — msi needs a Windows host)"
      exit 0 ;;
    *) EXTRA+=("$1"); shift;;
  esac
done

# --- Toolchain resolution ---------------------------------------------------
#
# Windows is a CROSS target: only `rustup` ships the `x86_64-pc-windows-msvc`
# std, so the build must run under the rustup-managed `cargo`, not a
# Homebrew/apt one that may be first on PATH and lack the target. Resolve the
# rustup proxy across the common locations of BOTH OSes and put it first. The
# repo's rust-toolchain.toml already pins `stable`, matching rustup.

OS="$(uname -s)"
RUSTUP_BINS=()
case "$OS" in
  Darwin) RUSTUP_BINS=("$HOME/.cargo/bin" "/opt/homebrew/opt/rustup/bin" "/usr/local/rustup/bin") ;;
  Linux)  RUSTUP_BINS=("$HOME/.cargo/bin" "/usr/local/cargo/bin" "/root/.cargo/bin") ;;
esac
USE_RUSTUP=""
for r in "${RUSTUP_BINS[@]}"; do
  if [[ -x "$r/cargo" && -x "$r/rustup" ]]; then
    USE_RUSTUP="$r"
    export PATH="$r:$PATH"
    break
  fi
done

# Ensure cargo-xwin (the cargo runner) and any rustup-installed binaries are
# visible even if their dir isn't on the user's interactive PATH.
export PATH="$HOME/.cargo/bin:$PATH"

CC="$(command -v cargo)"
if [[ -z "$USE_RUSTUP" ]]; then
  # Fall back to whatever cargo is present, but warn: it may lack the target.
  if [[ -z "$CC" ]]; then
    echo "==> cargo not found — install Rust via rustup (https://rustup.rs)" >&2; exit 1
  fi
  echo "==> warn: no rustup found; using $CC — the msvc target may be missing." >&2
fi

# --- LLVM / lld / NSIS toolchain (per-OS) -----------------------------------
case "$OS" in
  Darwin)
    # Homebrew: llvm + lld are keg-only (not on PATH), makensis is a formula.
    for keg in llvm lld; do
      [[ -d "/opt/homebrew/opt/$keg/bin" ]] && PATH="/opt/homebrew/opt/$keg/bin:$PATH"
    done
    ;;
  Linux)
    # System packages (Debian/Ubuntu: llvm + lld + nsis). cargo-xwin needs
    # llvm-rc / lld-link on PATH for the MSVC CRT pieces.
    # A quoted glob never expands in an assignment: expand the versioned
    # dirs explicitly (llvm-rc/lld-link live in /usr/lib/llvm-N/bin).
    for d in /usr/lib/llvm-*/bin; do [ -d "$d" ] && PATH="$d:$PATH"; done
    export PATH
    ;;
esac
export PATH

# --- Preflight: required tools + the msvc target ----------------------------
command -v cargo-xwin >/dev/null || {
  echo "==> missing cargo-xwin — install with: cargo install cargo-xwin --locked"; exit 1; }
if command -v rustup >/dev/null 2>&1; then
  rustup target list --installed | grep -q '^x86_64-pc-windows-msvc$' \
    || rustup target add x86_64-pc-windows-msvc
else
  echo "==> warn: rustup not on PATH — cannot guarantee the msvc target is installed." >&2
fi
if [[ "$BUNDLES" == *nsis* ]]; then
  command -v makensis >/dev/null || {
    echo "==> missing makensis — macOS: brew install makensis | Linux: apt install nsis"; exit 1; }
fi

# Stock CLI via npm (the vendored `cargo-tauri` is a local tweaked build — see .claude/skills/tauri-cli-rebase).
echo "==> pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles $BUNDLES ${EXTRA[*]:-}"
pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles "$BUNDLES" \
  ${EXTRA[@]+"${EXTRA[@]}"}

echo "==> Done:"
ls -lh src-tauri/target/x86_64-pc-windows-msvc/release/*.exe 2>/dev/null || true
ls -lh src-tauri/target/x86_64-pc-windows-msvc/release/bundle/nsis/*.exe 2>/dev/null || true
