#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# docker/linux-gnome/entrypoint.sh — PID 1 de la caja Linux.
#
# Levanta, en este orden:
#   1. Xvfb            display :1 (configurable con DISPLAY)
#   2. dbus            session bus de la sesion GNOME
#   3. WM              gnome-shell --x11 -> mutter --x11 (ambos son mutter:
#                      el WM que resuelve CSD, sombra y _GTK_THEME_VARIANT)
#   4. x11vnc          display exportado para VER la ventana por noVNC
#   5. websockify      noVNC en :6080 (http://localhost:6080/vnc.html)
#   6. sshd            :2222 — por ahi entra scripts/build-linux.sh --remote
#
# La sesion grafica corre como `dev` (root, nunca) porque gnome-shell aborta
# con geteuid()==0. El display no lleva xauth: es una caja de desarrollo local
# y asi el build por SSH puede lanzar la app sin exportar cookies.
#
# /tmp/.box-ready aparece cuando hay display + WM + VNC, para que los scripts
# esperen de forma fiable en vez de dormir a lo bruto.
# ---------------------------------------------------------------------------
set -uo pipefail

DEV_USER="${DEV_USER:-dev}"
DISPLAY_NUM="${DISPLAY_NUM:-${DISPLAY:-:1}}"
SCREEN_GEOMETRY="${SCREEN_GEOMETRY:-1600x1000x24}"
NOVNCPORT="${NOVNCPORT:-6080}"
VNC_PORT="${VNC_PORT:-5900}"
VNC_LISTEN="${VNC_LISTEN:-127.0.0.1}"   # ponlo a 0.0.0.0 para llegar desde otro equipo
SSHD_PORT="${SSHD_PORT:-2222}"
WM="${WM:-gnome-shell}"

log()  { printf '\033[1;34m[box]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[box]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[box]\033[0m %s\n' "$*" >&2; exit 1; }

DEV_HOME="$(getent passwd "$DEV_USER" | cut -d: -f6)"
[[ -n "$DEV_HOME" ]] || die "no existe el usuario $DEV_USER"

shutdown() {
  log "apagando la caja"
  # al reves: sshd, vnc, wm, xvfb
  for p in "${SSHD_PID:-}" "${NOVNC_PID:-}" "${VNC_PID:-}" "${WM_PID:-}" "${XVFB_PID:-}"; do
    [[ -n "$p" ]] && kill "$p" 2>/dev/null
  done
  pkill -u "$DEV_USER" -f 'gnome-shell|mutter|x11vnc' 2>/dev/null
  pkill -f "Xvfb $DISPLAY_NUM" 2>/dev/null
  rm -f /tmp/.box-ready
  sleep 1
  exit 0
}
trap shutdown TERM INT

as_dev() { setpriv --reuid="$DEV_USER" --regid="$DEV_USER" --init-groups -- "$@"; }

# El bus de sesion esta vivo si responde una llamada real (no solo si el proceso
# existe: un dbus-daemon colgado mantiene proceso y socket, pero no contesta, y
# eso es justo lo que rompe gnome-shell).
bus_alive() {
  as_dev dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
    --print-reply=literal /org/freedesktop/DBus \
    org.freedesktop.DBus.ListNames >/dev/null 2>&1
}

# Reinicia el bus de sesion. El WM hay que relanzarlo despues: gnome-shell se
# queda sin bus y se queda pegado en su pantalla de error.
restart_bus() {
  warn "reiniciando el bus de sesion"
  local sock="/run/box/session-bus"
  mkdir -p /run/box; chown "$DEV_USER" /run/box
  rm -f "$sock"
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$sock"
  as_dev dbus-daemon --session --fork --address="unix:path=$sock" \
    >/run/box/dbus-session.log 2>&1 </dev/null
  printf '%s\n' "$DBUS_SESSION_BUS_ADDRESS" > /run/box/dbus-session-address
  grep -v '^DBUS_SESSION_BUS_ADDRESS=' /etc/environment > /run/box/env.new 2>/dev/null || true
  printf 'DBUS_SESSION_BUS_ADDRESS=%s\n' "$DBUS_SESSION_BUS_ADDRESS" >> /run/box/env.new
  cat /run/box/env.new > /etc/environment
  bus_alive && log "bus de sesion vivo otra vez" || warn "el bus sigue sin responder"
}

