# Changelog

> Evolución completa de esta plantilla — 20 commits desde `455897d` hasta `9da8602`. Cada entrada explica **el motivo detrás del código no obvio**. Léelo antes de eliminar cualquier línea marcada `// Prestly pattern` o `// HuLa fix`.

## 2026-08-30 — Base

### `455897d` `feat: initial commit`
- Scaffold básico Tauri + Vite.

### `e08ca4a` `feat: modernize template — pnpm + node24, biome, i18n bilingüe, tailwind v4, tauri v2`
- Migra a **pnpm workspaces** (`pnpm-workspace.yaml:1`), Node `>=24`, Biome (`biome.json:1`), i18next EN/ES (`apps/web/src/i18n/config.ts:1`), Tailwind v4 vía `@tailwindcss/vite` (`packages/ui/src/styles/globals.css:1`), Turborepo, Vitest + Testing Library, semántica HTML5 (`App.tsx:19`, `index.html:5`). Define alias `@` → `src` y `@workspace/ui`.

### `653bebc` `feat: shadcn full + einui liquid glass — dual registry`
- Vendorea **45 componentes shadcn** + **einui liquid glass** (`glass-button`, `glass-card`, etc.) en `packages/ui`. Dual registry `@einui` vía `https://ui.eindev.ir/r/{name}.json`. Añade `framer-motion`, `radix-ui`, `recharts`, `@base-ui/react`. Todos los widgets glass viven en `packages/ui/src/components`.

### `10a74e4` `feat: unified iOS+macOS Xcode template — debug/hotreload/release pipelines`
- **Target único Xcode** `tauri-react-template_Apple` (`SUPPORTED_PLATFORMS = macosx iphoneos iphonesimulator` vía `apple.xcconfig`) con 3 configs:
  - `debug` — standalone con frontend embebido (`custom-protocol`), incremental rápido.
  - `hotreload` — probe al parent `tauri ios dev --open` vía **handshake JSON-RPC** (`$TMPDIR/com.tauri-react-template.app-server-addr`, timeout 1.5s), IPC completo (`TAURI_DEV_HOST`, merges, `xcode-script`); abre Terminal vía `open -a Terminal <script>.command` si el parent no está vivo.
  - `release` — producción standalone.
- Sentinel `DEVELOPMENT_TEAM` `__TAURI_DEVELOPMENT_TEAM__` resuelto por `scripts/Xcode/apple-xcode.sh` (`env` → `scripts/.team-id` → manual).
- Vendorea el template móvil `tauri-cli 2.11.4` en `src-tauri/vendor/`. `Info.plist` se convierte en la **plantilla única** para macOS+iOS (`tauri.*.conf.json: bundle`).

## 2026-08-30 — Fundación native-feel

### `f23a894` `feat: disable native webview context menu (Reload/Back) in release — all OS`
- Rust intercepta `contextmenu` para suprimir `Reload`/`Back` en WKWebView/WebView2/WebKitGTK + menús long-press móviles. Debug lo conserva.

### `c9ae1a4` `feat: native-app feel — prevent-default plugin, dragDrop/zoomHotkeys off, CSS+JS multi-OS`
- **El commit grande de sensación nativa:**
  - `dragDropEnabled:false` + `zoomHotkeysEnabled:false` en **las 4** ventanas `tauri.*.conf.json`.
  - Viewport `user-scalable=no, maximum-scale=1.0` (`index.html:5`), CSS `user-select:none` + `-webkit-user-drag:none` + `touch-action: pan-x pan-y` (`globals.css:136`), guards JS `dragstart` + `wheel` (`main.tsx:17`).
  - `tauri-plugin-prevent-default` con `Flags::debug()` (`lib.rs:390`) — bloquea menú/context/reload/devtools en release, los mantiene en debug.
- Por qué `touch-action: pan-x pan-y` y no `manipulation`/`none`: conserva scroll nativo; bloquea pinch-zoom sin matar gestos. Ver `ae5be97`.

### `ae5be97` `fix: restore normal scrolling in WebKit — touch-action manipulation instead of pan-x pan-y` (superseded)
- Prueba con `touch-action: manipulation` — luego se asentó en `pan-x pan-y` como valor saludable para WebKit.

### `45d5f34` `docs: multiplataforma — notas native-feel`
- Documenta que `dragDropEnabled`/`zoomHotkeysEnabled` deben estar en **las 4 configs**, no solo macOS.

## 2026-08-30 — Crystal / glass

### `f997723` `feat: efecto cristal — toggle de translucidez nativa (window-vibrancy)`
- Crate `window-vibrancy 0.8`, comando **sync** `window_effects_set {enabled, dark?}` (`lib.rs:18`, `lib.rs:78`) — `NSVisualEffectView` en macOS (`HudWindow`/`UnderWindowBackground`), Mica en Windows 11; `unsupported` en resto. `VibrancyProvider` (`vibrancy-provider.tsx`) + `localStorage: vibrancy` + `html.vibrancy` → `globals.css:177` body transparente.

### `efc552c` `feat: el efecto cristal sigue el tema de la app`
- `VibrancyProvider` observa `html.dark` vía `MutationObserver` y re-aplica material al cambiar de tema. macOS elige material según `dark` (el cristal sigue el tema de la app, no el del sistema).

