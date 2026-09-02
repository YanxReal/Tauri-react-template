#!/bin/bash
# Build Linux .deb (and AppImage) — nativo si estás en Linux, vía Docker si estás en macOS.
# Uso: ./scripts/build-linux.sh [--bundles deb|appimage|all] [--target aarch64|x86_64]
# Ejemplo: ./scripts/build-linux.sh --bundles deb
#          ./scripts/build-linux.sh --bundles deb --target x86_64
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLES="deb"
TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundles) BUNDLES="$2"; shift 2;;
    --target) TARGET="$2"; shift 2;;
    *) echo "Unknown arg $1"; exit 1;;
  esac
done

# Web ya debe estar compilado, pero lo aseguramos
echo "==> pnpm --filter web build"
pnpm --filter web build

if [[ "$(uname -s)" == "Linux" ]]; then
  echo "==> Linux nativo: cargo tauri build --bundles $BUNDLES ${TARGET:+--target $TARGET}"
  cargo tauri build --bundles "$BUNDLES" ${TARGET:+--target "$TARGET"} --config '{"build":{"beforeBuildCommand":""}}'
  echo "==> Listo. Mira src-tauri/target/release/bundle/"
  ls -lh src-tauri/target/release/bundle/deb/*.deb 2>/dev/null || true
  ls -lh src-tauri/target/release/bundle/appimage/*.AppImage 2>/dev/null || true
  exit 0
fi

# macOS host -> Docker con webkit pre-instalado (evita colapso RAM y glitches amarillos)
echo "==> macOS host: Docker rust:1.85 + webkit (WEBKIT_DISABLE_DMABUF_RENDERER ya en src-tauri/src/lib.rs)"
TARGET_FLAG=""
if [[ -n "$TARGET" ]]; then
  if [[ "$TARGET" == "x86_64" ]]; then TARGET_FLAG="--target x86_64-unknown-linux-gnu"
  elif [[ "$TARGET" == "aarch64" ]]; then TARGET_FLAG="--target aarch64-unknown-linux-gnu"
  else TARGET_FLAG="--target $TARGET"
  fi
fi

docker run --rm --network host -v "$ROOT:/workspace" -w /workspace rust:1.85 bash -c "
set -e
export DEBIAN_FRONTEND=noninteractive
echo 'APT::Acquire::Retries \"5\";' > /etc/apt/apt.conf.d/80-retries
echo 'Acquire::http::Timeout \"30\";' >> /etc/apt/apt.conf.d/80-retries
echo 'Acquire::http::Pipeline-Depth \"0\";' >> /etc/apt/apt.conf.d/80-retries
apt-get clean
apt-get update -qq 2>&1 | tail -5
apt-get install -y --no-install-recommends curl pkg-config libdbus-1-dev libwebkit2gtk-4.1-dev libgtk-3-dev libayatana-appindicator3-dev librsvg2-dev patchelf 2>&1 | tail -10
echo 'deps ok'
export PATH=\$HOME/.cargo/bin:\$PATH
if ! command -v cargo-tauri >/dev/null 2>&1; then cargo install tauri-cli --locked 2>&1 | tail -5; fi
ls /workspace/apps/web/dist/index.html 2>&1 | head -1 && echo 'dist ok'
cargo tauri build --bundles $BUNDLES $TARGET_FLAG --config '{\"build\":{\"beforeBuildCommand\":\"\"}}' 2>&1 | tee /tmp/tauri.log
echo EXIT_CODE:\$?
ls -lh target/release/bundle/deb/*.deb 2>&1 | head -10
ls -lh target/release/bundle/appimage/*.AppImage 2>&1 | head -10
"

echo "==> Listo (desde Docker). Mira src-tauri/target/release/bundle/"
ls -lh src-tauri/target/release/bundle/deb/*.deb 2>/dev/null | head -5 || true
