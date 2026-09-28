#!/bin/bash
# Visible Vite server for the template hotreload mode (no `tauri ios dev`
# parent): the Xcode "Build Rust Code" phase opens it via
# `open -a Terminal` when nothing listens on :1420, so HMR runs with visible
# logs. Closing the window stops the server.
set -euo pipefail
cd "$(dirname "$0")/../.."
exec pnpm dev