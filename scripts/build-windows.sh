#!/bin/bash
# Build Windows MSI + NSIS from macOS via cargo-xwin + Tauri bundler.
# Mirrors Prestly's scripts/build-windows.sh — exports xwin env then tauri build.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Export the cross env that cargo-xwin normally sets for `cargo xwin build`
eval "$(cargo xwin env --target x86_64-pc-windows-msvc)"

# Ensure llvm/lld in PATH (brew llvm + lld)
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
# lld-link lives in /opt/homebrew/bin via brew lld, ensure it too
export PATH="/opt/homebrew/bin:$PATH"

echo "==> Building Windows bundle for $ROOT/src-tauri (target x86_64-pc-windows-msvc)"
echo "    outputs: src-tauri/target/x86_64-pc-windows-msvc/release/bundle/{msi,nsis}/"
cargo tauri build --target x86_64-pc-windows-msvc "$@"
echo "==> Done. Check src-tauri/target/x86_64-pc-windows-msvc/release/bundle/"
