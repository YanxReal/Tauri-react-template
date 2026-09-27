# Scripts y tooling

> **Audiencia:** todos — qué correr y cuándo.

## Scripts raíz

`package.json:11`:

| Comando | Ejecuta |
|---------|---------|
| `pnpm dev` | `turbo dev` (web, TUI) |
| `pnpm build` | `turbo build` |
| `pnpm lint` | `biome check .` |
| `pnpm lint:fix` | `biome check --write .` |
| `pnpm format` / `pnpm format:check` | igual que lint (Biome también formatea) |
| `pnpm typecheck` | `turbo typecheck` |
| `pnpm test` | `turbo test` (vitest) |
| `pnpm tauri` | `tauri` (passthrough CLI) |
| `pnpm tauri:dev` / `pnpm tauri:build` | `tauri dev` / `tauri build` |

`Makefile`:

| Target | Efecto |
|--------|--------|
| `make dev` | `tauri dev` (desktop), respeta `APPLE_SIGNING_IDENTITY` |
| `make dev:web` | `pnpm --filter web dev` |
| `make dev:ios` | `pnpm tauri ios dev "iPhone 17"` (sim, usa `IOS_DEVICE`) |
| `make dev-ios-physical` | `cargo tauri ios dev "iPhone 17" --host $(IOS_DEV_HOST)` (necesita `make install-tauri-cli`) |
| `make dev-android-emulator` | arranca `$ANDROID_AVD` + `tauri android dev --target $ANDROID_TARGET` |
| `make gen-apple` | `scripts/Xcode/apple-xcode.sh` (xcodegen → `gen/apple`) |
| `make install-tauri-cli` | Compila `src-tauri/vendor/tauri-cli-2.12.0` (2.12.0 stock + 3 retoques: fallback standalone, target `_Apple`) → `~/.cargo/bin/cargo-tauri` |
| `make lint` / `make build` | alias |

Shells por OS: `scripts/build-linux.sh`, `scripts/build-windows.sh`, `scripts/Xcode/apple-xcode.sh`.

## Build Linux (`scripts/build-linux.sh`)

Construye los bundles de Linux y puede compilar **y lanzar** la app en una caja Linux por
SSH. Dos backends: `--remote [HOST]` (empuja por SSH y compila allí) y `--native` (compila en
un host Linux). Sin flag de modo: nativo en Linux, remoto si la caja responde — y si la caja
no está accesible el script para con instrucciones en vez de compilar en otro sitio.

| Flag | Efecto |
|------|--------|
| `--remote [HOST]` | rsync → caja SSH (por defecto `$LINUX_BUILD_REMOTE` o `ubuntu-vnc`) |
| `--native` | compila en este host (debe ser Linux) |
| `--release` / `--debug` | perfil de compilación (release por defecto; debug es mucho más rápido) |
| `--dev` | `tauri dev` (Vite + app, hot reload) en vez de un bundle; implica `--debug` |
| `--run` | tras compilar, lanza la app en el display indicado |
| `--bundles LIST` | `deb` (por defecto) \| `appimage` \| `rpm` \| `all` |
| `--target ARCH` | `aarch64` \| `x86_64` \| un triple de rust (debe coincidir con la caja) |
| `--display :N` | display X para `--dev`/`--run` (por defecto `:1`) |
| `--fetch` | copia los bundles de vuelta a `./dist-linux` |
| `--sync-only` / `--no-sync` | solo empuja las fuentes / reutiliza lo que ya hay en remoto |
| `--logs` / `--stop` | sigue / mata el dev server o la app en remoto (solo remoto) |

```bash
./scripts/build-linux.sh --remote --dev                  # compila + lanza en la caja
./scripts/build-linux.sh --remote --debug --run          # build rápido y lanza
./scripts/build-linux.sh --remote --release --bundles all --fetch
./scripts/build-linux.sh                                 # auto: remoto, o nativo en Linux
./scripts/build-linux.sh --native                        # fuerza un build local en Linux
```

El backend remoto usa `pnpm tauri` (la CLI fijada en `devDependencies`, así que no hay paso
`cargo install tauri-cli`) y espera que la caja tenga Rust, Node 24 y las cabeceras de
desarrollo de WebKitGTK/GTK. Cubre todo el ciclo por SSH: build (release o debug), `--dev`,
`--run`, `--logs` y `--stop`. El sync usa `rsync` si ambos extremos lo tienen y cae a `tar`
si no.

