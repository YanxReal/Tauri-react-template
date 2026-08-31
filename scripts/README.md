# scripts — helpers multi-plataforma (adaptado de Prestly, genérico)

- `Makefile` en la raíz es la fuente de verdad para dev/build multi-OS.
- `src-tauri/build.rs` compila `Assets.xcassets` vía `actool` solo si Xcode está disponible; sin Xcode usa `icon.icns` y avisa con `cargo:warning` (escritorio funciona sin Xcode).
- `rust-toolchain.toml` fija `stable` + targets `aarch64-apple-ios*` y `android` para `cargo check --target ...` y los builds móviles.
- `src-tauri/Assets.xcassets` + `Info.plist` + `tauri.macos.conf.json` (`titleBarStyle Overlay`, `transparent`) replican la capa macOS/Xcode de Prestly pero genérica.

## Xcode unificado (iOS + macOS en UN target)

La fuente de verdad del proyecto Xcode es el template:

    src-tauri/vendor/tauri-cli-2.11.4/templates/mobile/ios/

`src-tauri/gen/apple` se regenera **completo** desde ahí (está gitignored y NO persiste):

    scripts/Xcode/apple-xcode.sh             # regenera + xcodegen
    scripts/Xcode/apple-xcode.sh --build     # además compila iOS sim (vía CLI) y macOS host

Regla: editar SIEMPRE el template (project.yml, apple.xcconfig, entitlements, Assets.xcassets),
NUNCA el `.xcodeproj` generado ni su Info.plist.

- Target único `tauri-react-template_Apple`, destinos iOS + macOS vía `apple.xcconfig`
  (`SUPPORTED_PLATFORMS = macosx iphoneos iphonesimulator`) y branches `PLATFORM_NAME`
  en la phase "Build Rust Code".