# --- 0. permisos de las caches montadas -------------------------------------
# `docker volume` crea el contenido como root al montarlo encima de un
# directorio de la imagen, aunque la imagen lo tenga chown a dev. Sin esto el
# build falla con "Permission denied" al escribir el registry de cargo:
#   error: failed to create directory `/usr/local/cargo/registry/cache/...`
# Es el unico sitio donde hay que arreglarlo: al montar, no en cada build.
mkdir -p /usr/local/cargo/registry /usr/local/cargo/git \
         "$DEV_HOME/.local/share/pnpm/store"
chown -R "$DEV_USER:$DEV_USER" /usr/local/cargo /usr/local/rustup \
      "$DEV_HOME/.local/share" 2>/dev/null \
  || warn "no pude hacer chown de las caches (siguen como root; el build fallara)"

# --- 1. display --------------------------------------------------------------
[[ -e /tmp/.X11-unix/X"${DISPLAY_NUM#:}" ]] && rm -f "/tmp/.X11-unix/X${DISPLAY_NUM#:}"
log "Xvfb $DISPLAY_NUM ($SCREEN_GEOMETRY)"
Xvfb "$DISPLAY_NUM" -screen 0 "$SCREEN_GEOMETRY" -nolisten tcp -noreset \
     +extension GLX +extension RANDR +extension XKEYBOARD +render \
     >/tmp/xvfb.log 2>&1 &
XVFB_PID=$!
for _ in $(seq 1 50); do
  DISPLAY="$DISPLAY_NUM" xdpyinfo >/dev/null 2>&1 && break
  sleep 0.2
done
DISPLAY="$DISPLAY_NUM" xdpyinfo >/dev/null 2>&1 || { cat /tmp/xvfb.log; die "Xvfb no levanto $DISPLAY_NUM"; }
log "display $DISPLAY_NUM listo"

# --- 2. dbus -----------------------------------------------------------------
mkdir -p /run/dbus
dbus-uuidgen > /run/dbus/machine-id 2>/dev/null || true
rm -f /run/dbus/pid
dbus-daemon --system --fork 2>/dev/null || warn "dbus system ya estaba"

# Bus de SESION para el WM y las apps. IMPORTANTE: se arranca COMO `dev`, no
# como root. `dbus-daemon --session` aplica la politica de session.conf, que
# solo deja conectar al usuario que creo el bus: si lo crea root, el socket
# queda 0777 pero gnome-shell/mutter (como dev) reciben "Failed to get session
# bus: The connection is closed" y la sesion cae.
#
# Direccion FIJA y salida a FICHERO, nunca a una tuberia. Antes se leia la
# direccion con `$(dbus-daemon --session --fork --print-address=1)`, y el daemon
# heredaba la tuberia de stdout: al cerrarse el extremo de lectura, el daemon se
# bloqueaba escribiendo y se colgaba. Sintoma: el socket existia y el proceso
# vivia, pero `dbus-send` se quedaba en "Did not receive a reply", gnome-shell
# perdia su bus y pintaba su pantalla de "Oh no! Something has gone wrong".
# Con `--address` conocido de antemano no hace falta leer nada, y con la salida
# redirigida a un fichero no hay tuberia que se pueda cerrar.
DBUS_SOCK="/run/box/session-bus"
rm -f "$DBUS_SOCK"
# El socket NO puede ir en /run/dbus: ese directorio es de root (modo 755) y el
# bus corre como `dev`, asi que dbus-daemon falla con
# "Failed to bind socket /run/dbus/session: Permission denied".
# /run/box es nuestro y lo hacemos de dev.
# El mkdir va ANTES de redirigir la salida del daemon ahi: si no existe, el `>`
# falla y el bus no arranca nunca.
mkdir -p /run/box
chown "$DEV_USER" /run/box
chmod 755 /run/box
export DBUS_SESSION_BUS_ADDRESS="unix:path=$DBUS_SOCK"
as_dev dbus-daemon --session --fork --address="unix:path=$DBUS_SOCK" \
  >/run/box/dbus-session.log 2>&1 </dev/null