Como la caja mantiene `node_modules` y `target/` en disco, los rebuilds son incrementales
(segundos) y `--dev` da Vite + hot reload; se descartó un backend de contenedor por build
porque nunca podría ejecutar la app para probarla.

## La caja Linux

La caja actual es **[Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker)** (repo aparte): escritorio Ubuntu 26.04 + GNOME 50 (Wayland) en Docker para arm64, con noVNC, VNC nativo, SSH y toolchain Tauri v2 lista. Ahí es donde se compila y se mira la app ahora.

| | |
|---|---|
| Repo | [YanxReal/Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker) (`make install`) |
| noVNC / VNC / SSH | `http://localhost:6080/vnc.html` · `localhost:5902` · `ssh ubuntu-arm` (alias en `~/.ssh/config`, usuario `admin`, clave) |
| Ruta del proyecto | `/workspace/tauri-react-template` (bind `./workspace`) |
| Lanzar apps GUI | wrapper `dev <cmd>` (inyecta `WAYLAND_DISPLAY` + bus de sesión) |

Apúntala con el script de este repo (sync + build). Ojo: `--run`/`--dev` asumen un `DISPLAY` X11, así que en esta caja Wayland lanza vía `dev`:

```bash
LINUX_BUILD_DIR=/workspace/tauri-react-template ./scripts/build-linux.sh --remote ubuntu-arm --debug
# luego en la caja (sin GPU — render por software):
WEBKIT_DISABLE_COMPOSITING_MODE=1 LIBGL_ALWAYS_SOFTWARE=1 dev ./src-tauri/target/debug/tauri-react-template
```

### Caja mínima del repo (`docker/linux-gnome` + `scripts/linux-box.sh`)

Alternativa ligera X11 (Xvfb) que vive en este repo: Ubuntu 24.04 (GNOME 46 / mutter / GTK3 / WebKitGTK 4.1 — el stack exacto contra el que se verificó el trabajo del marco de ventana), la **sesión GNOME de Ubuntu** sobre Xvfb, y noVNC para que puedas *ver* la ventana.

```bash
./scripts/linux-box.sh up        # compila la imagen (primera vez) + crea + arranca
./scripts/linux-box.sh status    # display, WM, VNC, ssh, política de restart
./scripts/linux-box.sh down      # la para, CONSERVA el contenedor (caches siguen)
./scripts/linux-box.sh destroy   # la borra (--volumes: pierde caches de cargo/pnpm)
./scripts/linux-box.sh wait      # espera a que display + WM + ssh respondan
./scripts/linux-box.sh ssh       # shell en la caja
./scripts/linux-box.sh build …   # atajo de build-linux.sh --remote
./scripts/linux-box.sh app [--opaque]   # compila + lanza la app en :1
./scripts/linux-box.sh novnc     # imprime la URL de noVNC
```

**No arranca solo.** El contenedor se crea con `--restart=no`, así que Docker Desktop
puede arrancar con la caja parada; la levantas cuando la necesites. `down` conserva el
contenedor (y su `target/`, para que el próximo build sea incremental); solo `destroy`
lo borra.

| Pieza | Dónde | Notas |
|-------|-------|-------|
| Imagen | `docker/linux-gnome/Dockerfile` | Ubuntu 24.04 + dev de WebKitGTK 4.1 + Node 24 + pnpm 10.34.5 + Rust estable + `ubuntu-session` + mutter + x11vnc/TightVNC/noVNC + openssh |
| PID 1 | `docker/linux-gnome/entrypoint.sh` | Xvfb → dbus → sesión → x11vnc → TightVNC → noVNC → sshd, y luego supervisa cada rol |
| Control | `scripts/linux-box.sh` | up/down/destroy/status/wait/ssh/novnc/logs/build/app |
| SSH | `~/.ssh/config`, alias `ubuntu-vnc` | `127.0.0.1:2222`, usuario `dev` (nunca root: gnome-shell aborta como root) |
| Puertos | `2222` ssh, `6080` noVNC, `5901` TightVNC | ligados a `127.0.0.1`; el x11vnc crudo (5900) se queda dentro del contenedor |
| Contraseña | `dev` | una sola para las dos puertas: noVNC (que la reenvía a x11vnc) y TightVNC |
| Caches | volúmenes con nombre | `tauri-cargo-registry`, `tauri-cargo-git`, `tauri-pnpm-store` |

