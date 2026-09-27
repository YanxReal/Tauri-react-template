# Móvil — iOS y Android

La plantilla es **multiplataforma**: escritorio (macOS, Windows, Linux) **y** móvil (iOS, Android). Cualquier cambio debe probarse cross-platform.

## Fuente de verdad vs generado

- **Plantilla (edita aquí):** `src-tauri/vendor/tauri-cli-2.12.0/templates/mobile/ios/` — `project.yml`, `apple.xcconfig`, entitlements, `Assets.xcassets`. Es la fuente del proyecto Xcode.
- **Generado (nunca editar):** `src-tauri/gen/apple/` y `src-tauri/gen/android/` — gitignored, se regenera en cada `scripts/Xcode/apple-xcode.sh` o `tauri ios init`.

Regla: **nunca toques `src-tauri/gen/`** — cualquier edición manual se pierde al regenerar.

## iOS — target unificado Xcode (iOS + macOS en uno)

`scripts/Xcode/apple-xcode.sh` es el entrypoint (ver `scripts/README.md:8`):

```bash
scripts/Xcode/apple-xcode.sh            # xcodegen → src-tauri/gen/apple
scripts/Xcode/apple-xcode.sh --build    # + iOS simulator (CLI) + macOS host
make gen-apple                          # alias
```

Qué hace:

- Resuelve el sentinel `DEVELOPMENT_TEAM` → Team ID real (ver abajo) → `xcodegen`
- Target único `tauri-react-template_Apple` cuyo `SUPPORTED_PLATFORMS = macosx iphoneos iphonesimulator` vía `apple.xcconfig` y ramifica en `PLATFORM_NAME` en la fase "Build Rust Code".

### Tres configs de build (XcodeGen)

| Config | macOS | iOS |
|--------|-------|-----|
| `debug` | standalone con frontend embebido (`custom-protocol`) | igual — standalone, rápido, sin Vite/CLI |
| `release` | standalone optimizado | standalone optimizado |
| `hotreload` | abre Terminal con dev server Vite (`apps/web`, `:1420` + HMR), sin `custom-protocol` | hace probe al parent `tauri ios dev --open` vía handshake JSON-RPC (timeout 1.5s) en `$TMPDIR/com.tauri-react-template.app-server-addr`; si responde → `xcode-script` con IPC completo (`TAURI_DEV_HOST` etc.), si no abre el parent en Terminal; si no hay parent → fallback standalone |

Detalles en `scripts/README.md:22`.

### Comandos iOS (usa siempre el CLI parcheado)

El `cargo tauri` instalado puede ser un build modificado de Prestly (`com.yanxstudio.prestly`). Usa el **CLI stock**:

```bash
pnpm dlx @tauri-apps/cli@2.12.0 ios build --target aarch64-sim --debug
pnpm dlx @tauri-apps/cli@2.12.0 android build --debug --target aarch64
make dev:ios            # iOS simulator (cargo tauri parcheado + simctl, sin EBADARCH)
make dev-ios-physical   # iPhone por USB (necesita --host 169.254.x.x)
```

`Makefile:34` — `dev:ios` usa `pnpm tauri ios dev "$(IOS_DEVICE)"` (ruta sim). `dev-ios-physical` usa `cargo tauri ios dev "$(IOS_DEVICE)" --host $(IOS_DEV_HOST)` (device físico por IP link-local USB).

### Parche Xcode 26 — `cargo-mobile2` vendoreado

Xcode 26 lista **simuladores** como devices en `xcrun devicectl list devices --json-output` (`reality: "simulated"`). `cargo-mobile2 0.22.4` no filtraba → `tauri ios dev` trataba un sim como físico → `aarch64-apple-ios`/`-sdk iphoneos`/`devicectl install` → `MIInstallerErrorDomain 15 / EBADARCH`.

**Fix en esta plantilla** (no en `gen`):