printf '%s\n' "$DBUS_SESSION_BUS_ADDRESS" > /run/box/dbus-session-address
if [[ -e "$DBUS_SOCK" ]]; then
  log "dbus session: $DBUS_SESSION_BUS_ADDRESS"
  # pam_env lee /etc/environment en cada sesion ssh, y ahi no se lee ni
  # /etc/profile.d ni ~/.bashrc si la sesion no es interactiva. Lo escribimos
  # en runtime para que `ssh host 'gnome-terminal'` encuentre el mismo bus que
  # el escritorio que se ve por noVNC.
  grep -v '^DBUS_SESSION_BUS_ADDRESS=' /etc/environment > /run/box/env.new 2>/dev/null || true
  printf 'DBUS_SESSION_BUS_ADDRESS=%s\n' "$DBUS_SESSION_BUS_ADDRESS" >> /run/box/env.new
  cat /run/box/env.new > /etc/environment
  # Comprobacion real, no "me salio una cadena": un bus que se cuelga se
  # detecta aqui y no tres minutos despues con el shell en pantalla de error.
  if bus_alive; then
    log "dbus session responde para $DEV_USER"
  else
    warn "el bus de sesion no responde para $DEV_USER; revisa /run/box/dbus-session.log"
  fi
else
  warn "no se creo el socket del bus de sesion ($DBUS_SOCK); revisa /run/box/dbus-session.log"
fi

# --- 3. sesion GNOME (como dev) ---------------------------------------------
# OJO con las variables de render. La diferencia entre "escritorio Yaru + apps
# pintando" y "pantalla plana de un color" en esta caja es UNA variable:
#
#   GSK_RENDERER=cairo   -> pantalla plana. GNOME Shell 46 usa GTK4 y su
#                           compositor necesita GL; forzar el renderer de GTK4 a
#                           Cairo deja al shell vivo (proceso, D-Bus, clics)
#                           pero sin componer ni un pixel: todas las filas de la
#                           captura dan desviacion 0 y abrir una ventana cambia
#                           0 pixeles.
#   (sin GSK_RENDERER)   -> Yaru #023C88 + panel + ventanas, desviacion 3.7 en
#                           el panel y 37.6 en una ventana abierta.
#
# Medido con capturas. No volver a poner GSK_RENDERER=cairo "para que sea
# software": llvmpipe ya es software y GL le sobra.
#
# Y ojo con el MODO de sesion: los valores validos en Ubuntu son `ubuntu` o
# `gnome`. `GNOME_SHELL_SESSION_MODE=x11` NO existe (aunque `gnome-shell --x11`
# si sea un flag valido): el shell intenta cargar un modo inexistente y la
# sesion queda en pantalla plana. Se usa la receta estandar de Ubuntu
# (`XDG_CURRENT_DESKTOP=ubuntu:GNOME`, `DESKTOP_SESSION=ubuntu`,
# `XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg`).
#
# gnome-shell SIN systemd: BORRA /run/systemd.
#
# `misc/loginManager.js` de gnome-shell elige su gestor de sesion asi:
#
#     function haveSystemd() { return GLib.access('/run/systemd/seats', 0) >= 0; }
#     getLoginManager() { _loginManager = haveSystemd()
#                                   ? new LoginManagerSystemd()   // habla con logind
#                                   : new LoginManagerDummy(); }  // no habla con nadie
#
# El paquete `systemd` deja `/run/systemd/seats` en el fs aunque aqui no corra
# systemd (no hay init), asi que haveSystemd() da true y gnome-shell construye
# LoginManagerSystemd, que llama a `org.freedesktop.login1.GetSession` sobre el
# bus de SISTEMA. Sin logind la llamada lanza excepcion, el `main.js` revienta y
# gnome-shell muere con SIGSEGV ("killed by signal 11"); la sesion cae a mutter
# y no se ve ningun escritorio.
#
# Borrarlo hace que haveSystemd() sea false y gnome-shell use LoginManagerDummy,
# que resuelve sus promesas con valores neutros y no toca logind. Es el
# workaround estandar para GNOME en contenedores: systemd no corre, asi que el
# directorio no sirve de nada.
if [[ -d /run/systemd ]]; then
  rm -rf /run/systemd
  log "quitado /run/systemd (si no, gnome-shell busca logind y muere con SIGSEGV)"