Abre **http://localhost:6080/vnc.html** para ver y controlar el escritorio (contraseña
`dev`). Para un cliente nativo usa TightVNC contra `127.0.0.1:5901`, misma contraseña.
`DISPLAY=:1` queda exportado en toda sesión (vía `/etc/environment`, así que un
`ssh host 'cmd'` a secas también lo recibe), y hay `scrot` / `xdotool` / `wmctrl` /
`xrandr` para capturas y comprobaciones guionizadas.

### Hacer que GNOME funcione en un contenedor (medido, no supuesto)

Poner en pie una sesión GNOME real bajo Xvfb llevó varias rondas de medición a nivel de
píxel. Cada punto de abajo se verificó comparando capturas (`standard_deviation` por fila:
una pantalla congelada da `0` en todas); también queda registrado el valor equivocado, para
que nadie lo reintroduzca.

| Síntoma | Causa | Arreglo |
|---------|-------|---------|
| `Failed to get session bus: The connection is closed`; la sesión cae a mutter a pelo | el bus de sesión lo arrancaba **root**; `dbus-daemon --session` solo deja conectar al usuario que lo creó | arrancarlo como el usuario de la sesión (`setpriv --reuid=dev …`) |
| El shell vive y responde por D-Bus, pero la pantalla se **congela** en un color y abrir una ventana cambia 0 px | el bus se arrancaba dentro de `$(…)`: el daemon heredaba la tubería de la sustitución, se bloqueaba escribiendo en ella y se **colgaba** (socket y proceso vivos, sin respuestas) | `--address=` fijo + salida redirigida a un **fichero**, nunca a una tubería |
| `gnome-shell` muere con **signal 11** al arrancar (`background.js` → `loginManager.js`) | `misc/loginManager.js` elige `LoginManagerSystemd` si existe `/run/systemd/seats`; sin logind la llamada lanza excepción y `main.js` aborta | `rm -rf /run/systemd` (systemd no corre en el contenedor) |
| `gnome-session` muestra su diálogo de fallo; no encuentra la sesión `ubuntu` | sin el paquete `ubuntu-session` solo existe `gnome.session`, y el único modo del shell es `ubuntu.json` | instalar `ubuntu-session` + `ubuntu-settings` |
| La sesión arranca pero la pantalla queda plana | `GNOME_SHELL_SESSION_MODE=x11` — **ese modo no existe** (válidos: `ubuntu`, `gnome`); `gnome-shell --x11` es un flag, no un modo | `GNOME_SHELL_SESSION_MODE=ubuntu` + el entorno de Ubuntu (`XDG_CURRENT_DESKTOP=ubuntu:GNOME`, `DESKTOP_SESSION=ubuntu`, `XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg`) |
| **Toda la pantalla tapada por "Oh no! Something has gone wrong" y los clics no hacen nada** | muere un componente listado en `RequiredComponents` de `ubuntu.session`: `org.gnome.SettingsDaemon.Power` (necesita **logind**) y `org.gnome.SettingsDaemon.ScreensaverProxy` (necesita `org.gnome.ScreenSaver`), más `UsbProtection`, que hace SIGSEGV por lo mismo. `gnome-session` entonces declara la sesión fallida y `gnome-session-failed` dibuja esa pantalla a pantalla completa (una ventana de 1600x1000 — se ve en `xwininfo -root -tree`) | el entrypoint escribe `box.session` en `/usr/local/share/gnome-session/sessions/` quitando esos componentes de portátil de `RequiredComponents`, y corre `gnome-session --session=box`. Se comprueba con `grep -c gnome-session-failed` sobre el árbol de ventanas: tiene que dar **0** |
| El escritorio renderiza una vez y luego se congela para siempre | `GSK_RENDERER=cairo` fuerza GTK4 a Cairo y GNOME Shell 46 necesita GL para su compositor | no ponerlo — llvmpipe ya es software, lo que el shell quiere es GL |
| El mismo congelado, introducido "arreglando" el overview | `MESA_GL_VERSION_OVERRIDE=4.5` / `MESA_GLSL_VERSION_OVERRIDE=450` | no ponerlos; `glxinfo -B` ya informa `Max core profile version: 4.5` |
| `dbus-send`/las apps no alcanzan el bus de accesibilidad | falta `at-spi2-core` (y se puso `NO_AT_BRIDGE=1`) | instalar `at-spi2-core`, no desactivar el bridge |
| `x11vnc` sale con `BadAccess` en `X_ShmAttach` | MIT-SHM no puede attach dentro del contenedor | `-noshm` (el flag **no** es `-noshmem`, que aborta como opción desconocida) |
| `tightvncserver` aborta: `The USER environment variable is not set` | `setpriv` no define `USER` | pasar `USER=dev` |
| La sesión funciona pero **no hay dock**, ni iconos de bandeja, ni iconos de escritorio | el modo `ubuntu` del shell pide `ubuntu-dock@ubuntu.com`, `ubuntu-appindicators@ubuntu.com` y `ding@rastersoft.com` en `/usr/share/gnome-shell/modes/ubuntu.json`, pero `--no-install-recommends` se saltó los tres paquetes | instalar `gnome-shell-extension-ubuntu-dock`, `gnome-shell-extension-appindicator`, `gnome-shell-extension-desktop-icons-ng`. El dock se comprueba con `convert shot.png -crop 1x1000+40+0` → `standard_deviation` ~17 en vez de ~5 |