### `5fb6077` `feat: ventana nativa - esquinas redondeadas, arrastre y cristal por tema`
- Corrige `window-vibrancy` bajo `[target.'cfg(windows)']` — lo mueve a `[dependencies]` principal para que macOS lo enlace. Añade crate `windows = "0.61"` DWM (`Cargo.toml:54`). `DwmSetWindowAttribute(DWMWCP_ROUND)` para frameless Windows 11 (`lib.rs:399`). Nuevo `native-chrome.ts` (`usePlatform`, `useMacDragRegion`), header con botones nativos (`header.tsx`).

### `73d445a` `fix: ventana nativa — arrastre con banda reservada y cristal de fondo`
- Reserva **banda de 36px** (`--native-titlebar-height`) para drag, padding `app-shell`, header sticky en `top:36px`. Cristal de ventana completa: `color-mix(var(--background) 62%, transparent)` para que la translucidez siga el tema.

### `aa83704` `fix: arrastre macOS fiable (patron Prestly, banda 20px)`
- Drag intermitente: selección del webview + header sticky tapando la banda. Fix: `useMacDragRegion` replica exacto Prestly — `mousedown` a nivel document, `preventDefault` + `startDragging` en banda, doble-clic → maximize, excluye targets interactivos. Encoje banda a **20px** (`1.25rem`), header sticky en `top: var(--native-titlebar-height)`.

## 2026-08-31 — Ventana cross-platform

### `9177b88` `fix: ventana arrastrable y esquinas redondeadas en las 3 plataformas`
- Añade `core:window:allow-start-dragging` a `capabilities/default.json` (sin ello `startDragging` falla en silencio). `app-shell` se convierte en **contenedor de scroll** (`overflow-y: auto`) con `border-radius:10px` en macOS; header con `data-tauri-drag-region` en Windows/Linux. `html/body` transparentes en desktop — `app-shell` es dueño del background.

### `938f89a` `fix: traffic lights live-resize sin flicker + header alineado + windows NSIS/Wix`
- **Fix HuLa 3-mecanismos para traffic lights de macOS** (`lib.rs:107`):
  1. `WindowEvent::Focused/Resized/ScaleFactorChanged` (`lib.rs:437`)
  2. `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (`lib.rs:250`)
  3. **Polling a 60 fps** (`NSTimer` en `NSRunLoopCommonModes` + `needs_update` `±0.6px`, `lib.rs:449`) — dispara durante `NSEventTrackingRunLoopMode`
  - Targets `Close 22.5 / Mini 44.5 / Zoom 66.5`, `grow 3`, `lower 8`, `shift 16` + `extra_gap`, `setAutoresizingMask(0)`, header `pl-[96px] sm:pl-[108px]`.
- También: assets instalador Windows NSIS/Wix (`nsis-header.bmp`, `wix-banner.bmp`), `LICENSE.rtf`, iconos multi-tamaño `src-tauri/icons/`.
- Verificación: `pnpm build` + `cargo check` en macOS + Linux (docker `webkit2gtk-4.1`).

## 2026-09-02 — Glass y curvas en Linux

### `93657d3` `fix: linux glass veto + curvas ventana + toggle combinado`
- **Glitches amarillos Linux** (`a2.png`) — WebKitGTK 4.1 + DMABUF + NVIDIA/Wayland + `backdrop-blur` → `AcceleratedSurfaceDMABuf was unable to…` + `Error 71` + RAM. Fix: `GlassCardsProvider` retorna `false` si `platform==='linux'`, `GlassEffectToggle` deshabilitado, `globals.css:283` quita `backdrop-filter` → `var(--card)`, `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` antes de `Builder` (`lib.rs:371`). `html.linux .app-shell {border-radius:10px}` corrige ventana plana (`a1.png`). Nuevo `scripts/build-linux.sh`.

## 2026-09-05 — Sombra en Linux

### `9da8602` `fix: sombra de ventana nativa en Linux via GTK CssProvider + fallback webview`
- `tauri`/`tao` NO soportan `WindowConfig.shadow` en Linux (`"Linux: Unsupported"`). Con `decorations:false transparent:true` el nodo `window.background.csd decoration { box-shadow }` nunca se genera → ventana plana.
  - **Primaria:** `apply_linux_window_shadow` (`lib.rs:315`) — `gtk_window()` + `CssProvider` (prioridad APPLICATION) fuerza `.csd`, restaura `decoration { box-shadow: 0 16px 48px rgba(0,0,0,.38); margin:12px; border-radius:10px }` + `:backdrop`, añade `html.gtk-shadow` vía `window.eval`.
  - **Fallback:** `globals.css:244` `html.linux:not(.gtk-shadow) .app-shell` → `margin:12px + box-shadow` — para Sway/Hyprland/X11 donde se ignora CSD. Maximizado/fullscreen → `0`.
- Añade `gtk = "0.18"` (`Cargo.toml:67`, solo linux) + `useWindowStateClasses` para `window-maximized`/`window-fullscreen` vía capability `allow-is-fullscreen`.

---

## Lecciones para futuros cambios

- Si ves `// Prestly pattern` o `// HuLa fix`, esa línea sobrevivió a múltiples bugs de plataforma. Lee el commit antes de tocarla.
- `backdrop-blur` en Linux está vetado por motivo — cualquier re-activación debe manejar DMABUF + NVIDIA + Wayland y mantener RAM plana al redimensionar.
- Traffic lights: nunca elimines uno de los tres mecanismos — cada uno cubre un timing distinto (general, macOS 26, live-drag).
- `src-tauri/gen/` siempre es desechable — la fuente real de Xcode es `vendor/tauri-cli-*/templates/mobile/ios/`.

Siguiente: [Contribuir →](./contributing.md) · [Sensación nativa →](./native-feel.md)