fi

# --- 4a. sesion propia sin los componentes que no pueden funcionar -----------
# `gnome-session` declara la sesion FALLIDA (y `gnome-session-failed` tapa toda
# la pantalla con "Oh no! Something has gone wrong") en cuanto muere un
# componente listado en `RequiredComponents`. En un contenedor no hay logind ni
# org.gnome.ScreenSaver, asi que:
#
#   org.gnome.SettingsDaemon.Power              -> exit 1 (busca logind)
#   org.gnome.SettingsDaemon.ScreensaverProxy   -> busca org.gnome.ScreenSaver
#   org.gnome.SettingsDaemon.UsbProtection      -> SIGSEGV por el screensaver
#                                                  (no es requerido, pero igual)
#
# Son cosas de portatil (brillo, suspender, bloqueo de USB) que no significan
# nada aqui, asi que se quitan del RequiredComponents en vez de fingir logind.
# El resto de la sesion Ubuntu (Shell, panel, dock, tema, ajustes) se mantiene.
# El fichero va a /usr/local/share (esta en XDG_DATA_DIRS) para no pisar el
# ubuntu.session del paquete.
SESSION_DIR=/usr/local/share/gnome-session/sessions
if [[ -f /usr/share/gnome-session/sessions/ubuntu.session ]]; then
  mkdir -p "$SESSION_DIR"
  REQUIRED="org.gnome.Shell;org.gnome.SettingsDaemon.A11ySettings;org.gnome.SettingsDaemon.Color;org.gnome.SettingsDaemon.Datetime;org.gnome.SettingsDaemon.Housekeeping;org.gnome.SettingsDaemon.Keyboard;org.gnome.SettingsDaemon.MediaKeys;org.gnome.SettingsDaemon.PrintNotifications;org.gnome.SettingsDaemon.Rfkill;org.gnome.SettingsDaemon.Sharing;org.gnome.SettingsDaemon.Smartcard;org.gnome.SettingsDaemon.Sound;org.gnome.SettingsDaemon.Wacom;org.gnome.SettingsDaemon.XSettings"
  cat > "$SESSION_DIR/box.session" <<SESSION
[GNOME Session]
Name=Ubuntu (caja, sin logind)
RequiredComponents=$REQUIRED
SESSION
  log "sesion 'box' lista (sin Power/ScreensaverProxy/UsbProtection)"
fi

mkdir -p "/tmp/runtime-$DEV_USER"
chown "$DEV_USER" "/tmp/runtime-$DEV_USER"
chmod 700 "/tmp/runtime-$DEV_USER"

wm_session() {
  local bin="$1"; shift
  log "sesion: $bin $*"
  as_dev env \
    DISPLAY="$DISPLAY_NUM" \
    XDG_RUNTIME_DIR="/tmp/runtime-$DEV_USER" \
    HOME="$DEV_HOME" \
    USER="$DEV_USER" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    XDG_SESSION_TYPE=x11 \
    XDG_CURRENT_DESKTOP=ubuntu:GNOME \
    DESKTOP_SESSION=ubuntu \
    GNOME_SHELL_SESSION_MODE=ubuntu \
    XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg \
    LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    GDK_BACKEND=x11 \
    GTK_THEME=Adwaita \
    "$bin" "$@" >/tmp/wm.log 2>&1 &
  WM_PID=$!
}

