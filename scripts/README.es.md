# Scripts — Helpers multiplataforma

> 🌐 **Idioma:** **Español** | [English](README.md)

Automatización del repo: shells de build por SO, tooling Xcode, parcheo del CLI. El `Makefile`
(en la raíz) es la fuente de verdad para los comandos diarios de dev/build; los
ficheros de aquí los implementan.

- [Inventario](#-inventario)
- [Build por SO](#-build-por-so)
- [Xcode unificado](#-xcode-unificado-ios--macos-en-un-target)
- [Firma / DEVELOPMENT_TEAM](#-firma--development_team-auto-inyección)
- [CLI](#-cli)
- [Hot reload (IPC completo)](#-hot-reload-ipc-completo--tauri-ios-dev)

Relacionado: [`docs/es/scripts.md`](../../docs/es/scripts.md) (referencia de flags),
[`docs/es/mobile.md`](../../docs/es/mobile.md) (flujos iOS/Android),
[`MODS.md`](../../MODS.md) (modificaciones del CLI vendoreado).

## 📋 Inventario

| Script | Propósito |
|---|---|
| `scripts/build-linux.sh` | Bundles Linux; compila + lanza en caja Linux por SSH (`--remote`) o en local (`--native`). Perfiles `--release`/`--debug`; `--dev`, `--run`, `--fetch`, `--logs`, `--stop` |
| `scripts/build-windows.sh` | Cross-compile Windows x64 desde macOS/Linux (`cargo-xwin` + NSIS) |
| `scripts/box-shot.sh` | Captura de la caja Ubuntu-arm-docker por VNC (`VNC_PASSWORD`, default `/tmp/box-shot.png`) |
| `scripts/patch-tauri-cli.sh` | Aplica los 3 retoques locales sobre una copia stock de `tauri-cli` (rechaza versiones desconocidas) |
| `scripts/Xcode/apple-xcode.sh` | Regenera `src-tauri/gen/apple` (xcodegen); `--build` además compila sim iOS + host macOS |
| `scripts/Xcode/xcode-dev-parent.command` | Lanzador doble-clic de `tauri ios dev --open` (Terminal) |
| `apps/web/scripts/xcode/xcode-dev-server.command` | Servidor Vite doble-clic (`:1420` + HMR) |

Inputs de build de apoyo (no son scripts, pero parte del sistema):

- `src-tauri/build.rs` compila `Assets.xcassets` vía `actool` cuando el tooling de Xcode está presente; si no, cae a `icon.icns` con un `cargo:warning`.
- `rust-toolchain.toml` fija `stable` + targets `aarch64-apple-ios*` y Android para `cargo check --target ...` y los builds móviles.
- `src-tauri/Assets.xcassets` + `Info.plist` + `tauri.macos.conf.json` (`titleBarStyle Overlay`, `transparent`) replican la capa genérica macOS/Xcode.

## 🔨 Build por SO

| Script | Qué hace |
|---|---|
| `scripts/build-linux.sh` | Bundles Linux más compilar/lanzar. Backends `--remote [HOST]` (SSH, vía principal) y `--native`. Perfiles `--release`/`--debug`; extras `--dev`, `--run`, `--fetch`, `--logs`, `--stop`. Flags completos: `docs/es/scripts.md`. |
| `scripts/build-windows.sh` | Cross-compile Windows x64 desde macOS/Linux (`cargo-xwin` + NSIS). Setup una sola vez: `brew install llvm lld makensis`, `cargo install cargo-xwin --locked`, `rustup target add x86_64-pc-windows-msvc`. MSI/WiX necesita host Windows. |

## 📱 Xcode unificado (iOS + macOS en UN target)

La fuente de verdad del proyecto Xcode es el template:

    src-tauri/vendor/tauri-cli-2.12.0/templates/mobile/ios/

`src-tauri/gen/apple` se regenera **completo** desde ahí (gitignored, NO persiste):

    scripts/Xcode/apple-xcode.sh             # regenera + xcodegen
    scripts/Xcode/apple-xcode.sh --build     # además compila sim iOS (vía CLI) + host macOS

Regla: editar SIEMPRE el template (`project.yml`, `apple.xcconfig`, entitlements, `Assets.xcassets`),
NUNCA el `.xcodeproj` generado ni su Info.plist.

- Target único `tauri-react-template_Apple`, destinos iOS + macOS vía `apple.xcconfig`
  (`SUPPORTED_PLATFORMS = macosx iphoneos iphonesimulator`) con branches
  `PLATFORM_NAME` en la phase "Build Rust Code".
- **Tres configs de build** (XcodeGen `configs:`): `debug`, `release` y `hotreload`.
  La phase ("Build Rust Code") elige el pipeline:
  - macOS → standalone (`cargo build --lib` del host). `debug`/`release` embeben el
    frontend (`custom-protocol`); `hotreload` abre la Terminal en primer plano con Vite
    (`apps/web`, devUrl :1420 + HMR) y compila la app SIN custom-protocol para que
    consuma el dev server → `Externals/macosx/...`.
  - iOS `debug` → **igual que release pero rápido**: standalone con el frontend
    embebido (`--features tauri/custom-protocol`) como release, **sin Vite ni CLI**:
    la app completa corre y ⌘R incremental = compilación rápida de solo Rust (el
    JS no se toca salvo que cambie el dist). Para HMR usa `hotreload`.
  - iOS `hotreload` → hot reload honesto: primero **sondea** el parent
    `tauri ios dev --open` con un handshake WebSocket JSON-RPC real y timeout 1.5s
    sobre el fichero IPC de address
    (`$TMPDIR/com.tauri-react-template.app-server-addr` — el CLI monta un server
    jsonrpsee con el método `options`). Si responde → corre `xcode-script`
    (IPC completo: features, merges de config, `TAURI_DEV_HOST`…). Si no (addr
    stale apuntando p.ej. al WS de Vite, puerto cerrado o sin fichero — el
    `read_options` stock colgaría Xcode para siempre, por eso este probe NUNCA
    deja que el build se cuelgue) → abre en Terminal el parent
    `tauri ios dev --open` (con `--host <LAN>` para device físico), espera ~40s
    y reintenta. Sin parent → abre la terminal del dev server
    (`apps/web/scripts/xcode/xcode-dev-server.command`), avisa y cae a standalone.
  - `release` → standalone con `--features tauri/custom-protocol` para
    producción (compila desde cero: correcto para release).
- Terminal en primer plano sin AppleScript: la phase usa `open -a Terminal
  <script>.command` (LaunchServices → sin permisos TCC, `open` nunca bloquea
  la phase). Dos runscripts en el repo (sobreviven a la regen):
  `apps/web/scripts/xcode/xcode-dev-server.command` (Vite :1420 + HMR) y
  `scripts/Xcode/xcode-dev-parent.command` (`tauri ios dev --open`, con
  `--host <LAN>` si hay red).
- Aviso de doble Vite: en hotreload, el parent levanta Vite (su
  `beforeDevCommand`) y falla si `:1420` ya está ocupado
  ("beforeDevCommand terminated with a non-zero..."). No dejes un Vite
  preview/dev previo corriendo antes de lanzar la config `hotreload`.
- `xcode-script` de cargo-mobile stagea `Externals/<arch>/<PROFILE>` (`debug`
  para todo lo que no sea release); la phase además copia ese lib al path por
  SDK que enlaza el target (`Externals/<PLATFORM_NAME>/<CONFIGURATION>`), para
  que el lib fresco siempre gane.
- Cerrar `hotreload` (⌘. / terminar app) **no** cierra el parent:
  `tauri ios dev --open` queda durmiendo (~24h) con su server IPC de options y
  su Vite en `:1420`. Para liberar puertos: cerrar la ventana de Terminal (⌘W)
  o Ctrl+C → SIGHUP mata al parent y a Vite. El addr file stale no rompe nada:
  el probe lo descarta rápido (puerto cerrado). `hotreload` también compila
  rápido: Rust incremental en debug + HMR de Vite (solo el primer build desde
  cero es largo).
- Así el botón "Run" de Xcode significa: `debug`/`release` = app completa
  standalone sin CLI padre (debug rápido, release optimizado); `hotreload` =
  auto-abre la Terminal con el parent y hace HMR real de frontend (y Rust en
  device físico).
- Scheme `tauri-react-template_Apple` para Xcode/macOS. Scheme
  `tauri-react-template_iOS` (shim que construye el target `_Apple`) +
  `_iOS/Info.plist`: requeridos por cargo-mobile2, que usa `config.scheme()`
  = `<app>_iOS` para `tauri ios dev|build`.
- Entitlements estáticos por plataforma (ios.entitlements / macos.entitlements)
  vía `CODE_SIGN_ENTITLEMENTS[sdk=...]`.

## 🔏 Firma / DEVELOPMENT_TEAM (auto-inyección)

El template **nunca hardcodea el Team ID**: lleva un sentinel
`__TAURI_DEVELOPMENT_TEAM__` que `scripts/Xcode/apple-xcode.sh` resuelve ANTES
de `xcodegen`, sobre la copia en `gen/`. Prioridad:

1. env `DEVELOPMENT_TEAM`
2. fichero `scripts/.team-id` (gitignored, persiste entre regeneraciones)
3. ninguno → la línea se omite y el team se elige a mano en Xcode

Cuándo hace falta team: SIEMPRE el pipeline `tauri ios dev|build`
(cargo-mobile transita por device + archive/export — Xcode moderno lista los
sims vía `devicectl` como devices). No hace falta para builds directos de
Xcode sobre **sim** (firma ad-hoc `-`/Manual vía
`CODE_SIGN_STYLE[sdk=iphonesimulator*]`) ni para macOS.

Cómo hacerlo (elige UNA opción):

```bash
# (1) una vez: una sola generación con team
DEVELOPMENT_TEAM=ABCDE12345 scripts/Xcode/apple-xcode.sh

# (2) durable: escribe el team y regenera (recomendado)
echo ABCDE12345 > scripts/.team-id
scripts/Xcode/apple-xcode.sh

# (3) a mano: sin config, regeneras y eliges en Xcode →
#     Target → Signing & Capabilities. OJO: la elección manual se pierde al
#     regenerar (gen/ se reconstruye completo) → para persistir usa .team-id.
```

Tu Team ID se ve en Xcode → Target → Signing & Capabilities (o Apple ID →
Membership Details). Verificar que Xcode lo recibió:

```bash
xcodebuild -project src-tauri/gen/apple/tauri-react-template.xcodeproj \
  -scheme tauri-react-template_Apple -configuration Debug \
  -showBuildSettings | grep DEVELOPMENT_TEAM        # → "DEVELOPMENT_TEAM = ABCDE12345"
```

Sin team configurado el grep no debe devolver nada (elección manual).

## 🧰 CLI

El `cargo-tauri` para flujos iOS se compila del `tauri-cli 2.12.0`
vendoreado (stock + 3 retoques locales: fallback standalone, target `_Apple`
— ver `MODS.md` en la raíz):

```bash
make install-tauri-cli   # compila vendor/tauri-cli → ~/.cargo/bin/cargo-tauri
cargo tauri ios dev "iPhone 17"
```

Para operaciones stock puntuales (sin retoques locales):

```bash
pnpm dlx @tauri-apps/cli@2.12.0 ios build --target aarch64-sim --debug
pnpm dlx @tauri-apps/cli@2.12.0 android build --debug --target aarch64
```

### Hot reload (IPC completo) — `tauri ios dev`

El dev frontend de `apps/web` escucha en TODAS las interfaces (`host: true` en
`vite.config.ts`): `tauri ios dev` negocia el devUrl con una IP de red del
host y debe poder consultar el server en esa IP.

- **iPhone físico**: `tauri ios dev --host 192.168.x.x "iPhone 17"` →
  build+archive+export+install vía xcodebuild/devicectl + hot reload de Rust
  (watcher del CLI). La config `hotreload` del proyecto usa la misma forma: si
  el parent no está vivo, la phase lo abre en Terminal con `--host <LAN>`
  (por eso el fix de Vite `host: true`).
- **Simulador**: desde Xcode 26, `devicectl` lista los sims como devices y
  cargo-mobile intentaba `devicectl device install app` en un sim → no
  soportado ("Install Application is not supported"). Para SIM:
  `tauri ios dev --open` (mantiene el parent vivo: IPC + options) y corre la
  config `hotreload` del scheme `tauri-react-template_Apple` en Xcode con el
  sim → cada ⌘R compila por `xcode-script` con las options del parent y el
  frontend hace HMR por Vite. El auto-reload de Rust en sim queda limitado por
  el CLI upstream; `debug` conserva el camino standalone sin CLI. (Arreglado
  oficialmente para el listado en `cargo-mobile2 0.22.5`; ver `MODS.md`.)
