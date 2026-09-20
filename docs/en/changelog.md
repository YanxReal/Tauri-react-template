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
  - Viewport `user-scalable=no, maximum-scale=1.0` (`index.html:5`), CSS `user-select:none` + `-webkit-user-drag:none` + `touch-action: pan-x pan-y` (`globals.css:137`), JS `dragstart` + `wheel` guards (`main.tsx:21`).
  - `tauri-plugin-prevent-default` with `Flags::debug()` (`lib.rs:330`) — blocks context menu / reload / devtools in release, keeps them in debug.
- Why `touch-action: pan-x pan-y` not `manipulation`/`none`: keeps native scroll alive; `pan-x pan-y` disables pinch-zoom without killing gesture. See `ae5be97`.

### `ae5be97` `fix: restore normal scrolling in WebKit — touch-action manipulation instead of pan-x pan-y` (superseded)
- Experimentally tried `touch-action: manipulation` — later settled on `pan-x pan-y` (see above) as the WebKit-healthy value.

### `45d5f34` `docs: multiplataforma — native-feel notes`
- Documents that `dragDropEnabled`/`zoomHotkeysEnabled` must be in **all 4 configs**, not just macOS.

## 2026-08-30 — Crystal / glass

### `f997723` `feat: efecto cristal — toggle de translucidez nativa (window-vibrancy)`
- `window-vibrancy 0.8` crate, **sync** command `window_effects_set {enabled, dark?}` (`lib.rs:26`, `lib.rs:82`) — `NSVisualEffectView` on macOS (`HudWindow`/`UnderWindowBackground`), Mica on Windows 11; `unsupported` elsewhere. `VibrancyProvider` (`vibrancy-provider.tsx`) + `localStorage: vibrancy` + `html.vibrancy` → `globals.css:177` transparent body.

### `efc552c` `feat: el efecto cristal sigue el tema de la app`
- `VibrancyProvider` watches `html.dark` via `MutationObserver` and re-applies material on theme change. macOS picks material per `dark` (so crystal follows app theme, not system).

### `5fb6077` `feat: ventana nativa - esquinas redondeadas, arrastre y cristal por tema`
- Fixes `window-vibrancy` being under `[target.'cfg(windows)']` — moves to main `[dependencies]` so macOS links it. Adds `windows = "0.61"` DWM crate (`Cargo.toml:57`). `DwmSetWindowAttribute(DWMWCP_ROUND)` for Windows 11 frameless (`lib.rs:365`). New `native-chrome.ts` (`usePlatform`, `useMacDragRegion`), header with native caption buttons (`header.tsx`).

### `73d445a` `fix: ventana nativa — arrastre con banda reservada y cristal de fondo`
- Reserves a **36px band** (`--native-titlebar-height`) for drag, `app-shell` padding, sticky header at `top:36px`. Full-window crystal: `color-mix(var(--background) 62%, transparent)` so background translucency follows theme.

### `aa83704` `fix: arrastre macOS fiable (patron Prestly, banda 20px)`
- Drag was intermittent: webview selection + sticky header covering the band. Fix: `useMacDragRegion` exactly mirrors Prestly — document-level `mousedown`, `preventDefault` + `startDragging` in band, double-click → maximize, excludes interactive targets. Shrinks band to **20px** (`1.25rem`), header sticky at `top: var(--native-titlebar-height)`.

## 2026-08-31 — Cross-platform window

### `9177b88` `fix: ventana arrastrable y esquinas redondeadas en las 3 plataformas`
- Adds `core:window:allow-start-dragging` to `capabilities/default.json` (without it `startDragging` silently fails). `app-shell` becomes the **scroll container** (`overflow-y: auto`) with `border-radius:10px` on macOS; header gets `data-tauri-drag-region` on Windows/Linux. `html/body` transparent in desktop — `app-shell` owns the background.

