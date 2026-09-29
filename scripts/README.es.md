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
[`references/mods.md`](../../.claude/skills/tauri-cli-rebase/references/mods.md) (modificaciones del CLI vendoreado).

## 📋 Inventario

| Script | Propósito |
|---|---|
| Skill `.claude/skills/linux-build/` | **Bundles Linux por SSH** (la única vía Linux: caja Docker en macOS/Windows). Solo SSH — sync con rsync sin `.git` (sin clonar), nunca gestiona el contenedor. Script: `.claude/skills/linux-build/scripts/linux-build.sh`; perfiles `--release`/`--debug` (debug = `--no-bundle`), extras `--dev`, `--run`, `--verify` (assistant shot/ocr), `--fetch`, `--logs`, `--stop` |
| `scripts/build-windows.sh` | Cross-compile Windows x64 desde macOS/Linux (`cargo-xwin` + NSIS) |
| Skill `.claude/skills/tauri-cli-rebase/` | Rebase del `tauri-cli` vendoreado — re-aplica las 5 modificaciones locales (MOD-1..MOD-5) semánticamente sobre una versión stock nueva (`.claude/skills/tauri-cli-rebase/references/mods.md`) |
| `scripts/Xcode/apple-xcode.sh` | Regenera `src-tauri/gen/apple` (init del CLI vendoreado, branding-aware); `--build` además compila sim iOS + host macOS |
| `scripts/Android/android-autogen.sh` | Regenera `src-tauri/gen/android` (init del CLI vendoreado, branding-aware, Linux/Win/macOS + `.cmd`); `--build` además compila el APK debug |
| `scripts/Xcode/xcode-dev.command` | Ayuda dev unificada — `server` (Vite visible `:1420` + HMR, por defecto) o `parent` (`tauri ios dev --open` IPC completo) |
| `scripts/install-skills.sh` (+ `.cmd`) | Instala todas las agent skills del proyecto; el `.cmd` es el launcher de Windows (corre el `.sh` vía Git Bash) |
| `scripts/branding-update.sh` | `make rebrand` — propaga la identidad de `branding.json` a todos lados (configs, Cargo/package, title/og de index.html, favicon desde el máster) |
| `scripts/check-docs-parity.sh` / `scripts/check-agents-anchors.sh` | Guardas de `make check-docs`: espejo EN/ES (ficheros, estructura, router, interpolación i18n) + deriva de anclas `file:line` |
| `scripts/mobile/icon-composite.swift` / `icon-flat.swift` | Componen los iconos de marketing iOS 1024 desde el máster / generan los placeholders neutros del template |

Inputs de build de apoyo (no son scripts, pero parte del sistema):

- `src-tauri/build.rs` compila `Assets.xcassets` vía `actool` cuando el tooling de Xcode está presente; si no, cae a `icon.icns` con un `cargo:warning`.
- `rust-toolchain.toml` fija `stable` + targets `aarch64-apple-ios*` y Android para `cargo check --target ...` y los builds móviles.
- `src-tauri/Assets.xcassets` + `Info.plist` + `tauri.macos.conf.json` (`titleBarStyle Overlay`, `transparent`) replican la capa genérica macOS/Xcode.

## 🔨 Build por SO

| Script | Qué hace |
|---|---|
| `.claude/skills/linux-build/scripts/linux-build.sh` | Bundles Linux más compilar/lanzar/verificar. **Solo SSH** (`--remote [HOST]`); `--release`/`--debug` (debug = `--no-bundle`), `--verify` (assistant windows/shot/ocr + PNG a `dist-linux/`), extras `--dev`, `--run`, `--fetch`, `--logs`, `--stop`. Flags completos: `docs/es/scripts.md`. |
| `scripts/build-windows.sh` | Cross-compile Windows x64 desde macOS/Linux (`cargo-xwin` + NSIS). Setup una sola vez: `brew install llvm lld makensis`, `cargo install cargo-xwin --locked`, `rustup target add x86_64-pc-windows-msvc`. MSI/WiX necesita host Windows. |

## 📱 Xcode unificado (iOS + macOS en UN target)

La fuente de verdad del proyecto Xcode es el template:

    src-tauri/vendor/tauri-cli-2.12.0/templates/mobile/ios/

`src-tauri/gen/apple` se regenera **completo** desde ahí (gitignored, NO persiste):

    scripts/Xcode/apple-xcode.sh             # regenera (init del CLI vendoreado)
    scripts/Xcode/apple-xcode.sh --build     # además compila sim iOS (vía CLI) + host macOS

Android es la misma idea, espejada en `scripts/Android/`:

    scripts/Android/android-autogen.sh       # regenera gen/android (branding-aware)
    scripts/Android/android-autogen.sh --build   # + APK debug (aarch64)

Regla: editar SIEMPRE el template (`project.yml`, `apple.xcconfig`, entitlements, `Assets.xcassets`),
NUNCA el `.xcodeproj` generado ni su Info.plist.

- Target único `tauri-react-template_Apple`, destinos iOS + macOS vía `apple.xcconfig`
  (`SUPPORTED_PLATFORMS = macosx iphoneos iphonesimulator`) con branches
  `PLATFORM_NAME` en la phase "Build Rust Code".