- `cargo-mobile2 0.22.5` (crates.io, 17-08-2026) ya trae el fix de Xcode 27 oficial (`ee65fb1`: filtro de simuladores por `visibility_class` + diccionario `properties` + arranque por Device Hub) — ya no hay `[patch.crates-io]`.
- `src-tauri/vendor/tauri-cli-2.12.0/src/mobile/` conserva 3 cambios locales sobre el 2.12.0 stock (ver `MODS.md` en la raíz del repo para el porqué + checklist de rebase): `fallback_options()` (builds standalone de Xcode sin proceso CLI padre), búsqueda del target `_iOS` → `_Apple` y el reemplazo simplificado de `{{app.name}}` en `project.rs`. `scripts/patch-tauri-cli.sh` los aplica sobre una copia stock (rechaza versiones que no conoce).

Instálalo una vez por clon:

```bash
make install-tauri-cli   # compila vendor/tauri-cli → ~/.cargo/bin/cargo-tauri
cargo tauri ios dev "iPhone 17"
```

`pnpm tauri ios dev` (CLI de Node) sigue usando la copia sin parche del registry — para iOS usa `cargo tauri`.

> `cargo-mobile2 0.22.5` salió el 17-08-2026 con el fix de Xcode 27, así que el vendor ahora es un rebase del `tauri-cli 2.12.0` stock (que pide `cargo-mobile2 ^0.22.5`) más los 3 cambios locales de arriba — sin copia parcheada de mobile2 ni sección `[patch]`.

### Info.plist

Edita **solo la plantilla**: `src-tauri/Info.plist` — es la fuente para macOS (`tauri.macos.conf.json: bundle.macOS.infoPlist`) **y** iOS (`tauri.ios.conf.json: bundle.iOS.infoPlist`). Ahí añade `NSAppTransportSecurity` (`NSAllowsLocalNetworking` + `NSAllowsArbitraryLoads` para `http://192.0.0.2:1420`/`ws://` HMR), `NSLocalNetworkUsageDescription`, `NSBonjourServices`.

`src-tauri/gen/apple/.../Info.plist` es autogen.

### DEVELOPMENT_TEAM

La plantilla nunca hardcodea el Team ID — el sentinel `__TAURI_DEVELOPMENT_TEAM__` lo resuelve `scripts/Xcode/apple-xcode.sh` **antes** de `xcodegen`. Prioridad:

1. env `DEVELOPMENT_TEAM`
2. fichero `scripts/.team-id` (gitignored, persiste)
3. omitido → elige en Xcode → Signing & Capabilities

```bash
echo TU_TEAM_ID > scripts/.team-id
scripts/Xcode/apple-xcode.sh
# verifica:
xcodebuild -project src-tauri/gen/apple/tauri-react-template.xcodeproj \
  -scheme tauri-react-template_Apple -configuration Debug \
  -showBuildSettings | grep DEVELOPMENT_TEAM
```

Necesario para `tauri ios dev|build`; no necesario para builds de Xcode sobre **sim** (firma ad-hoc `CODE_SIGN_STYLE[sdk=iphonesimulator*]`) ni para macOS.

## Android

```bash
make dev-android-emulator   # APK debug → emulator (aarch64)
pnpm dlx @tauri-apps/cli@2.12.0 android build --debug --target aarch64
```

`ANDROID_AVD` / `ANDROID_TARGET` son vars del Makefile (`Resizable_Experimental` / `aarch64`).

## Dev sin TUI de Turbo

`pnpm dev` = `turbo dev` (TUI `?1000h`). `tauri dev` lo mata con `SIGTERM` dejando el modo ratón activo. `tauri.conf.json:build.beforeDevCommand` es `pnpm --filter web dev` (Vite directo, sin Turbo) así `tauri ios dev` nunca activa `?1000h`.

## Hot reload (full IPC)

`apps/web/vite.config.ts:25` — `host: host || true` (todas las interfaces). `tauri ios dev` negocia `devUrl` en una IP LAN; Vite debe ser alcanzable en esa IP + `ws://:1421` HMR.

- iPhone físico: `tauri ios dev --host 192.168.x.x "iPhone Studio"` → xcodebuild/devicectl + watcher de Rust.
- Simulador + scheme `hotreload`: si el parent `tauri ios dev --open` está vivo, `xcode-script` consume sus options + `TAURI_DEV_HOST`; si no, lo abre en Terminal.

Siguiente: [Sensación nativa →](./native-feel.md)
