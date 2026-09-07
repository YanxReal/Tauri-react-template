# Changelog

> Complete evolution of this template — 20 commits from `455897d` to `9da8602`. Every entry links to the **reason behind non-obvious code**. Read it before removing anything marked `// Prestly pattern` or `// HuLa fix`.

## 2026-08-30 — Foundation

### `455897d` `feat: initial commit`
- Bare Tauri + Vite scaffold.

### `e08ca4a` `feat: modernize template — pnpm + node24, biome, i18n bilingüe, tailwind v4, tauri v2`
- Migrates to **pnpm workspaces** (`pnpm-workspace.yaml:1`), Node `>=24`, Biome (`biome.json:1`), i18next EN/ES (`apps/web/src/i18n/config.ts:1`), Tailwind v4 via `@tailwindcss/vite` (`packages/ui/src/styles/globals.css:1`), Turborepo, Vitest + Testing Library, HTML5 semantics (`App.tsx:19`, `index.html:5`). Sets workspace `@` → `src` and `@workspace/ui`.

### `653bebc` `feat: shadcn full + einui liquid glass — dual registry`
- Vendors **45 shadcn components** + **einui liquid glass** (`glass-button`, `glass-card`, etc.) into `packages/ui`. Dual registry `@einui` via `https://ui.eindev.ir/r/{name}.json`. Adds `framer-motion`, `radix-ui`, `recharts`, `@base-ui/react`. All glass widgets live in `packages/ui/src/components` — not `apps/web`.

### `10a74e4` `feat: unified iOS+macOS Xcode template — debug/hotreload/release pipelines`
- **Single Xcode target** `tauri-react-template_Apple` (`SUPPORTED_PLATFORMS = macosx iphoneos iphonesimulator` via `apple.xcconfig`) with 3 build configs:
  - `debug` — standalone with embedded frontend (`custom-protocol`), fast incremental.
  - `hotreload` — probes parent `tauri ios dev --open` via **JSON-RPC handshake** (`$TMPDIR/com.tauri-react-template.app-server-addr`, timeout 1.5s), full IPC (`TAURI_DEV_HOST`, config merges, `xcode-script`); opens Terminal via `open -a Terminal <script>.command` if parent not alive.
  - `release` — production standalone.
- `DEVELOPMENT_TEAM` sentinel `__TAURI_DEVELOPMENT_TEAM__` resolved by `scripts/Xcode/apple-xcode.sh` (`env` → `scripts/.team-id` → manual).
- Vendors `tauri-cli 2.11.4` mobile template into `src-tauri/vendor/`. `Info.plist` becomes the **single template** for both macOS+iOS (`tauri.*.conf.json: bundle`).

## 2026-08-30 — Native-feel foundation

### `f23a894` `feat: disable native webview context menu (Reload/Back) in release — all OS`
- Rust intercepts `contextmenu` to suppress `Reload`/`Back` on WKWebView/WebView2/WebKitGTK + long-press mobile menus. Debug keeps it.

### `c9ae1a4` `feat: native-app feel — prevent-default plugin, dragDrop/zoomHotkeys off, CSS+JS multi-OS`
- **The big native-feel commit:**
  - `dragDropEnabled:false` + `zoomHotkeysEnabled:false` in **all 4** `tauri.*.conf.json` windows.
  - Viewport `user-scalable=no, maximum-scale=1.0` (`index.html:5`), CSS `user-select:none` + `-webkit-user-drag:none` + `touch-action: pan-x pan-y` (`globals.css:136`), JS `dragstart` + `wheel` guards (`main.tsx:17`).
  - `tauri-plugin-prevent-default` with `Flags::debug()` (`lib.rs:390`) — blocks context menu / reload / devtools in release, keeps them in debug.
- Why `touch-action: pan-x pan-y` not `manipulation`/`none`: keeps native scroll alive; `pan-x pan-y` disables pinch-zoom without killing gesture. See `ae5be97`.

### `ae5be97` `fix: restore normal scrolling in WebKit — touch-action manipulation instead of pan-x pan-y` (superseded)
- Experimentally tried `touch-action: manipulation` — later settled on `pan-x pan-y` (see above) as the WebKit-healthy value.

### `45d5f34` `docs: multiplataforma — native-feel notes`
- Documents that `dragDropEnabled`/`zoomHotkeysEnabled` must be in **all 4 configs**, not just macOS.

## 2026-08-30 — Crystal / glass

### `f997723` `feat: efecto cristal — toggle de translucidez nativa (window-vibrancy)`
- `window-vibrancy 0.8` crate, **sync** command `window_effects_set {enabled, dark?}` (`lib.rs:18`, `lib.rs:78`) — `NSVisualEffectView` on macOS (`HudWindow`/`UnderWindowBackground`), Mica on Windows 11; `unsupported` elsewhere. `VibrancyProvider` (`vibrancy-provider.tsx`) + `localStorage: vibrancy` + `html.vibrancy` → `globals.css:177` transparent body.

### `efc552c` `feat: el efecto cristal sigue el tema de la app`
- `VibrancyProvider` watches `html.dark` via `MutationObserver` and re-applies material on theme change. macOS picks material per `dark` (so crystal follows app theme, not system).

