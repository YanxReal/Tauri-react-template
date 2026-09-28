#!/bin/bash
# Visible Terminal parent `tauri ios dev --open` for the template hotreload
# full-IPC mode. The "Build Rust Code" phase opens it via
# `open -a Terminal` when no live parent exists (JSON-RPC probe). The parent
# starts Vite through its beforeDevCommand and serves options over IPC until
# the window closes.
set -euo pipefail
cd "$(dirname "$0")/../.."
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
HOST=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo)
exec pnpm dlx @tauri-apps/cli@2.12.0 ios dev --open ${HOST:+--host $HOST}