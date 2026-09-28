#!/bin/bash
# Build the Windows x64 bundle from macOS/Linux via cargo-xwin.
# Uso: ./scripts/build-windows.sh [--bundles nsis] [args extra de `tauri build`]
# Ejemplo: ./scripts/build-windows.sh
#          ./scripts/build-windows.sh --bundles nsis --debug
#
# Requisitos (una sola vez):
#   brew install llvm lld makensis        # macOS: clang-cl/llvm-rc + lld-link + NSIS
#   cargo install cargo-xwin --locked
#   rustup target add x86_64-pc-windows-msvc
# El MSI (WiX) solo se puede empaquetar en un host Windows — usa `--bundles nsis` aquí.
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

# LLVM (clang-cl, llvm-rc) y lld (lld-link) son keg-only en macOS: no están en PATH.
for keg in llvm lld; do
  [[ -d "/opt/homebrew/opt/$keg/bin" ]] && PATH="/opt/homebrew/opt/$keg/bin:$PATH"
done
export PATH

command -v cargo-xwin >/dev/null || {
  echo "==> falta cargo-xwin — instala con: cargo install cargo-xwin --locked"; exit 1; }
rustup target list --installed | grep -q '^x86_64-pc-windows-msvc$' \
  || rustup target add x86_64-pc-windows-msvc
if [[ "$BUNDLES" == *nsis* ]]; then
  command -v makensis >/dev/null || {
    echo "==> falta makensis — instala con: brew install makensis"; exit 1; }
fi

# CLI stock vía npm (el `cargo-tauri` vendoreado es un build local con retoques — ver MODS.md).
echo "==> pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles $BUNDLES ${EXTRA[*]:-}"
pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles "$BUNDLES" \
  ${EXTRA[@]+"${EXTRA[@]}"}

echo "==> Listo:"
ls -lh src-tauri/target/x86_64-pc-windows-msvc/release/*.exe 2>/dev/null || true
ls -lh src-tauri/target/x86_64-pc-windows-msvc/release/bundle/nsis/*.exe 2>/dev/null || true