wait_for_wm() {
  # `_NET_SUPPORTING_WM_CHECK` en la raiz solo existe si hay WM. `wmctrl -m` es
  # el segundo filtro (importante: mutter anuncia esa propiedad antes de
  # terminar de tomar la pantalla y aceptaria pulsaciones demasiado pronto).
  local i
  for i in $(seq 1 60); do
    if DISPLAY="$DISPLAY_NUM" xprop -root _NET_SUPPORTING_WM_CHECK >/dev/null 2>&1 \
       && DISPLAY="$DISPLAY_NUM" wmctrl -m >/dev/null 2>&1; then
      return 0
    fi
    kill -0 "$WM_PID" 2>/dev/null || return 1
    sleep 0.5
  done
  return 1
}

start_wm() {
  # Antes de nada, limpia cualquier sesion previa: si queda un mutter vivo,
  # el nuevo no puede tomar el display y falla con "Impossible to set scaling"
  # / errores de CRTC. Sin esto, un rearmo encima de otro se cicla.
  pkill -f "[g]nome-session" 2>/dev/null
  pkill -f "[m]utter --x11" 2>/dev/null
  pkill -f "[g]nome-shell --x11" 2>/dev/null
  sleep 1

  # `gnome-session` es la sesion REAL de GNOME: arranca gnome-shell --x11 (el
  # shell con panel, dash y apps), gnome-settings-daemon, dconf, etc. Es lo que
  # hay que usar para VER un escritorio, no solo una ventana. El modo sale de
  # XDG_SESSION_TYPE=x11: esta version de gnome-session NO acepta
  # --session-mode (falla con "Unknown option").
  # `mutter` a pelo es solo el WM+compositor: fallback minimo para probar el
  # marco CSD, pero no se ve ningun escritorio.
  case "$WM" in
    gnome-session)
      # `--session=box` es la sesion Ubuntu sin los componentes que necesitan
      # logind/ScreenSaver (ver el comentario donde se genera box.session). Con
      # `--session=ubuntu` a secas, gsd-power muere y gnome-session tapa la
      # pantalla con su dialogo "Oh no! Something has gone wrong".
      wm_session gnome-session --session=box && wait_for_wm && return 0
      warn "sesion box no levanto; pruebo la ubuntu de serie"
      wm_session gnome-session --session=ubuntu && wait_for_wm && return 0
      warn "gnome-session no levanto; cae a mutter (mira /tmp/wm.log)"
      ;;
    gnome-shell)
      wm_session gnome-shell --x11 --replace && wait_for_wm && return 0
      warn "gnome-shell no levanto; cae a mutter (mira /tmp/wm.log)"
      ;;
  esac
  wm_session mutter --x11 --replace && wait_for_wm && return 0
  return 1
}

start_wm || die "no levanto ninguna sesion en $DISPLAY_NUM — mira /tmp/wm.log"
log "WM: $(DISPLAY="$DISPLAY_NUM" wmctrl -m 2>/dev/null | head -1 || echo '(sin nombre)')"
log "modo: $WM"
sed -n '1,4p' /tmp/wm.log 2>/dev/null || true

# --- 4. x11vnc ---------------------------------------------------------------
log "x11vnc en $VNC_LISTEN:$VNC_PORT (display $DISPLAY_NUM, contrasena: dev)"
# `-noshm`: dentro del contenedor el X_ShmAttach falla con BadAccess y x11vnc
# se cae. La opcion se llama `-noshm`; `-noshmem` NO existe y hace abortar con
# "unrecognized option".
# `-onetile`: una pantalla redimensionable necesita un solo tile, si no salen
# costuras al redimensionar. `-noxdamage`: Xvfb no lo soporta bien.
# `-rfbauth`: contrasena `dev` (fichero generado en la imagen con vncpasswd).
# Sin el, `-nopw` dejaria la pantalla abierta a cualquiera que llegue al puerto.
as_dev env DISPLAY="$DISPLAY_NUM" HOME="$DEV_HOME" \
  x11vnc -display "$DISPLAY_NUM" -rfbport "$VNC_PORT" -localhost \
    -rfbauth "$DEV_HOME/.vnc/passwd" \
    -forever -shared -noxdamage -onetile -noshm -quiet \
    >/tmp/x11vnc.log 2>&1 &
VNC_PID=$!

