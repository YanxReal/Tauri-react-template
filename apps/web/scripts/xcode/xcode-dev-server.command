#!/bin/bash
# Servidor Vite visible para el modo hotreload del template (sin parent de
# `tauri ios dev`): la phase "Build Rust Code" de Xcode lo abre con
# `open -a Terminal` cuando nada escucha en :1420, así el HMR funciona con
# logs visibles. Cerrar la ventana detiene el servidor.
set -euo pipefail
cd "$(dirname "$0")/../.."
exec pnpm dev