- **Tres configs de build** (XcodeGen `configs:`): `debug`, `release` y `hotreload`.
  La phase ("Build Rust Code") decide el pipeline:
  - macOS → standalone (`cargo build --lib` host). `debug`/`release` con frontend
    embebido (`custom-protocol`); `hotreload` abre la terminal en primer plano con Vite
    (`apps/web`, devUrl :1420 + HMR) y compila la app SIN custom-protocol para que
    consuma el dev server → `Externals/macosx/...`.
  - iOS `debug` → **igual que release pero rápido**: standalone con el frontend
    embebido (`--features tauri/custom-protocol`) como release, **sin Vite ni CLI**:
    app completa agarra y ⌘R incremental = compilación rápida de solo Rust (el
    JS no se toca salvo que cambie el dist). Para HMR usa la config `hotreload`.
  - iOS `hotreload` → hot reload honesto: FIRST **probea** el parent `tauri ios dev --open`
    con un handshake WebSocket JSON-RPC real y timeout 1.5s sobre el address IPC
    (`$TMPDIR/com.tauri-react-template.app-server-addr`, el CLI monta un server jsonrpsee con
    el método `options`). Si responde → corre `xcode-script` (full IPC: features, config merges,
    `TAURI_DEV_HOST`…). Si no (addr stale apuntando p.ej. al WS de Vite, puerto cerrado o sin
    archivo → el stock `read_options` de Xcode se colgaría para siempre: por eso este probe
    NUNCA deja que el build se cuelgue) → abre en Terminal el parent `tauri ios dev --open`
    ([`--host <LAN>`](./README.md#hot-reload-full-ipc--tauri-ios-dev) para device físico),
    espera hasta ~40s y reintenta. Sin parent → abre la terminal del dev server
    (`apps/web/scripts/xcode/xcode-dev-server.command`), avisa y cae a standalone.
  - `release` → standalone con `--features tauri/custom-protocol` para producción (compila
    desde cero: correcto para release).
- Terminal visible en PRIMER PLANO sin AppleScript: la phase usa `open -a Terminal
  <script>.command` (estilo Prestly; LaunchServices → sin permisos TCC, `open` no bloquea
  nunca la phase). Dos runscripts en el repo (persisten a la regen):
  `apps/web/scripts/xcode/xcode-dev-server.command` (Vite :1420 + HMR) y
  `scripts/Xcode/xcode-dev-parent.command` (`tauri ios dev --open` con `--host <LAN>` si hay red).
- Ojo de doble Vite: en hotreload, el parent levanta Vite (su `beforeDevCommand`) y falla si
  `:1420` ya está ocupado ("beforeDevCommand terminated with a non-zero..."). No dejar un Vite
  preview/dev previo corriendo antes de lanzar la config `hotreload`.
- `xcode-script` de cargo-mobile stagea `Externals/<arch>/<PROFILE>` (`debug` para cualquier
  config != release); la phase además copia ese lib al path por SDK que enlaza el target
  (`Externals/<PLATFORM_NAME>/<CONFIGURATION>`), para que el lib fresco siempre gane.
- Al cerrar la config `hotreload` (⌘. / terminar app) **el parent NO se cierra solo**:
  `tauri ios dev --open` queda durmiendo (~24h) con el server de options IPC y su Vite en
  `:1420`. Para liberar puertos: cerrar la ventana de Terminal (⌘W) o Ctrl+C → SIGHUP mata
  al parent y a Vite. El addr file stale no rompe nada: el probe lo descarta rápido
  (puerto cerrado). `hotreload` también compila rápido: Rust en perfil debug incremental +
  HMR de Vite (solo el primer build desde cero es largo).
- Así el botón "Run/Run…" de Xcode: `debug`/`release` app completa standalone sin CLI padre
  (debug rápido, release optimizado); `hotreload` auto-abre la Terminal con el parent y hace
  HMR real de frontend (y Rust en device físico).
- Scheme `tauri-react-template_Apple` para Xcode/macOS. Scheme `tauri-react-template_iOS`
  (shim que construye el target `_Apple`) + `_iOS/Info.plist`: requeridos por cargo-mobile2,
  que usa `config.scheme()` = `<app>_iOS` para `tauri ios dev|build`.
- Entitlements estáticos por plataforma (ios.entitlements / macos.entitlements) vía
  `CODE_SIGN_ENTITLEMENTS[sdk=...]`.
- Firma: `DEVELOPMENT_TEAM` en project.yml (igual que Prestly hardcodea el suyo) para el
  pipeline CLI; el SDK `iphonesimulator` firma ad-hoc ("-") para los builds directos de
  Xcode sobre sim sin cuenta de desarrollador.

## CLI

El `cargo-tauri` instalado en esta máquina es un build modificado de Prestly (genera
proyectos Prestly-branded: `com.yanxstudio.prestly`, `web-app`, `yarn`). Para ESTE template
usar SIEMPRE el CLI stock (mismo código Rust que la versión npm):

    pnpm dlx @tauri-apps/cli@2.11.4 ios build --target aarch64-sim --debug
    pnpm dlx @tauri-apps/cli@2.11.4 android build --debug --target aarch64

### Hot reload (full IPC) — `tauri ios dev`

El dev frontend de `apps/web` escucha en TODAS las interfaces (`host: true` en
`vite.config.ts`, como Prestly): `tauri ios dev` negocia el devUrl con una IP de red del
host y debe poder consultar el server en esa IP.

- **iPhone físico**: `tauri ios dev --host 192.168.x.x "iPhone Studio"` → build+archive+
  export+install vía xcodebuild/devicectl + hot reload de Rust (watcher del CLI). La config
  `hotreload` del proyecto usa la misma forma: si el parent no está vivo, la phase lo abre en
  Terminal con `--host <LAN>` (por eso el fix de Vite `host: true`). Es el flujo diario de
  Prestly.
- **Simulador**: con Xcode 26, `devicectl` lista los sims como devices y cargo-mobile intenta
  `devicectl device install app` a un sim → no soportado ("Install Application is not
  supported"). Para SIM: `tauri ios dev --open` (mantiene el parent vivo: IPC + options) y
  corre la config `hotreload` del scheme `tauri-react-template_Apple` en Xcode con el sim →
  cada ⌘R compila por `xcode-script` con las options del parent y el frontend hace HMR por
  Vite. El auto-reload de Rust en sim queda limitado por el CLI upstream; `debug` sigue el
  camino standalone sin CLI.

## Sin Xcode (Linux/Windows/macOS sin Xcode)

Todo compila en desktop (`pnpm dev`, `pnpm dlx @tauri-apps/cli@2.11.4 dev`, `make dev`).
iOS/Android solo con Xcode / Android SDK.