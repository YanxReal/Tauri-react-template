#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# linux-box.sh — control de la caja Linux (docker/linux-gnome).
#
# Ubuntu 24.04 + GNOME sobre Xvfb, con noVNC para VER la ventana y SSH para
# controlarla. Es la caja que usa `scripts/build-linux.sh --remote` (alias
# `ubuntu-vnc` en ~/.ssh/config). Compila ahí el codigo `cfg(target_os=linux)`
# que en el Mac no se puede ni comprobar.
#
# IMPORTANTE: el contenedor se crea con `--restart=no`. Docker Desktop puede
# arrancar con la caja apagada; la levantas tu cuando la necesites.
#
#   up        arranca la caja (crea el contenedor la primera vez)
#   down      para la caja (conservala; NO la borra)
#   destroy   borra el contenedor (--volumes: pierde caches de cargo/pnpm)
#   status    estado + si display/WM/vnc/ssh responden
#   wait      espera a que la caja este lista (para scripts)
#   ssh [cmd] shell/comando por ssh en la caja
#   novnc     imprime la URL de noVNC
#   vnc       imprime host:puerto del VNC directo (TightVNC, contrasena: dev)
#   logs      sigue el log del contenedor
#   build ... atajo: build-linux.sh --remote (sin --remote)
#   app [--opaque]  compila y lanza la app en :1 (visible en noVNC)
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="${LINUX_BOX_NAME:-tauri-linux-gnome}"
IMAGE="${LINUX_BOX_IMAGE:-tauri-linux-gnome:24.04}"
SSH_PORT="${LINUX_BOX_SSH_PORT:-2222}"
NOVNC_PORT="${LINUX_BOX_NOVNC_PORT:-6080}"
DOCKER="${DOCKER:-docker}"
KEY="${LINUX_BOX_KEY:-$HOME/.ssh/id_ed25519.pub}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

have_docker() { command -v "$DOCKER" >/dev/null 2>&1; }

ensure_image() {
  if $DOCKER image inspect "$IMAGE" >/dev/null 2>&1; then
    return 0
  fi
  log "no existe $IMAGE; compilando (la primera vez tarda varios minutos)"
  $DOCKER build -t "$IMAGE" "$ROOT/docker/linux-gnome"
}

# authorized_keys del host montado en el contenedor (build-time no puede leer
# las claves del usuario, y no queremos claves fijadas en la imagen).
# bash 3.2-safe (sin mapfile): imprime un flag y sus argumentos.
has_key() { [[ -f "$KEY" ]]; }

cmd_up() {
  have_docker || die "no encuentro docker en el PATH"
  if $DOCKER ps --format '{{.Names}}' | grep -qx "$NAME"; then
    log "$NAME ya esta corriendo"
    return 0
  fi
  ensure_image
  if ! $DOCKER ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
    # Contenedor nuevo => host key nuevo. El alias `ubuntu-vnc` usa un
    # known_hosts propio justamente para esto (ver ~/.ssh/config); si no lo
    # limpiamos, el proximo ssh muere con "HOST IDENTIFICATION HAS CHANGED".
    rm -f "$HOME/.ssh/known_hosts_ubuntu-vnc"
    log "creando $NAME (--restart=no: no arranca solo)"
    if has_key; then
      $DOCKER run -d --name "$NAME" \
        --restart=no \
        --shm-size=1g \
        -e WM="${LINUX_BOX_WM:-gnome-session}" \
        -e SCREEN_GEOMETRY="${LINUX_BOX_GEOMETRY:-1600x1000x24}" \
        -p "127.0.0.1:${SSH_PORT}:2222" \
        -p "127.0.0.1:${NOVNC_PORT}:6080" \
        -p "127.0.0.1:${LINUX_BOX_VNC_PORT:-5901}:5901" \
        -v tauri-cargo-registry:/usr/local/cargo/registry \
        -v tauri-cargo-git:/usr/local/cargo/git \
        -v tauri-pnpm-store:/home/dev/.local/share/pnpm/store \
        -v "$KEY:/home/dev/.ssh/authorized_keys:ro" \
        "$IMAGE" >/dev/null
    else
      warn "no hay clave publica en $KEY: el SSH se quedara sin poder entrar"
      $DOCKER run -d --name "$NAME" \
        --restart=no \
        --shm-size=1g \
        -e WM="${LINUX_BOX_WM:-gnome-session}" \
        -e SCREEN_GEOMETRY="${LINUX_BOX_GEOMETRY:-1600x1000x24}" \
        -p "127.0.0.1:${SSH_PORT}:2222" \
        -p "127.0.0.1:${NOVNC_PORT}:6080" \
        -p "127.0.0.1:${LINUX_BOX_VNC_PORT:-5901}:5901" \
        -v tauri-cargo-registry:/usr/local/cargo/registry \
        -v tauri-cargo-git:/usr/local/cargo/git \
        -v tauri-pnpm-store:/home/dev/.local/share/pnpm/store \
        "$IMAGE" >/dev/null
    fi
  else
    log "arrancando $NAME existente"
    $DOCKER start "$NAME" >/dev/null
  fi
  cmd_wait
  cmd_status
}

cmd_down() {
  have_docker || die "no encuentro docker en el PATH"
  $DOCKER stop "$NAME" >/dev/null 2>&1 && log "$NAME parada (conservada)" \
    || warn "$NAME no estaba corriendo"
}

cmd_destroy() {
  $DOCKER rm -f -v "$NAME" >/dev/null 2>&1 && log "$NAME borrada" \
    || warn "$NAME no existia"
}

