# Solución de problemas

## Terminal rota: `35;22;36M` / `?1000h`

**Causa:** `pnpm dev` (= `turbo dev`) activa el modo ratón TUI de Turbo. `tauri dev` lo mata con `SIGTERM` dejando la terminal en ese modo.

**Fix:** `tauri.conf.json:build.beforeDevCommand` ya es `pnpm --filter web dev` (Vite directo, sin Turbo). Usa `make dev` / `pnpm tauri:dev` para desktop. Solo ejecuta `pnpm dev` standalone (solo web).

Resetea una terminal rota: `reset` o `tput rmcup`.

## Traffic lights de macOS saltan al redimensionar

Asegúrate de que `lib.rs:107` `adjust_macos_traffic_lights` + `ensure_traffic_lights_observer` + polling 60 fps existan. Contrarrestan que AppKit los resetee a `12px` en cada layout. Verifica `titleBarStyle: Overlay` + `hiddenTitle` en `tauri.macos.conf.json`. Comprueba targets `22.5/44.5/66.5`.

## No hay sombra en Linux / ventana plana

Ahora **solo nativo** (`lib.rs:315` `StyleContext::add_provider` — Wayland-safe). El bug previo era `add_provider_for_screen` con `screen == None` en Wayland puro → provider nunca registrado. Ahora mira `journalctl` / `RUST_LOG=info` para `linux shadow: provider added via window StyleContext (Wayland/X11 without screen)` vs `via window + screen (X11)`. Si sigue plana, verifica que el compositor dibuje sombras `CSD decoration` (Sway/Hyprland SSD-only ignoran CSD por diseño; X11 sin `picom/compton` no tiene sombra).

## Glitches amarillos glass / RAM disparada en Linux

Desactiva glass — Linux fuerza `glass OFF` por diseño (`glass-cards-provider.tsx` + `globals.css:283`). Mantén `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` en `lib.rs:371`. Ver Plan A degradado en `native-feel.md`.

## `pnpm install` falla / mismatch Node

Requiere **Node >=24** y **pnpm >=10** (`package.json:engines`). Usa `nvm use` / `pnpm env use --global 10`.

## `cargo check` falla en target iOS

```bash
cargo check --target aarch64-apple-ios --manifest-path src-tauri/Cargo.toml
```

Requiere targets de `rust-toolchain.toml` instalados (`rustup show`). Sin Xcode, el `cargo check` de desktop sigue pasando.

## `tauri ios dev` EBADARCH / MIInstallerErrorDomain 15

Xcode 26 lista simuladores vía `devicectl` — `cargo-mobile2 0.22.4` sin parche instala con `-sdk iphoneos` → mismatch de arch.

```bash
make install-tauri-cli
cargo tauri ios dev "iPhone 17"   # no pnpm tauri
```

Para device físico usa `make dev-ios-physical` (necesita `--host 169.254.x.x`).

## Puerto 1420 ya en uso / hotreload `beforeDevCommand terminated`

Otro Vite está corriendo. Mátalo (`lsof -i :1420`, `pkill -f vite`) antes de lanzar el scheme `hotreload` — crea un segundo Vite vía el parent `tauri ios dev`.

## `DEVELOPMENT_TEAM` no inyectado / falla de firma

```bash
echo TU_TEAM_ID > scripts/.team-id
scripts/Xcode/apple-xcode.sh
xcodebuild -project src-tauri/gen/apple/tauri-react-template.xcodeproj \
  -scheme tauri-react-template_Apple -configuration Debug \
  -showBuildSettings | grep DEVELOPMENT_TEAM
```

La selección manual en Xcode se pierde al regenerar — usa `.team-id`.

## Scroll con tirones / rubber-band roto

Nunca añadas `overscroll-behavior:none` u overrides `overflow:hidden` más allá de `globals.css`. La app depende de `touch-action: pan-x pan-y` para scroll nativo. El plugin Rust (`prevent-default` con `Flags::debug()`) no toca el scroll — si añades CSS custom, verifica scroll 0↔max con JS.

## Traducciones faltantes / fallback a inglés inesperado

Asegúrate de que la key exista en **ambos** `en.json` y `es.json`. `fallbackLng: "en"` oculta keys `es` faltantes. Comprueba que `supportedLngs` incluya tu locale en `i18n/config.ts:20`.

Siguiente: [Contribuir →](./contributing.md)
