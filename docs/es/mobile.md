# Móvil — iOS y Android

> **Audiencia:** devs iOS/Android — target Xcode unificado, configs, emulador.

La plantilla es **multiplataforma**: escritorio (macOS, Windows, Linux) **y** móvil (iOS, Android). Cualquier cambio debe probarse cross-platform.

## Fuente de verdad vs generado

- **Plantilla (edita aquí):** `src-tauri/vendor/tauri-cli-2.12.0/templates/mobile/ios/` — `project.yml`, `apple.xcconfig`, entitlements, `Assets.xcassets`. Es la fuente del proyecto Xcode.
- **Generado (nunca editar):** `src-tauri/gen/apple/` y `src-tauri/gen/android/` — gitignored, se regenera con los scripts autogen de abajo.

Regla: **nunca toques `src-tauri/gen/`** — cualquier edición manual se pierde al regenerar.

## Scripts autogen (los ÚNICOS generadores válidos)

El CLI vendoreado (`make install-tauri-cli`) resuelve identifiers/teams y escribe
los proyectos desde los templates vendoreados; `xcodegen` solo no puede parsear
el markup Handlebars. Ambos wrappers leen `branding.json` (nombre de la app) y
son multi-plataforma (macOS/Linux directo; Windows vía `.cmd`/Git Bash):

```bash
scripts/Xcode/apple-xcode.sh              # regen gen/apple (Xcode iOS+macOS)
scripts/Android/android-autogen.sh        # regen gen/android (proyecto Studio + MainActivity)
make gen-apple / make gen-android         # alias
```

**Los iconos son parte del regen.** `branding/icon-1024.png` es el máster
(`icons.master` en `branding.json`); ambos scripts corren
`scripts/mobile/mobile-icons-regen.sh` justo tras el `init` — `tauri icon`
regenera `icons/` + `gen/apple` + `gen/android` desde el máster y el script
compone el trío de marketing iOS 1024 (light/dark/tinted) que el CLI no genera.
Los templates vendoreados llevan placeholders neutros, así que un `gen/` fresco
nunca arrastra arte ajeno; para rebrandear se reemplaza el máster, jamás los
sets generados.

## iOS — target unificado Xcode (iOS + macOS en uno)

`scripts/Xcode/apple-xcode.sh` es el entrypoint (ver `scripts/README.es.md:46`):

```bash
scripts/Xcode/apple-xcode.sh            # init del CLI vendoreado → src-tauri/gen/apple
scripts/Xcode/apple-xcode.sh --build    # + iOS simulator (CLI) + macOS host
make gen-apple                          # alias
```

Qué hace:

- Resuelve el sentinel `DEVELOPMENT_TEAM` → Team ID real (ver abajo) → vendored CLI `ios init`
- Target único `tauri-react-template_Apple` cuyo `SUPPORTED_PLATFORMS = macosx iphoneos iphonesimulator` vía `apple.xcconfig` y ramifica en `PLATFORM_NAME` en la fase "Build Rust Code".

### Dos configs de build (XcodeGen)

La vieja config `hotreload` se retiró en el rebase a tauri-cli 2.12 — `debug`
es el flujo dev/HMR ahora (consume el dev server de Vite).

| Config | macOS | iOS |
|--------|-------|-----|
| `debug` | dev server de Vite (`apps/web`, `:1420` + HMR), sin `custom-protocol`; abre la Terminal dev cuando Vite está caído | mismo flujo: `xcode-script --configuration debug` (el fallback MOD-1 da semántica dev: `devUrl` + HMR) |
| `release` | standalone optimizado, frontend embebido | standalone optimizado, frontend embebido |

Detalles en `scripts/README.es.md:46`.

### Comandos iOS (qué CLI usar)

Aquí hay dos CLIs — elige por flujo:

```bash
pnpm dlx @tauri-apps/cli@2.12.0 ios build --target aarch64-sim --debug
pnpm dlx @tauri-apps/cli@2.12.0 android build --debug --target aarch64
make dev:ios            # simulador iOS (cargo tauri + simctl, sin EBADARCH)
make dev-ios-physical   # iPhone por USB (necesita --host 169.254.x.x)
```