### `938f89a` `fix: traffic lights live-resize sin flicker + header alineado + windows NSIS/Wix`
- **HuLa 3-mechanism fix for macOS traffic lights** (`lib.rs:116`):
  1. `WindowEvent::Focused/Resized/ScaleFactorChanged` (`lib.rs:390`)
  2. `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (`lib.rs:253`)
  3. **60 fps polling** (`NSTimer` in `NSRunLoopCommonModes` + `needs_update` `±0.6px`, `lib.rs:412`) — fires during `NSEventTrackingRunLoopMode`
  - Targets `Close 22.5 / Mini 44.5 / Zoom 66.5`, `grow 3`, `lower 8`, `shift 16` + `extra_gap`, `setAutoresizingMask(0)`, header `pl-[96px] sm:pl-[108px]`.
- Also: Windows NSIS/Wix installer assets (`nsis-header.bmp`, `wix-banner.bmp`), `LICENSE.rtf`, multi-size `src-tauri/icons/`.
- Verification: `pnpm build` + `cargo check` on macOS + Linux (docker `webkit2gtk-4.1`).

## 2026-09-02 — Linux glass & curves

### `93657d3` `fix: linux glass veto + curvas ventana + toggle combinado`
- **Linux yellow glitches** (`a2.png`) — WebKitGTK 4.1 + DMABUF + NVIDIA/Wayland + `backdrop-blur` → `AcceleratedSurfaceDMABuf was unable to…` + `Error 71` + RAM spike. Fix: `GlassCardsProvider` returns `false` if `platform==='linux'`, `GlassEffectToggle` disabled, `globals.css:237` strips `backdrop-filter` → `var(--card)`, `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` before `Builder` (`lib.rs:315`). `html.linux .app-shell {border-radius:10px}` fixes flat window (`a1.png`). New `scripts/build-linux.sh`.

## 2026-09-05 — Linux shadow

### `9da8602` `fix: sombra de ventana nativa en Linux via GTK CssProvider + fallback webview`
> **Historical — replaced.** Everything below was deleted; see the 2026-09-07 → 2026-09-18 section.

- `tauri`/`tao` do NOT support `WindowConfig.shadow` on Linux (`"Linux: Unsupported"`). With `decorations:false transparent:true` the `window.background.csd decoration { box-shadow }` node never generates → flat window.
  - **Primary:** `apply_linux_window_shadow` — `gtk_window()` + `CssProvider` (APPLICATION priority) forces `.csd`, restores `decoration { box-shadow: 0 16px 48px rgba(0,0,0,.38); margin:12px; border-radius:10px }` + `:backdrop`, adds `html.gtk-shadow` via `window.eval`.
  - **Fallback:** `html.linux:not(.gtk-shadow) .app-shell` → `margin:12px + box-shadow` — for Sway/Hyprland/X11 where CSD is ignored. Maximized/fullscreen → `0`.
- Adds `gtk = "0.18"` (linux target only) + `useWindowStateClasses` for `window-maximized`/`window-fullscreen` via capability `allow-is-fullscreen`.

## 2026-09-07 → 2026-09-18 — Linux shadow saga, reverted

12 commits (`83042a6` … `98966ab`) chased the Linux frame: hybrid shadow → native-only `StyleContext::add_provider` → CSD latched with a hidden `HeaderBar` → `transparent:false` → forced RGBA visual + `opaque_region` → `set_opacity(0.99)`.

**Outcome — Linux stops drawing its own frame.** `tauri.linux.conf.json:11` uses `decorations: true` + `transparent: false`, so GTK / the compositor draw the titlebar with native minimize / maximize / close, shadow and corner radius. `apply_linux_window_shadow`, the linux-only `gtk` / `gdk` deps and every `.app-shell` frame rule (`border-radius` / `margin` / `box-shadow` / `contain` / inner-scroll) were deleted. Windows also went `decorations: true` here, but that was reverted one day later — see the 2026-09-19 entry. The custom **drag** area stays (`data-tauri-drag-region` + `useWindowDragRegion`, Prestly 56px band).

Why the hacks could not work: with `transparent:false` tao never installs an RGBA visual (it does it **before realize**, only for transparent windows) and `gtk_widget_set_visual()` after realize is a no-op, so the corners could never blend — the white/opaque 1px corners and the square buffer under the rounded `decoration` were that, not a CSS bug.

Least privilege: `core:window:allow-minimize` / `allow-close` / `allow-is-maximized` / `allow-is-fullscreen` were dropped from `capabilities/default.json:6` (they only existed for the caption buttons and `useWindowStateClasses`). `allow-start-dragging`, `allow-internal-toggle-maximize` (Tauri's injected `data-tauri-drag-region` script) and `allow-toggle-maximize` (double-click fallback in `useWindowDragRegion`) stay. `allow-is-fullscreen` is still unused; `allow-minimize` / `allow-close` / `allow-is-maximized` came back with the Windows caption buttons on 2026-09-19.

## 2026-09-19 — Scroll: header out of the scroller + native overlay scrollbars

The window used the OS default scrollbar on all three platforms — on Windows that is the classic bar: grey gutter, up/down arrow buttons, its own column at the window edge. Worse, it belonged to the *shell* (header + content), so it also stole ~12px from the header and pushed the caption buttons inwards.

- **The scroller moved to the content.** `.app-shell` is now `height:100dvh; overflow:hidden` (clips only) and a new `.app-scroll` (`globals.css:231`) owns `overflow-y:auto` wrapping just `main` + `Footer` (`apps/web/src/App.tsx:52`). The header — which *is* the titlebar — lives outside it, so a scrollbar can neither narrow it nor paint over the close button. The browser build is unchanged (the div is inert, the document scrolls) and keeps `md:sticky`.
- **Overlay scrollbars come from the platform, not from CSS.** Windows: `"scrollBarStyle": "fluentOverlay"` (`tauri.windows.conf.json:13`, WebView2 >= 125.0.2535.41) → Fluent overlay bar (thin pill, auto-hides, floats over the content). macOS keeps its native auto-hiding overlay; Linux follows `gtk-overlay-scrolling` in WebKitGTK.
- **Discarded first attempt (do not repeat):** a custom `::-webkit-scrollbar` pill (12px gutter, 6px thumb, transparent track, no buttons) looked right but forces the *classic* non-overlay scrollbar in both WebKit and Chromium — on macOS it kills the native auto-hide, and it fights `scrollBarStyle`. Adding `scrollbar-width`/`scrollbar-color` made it worse: in Chromium those standard properties take precedence and **ignore** the webkit pseudo-elements, which is how the arrow buttons came back. No scrollbar CSS remains.
- Verified on Windows 11 build 26200: header reaches the rounded corner with no gutter, no scrollbar when idle, a thin overlay pill while scrolling, wheel and PageDown scroll the new container.

## 2026-09-19 — Windows: overlay titlebar with decorum (Edge style)

Windows is frameless again (`tauri.windows.conf.json:12` → `decorations: false`, `transparent: true` kept for Mica) and the app draws the titlebar: the [decorum](https://github.com/clearlysid/tauri-plugin-decorum) community plugin (`Cargo.toml`, Windows-only target deps; `lib.rs:339`) plus `create_overlay_titlebar()` in `setup()` (`lib.rs:361`). This is the Edge / VS Code model — one fixed 44px band instead of the OS frame on top of the app header.

- `apps/web/src/components/layout/window-controls.tsx:61` renders minimize / maximize-restore / close (lucide icons, 46px hit area, red hover on close), mounted by `header.tsx:224` only when `platform === 'windows'`.
- The buttons sit **flush with the right edge** (`window-controls.tsx:120`, no `pr-2`): the 46px close button ends exactly at the client edge, so its red hover reaches the corner and DWM clips it with the window radius. Same geometry as Edge/Chromium (46px wide, icon ~23px from the edge).
- Snap Layouts: hovering maximize for 620 ms (`window-controls.tsx:8`) focuses the window and invokes `plugin:decorum|show_snap_overlay` (`window-controls.tsx:104`) — decorum presses Win+Z and then Alt to hide the numbered badges. Chromium answers `WM_NCHITTEST` with `HTMAXBUTTON` for the true hover flyout; tao does not expose that hook, so this is the closest equivalent. Verified on a Windows 11 build 26200 VM: minimizar / maximizar / restaurar / cerrar work, dragging by the header moves the window, `DwmGetWindowAttribute` reports `corner = 2` (`DWMWCP_ROUND`), `WS_THICKFRAME` stays set (resizable) and the flyout opens after the hover — see `troubleshooting.md` for the black-window gotcha when the app is launched from a service context.
- `globals.css:230` hides the 32px titlebar decorum injects (`[data-tauri-decorum-tb]`), which would cover the header and swallow the button clicks; the drag band stays ours (`data-tauri-drag-region` + `useWindowDragRegion`, `header.tsx:68`). Resize borders still work (tao hit-tests the frame edges of undecorated resizable windows) and `DWMWCP_ROUND` (`lib.rs:365`) keeps the corners round.
- Permissions: `allow-minimize` / `allow-close` / `allow-is-maximized` / `allow-set-focus` back in `capabilities/default.json:6` (the last one is `capabilities/default.json:15`; without it `setFocus()` rejects and the `catch` in `window-controls.tsx` swallows it, so the Snap Layouts flyout silently never opens), and `decorum:allow-show-snap-overlay` in its own `capabilities/windows.json:7` with `platforms: ["windows"]` — the plugin is a `cfg(windows)` dependency, so keeping the permission in `default.json` made every macOS/Linux `cargo check` fail with `Permission decorum:allow-show-snap-overlay not found`. Linux keeps full native decorations; macOS untouched.

## 2026-09-19 — Titlebar: fixed 44px band + readable control hover

- `header.tsx:29` — `HEADER_HEIGHT` pins the band per platform (`h-[52px]` macOS, `h-11` = 44px Win/Linux, `h-14` mobile) instead of one `h-14`. 44px is what the shell's flex column already squeezed the header down to (min-content), i.e. the band users actually saw; `shrink-0` + the fixed class just stop it from depending on the page content. The caption buttons (`h-full`) fill the band and the language / theme controls stay 32px, so the pill never clips.
- `native-chrome.ts:12` — the Prestly drag band no longer hardcodes 56px: `headerBandHeight()` measures `.app-header` at runtime (fallbacks 52 macOS / 44 Win-Linux), so band and drag zone cannot drift apart.
- `header.tsx:18` — language / theme buttons share one hover token, `hover:bg-black/10 dark:hover:bg-white/15`, applied to **both** the shadcn and the glass branch. The old defaults were unreadable on the band: `bg-muted` / `dark:bg-muted/50` vanish on the dark translucent bar, and the glass `hover:bg-white/10` inverts to 6 % black in the light theme (`globals.css:403`). The glass buttons keep `hover:scale-100`, so the pill no longer grows out of the titlebar.
- Verified on the Windows 11 build 26200 VM (VNC + pixel probe): the titlebar band is 44px (48 captured px at the VM's ~1.09 scale, caption hover rect + 1px border), the theme / language hover goes `(11,11,11)` → `(49,49,49)` in dark and `(254,254,254)` → `(228,228,228)` in light, the red close hover still spans the last 46px (x=1350..1399, client edge 1400) and dragging the band moves the window exactly as far as the pointer.

## 2026-09-20 — Two independent glass switches

- The combined `GlassEffectToggle` is gone. `GlassControls` (`apps/web/src/components/layout/glass-controls.tsx`) renders two switches side by side: `VibrancyToggle` (`vibrancy-toggle.tsx`, the native window material) and `GlassCardsToggle` (`glass-cards-toggle.tsx`, the web `glass-*` components).
- Any combination is now valid: vibrancy + solid cards, glass cards on an opaque window, or both. The two providers were already independent (`localStorage: vibrancy` vs `glass-cards`) — only the single switch tied them together.
- `GlassCardsProvider` now exposes `supported` (`platform !== 'linux'`) and collapses `enabled` to `false` there, so on Linux the switch renders **disabled** with the "unavailable on this platform" tooltip instead of flipping a switch that does nothing. `useGlassCards()` no longer re-implements the Linux veto; the `html.glass-cards` class follows the effective value.
- i18n: `vibrancy.label` is now "Crystal effect" / "Efecto cristal" (it no longer drives the cards) and both switches expose their `hint` as a tooltip.
- `glass-effect-toggle.tsx` deleted. Checks green: `pnpm typecheck`, `pnpm lint`, `pnpm test`.

## 2026-09-19 — macOS traffic lights: 2px further left

- `TRAFFIC_LIGHTS_X` (`lib.rs:117`) is now `17.5 / 39.5 / 61.5` (was `19.5 / 41.5 / 63.5`): 2px closer to the window's left edge, vertical centring and `grow 3` / `shift_right 16` + `extra_gap` untouched.
- Verified with a screen capture: dots at `17.5–75px` from the window's left edge, centre `26px` from the top (middle of the 52px header).

## 2026-09-19 — macOS traffic lights centred in the 52px header band

- `traffic_lights_target_y` (`lib.rs:142`) now derives `y` from the button **superview** (`isFlipped()` + container height) instead of assuming the frame `y` is the distance from the window top. On macOS 26 that titlebar container is **not flipped**, so the old absolute write of `26 - size/2` pushed the dots ~9px *up*: measured from the window top they went from `9–23px` (native) to `0–13px`.
- Result: dot centres sit at `MACOS_HEADER_BAND / 2` (`lib.rs:123` = 26px) — the middle of the macOS header (`header.tsx:29`, `h-[52px]`). Verified with a plain screen capture: native centre `15.8px` → `25.8px`.
- `adjust_macos_traffic_lights` (`lib.rs:162`) drops the blind `lower 8` / `−3px` nudges: the absolute target makes the write idempotent, so the 60 fps drift detector (`needs_traffic_lights_update`, `lib.rs:257`) stops re-applying a frame on every tick.

## 2026-09-19 — macOS traffic lights: 3px to the left

- `lib.rs:116` — the three dots snap to `19.5 / 41.5 / 63.5` (were `22.5 / 44.5 / 66.5`): 3px closer to the window's left edge, with `grow 3` / `lower 8` / `shift 16` + `extra_gap` untouched.
- The target X now lives in `TRAFFIC_LIGHTS_X` (`lib.rs:116`), shared by `adjust_macos_traffic_lights` (`lib.rs:124`) and the drift detector `needs_traffic_lights_update` (`lib.rs:234`). Two hand-kept copies are what made the 60 fps observer re-apply the frame on every tick; the docs' `lib.rs:116` pointers were updated with it.

## 2026-09-18 — Windows cross-compile working

`scripts/build-windows.sh` now cross-compiles the Windows x64 bundle from macOS/Linux with `cargo-xwin` (previously it shelled out to the Prestly-branded `cargo-tauri` and defaulted to `--bundles msi`, which cannot run off-Windows). It resolves the keg-only LLVM/lld paths, checks `cargo-xwin` / the MSVC target / `makensis`, and runs the stock CLI: `pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles nsis`. Outputs `tauri-react-template.exe` + the NSIS setup `.exe`. Docs: `docs/en/scripts.md` § Windows cross-compile.

---

## Lessons for future changes

- If you see `// Prestly pattern` or `// HuLa fix`, that line survived multiple platform bugs. Read the commit before touching it.
- Linux `backdrop-blur` is vetoed for a reason — any re-enable must handle DMABUF + NVIDIA + Wayland and keep RAM flat on resize.
- Traffic lights: never remove one of the three mechanisms — each covers a different timing (general, macOS 26, live-drag).
- `src-tauri/gen/` is always disposable — the real Xcode source is `vendor/tauri-cli-*/templates/mobile/ios/`.

Next: [Contributing →](./contributing.md) · [Native Feel →](./native-feel.md)