# --- 4b. TightVNC como via alterna ------------------------------------------
# `Xvnc` de tightvncserver sirve un display propio en :2 con su VNC en 5901 y
# contrasena `dev`. Es una segunda puerta de entrada (util si x11vnc se atasca)
# y aporta `vncpasswd`/`vncviewer`. No sustituye a la principal: compartir el
# display :1 con x11vnc daria dos servidores VNC sobre el mismo framebuffer.
if [[ "${TIGHTVNC:-1}" == "1" ]]; then
  log "tightvncserver en 127.0.0.1:5901 (display :2, contrasena: dev)"
  # `USER` es obligatorio: tightvncserver aborta con "The USER environment
  # variable is not set" si falta (setpriv no lo pone).
  as_dev env HOME="$DEV_HOME" USER="$DEV_USER" \
    tightvncserver :2 -geometry "${SCREEN_GEOMETRY%x*}" -depth 24 \
      -rfbport 5901 -rfbauth "$DEV_HOME/.vnc/passwd" -localhost \
    >/tmp/tightvnc.log 2>&1 &
  TIGHTVNC_PID=$!
fi

# --- 5. noVNC ----------------------------------------------------------------
log "noVNC en http://localhost:$NOVNCPORT/vnc.html"
if [[ -d /usr/share/novnc ]]; then
  websockify --web /usr/share/novnc "$NOVNCPORT" "localhost:$VNC_PORT" \
    >/tmp/novnc.log 2>&1 &
else
  novnc_proxy --vnc localhost:"$VNC_PORT" --listen "$NOVNCPORT" \
    >/tmp/novnc.log 2>&1 &
fi
NOVNC_PID=$!

# --- 6. sshd -----------------------------------------------------------------
sed -i "s/^#\?Port .*/Port $SSHD_PORT/" /etc/ssh/sshd_config
/usr/sbin/sshd
SSHD_PID=$!
log "sshd en :$SSHD_PORT (usuario $DEV_USER)"

# --- listo -------------------------------------------------------------------
touch /tmp/.box-ready
log "CAJA LISTA — noVNC http://localhost:$NOVNCPORT/vnc.html | ssh $DEV_USER@localhost -p $SSHD_PORT"
log "build: scripts/build-linux.sh --remote $DEV_USER@localhost --target aarch64 --debug --run"

# PID 1 no puede salir o el contenedor muere. Supervision POR ROL, no por "ha
# muerto algun PID de la lista": antes un unico array reiniciaba el WM en
# cuanto moria CUALQUIER hijo, y como `dbus-run-session`/`runuser` dejaban PIDs
# intermediarios, tumbaba un mutter sano y la caja se caia en cascada. Ahora cada
# rol se vigila por su PID real y el WM se rearma solo si de verdad no esta
# tomando la pantalla. Si se muere Xvfb no hay autoreparacion (habria que
# relanzar todo el display): se avisa y se deja que la caja decida.
while true; do
  if ! kill -0 "$XVFB_PID" 2>/dev/null; then
    warn "Xvfb murio; el display se fue — reinicia la caja (linux-box.sh up)"
  fi
  # El bus primero: sin el, gnome-shell se queda con la pantalla de error
  # aunque el proceso siga vivo, y relanzar el WM no arreglaria nada.
  if ! bus_alive; then
    restart_bus
    start_wm || warn "no se pudo relanzar el WM tras reiniciar el bus"
  fi
  if ! kill -0 "$WM_PID" 2>/dev/null \
     || ! DISPLAY="$DISPLAY_NUM" wmctrl -m >/dev/null 2>&1; then
    warn "el WM no esta; rearmando"
    # Nunca `die` aqui: el contenedor murio antes por eso y perdia el display,
    # las caches y la sesion ssh. Reintentar para arriba es lo que toca.
    start_wm || warn "no se pudo recuperar el WM todavia (reintento en 5s)"
  fi
  if ! kill -0 "$VNC_PID" 2>/dev/null; then
    warn "x11vnc murio; noVNC se queda sin pantalla — reinicia la caja"
  fi
  if ! kill -0 "$SSHD_PID" 2>/dev/null; then
    warn "sshd murio; rearmando"
    /usr/sbin/sshd && SSHD_PID=$!
  fi
  sleep 5
done
