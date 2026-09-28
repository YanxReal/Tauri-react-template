#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# box-shot.sh — screenshot of the Ubuntu-arm-docker box over VNC.
#
# Why VNC and not a GNOME API: on this box `org.gnome.Shell.Screenshot`,
# `GetWindows` and `Eval` answer `AccessDenied`, `gnome-screenshot` fails with
# no surface, and the portal exposes no `Screenshot`. The VNC framebuffer
# always arrives (vncdotool + `admin` password).
#
# Two measured details:
#   - Capturing right after connect can come out flat (blank frame):
#     hence the 3s wait before capturing. (No `move`: moving the mouse once
#     hung vncdotool and left the process attached to the session.)
#   - GRD admits only ONE VNC client at a time: if you are watching via noVNC,
#     the capture is rejected and the script says so (close noVNC for a moment).
#   - Double anti-hang net: `vncdo -t 60` + `timeout 90`.
#
# Usage:
#   ./scripts/box-shot.sh [/path/output.png]   # default: /tmp/box-shot.png
#   VNC_PASSWORD=xxx ./scripts/box-shot.sh     # if you changed the password
# ---------------------------------------------------------------------------
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,/^set -euo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d'
  exit 0
fi

BOX_DIR="${UBUNTU_ARM_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../Ubuntu-arm-docker" && pwd)}"
OUT="${1:-/tmp/box-shot.png}"
TMP=/tmp/box-shot-tmp.png
VNC_PASS="${VNC_PASSWORD:-admin}"
VNC_PORT="${VNC_PORT:-5900}"

[[ -f "$BOX_DIR/docker-compose.yml" ]] || {
  echo "cannot find $BOX_DIR/docker-compose.yml (set UBUNTU_ARM_DIR)" >&2
  exit 1
}

cd "$BOX_DIR" || exit 1

docker compose exec -u admin -T ubuntu-desktop bash -lc "
  [ -x /tmp/vncenv/bin/vncdo ] || { python3 -m venv /tmp/vncenv && /tmp/vncenv/bin/pip install -q vncdotool; }
  timeout 90 /tmp/vncenv/bin/vncdo -t 60 -s 127.0.0.1::$VNC_PORT -p $(printf '%q' "$VNC_PASS") sleep 3 capture $TMP 2>&1 \
    | grep -viE 'deprecat|encryptor' | head -3
  ls -la $TMP 2>&1" || exit 1

docker cp "ubuntu-desktop:$TMP" "$OUT" >/dev/null \
  && echo "screenshot: $OUT"
