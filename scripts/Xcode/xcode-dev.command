#!/bin/bash
# Unified dev helper for the iOS/macOS hotreload modes (one file, two roles).
#
#   server   (default)  Visible Vite server for the template hotreload mode
#                       WITHOUT a `tauri ios dev` parent. The Xcode "Build
#                       Rust Code" phase opens this via `open -a Terminal`
#                       when nothing listens on :1420, so HMR runs with
#                       visible logs. Closing the window stops the server.
#
#   parent               Visible Terminal running `tauri ios dev --open` (the
#                       full-IPC parent). Opens Vite through its
#                       beforeDevCommand and serves options over IPC until
#                       the window closes. Manual use for the hotreload
#                       config that needs the real parent.
#
# Usage:
#   ./xcode-dev.command [server|parent]   (default: server)
#   ./xcode-dev.command -h|--help
set -euo pipefail

cd "$(dirname "$0")/../.."
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

MODE="${1:-server}"

case "$MODE" in
  server)
    exec pnpm dev
    ;;
  parent)
    HOST=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo)
    exec pnpm dlx @tauri-apps/cli@2.12.0 ios dev --open ${HOST:+--host $HOST}
    ;;
  -h|--help)
    echo "Usage: ./xcode-dev.command [server|parent]   (default: server)"
    echo ""
    echo "  server   Visible Vite dev server (Xcode hotreload WITHOUT parent)."
    echo "  parent   Visible 'tauri ios dev --open' full-IPC parent (manual)."
    exit 0
    ;;
  *)
    echo "unknown mode: $MODE (use server | parent)" >&2
    exit 1
    ;;
esac