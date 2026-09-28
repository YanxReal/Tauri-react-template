#!/bin/bash
# Build the Windows x64 bundle from macOS/Linux via cargo-xwin.
# Usage: ./scripts/build-windows.sh [--bundles nsis] [extra `tauri build` args]
# Example: ./scripts/build-windows.sh
#          ./scripts/build-windows.sh --bundles nsis --debug
#
# Requirements (one time):
#   brew install llvm lld makensis        # macOS: clang-cl/llvm-rc + lld-link + NSIS
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
    --bundles) BUNDLES="$2"; shift 2;;
    *) EXTRA+=("$1"); shift;;
  esac
done

# LLVM (clang-cl, llvm-rc) and lld (lld-link) are keg-only on macOS: not on PATH.
for keg in llvm lld; do
  [[ -d "/opt/homebrew/opt/$keg/bin" ]] && PATH="/opt/homebrew/opt/$keg/bin:$PATH"
done
export PATH

command -v cargo-xwin >/dev/null || {
  echo "==> missing cargo-xwin — install with: cargo install cargo-xwin --locked"; exit 1; }
rustup target list --installed | grep -q '^x86_64-pc-windows-msvc$' \
  || rustup target add x86_64-pc-windows-msvc
if [[ "$BUNDLES" == *nsis* ]]; then
  command -v makensis >/dev/null || {
    echo "==> missing makensis — install with: brew install makensis"; exit 1; }
fi

# Stock CLI via npm (the vendored `cargo-tauri` is a local tweaked build — see MODS.md).
echo "==> pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles $BUNDLES ${EXTRA[*]:-}"
pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles "$BUNDLES" \
  ${EXTRA[@]+"${EXTRA[@]}"}

echo "==> Done:"
ls -lh src-tauri/target/x86_64-pc-windows-msvc/release/*.exe 2>/dev/null || true
ls -lh src-tauri/target/x86_64-pc-windows-msvc/release/bundle/nsis/*.exe 2>/dev/null || true