`Makefile:37` — `dev:ios` usa `pnpm tauri ios dev "$(IOS_DEVICE)"` (ruta sim, el Node CLI stock vale). `dev-ios-physical` usa `cargo tauri ios dev "$(IOS_DEVICE)" --host $(IOS_DEV_HOST)` (binario local con los retoques `_Apple` — necesario para el target unificado).

### Parche Xcode 26 — `cargo-mobile2` vendoreado

Xcode 26 lista **simuladores** como devices en `xcrun devicectl list devices --json-output` (`reality: "simulated"`). `cargo-mobile2 0.22.4` no filtraba → `tauri ios dev` trataba un sim como físico → `aarch64-apple-ios`/`-sdk iphoneos`/`devicectl install` → `MIInstallerErrorDomain 15 / EBADARCH`.

**Fix en esta plantilla** (no en `gen`):

- `cargo-mobile2 0.22.5` (crates.io, 17-08-2026) ya trae el fix de Xcode 27 oficial (`ee65fb1`: filtro de simuladores por `visibility_class` + diccionario `properties` + arranque por Device Hub) — ya no hay `[patch.crates-io]`.
- `src-tauri/vendor/tauri-cli-2.12.0/src/mobile/` conserva 3 cambios locales sobre el 2.12.0 stock (ver la skill `tauri-cli-rebase` con su `references/mods.md` para el porqué + checklist de rebase): `fallback_options()` (builds standalone de Xcode sin proceso CLI padre), búsqueda del target `_iOS` → `_Apple` y el reemplazo simplificado de `{{app.name}}` en `project.rs`. La skill `.claude/skills/tauri-cli-rebase/` los re-aplica semánticamente sobre una versión stock nueva.

Instálalo una vez por clon:

```bash
make install-tauri-cli   # compila vendor/tauri-cli → ~/.cargo/bin/cargo-tauri
cargo tauri ios dev "iPhone 18 Pro"
```

`pnpm tauri ios dev` (Node CLI 2.12.0) es stock — vale para flujos de sim, pero le faltan los retoques `_Apple`/standalone, así que los flujos de dispositivo y Xcode usan `cargo tauri`.

> `cargo-mobile2 0.22.5` salió el 17-08-2026 con el fix de Xcode 27, así que el vendor ahora es un rebase del `tauri-cli 2.12.0` stock (que pide `cargo-mobile2 ^0.22.5`) más los 3 cambios locales de arriba — sin copia parcheada de mobile2 ni sección `[patch]`.

### Info.plist

Edita **solo la plantilla**: `src-tauri/Info.plist` — es la fuente para macOS (`tauri.macos.conf.json: bundle.macOS.infoPlist`) **y** iOS (`tauri.ios.conf.json: bundle.iOS.infoPlist`). Ahí añade `NSAppTransportSecurity` (`NSAllowsLocalNetworking` + `NSAllowsArbitraryLoads` para `http://192.0.0.2:1420`/`ws://` HMR), `NSLocalNetworkUsageDescription`, `NSBonjourServices`.

`src-tauri/gen/apple/.../Info.plist` es autogen.

### DEVELOPMENT_TEAM

La plantilla nunca hardcodea el Team ID — `scripts/Xcode/apple-xcode.sh` lo lee (env `DEVELOPMENT_TEAM`, que `make` carga del `.env`, o `scripts/.team-id`) y exporta `APPLE_DEVELOPMENT_TEAM`, la variable que el CLI vendoreado lee en `ios init` para rellenar `{{apple.development-team}}` en el proyecto generado. Prioridad:

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
- Simulador + config `debug`: compila vía `xcode-script` (semántica dev — carga `devUrl`); un parent `tauri ios dev --open` es opcional (IPC completo si está, Vite solo si no).

Siguiente: [Sensación nativa →](./native-feel.md)