Merece la pena repetir lo de `GSK_RENDERER` y los overrides de Mesa: los dos se añadieron
como arreglos y los dos **causaron** el congelado que pretendían curar. La regla que salió
de ahí es medir antes y después con la `standard_deviation` por fila, en vez de fiarse de
una variable que suena plausible.

## Cross-compile Windows (`cargo-xwin`)

`scripts/build-windows.sh [--bundles nsis] [args de tauri build]` construye el bundle Windows x64 desde macOS/Linux — resuelve él mismo las rutas keg-only de LLVM/lld y llama a `pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles nsis`.

Setup una sola vez: `brew install llvm lld makensis` (macOS; `makensis` solo hace falta para el bundle NSIS), `cargo install cargo-xwin --locked` y `rustup target add x86_64-pc-windows-msvc`. Salidas: `src-tauri/target/x86_64-pc-windows-msvc/release/tauri-react-template.exe` (app) y `.../bundle/nsis/tauri-react-template_0.1.0_x64-setup.exe` (instalador; ~200 MB porque `webviewInstallMode: offlineInstaller` embebe WebView2).

Notas: el bundler MSI/WiX solo corre en un host Windows (`--bundles nsis` es el default en macOS/Linux); firmar el instalador también requiere Windows salvo que definas `bundle > windows > signCommand`. `cargo xwin check --target x86_64-pc-windows-msvc` es la vía rápida para type-checkear el código Windows.

## Helper Xcode

`scripts/Xcode/apple-xcode.sh` (`scripts/README.md:8`):

- Resuelve el sentinel `DEVELOPMENT_TEAM` → ID real (env `DEVELOPMENT_TEAM` > `scripts/.team-id` > omitido).
- Corre `xcodegen` → `src-tauri/gen/apple`.
- Con `--build` también compila iOS sim + macOS host.

Ver `docs/es/mobile.md` para configs y el parche `cargo-mobile2` de Xcode 26.

## Lint y format (Biome)

`biome.json:1`:

- `formatter: indentStyle space, indentWidth 2, lineWidth 80, lineEnding lf`
- `linter.rules: preset recommended` + `noUnusedVariables:warn`, `noExplicitAny:warn`, `useImportType:error`
- `javascript.formatter: quoteStyle double, semicolons asNeeded, trailingCommas es5`
- `overrides`: desactiva linter/formatter dentro de `src-tauri/**` y `packages/ui/src/components/**` + `apps/web/src/components/*.tsx`

```bash
pnpm lint
pnpm lint:fix
pnpm format:check
biome check --write .   # directo
```

## Git hooks

`package.json:23` `prepare: husky`:

- `.husky/pre-commit` → `lint-staged`
- `lint-staged:25` — `*.{ts,tsx,js,jsx,json,jsonc,css}` → `biome check --write --no-errors-on-unmatched`

## CI

`.github/workflows/frontend.yml:1` — en PR/push que toque `apps/web/**`, `packages/**`: `pnpm install` → `typecheck` → `lint` → `test` → `build` (Node 24, pnpm 10).

`.github/workflows/rust.yml:1` — en PR/push que toque `src-tauri/**`, `rust-toolchain.toml`: `cargo check` + `cargo fmt --check` (stable + cache).

## Pines Node / pnpm

- `.nvmrc` + `.node-version` — Node 24
- `.npmrc` — ajustes pnpm
- `pnpm-lock.yaml` frozen en CI (`--frozen-lockfile`)

Siguiente: [Solución de problemas →](./troubleshooting.md)
