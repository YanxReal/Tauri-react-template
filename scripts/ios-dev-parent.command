#!/bin/bash
# Parent `tauri ios dev --open` visible en Terminal para el modo hotreload
# full IPC del template. La phase "Build Rust Code" la abre con
# `open -a Terminal` cuando no hay parent vivo (probe JSON-RPC). El parent
# levanta Vite vía su beforeDevCommand y sirve las options por IPC hasta que
# se cierre la ventana.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
HOST=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo)
exec pnpm dlx @tauri-apps/cli@2.11.4 ios dev --open ${HOST:+--host $HOST}