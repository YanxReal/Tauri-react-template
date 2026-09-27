# syntax=docker/dockerfile:1
#
# docker/linux-gnome/Dockerfile
# Caja Linux de build + pruebas para tauri-react-template.
#
# Ubuntu 24.04 (GNOME 46 / mutter / GTK3 / WebKitGTK 4.1) — la combinacion
# exacta contra la que se verifico el marco CSD del proyecto (ver
# docs/en/native-feel.md §0). Corre la sesion GNOME sobre Xvfb, expone la
# pantalla por noVNC para poder MIRAR la ventana, y acepta SSH para que
# scripts/build-linux.sh --remote compile ahi.
#
# No arranca solo: el contenedor se crea con --restart=no (ver
# scripts/linux-box.sh up|down). Docker puede arrancar sin que la caja levante.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    DISPLAY=:1 \
    SCREEN_GEOMETRY=1600x1000x24 \
    NOVNCPORT=6080 \
    VNC_PORT=5900 \
    WM=gnome-session \
    DESKTOP_APPS=1

# --- 1. Sistema + toolchain de Tauri ----------------------------------------
# El segundo RUN con apt evita la caché de capa cuando cambian los headers de
# WebKitGTK (lo que se recompila mas a menudo).
RUN apt-get update && apt-get install --no-install-recommends -y \
      ca-certificates curl wget gnupg git rsync sudo tzdata locales \
      build-essential pkg-config file \
      libwebkit2gtk-4.1-dev \
      libgtk-3-dev libssl-dev libxdo-dev librsvg2-dev \
      libayatana-appindicator3-dev patchelf \
      xdg-utils desktop-file-utils \
 && rm -rf /var/lib/apt/lists/*

# --- 2. Sesion grafica: mutter (WM) + Xvfb + VNC -----------------------------
# POR QUE mutter y NO gnome-session (que es el WM "de verdad" de GNOME):
# con render por software (llvmpipe) la sesion completa de GNOME Shell es
# INESTABLE en un contenedor. Medido aqui:
#   - el overview de Activities se abre pero se dibuja plano (96% de un color);
#   - al interactuar, gnome-shell lanza su dialogo de crash "Oh no! Something
#     has gone wrong" y deja el escritorio inservible;
#   - aparece una ventana `gnome-session-failed`, o sea que la sesion ya ha
#     fallado al menos una vez.
# Arreglar eso es pelearse con el render de gnome-shell sobre llvmpipe, y no
# es lo que hace falta aqui: lo que hace falta es VER e INTERACTUAR con la
# ventana de la app.
#
# mutter es el WM+compositor de GNOME: el mismo que resuelve CSD, la sombra y
# `_GTK_THEME_VARIANT`, o sea justo lo que hay que probar, y es estable. Para
# que se parezca a un escritorio de verdad se le anade:
#   - tint2: un panel (barra) con menu, reloj y lanzadores, clicable.
#   - xterm / gnome-terminal / nautilus: apps reales para abrir y usar.
#   - x11-apps (xeyes, xclock): utilidades clasicas para comprobar el WM.
# `LINUX_BOX_WM=gnome-session` o `WM=gnome-shell` levantan el shell completo si
# prefieres probarlo, sabiendo que puede caer.
RUN apt-get update && apt-get install --no-install-recommends -y \
      xvfb x11vnc tightvncserver x11-utils x11-xserver-utils xdotool wmctrl scrot imagemagick \
      novnc websockify \
      dbus-x11 dbus-user-session \
      gnome-shell gnome-session gnome-session-bin gnome-settings-daemon \
      ubuntu-session ubuntu-settings \
      gnome-shell-extension-ubuntu-dock \
      gnome-shell-extension-appindicator \
      gnome-shell-extension-desktop-icons-ng \
      gnome-control-center \
      dconf-gsettings-backend dconf-cli \
      gsettings-desktop-schemas adwaita-icon-theme gnome-themes-extra \
      mutter \
      at-spi2-core \
      gnome-terminal nautilus gnome-text-editor eog gnome-calculator \
      x11-apps xfonts-base xterm \
      tint2 \
      fonts-dejavu-core fonts-liberation2 \
      policykit-1 \
 && rm -rf /var/lib/apt/lists/*

# --- 3. Usuario de trabajo `dev` ---------------------------------------------
# gnome-shell aborta si geteuid()==0, asi que la sesion grafica (y el build por
# SSH) corre como este usuario. sudo sin password para lo puntual.
# uid 1000 ya lo ocupa `ubuntu` en la imagen base: dejamos que useradd elija.
RUN useradd -m -s /bin/bash dev \
 && echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev \
 && chmod 440 /etc/sudoers.d/dev \
 && mkdir -p /home/dev/.ssh /home/dev/tauri-react-template \
 && chmod 700 /home/dev/.ssh && chown -R dev:dev /home/dev

# --- 4. Node 24 + pnpm (mismas versiones que exige el repo) ----------------
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
 && apt-get install --no-install-recommends -y nodejs \
 && rm -rf /var/lib/apt/lists/* \
 # pnpm queda pineado a la version del repo (packageManager: pnpm@10.34.5).
 # `corepack prepare --activate` solo no basta: fuera de un proyecto con
 # package.json, `pnpm -v` resuelve a la ultima publicada (12.x) y descenta.
 && corepack enable \
 && COREPACK_DEFAULT_TO_LATEST=0 corepack install --global pnpm@10.34.5 \
 && node --version && (cd /tmp && COREPACK_DEFAULT_TO_LATEST=0 pnpm --version)

# --- 5. Rust estable (misma toolchain que rust-toolchain.toml) ---------------
ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path --profile minimal \
 && rustc --version && cargo --version \
 && rustup target add aarch64-unknown-linux-gnu \
 && chown -R dev:dev /usr/local/cargo /usr/local/rustup

# --- 5. SSH: la caja se maneja por ssh (scripts/build-linux.sh --remote) ----
RUN apt-get update && apt-get install --no-install-recommends -y openssh-server \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /var/run/sshd \
 && printf 'Port 2222\nPermitRootLogin no\nPubkeyAuthentication yes\nPasswordAuthentication no\n' \
      > /etc/ssh/sshd_config.d/10-tauri-box.conf \
 && ssh-keygen -A

# --- 4b. contrasenas VNC (dev / dev) ----------------------------------------
# Una sola contrasena VNC, `dev`, compartida por los dos caminos:
#   - x11vnc (el que sirve la pantalla a noVNC) con `-rfbauth`
#   - tightvncserver, que aporta `Xvnc` + `vncpasswd` y sirve como via alterna
#     por VNC directo en :5901 si algun dia x11vnc molesta.
# El fichero de contrasena lo genera `vncpasswd -f` y lo lee x11vnc; no se puede
# fijar por env, tiene que ser un fichero con el hash ofuscado del protocolo.
# noVNC NO tiene contrasena propia: su pagina pide la del VNC, o sea `dev`.
RUN mkdir -p /home/dev/.vnc \
 && printf 'dev\n' | vncpasswd -f > /home/dev/.vnc/passwd \
 && chmod 600 /home/dev/.vnc/passwd \
 && chown -R dev:dev /home/dev/.vnc

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# DISPLAY + toolchain disponibles en toda sesion (ssh included). sshd arranca una
# sesion limpia y NO hereda el ENV del contenedor, asi que sin esto `rustc` no
# aparece por ssh (scripts/build-linux.sh lo exporta en su comando, pero para
# trabajar a mano hace falta aqui).
RUN printf '%s\n' \
      'export DISPLAY=:1' \
      'export CARGO_HOME=/usr/local/cargo' \
      'export RUSTUP_HOME=/usr/local/rustup' \
      'export PATH=/usr/local/cargo/bin:$PATH' \
      > /etc/profile.d/tauri-box.sh \
 && chmod 644 /etc/profile.d/tauri-box.sh \
 && { printf '\n# caja Linux de pruebas (docker/linux-gnome)\n'; \
      cat /etc/profile.d/tauri-box.sh; } >> /home/dev/.bashrc \
 && chown dev:dev /home/dev/.bashrc \
 # /etc/environment lo lee pam_env, y ese SI se aplica a `ssh host 'cmd'`
 # (no interactivo, no login): ni /etc/profile.d ni ~/.bashrc se leen ahi, asi
 # que sin esto `ssh ubuntu-vnc 'cargo test'` no encuentra cargo.
 && printf '%s\n' \
      'DISPLAY=:1' \
      'CARGO_HOME=/usr/local/cargo' \
      'RUSTUP_HOME=/usr/local/rustup' \
      'PATH=/usr/local/cargo/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games' \
      >> /etc/environment \
 && chown dev:dev /usr/local/cargo /usr/local/rustup

# Display + puertos: 2222 ssh, 6080 noVNC. 5900 (VNC crudo) queda en localhost.
EXPOSE 22 2222 6080

# El entrypoint es el PID 1:xwfb -> wm -> vnc -> novnc -> sshd.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