- **Dos configs de build** (XcodeGen `configs:`): `debug`, `release`. La vieja
  config `hotreload` se retiró en el rebase a tauri-cli 2.12 — la config
  `debug` hace ese papel ahora (consume el dev server de Vite). La phase
  ("Build Rust Code") elige el pipeline:
  - macOS `release` → `pnpm build` + `cargo build --lib --release --features
    tauri/custom-protocol` (frontend embebido).
  - macOS `debug` → `cargo build --lib` SIN custom-protocol (carga
    `devUrl` :1420); si Vite no está sirviendo, la phase abre
    `scripts/Xcode/xcode-dev.command` en una Terminal. Stagea
    `Externals/macosx/<config>/`.
  - iOS `release` → `pnpm build` primero, luego `xcode-script --configuration
    release` (el CLI aplica `custom-protocol` → standalone).
  - iOS `debug` → **flujo dev/HMR**: abre `xcode-dev.command` cuando Vite está
    caído, luego `xcode-script --configuration debug`; el fallback del CLI
    vendoreado (MOD-1, ver `.claude/skills/tauri-cli-rebase/references/mods.md`)
    da semántica dev — carga `devUrl`, HMR vía Vite.
- Terminal en primer plano sin AppleScript: la phase usa `open -a Terminal
  <script>.command` (LaunchServices → sin permisos TCC, `open` nunca bloquea
  la phase). Un runscript unificado en el repo (sobrevive a la regen):
  `scripts/Xcode/xcode-dev.command` — `server` (Vite :1420 + HMR, por defecto,
  el que usa la phase) o `parent` (`tauri ios dev --open`, con `--host <LAN>`
  si hay red).
- Aviso de doble Vite: un parent `tauri ios dev` levanta Vite (su
  `beforeDevCommand`) y falla si `:1420` ya está ocupado
  ("beforeDevCommand terminated with a non-zero..."). No dejes un Vite
  previo corriendo antes de un build dev.
- `xcode-script` de cargo-mobile stagea `Externals/<arch>/<PROFILE>` (`debug`
  para todo lo que no sea release); la phase además copia ese lib al path por
  SDK que enlaza el target (`Externals/<PLATFORM_NAME>/<CONFIGURATION>`), para
  que el lib fresco siempre gane.
- Cerrar el flujo dev (⌘. / terminar app) **no** cierra un parent
  `tauri ios dev --open`: queda durmiendo (~24h) con su server IPC de options
  y su Vite en `:1420`. Para liberar puertos: cerrar la ventana de Terminal
  (⌘W) o Ctrl+C → SIGHUP mata al parent y a Vite. Los builds dev compilan
  rápido: Rust incremental en debug + HMR de Vite (solo el primer build desde
  cero es largo).
- Así el botón "Run" de Xcode significa: `release` = app completa standalone
  (optimizada); `debug` = el flujo dev/HMR (Vite + Rust incremental; abre
  Terminal cuando el dev server está caído).
- Scheme `tauri-react-template_Apple` para Xcode/macOS. Scheme
  `tauri-react-template_iOS` (shim que construye el target `_Apple`) +
  `_iOS/Info.plist`: requeridos por cargo-mobile2, que usa `config.scheme()`
  = `<app>_iOS` para `tauri ios dev|build`.
- Entitlements estáticos por plataforma (ios.entitlements / macos.entitlements)
  vía `CODE_SIGN_ENTITLEMENTS[sdk=...]`.

## 🔏 Firma / DEVELOPMENT_TEAM (auto-inyección)

El template **nunca hardcodea el Team ID**: `scripts/Xcode/apple-xcode.sh` lo
lee y exporta `APPLE_DEVELOPMENT_TEAM` — la variable que el CLI vendoreado
consume en `ios init` para rellenar `{{apple.development-team}}` en el
proyecto generado. Prioridad:

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
— ver `.claude/skills/tauri-cli-rebase/references/mods.md`):

```bash
make install-tauri-cli   # compila vendor/tauri-cli → ~/.cargo/bin/cargo-tauri
cargo tauri ios dev "iPhone 18 Pro"
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

- **iPhone físico**: `tauri ios dev --host 192.168.x.x "iPhone 18 Pro"` →
  build+archive+export+install vía xcodebuild/devicectl + hot reload de Rust
  (watcher del CLI). La config `debug` del proyecto usa la misma forma: si
  el parent no está vivo, la phase lo abre en Terminal con `--host <LAN>`
  (por eso el fix de Vite `host: true`).
- **Simulador**: desde Xcode 26, `devicectl` lista los sims como devices y
  cargo-mobile intentaba `devicectl device install app` en un sim → no
  soportado ("Install Application is not supported"). Para SIM:
  `tauri ios dev --open` (mantiene el parent vivo: IPC + options) y corre la
  config `debug` del scheme `tauri-react-template_Apple` en Xcode con el
  sim → cada ⌘R compila por `xcode-script` con las options del parent y el
  frontend hace HMR por Vite. El auto-reload de Rust en sim queda limitado por
  el CLI upstream; `debug` conserva el camino standalone sin CLI. (Arreglado
  oficialmente para el listado en `cargo-mobile2 0.22.5`; ver `.claude/skills/tauri-cli-rebase/references/mods.md`.)