# Toda sesion ssh va con DISPLAY listo (el contenedor lo exporta en
# /etc/profile.d, pero ssh <cmd> no pasa por profile: hay que mandarlo).
box_ssh() { ssh -o BatchMode=yes -o ConnectTimeout=6 ubuntu-vnc "export DISPLAY=:1; $*"; }

cmd_wait() {
  local tries="${1:-60}"
  for _ in $(seq 1 "$tries"); do
    if box_ssh 'test -f /tmp/.box-ready && xdpyinfo >/dev/null 2>&1 && wmctrl -m >/dev/null 2>&1' >/dev/null 2>&1; then
      log "caja lista (display + WM + ssh)"
      return 0
    fi
    sleep 1
  done
  warn "la caja no respondio en ${tries}s; mira: $0 logs"
  return 1
}

cmd_status() {
  have_docker || die "no encuentro docker en el PATH"
  printf 'contenedor : %s\n' "$($DOCKER ps -a --filter "name=^${NAME}$" --format '{{.Status}}' || echo '(no existe)')"
  printf 'restart    : %s  (no => no arranca solo)\n' \
    "$($DOCKER inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$NAME" 2>/dev/null || echo '?')"
  printf 'display    : %s\n' "$(box_ssh 'xdpyinfo | grep dimensions' 2>/dev/null || echo '(sin ssh)')"
  printf 'wm         : %s\n' "$(box_ssh 'wmctrl -m | head -1' 2>/dev/null || echo '(sin ssh)')"
  printf 'novnc      : %s\n' "$(cmd_novnc)"
  printf 'vnc        : %s\n' "$(box_ssh 'pgrep -x x11vnc >/dev/null && echo ok || echo CAIDO' 2>/dev/null)"
  printf 'pantalla   : %s\n' "$(box_ssh 'xrandr | grep " connected"' 2>/dev/null | head -1 || echo '(sin xrandr)')"
}

cmd_novnc() { echo "http://localhost:${NOVNC_PORT}/vnc.html"; }

cmd_ssh() { exec ssh ubuntu-vnc "$@"; }

cmd_logs() { exec $DOCKER logs -f "$NAME"; }

cmd_build() { exec "$ROOT/scripts/build-linux.sh" --remote ubuntu-vnc "$@"; }

# Lanza la app en el display de la caja, visible en noVNC.
#
# --opaque: pone `transparent: false` en la config DE LA CAJA antes de compilar.
#
#   OJO, esto cambia lo que estas probando. `transparent: true` (lo que lleva el
#   repo) hace que la ventana use un visual TrueColor de 32 bits con canal alfa.
#   Medido en esta caja: con `transparent: true` mutter NO gestiona la ventana
#   (`_NET_WM_DESKTOP` no aparece) y no la compone — la captura del root sale con
#   solo el wallpaper, aunque la ventana este mapeada y los procesos de WebKit
#   vivos. El visual de 32 bits SI existe en Xvfb (`xdpyinfo`: visual 0x213,
#   depth 32), asi que el limite es mutter + llvmpipe, no la caja.
#   Con `transparent: false` la ventana se ve y se puede interactuar.
#
#   Traduccion: en la caja puedes verificar titlebar, arrastre, resize, caption
#   buttons y scroll, pero NO las esquinas redondeadas con alfa — justamente lo
#   que `transparent: true` habilita. Eso necesita una maquina con GL real (el
#   changelog lo verifico en la caja Ubuntu ARM).
#
# El cambio es sobre la copia de la caja, no sobre el repo: el proximo
# `rsync --delete` de build-linux.sh la restaura sola.
cmd_app() {
  local opaque=0
  for a in "$@"; do
    case "$a" in
      --opaque) opaque=1 ;;
      *) die "flag desconocido para 'app': $a" ;;
    esac
  done
  box_ssh "cd ~/tauri-react-template" >/dev/null 2>&1 \
    || die "la caja no responde; arranca con: $0 up"

  if [[ "$opaque" == "1" ]]; then
    warn "modo --opaque: transparent:false solo en la caja (las esquinas con alfa"
    warn "no se pueden verificar aqui; ver la nota en scripts/linux-box.sh)"
  fi

  if [[ "$opaque" == "1" ]]; then
    ssh ubuntu-vnc "cd ~/tauri-react-template && sed -i 's/\"transparent\": true/\"transparent\": false/' src-tauri/tauri.linux.conf.json && grep -n transparent src-tauri/tauri.linux.conf.json"
  fi

  # compila incremental y arranca en :1 (setsid para que sobreviva al ssh)
  box_ssh "cd ~/tauri-react-template && export PATH=/usr/local/cargo/bin:\$PATH && pnpm tauri build --bundles deb --debug" >/dev/null
  box_ssh "pkill -f '[t]auri-react-template' >/dev/null 2>&1; sleep 1; true"
  log "lanzando la app en DISPLAY=:1 — mirala en $(cmd_novnc)"
  box_ssh "cd ~/tauri-react-template && setsid ./src-tauri/target/debug/tauri-react-template >/tmp/app.log 2>&1 & sleep 10; DISPLAY=:1 wmctrl -l"
}

usage() { sed -n '3,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d'; }

case "${1:-}" in
  up)      shift; cmd_up "$@" ;;
  down)    shift; cmd_down "$@" ;;
  destroy) shift; cmd_destroy "$@" ;;
  status)  shift; cmd_status "$@" ;;
  wait)    shift; cmd_wait "$@" ;;
  ssh)     shift; cmd_ssh "$@" ;;
  novnc)   shift; cmd_novnc "$@" ;;
  logs)    shift; cmd_logs "$@" ;;
  build)   shift; cmd_build "$@" ;;
  app)     shift; cmd_app "$@" ;;
  -h|--help|help) usage ;;
  *) usage; die "subcomando desconocido: ${1:-} (prueba --help)" ;;
esac