### `5fb6077` `feat: ventana nativa - esquinas redondeadas, arrastre y cristal por tema`
- Fixes `window-vibrancy` being under `[target.'cfg(windows)']` — moves to main `[dependencies]` so macOS links it. Adds `windows = "0.61"` DWM crate (`Cargo.toml:54`). `DwmSetWindowAttribute(DWMWCP_ROUND)` for Windows 11 frameless (`lib.rs:399`). New `native-chrome.ts` (`usePlatform`, `useMacDragRegion`), header with native caption buttons (`header.tsx`).

### `73d445a` `fix: ventana nativa — arrastre con banda reservada y cristal de fondo`
- Reserves a **36px band** (`--native-titlebar-height`) for drag, `app-shell` padding, sticky header at `top:36px`. Full-window crystal: `color-mix(var(--background) 62%, transparent)` so background translucency follows theme.

### `aa83704` `fix: arrastre macOS fiable (patron Prestly, banda 20px)`
- Drag was intermittent: webview selection + sticky header covering the band. Fix: `useMacDragRegion` exactly mirrors Prestly — document-level `mousedown`, `preventDefault` + `startDragging` in band, double-click → maximize, excludes interactive targets. Shrinks band to **20px** (`1.25rem`), header sticky at `top: var(--native-titlebar-height)`.

## 2026-08-31 — Cross-platform window

### `9177b88` `fix: ventana arrastrable y esquinas redondeadas en las 3 plataformas`
- Adds `core:window:allow-start-dragging` to `capabilities/default.json` (without it `startDragging` silently fails). `app-shell` becomes the **scroll container** (`overflow-y: auto`) with `border-radius:10px` on macOS; header gets `data-tauri-drag-region` on Windows/Linux. `html/body` transparent in desktop — `app-shell` owns the background.

### `938f89a` `fix: traffic lights live-resize sin flicker + header alineado + windows NSIS/Wix`
- **HuLa 3-mechanism fix for macOS traffic lights** (`lib.rs:107`):
  1. `WindowEvent::Focused/Resized/ScaleFactorChanged` (`lib.rs:437`)
  2. `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (`lib.rs:250`)
  3. **60 fps polling** (`NSTimer` in `NSRunLoopCommonModes` + `needs_update` `±0.6px`, `lib.rs:449`) — fires during `NSEventTrackingRunLoopMode`
  - Targets `Close 22.5 / Mini 44.5 / Zoom 66.5`, `grow 3`, `lower 8`, `shift 16` + `extra_gap`, `setAutoresizingMask(0)`, header `pl-[96px] sm:pl-[108px]`.
- Also: Windows NSIS/Wix installer assets (`nsis-header.bmp`, `wix-banner.bmp`), `LICENSE.rtf`, multi-size `src-tauri/icons/`.
- Verification: `pnpm build` + `cargo check` on macOS + Linux (docker `webkit2gtk-4.1`).

## 2026-09-02 — Linux glass & curves

### `93657d3` `fix: linux glass veto + curvas ventana + toggle combinado`
- **Linux yellow glitches** (`a2.png`) — WebKitGTK 4.1 + DMABUF + NVIDIA/Wayland + `backdrop-blur` → `AcceleratedSurfaceDMABuf was unable to…` + `Error 71` + RAM spike. Fix: `GlassCardsProvider` returns `false` if `platform==='linux'`, `GlassEffectToggle` disabled, `globals.css:283` strips `backdrop-filter` → `var(--card)`, `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` before `Builder` (`lib.rs:371`). `html.linux .app-shell {border-radius:10px}` fixes flat window (`a1.png`). New `scripts/build-linux.sh`.

## 2026-09-05 — Linux shadow

### `9da8602` `fix: sombra de ventana nativa en Linux via GTK CssProvider + fallback webview`
- `tauri`/`tao` do NOT support `WindowConfig.shadow` on Linux (`"Linux: Unsupported"`). With `decorations:false transparent:true` the `window.background.csd decoration { box-shadow }` node never generates → flat window.
  - **Primary:** `apply_linux_window_shadow` (`lib.rs:315`) — `gtk_window()` + `CssProvider` (APPLICATION priority) forces `.csd`, restores `decoration { box-shadow: 0 16px 48px rgba(0,0,0,.38); margin:12px; border-radius:10px }` + `:backdrop`, adds `html.gtk-shadow` via `window.eval`.
  - **Fallback:** `globals.css:244` `html.linux:not(.gtk-shadow) .app-shell` → `margin:12px + box-shadow` — for Sway/Hyprland/X11 where CSD is ignored. Maximized/fullscreen → `0`.
- Adds `gtk = "0.18"` (`Cargo.toml:67`, linux target only) + `useWindowStateClasses` for `window-maximized`/`window-fullscreen` via capability `allow-is-fullscreen`.

---

## Lessons for future changes

- If you see `// Prestly pattern` or `// HuLa fix`, that line survived multiple platform bugs. Read the commit before touching it.
- Linux `backdrop-blur` is vetoed for a reason — any re-enable must handle DMABUF + NVIDIA + Wayland and keep RAM flat on resize.
- Traffic lights: never remove one of the three mechanisms — each covers a different timing (general, macOS 26, live-drag).
- `src-tauri/gen/` is always disposable — the real Xcode source is `vendor/tauri-cli-*/templates/mobile/ios/`.

Next: [Contributing →](./contributing.md) · [Native Feel →](./native-feel.md)
