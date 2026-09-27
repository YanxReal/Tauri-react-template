#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# box-shot.sh — captura de pantalla de la caja Ubuntu-arm-docker por VNC.
#
# Por qué VNC y no una API de GNOME: en esta caja `org.gnome.Shell.Screenshot`,
# `GetWindows` y `Eval` responden `AccessDenied`, `gnome-screenshot` falla sin
# superficie y el portal no expone `Screenshot`. El framebuffer por VNC sí
# llega siempre (vncdotool + contraseña `admin`).
#
# Dos detalles medidos:
#   - Una captura inmediata al conectar puede salir plana (frame en blanco):
#     por eso se espera 3s antes de capturar. (Sin `move`: mover el ratón
#     colgó vncdotool una vez y dejó el proceso enganchado a la sesión.)
#   - GRD solo admite UN cliente VNC a la vez: si estás mirando por noVNC, la
#     captura se rechaza y el script lo dice (cierra noVNC un momento).
#   - Doble red de seguridad anti-cuelgue: `vncdo -t 60` + `timeout 90`.
#
# Uso:
#   ./scripts/box-shot.sh [/ruta/salida.png]   # default: /tmp/box-shot.png
#   VNC_PASSWORD=xxx ./scripts/box-shot.sh     # si cambiaste la contraseña
# ---------------------------------------------------------------------------
set -uo pipefail

BOX_DIR="${UBUNTU_ARM_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../Ubuntu-arm-docker" && pwd)}"
OUT="${1:-/tmp/box-shot.png}"
TMP=/tmp/box-shot-tmp.png
VNC_PASS="${VNC_PASSWORD:-admin}"

cd "$BOX_DIR" || { echo "no encuentro $BOX_DIR (define UBUNTU_ARM_DIR)"; exit 1; }

docker compose exec -u admin -T ubuntu-desktop bash -lc "
  [ -x /tmp/vncenv/bin/vncdo ] || { python3 -m venv /tmp/vncenv && /tmp/vncenv/bin/pip install -q vncdotool; }
  timeout 90 /tmp/vncenv/bin/vncdo -t 60 -s 127.0.0.1::5900 -p '$VNC_PASS' sleep 3 capture $TMP 2>&1 \
    | grep -viE 'deprecat|encryptor' | head -3
  ls -la $TMP 2>&1" || exit 1

docker cp "ubuntu-desktop:$TMP" "$OUT" >/dev/null \
  && echo "captura: $OUT"
