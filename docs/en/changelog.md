# Changelog

> Complete evolution of this template — 52 commits from `455897d` (initial) to HEAD. The milestones table in `AGENTS.md` §1 covers the first 20; the rest is the Windows/Linux window-frame arc documented below. Every entry links to the **reason behind non-obvious code**. Read it before removing anything marked `// HuLa fix`.

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
  - `tauri-plugin-prevent-default` with `Flags::debug()` (`lib.rs:758`) — blocks context menu / reload / devtools in release, keeps them in debug.
- Why `touch-action: pan-x pan-y` not `manipulation`/`none`: keeps native scroll alive; `pan-x pan-y` disables pinch-zoom without killing gesture. See `ae5be97`.

### `ae5be97` `fix: restore normal scrolling in WebKit — touch-action manipulation instead of pan-x pan-y` (superseded)
- Experimentally tried `touch-action: manipulation` — later settled on `pan-x pan-y` (see above) as the WebKit-healthy value.

### `45d5f34` `docs: multiplataforma — native-feel notes`
- Documents that `dragDropEnabled`/`zoomHotkeysEnabled` must be in **all 4 configs**, not just macOS.

## 2026-08-30 — Crystal / glass

### `f997723` `feat: efecto cristal — toggle de translucidez nativa (window-vibrancy)`
- `window-vibrancy 0.8` crate, **sync** command `window_effects_set {enabled, dark?}` (`lib.rs:31`, `lib.rs:125`) — `NSVisualEffectView` on macOS (`HudWindow`/`UnderWindowBackground`), Mica on Windows 11; `unsupported` elsewhere. `VibrancyProvider` (`vibrancy-provider.tsx`) + `localStorage: vibrancy` + `html.vibrancy` → `globals.css:177` transparent body.

### `efc552c` `feat: el efecto cristal sigue el tema de la app`
- `VibrancyProvider` watches `html.dark` via `MutationObserver` and re-applies material on theme change. macOS picks material per `dark` (so crystal follows app theme, not system).

### `5fb6077` `feat: ventana nativa - esquinas redondeadas, arrastre y cristal por tema`
- Fixes `window-vibrancy` being under `[target.'cfg(windows)']` — moves to main `[dependencies]` so macOS links it. Adds `windows = "0.61"` DWM crate (`Cargo.toml:57`). `DwmSetWindowAttribute(DWMWCP_ROUND)` for Windows 11 frameless (`lib.rs:810`). New `native-chrome.ts` (`usePlatform`, `useMacDragRegion`), header with native caption buttons (`header.tsx`).

### `73d445a` `fix: ventana nativa — arrastre con banda reservada y cristal de fondo`
- Reserves a **36px band** (`--native-titlebar-height`) for drag, `app-shell` padding, sticky header at `top:36px`. Full-window crystal: `color-mix(var(--background) 62%, transparent)` so background translucency follows theme.

### `aa83704` `fix: arrastre macOS fiable (patron Prestly, banda 20px)`
- Drag was intermittent: webview selection + sticky header covering the band. Fix: `useMacDragRegion` uses a document-level `mousedown`, `preventDefault` + `startDragging` in band, double-click → maximize, excludes interactive targets. Shrinks band to **20px** (`1.25rem`), header sticky at `top: var(--native-titlebar-height)`.

## 2026-08-31 — Cross-platform window

### `9177b88` `fix: ventana arrastrable y esquinas redondeadas en las 3 plataformas`
- Adds `core:window:allow-start-dragging` to `capabilities/default.json` (without it `startDragging` silently fails). `app-shell` becomes the **scroll container** (`overflow-y: auto`) with `border-radius:10px` on macOS; header gets `data-tauri-drag-region` on Windows/Linux. `html/body` transparent in desktop — `app-shell` owns the background.

### `938f89a` `fix: traffic lights live-resize sin flicker + header alineado + windows NSIS/Wix`
- **HuLa 3-mechanism fix for macOS traffic lights** (`lib.rs:160`):
  1. `WindowEvent::Focused/Resized/ScaleFactorChanged` (`lib.rs:838`)
  2. `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (`lib.rs:331`)
  3. **60 fps polling** (`NSTimer` in `NSRunLoopCommonModes` + `needs_update` `±0.6px`, `lib.rs:865`) — fires during `NSEventTrackingRunLoopMode`
  - Targets `Close 22.5 / Mini 44.5 / Zoom 66.5`, `grow 3`, `lower 8`, `shift 16` + `extra_gap`, `setAutoresizingMask(0)`, header `pl-[96px] sm:pl-[108px]`.
- Also: Windows NSIS/Wix installer assets (`nsis-header.bmp`, `wix-banner.bmp`), `LICENSE.rtf`, multi-size `src-tauri/icons/`.
- Verification: `pnpm build` + `cargo check` on macOS + Linux (docker `webkit2gtk-4.1`).

## 2026-09-02 — Linux glass & curves

### `93657d3` `fix: linux glass veto + curvas ventana + toggle combinado`
- **Linux yellow glitches** (`a2.png`) — WebKitGTK 4.1 + DMABUF + NVIDIA/Wayland + `backdrop-blur` → `AcceleratedSurfaceDMABuf was unable to…` + `Error 71` + RAM spike. Fix: `GlassCardsProvider` returns `false` if `platform==='linux'`, `GlassEffectToggle` disabled, `globals.css:237` strips `backdrop-filter` → `var(--card)`, `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` before `Builder` (`lib.rs:749`). `html.linux .app-shell {border-radius:10px}` fixes flat window (`a1.png`). New `scripts/build-linux.sh`.

## 2026-09-05 — Linux shadow

### `9da8602` `fix: sombra de ventana nativa en Linux via GTK CssProvider + fallback webview`
> **Historical — replaced.** Everything below was deleted; see the 2026-09-07 → 2026-09-18 section.

- `tauri`/`tao` do NOT support `WindowConfig.shadow` on Linux (`"Linux: Unsupported"`). With `decorations:false transparent:true` the `window.background.csd decoration { box-shadow }` node never generates → flat window.
  - **Primary:** `apply_linux_window_shadow` — `gtk_window()` + `CssProvider` (APPLICATION priority) forces `.csd`, restores `decoration { box-shadow: 0 16px 48px rgba(0,0,0,.38); margin:12px; border-radius:10px }` + `:backdrop`, adds `html.gtk-shadow` via `window.eval`.
  - **Fallback:** `html.linux:not(.gtk-shadow) .app-shell` → `margin:12px + box-shadow` — for Sway/Hyprland/X11 where CSD is ignored. Maximized/fullscreen → `0`.
- Adds `gtk = "0.18"` (linux target only) + `useWindowStateClasses` for `window-maximized`/`window-fullscreen` via capability `allow-is-fullscreen`.

## 2026-09-07 → 2026-09-18 — Linux shadow saga, reverted

12 commits (`83042a6` … `98966ab`) chased the Linux frame: hybrid shadow → native-only `StyleContext::add_provider` → CSD latched with a hidden `HeaderBar` → `transparent:false` → forced RGBA visual + `opaque_region` → `set_opacity(0.99)`.

**Outcome — Linux stops drawing its own frame.** `tauri.linux.conf.json:11` uses `decorations: true` + `transparent: false`, so GTK / the compositor draw the titlebar with native minimize / maximize / close, shadow and corner radius. `apply_linux_window_shadow`, the linux-only `gtk` / `gdk` deps and every `.app-shell` frame rule (`border-radius` / `margin` / `box-shadow` / `contain` / inner-scroll) were deleted. Windows also went `decorations: true` here, but that was reverted one day later — see the 2026-09-19 entry. The custom **drag** area stays (`data-tauri-drag-region` + `useWindowDragRegion`, 56px drag band).

Why the hacks could not work: with `transparent:false` tao never installs an RGBA visual (it does it **before realize**, only for transparent windows) and `gtk_widget_set_visual()` after realize is a no-op, so the corners could never blend — the white/opaque 1px corners and the square buffer under the rounded `decoration` were that, not a CSS bug.

Least privilege: `core:window:allow-minimize` / `allow-close` / `allow-is-maximized` / `allow-is-fullscreen` were dropped from `capabilities/default.json:6` (they only existed for the caption buttons and `useWindowStateClasses`). `allow-start-dragging`, `allow-internal-toggle-maximize` (Tauri's injected `data-tauri-drag-region` script) and `allow-toggle-maximize` (double-click fallback in `useWindowDragRegion`) stay. `allow-is-fullscreen` is still unused; `allow-minimize` / `allow-close` / `allow-is-maximized` came back with the Windows caption buttons on 2026-09-19.

## 2026-09-19 — Scroll: header out of the scroller + native overlay scrollbars

The window used the OS default scrollbar on all three platforms — on Windows that is the classic bar: grey gutter, up/down arrow buttons, its own column at the window edge. Worse, it belonged to the *shell* (header + content), so it also stole ~12px from the header and pushed the caption buttons inwards.

- **The scroller moved to the content.** `.app-shell` is now `height:100dvh; overflow:hidden` (clips only) and a new `.app-scroll` (`globals.css:231`) owns `overflow-y:auto` wrapping just `main` + `Footer` (`apps/web/src/App.tsx:52`). The header — which *is* the titlebar — lives outside it, so a scrollbar can neither narrow it nor paint over the close button. The browser build is unchanged (the div is inert, the document scrolls) and keeps `md:sticky`.
- **Overlay scrollbars come from the platform, not from CSS.** Windows: `"scrollBarStyle": "fluentOverlay"` (`tauri.windows.conf.json:13`, WebView2 >= 125.0.2535.41) → Fluent overlay bar (thin pill, auto-hides, floats over the content). macOS keeps its native auto-hiding overlay; Linux follows `gtk-overlay-scrolling` in WebKitGTK.
- **Discarded first attempt (do not repeat):** a custom `::-webkit-scrollbar` pill (12px gutter, 6px thumb, transparent track, no buttons) looked right but forces the *classic* non-overlay scrollbar in both WebKit and Chromium — on macOS it kills the native auto-hide, and it fights `scrollBarStyle`. Adding `scrollbar-width`/`scrollbar-color` made it worse: in Chromium those standard properties take precedence and **ignore** the webkit pseudo-elements, which is how the arrow buttons came back. No scrollbar CSS remains.
- Verified on Windows 11 build 26200: header reaches the rounded corner with no gutter, no scrollbar when idle, a thin overlay pill while scrolling, wheel and PageDown scroll the new container.

## 2026-09-19 — Windows: overlay titlebar with decorum (Edge style)

Windows is frameless again (`tauri.windows.conf.json:12` → `decorations: false`, `transparent: true` kept for Mica) and the app draws the titlebar: the [decorum](https://github.com/clearlysid/tauri-plugin-decorum) community plugin (`Cargo.toml`, Windows-only target deps; `lib.rs:774`) plus `create_overlay_titlebar()` in `setup()` (`lib.rs:814`). This is the Edge / VS Code model — one fixed 44px band instead of the OS frame on top of the app header.

- `apps/web/src/components/layout/window-controls.tsx:61` renders minimize / maximize-restore / close (lucide icons, 46px hit area, red hover on close), mounted by `header.tsx:224` only when `platform === 'windows'`.
- The buttons sit **flush with the right edge** (`window-controls.tsx:120`, no `pr-2`): the 46px close button ends exactly at the client edge, so its red hover reaches the corner and DWM clips it with the window radius. Same geometry as Edge/Chromium (46px wide, icon ~23px from the edge).
- Snap Layouts: hovering maximize for 620 ms (`window-controls.tsx:8`) focuses the window and invokes `plugin:decorum|show_snap_overlay` (`window-controls.tsx:104`) — decorum presses Win+Z and then Alt to hide the numbered badges. Chromium answers `WM_NCHITTEST` with `HTMAXBUTTON` for the true hover flyout; tao does not expose that hook, so this is the closest equivalent. Verified on a Windows 11 build 26200 VM: minimizar / maximizar / restaurar / cerrar work, dragging by the header moves the window, `DwmGetWindowAttribute` reports `corner = 2` (`DWMWCP_ROUND`), `WS_THICKFRAME` stays set (resizable) and the flyout opens after the hover — see `troubleshooting.md` for the black-window gotcha when the app is launched from a service context.
- `globals.css:230` hides the 32px titlebar decorum injects (`[data-tauri-decorum-tb]`), which would cover the header and swallow the button clicks; the drag band stays ours (`data-tauri-drag-region` + `useWindowDragRegion`, `header.tsx:68`). Resize borders still work (tao hit-tests the frame edges of undecorated resizable windows) and `DWMWCP_ROUND` (`lib.rs:810`) keeps the corners round.
- Permissions: `allow-minimize` / `allow-close` / `allow-is-maximized` / `allow-set-focus` back in `capabilities/default.json:6` (the last one is `capabilities/default.json:15`; without it `setFocus()` rejects and the `catch` in `window-controls.tsx` swallows it, so the Snap Layouts flyout silently never opens), and `decorum:allow-show-snap-overlay` in its own `capabilities/windows.json:7` with `platforms: ["windows"]` — the plugin is a `cfg(windows)` dependency, so keeping the permission in `default.json` made every macOS/Linux `cargo check` fail with `Permission decorum:allow-show-snap-overlay not found`. Linux keeps full native decorations; macOS untouched.

## 2026-09-19 — Titlebar: fixed 44px band + readable control hover

- `header.tsx:29` — `HEADER_HEIGHT` pins the band per platform (`h-[52px]` macOS, `h-11` = 44px Win/Linux, `h-14` mobile) instead of one `h-14`. 44px is what the shell's flex column already squeezed the header down to (min-content), i.e. the band users actually saw; `shrink-0` + the fixed class just stop it from depending on the page content. The caption buttons (`h-full`) fill the band and the language / theme controls stay 32px, so the pill never clips.
- `native-chrome.ts:12` — the drag band no longer hardcodes 56px: `headerBandHeight()` measures `.app-header` at runtime (fallbacks 52 macOS / 44 Win-Linux), so band and drag zone cannot drift apart.
- `header.tsx:18` — language / theme buttons share one hover token, `hover:bg-black/10 dark:hover:bg-white/15`, applied to **both** the shadcn and the glass branch. The old defaults were unreadable on the band: `bg-muted` / `dark:bg-muted/50` vanish on the dark translucent bar, and the glass `hover:bg-white/10` inverts to 6 % black in the light theme (`globals.css:403`). The glass buttons keep `hover:scale-100`, so the pill no longer grows out of the titlebar.
- Verified on the Windows 11 build 26200 VM (VNC + pixel probe): the titlebar band is 44px (48 captured px at the VM's ~1.09 scale, caption hover rect + 1px border), the theme / language hover goes `(11,11,11)` → `(49,49,49)` in dark and `(254,254,254)` → `(228,228,228)` in light, the red close hover still spans the last 46px (x=1350..1399, client edge 1400) and dragging the band moves the window exactly as far as the pointer.

## 2026-09-20 — Two independent glass switches

- The combined `GlassEffectToggle` is gone. `GlassControls` (`apps/web/src/components/layout/glass-controls.tsx`) renders two switches side by side: `VibrancyToggle` (`vibrancy-toggle.tsx`, the native window material) and `GlassCardsToggle` (`glass-cards-toggle.tsx`, the web `glass-*` components).
- Any combination is now valid: vibrancy + solid cards, glass cards on an opaque window, or both. The two providers were already independent (`localStorage: vibrancy` vs `glass-cards`) — only the single switch tied them together.
- `GlassCardsProvider` now exposes `supported` (`platform !== 'linux'`) and collapses `enabled` to `false` there, so on Linux the switch renders **disabled** with the "unavailable on this platform" tooltip instead of flipping a switch that does nothing. `useGlassCards()` no longer re-implements the Linux veto; the `html.glass-cards` class follows the effective value.
- i18n: `vibrancy.label` is now "Crystal effect" / "Efecto cristal" (it no longer drives the cards) and both switches expose their `hint` as a tooltip.
- `glass-effect-toggle.tsx` deleted. Checks green: `pnpm typecheck`, `pnpm lint`, `pnpm test`.

## 2026-09-19 — macOS traffic lights: 2px further left

- `TRAFFIC_LIGHTS_X` (`lib.rs:160`) is now `17.5 / 39.5 / 61.5` (was `19.5 / 41.5 / 63.5`): 2px closer to the window's left edge, vertical centring and `grow 3` / `shift_right 16` + `extra_gap` untouched.
- Verified with a screen capture: dots at `17.5–75px` from the window's left edge, centre `26px` from the top (middle of the 52px header).

## 2026-09-19 — macOS traffic lights centred in the 52px header band

- `traffic_lights_target_y` (`lib.rs:185`) now derives `y` from the button **superview** (`isFlipped()` + container height) instead of assuming the frame `y` is the distance from the window top. On macOS 26 that titlebar container is **not flipped**, so the old absolute write of `26 - size/2` pushed the dots ~9px *up*: measured from the window top they went from `9–23px` (native) to `0–13px`.
- Result: dot centres sit at `MACOS_HEADER_BAND / 2` (`lib.rs:166` = 26px) — the middle of the macOS header (`header.tsx:29`, `h-[52px]`). Verified with a plain screen capture: native centre `15.8px` → `25.8px`.
- `adjust_macos_traffic_lights` (`lib.rs:205`) drops the blind `lower 8` / `−3px` nudges: the absolute target makes the write idempotent, so the 60 fps drift detector (`needs_traffic_lights_update`, `lib.rs:300`) stops re-applying a frame on every tick.

## 2026-09-19 — macOS traffic lights: 3px to the left

- `lib.rs:160` — the three dots snap to `19.5 / 41.5 / 63.5` (were `22.5 / 44.5 / 66.5`): 3px closer to the window's left edge, with `grow 3` / `lower 8` / `shift 16` + `extra_gap` untouched.
- The target X now lives in `TRAFFIC_LIGHTS_X` (`lib.rs:160`), shared by `adjust_macos_traffic_lights` (`lib.rs:205`) and the drift detector `needs_traffic_lights_update` (`lib.rs:300`). Two hand-kept copies are what made the 60 fps observer re-apply the frame on every tick; the docs' `lib.rs:160` pointers were updated with it.

## 2026-09-18 — Windows cross-compile working

`scripts/build-windows.sh` now cross-compiles the Windows x64 bundle from macOS/Linux with `cargo-xwin` (previously it shelled out to a third-party branded `cargo-tauri` and defaulted to `--bundles msi`, which cannot run off-Windows). It resolves the keg-only LLVM/lld paths, checks `cargo-xwin` / the MSVC target / `makensis`, and runs the stock CLI: `pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles nsis`. Outputs `tauri-react-template.exe` + the NSIS setup `.exe`. Docs: `docs/en/scripts.md` § Windows cross-compile.

---

## 2026-09-22 — Linux titlebar follows the app theme (`GtkHeaderBar` / CSD) → superseded

- **The native frame cannot follow the in-app theme.** mutter resolves the SSD titlebar variant from the `_GTK_THEME_VARIANT` X11 property **once, when the window is managed** (`LOAD_INIT` in `mutter/src/x11/window-props.c`). Verified on GNOME 46 that `window.setTheme()` (which only reaches `gtk-application-prefer-dark-theme`), writing the property with `xprop` and a real unmap/remap all leave the bar on the system variant — a dark app on a light desktop kept a white titlebar, and the other way round.
- `install_linux_titlebar` (removed in the 2026-09-23 entry) installs a real `GtkHeaderBar` (CSD) in `setup()`: GTK paints it in-process, so it repaints the instant `gtk-application-prefer-dark-theme` flips. `useNativeTheme` (`native-chrome.ts:131`, wired in `title-bar.tsx:21`) drives `window.setTheme()` from the resolved theme, **Linux only** (on macOS it would change `NSApp` appearance, on Windows the app-wide dark mode).
- `tauri.linux.conf.json:11` keeps `decorations: true` and gains `visible: false` (`:12`): the window is born hidden so the headerbar lands **before** GTK realizes it — no `Gtk-WARNING: gtk_window_set_titlebar() called on a realized window`, no flash of the system frame. `setup()` shows it at the end either way.
- `gtk = "0.18"` returns as a Linux-only dependency (`Cargo.toml:69`, the same version tao/wry use). Native buttons, shadow and rounded corners come from GTK's CSD; still no CSS frame on `.app-shell`.
- New permission `core:window:allow-set-theme` (`capabilities/default.json:16`): without it `setTheme()` rejects silently and the bar keeps the system variant.

## 2026-09-23 — Linux: app-drawn titlebar over a latched CSD frame (superseded by the GTK frame-class/resize work below)

- Two bugs in the 2026-09-22 design, both verified on GNOME 46: (1) the **bottom** corners were square — GTK's CSD rounds the window background, but the webview paints over it (the top ones only looked right because the GTK headerbar covered them); (2) the `GtkHeaderBar` was **not draggable** — tao creates the window in SSD mode, so GTK never wires the CSD drag (the app header's own drag *did* work).
- The fix follows the Edge / VS Code / Chromium "custom frame" pattern, i.e. the same model as Windows: the **app draws the titlebar** (`header.tsx` 44px band + `WindowControls` for Win/Linux, `header.tsx:222`) and `install_linux_frame` (`lib.rs:672`) latches CSD with an empty, hidden `GtkHeaderBar` plus a transparent GTK window background, so GTK contributes only its **native shadow**.
- `set_no_show_all(true)` is load-bearing: tao shows the window with `window.show_all()` (`vendor/tao-0.35.3/src/platform_impl/linux/event_loop.rs:308`), which re-showed the hidden bar and ate 43px at the top.
- `globals.css:245` → `html.linux .app-shell { border-radius: 10px }`: with a transparent frame the shell defines the shape.
- **`transparent: true`** (`tauri.linux.conf.json:13`) is what makes the corners *look* round. With `transparent: false` the radius was applied and the corners were transparent in the DOM, but the **webview's own background** stayed opaque (Adwaita's base `#1e1e1e`) and filled the area outside the radius, so they read as square. tao installs the RGBA visual **before realize** and only for transparent windows, and wry only clears the webview background for transparent windows — the missing piece the old `apply_linux_window_shadow` never had. Verified with a per-row pixel scan of the corner: with `transparent: false` the content edge is a straight line (`inset=0` on every row); with `transparent: true` it follows the arc (`inset 8 → 4 → 2 → 1 → 0`) and the corner pixels are the desktop.
- Verified on the Ubuntu ARM box: drag (`80,80 → 179,180`), minimize (`_NET_WM_STATE_HIDDEN`), maximize (`MAXIMIZED_HORZ/VERT` + restore icon), double-click to restore, four rounded corners with shadow, in light and dark.

## 2026-09-24 — Linux corners: rounded shadow + webview clip → superseded

- The corners *were* rounded (the CSS radius applied and the pixels were transparent) but they still read as square, because GTK3's Adwaita only rounds the **top** corners: `decoration { border-radius: $window_radius $window_radius 0 0 }` (`$window_radius = 8px`), so its shadow is square at the bottom. Same bug Firefox fixed behind `gtk.rounded-bottom-corners` (bugzilla 1964149). Fix: rewrite the frame radius from a `GtkCssProvider` (`window.background` + `decoration { border-radius: 10px }`), the approach the GTK community recommends.
- Second artifact: with the software renderer Linux requires (`WEBKIT_DISABLE_DMABUF_RENDERER=1`) the **webview surface is opaque** — wry's `set_background_color(transparent)` is not enough — and a square "shoulder" showed just outside the rounded corners (Firefox bug 1509931). Fix: the experimental X11 webview shape clip shapes the webview's `GdkWindow` to the same rounded rect via `gdk_window_shape_combine_region` (X11; a no-op on Wayland, where the surface is already transparent). Re-applied on `size-allocate` and `realize`.
- `transparent: false` cannot work: without alpha nothing can blend at the corners, so the webview's own background (Adwaita base `#1e1e1e`) fills them. Verified by pixel scan: with `false` the content edge is a straight line, with `true` it follows the arc (inset 8 → 4 → 2 → 1 → 0).
- Known residual: a ~1px brighter arc on the corner (GTK draws the shadow around the decoration's box, leaving a thin dead band inside it). Dropping `.app-shell`'s radius and letting the clip alone define the shape removes it at the cost of an aliased corner.
- Verified on the Ubuntu ARM box: the arc measured at all four corners, drag (`200,150 → 260,210`), minimize (`_NET_WM_STATE_HIDDEN`), maximize (`MAXIMIZED_HORZ/VERT`) + restore, no WebKit errors.

---

## 2026-09-24 — Linux: native CSD decoration, no overrides (superseded)

- Simplifies the frame after measuring the alternatives. `transparent: true` + a `decoration` radius override + an X11 shape clip on the webview did round all four corners, but the clip is lost whenever WebKit recreates its render window (a page reload), and with `transparent: false` the webview surface stays opaque, so the clip was the only thing shaping the corners in the first place.
- Final design: GTK keeps its **native** decoration untouched. `install_linux_frame` (`lib.rs:672`) only latches CSD with an empty, hidden `GtkHeaderBar`; `transparent: false`; `.app-shell` gets `border-top-left/right-radius: 8px` (Adwaita's `$window_radius`) so the content does not cover GTK's top rounding. GTK3 rounds only the top corners (`decoration { border-radius: r r 0 0 }`), so the bottom corners are square — native GTK3.
- The titlebar stays the app's (44px header + `WindowControls`), which is the whole point: mutter's SSD cannot follow the app theme (`_GTK_THEME_VARIANT` is read once, `LOAD_INIT`) and its titlebar is not draggable under tao.
- Measured with a pixel scan of the top-left corner: the 8px arc is there, filled by the webview's background (`#1e1e1e` dark / white light) — in a dark theme it reads as a slightly lighter rounded edge, which is the native frame colour. Drag, minimize, maximize and restore verified.

---

## 2026-09-24 — Linux: GTK frame class + system-rounded CSD + shadow resize grip

- **GTK frame class (Chromium theme-integration pattern):** `install_linux_frame` assigns `tauri-app` to the GtkWindow `window.background` node (`APP_FRAME_CLASS`, `lib.rs:385`); the app provider targets `window.background.tauri-app decoration`. Confirmed at runtime: the class appears alongside `background` and `csd`, and a temporary class-scoped GTK border styles the actual frame node. The test style was removed; GTK themes/user CSS can target the same selector.
- **Rounded native CSD:** GTK3 Adwaita defaults to top-only corner rounding. The app provider explicitly sets `border-radius: 16px` on the `decoration` node (`lib.rs:697`), and `.app-shell` matches (`globals.css:245`), so GTK paints a rounded shadow/frame at all four corners while the window stays `transparent: false`.
- **Resize from the CSD shadow margin:** GTK docs say the `.csd` shadow area is normally a resize grip, but tao did not reliably deliver those edge events. `install_linux_resize_grip` (`lib.rs:537`) includes the margin in the GTK input region (outermost 8px click-through), sets the directional cursor, and calls `gtk_window_begin_resize_drag`. The input shape is reapplied on realize/map/size-allocate. `useWindowResizeEdges` / `start_window_resize` (`lib.rs:88`) handle the inner 6px webview edge. Verified on all eight edges/corners; repeated right-edge drags 1100 → 1220px.
- **Chromium comparison:** Current Chromium `BrowserFrameViewLinux` paints a custom Views frame with its own shadow/hit-testing and uses top-only corner radii. This app deliberately keeps GTK's native CSD decoration and shadow; the adopted Chromium-inspired piece is the named GTK CSS class for theme integration.
- Verified on the Ubuntu ARM GTK3 desktop: theme class, 16px four-corner GTK decoration, shadow-margin resize, app-edge resize, drag, minimize/maximize/restore. `transparent: false` is retained.

---

## 2026-09-25 — Linux: `transparent: true` makes the corners real

- The 16px `decoration` radius and the `tauri-app` class were correctly applied (proven with a temporary magenta border test), yet zoomed screenshots still showed square corners. Root cause, confirmed by evidence: with `transparent: false` the X11 window has no alpha channel, so the compositor cannot blend anything — every pixel of the window rectangle stays opaque and CSS radius can only round what is drawn inside.
- Fix: `tauri.linux.conf.json:13` → `transparent: true`. Tao installs the RGBA visual before realize, the compositor antialiases the arc, and the desktop shows through. Verified with zoomed screenshots in light and dark themes, margin/content resize (1100 → 1220px), header drag, minimize/maximize/restore, and a maximized window with no gaps — no WebKit errors.
- Kept deliberately: CSD latch, `tauri-app` class, `decoration` radius override, both resize paths, `WEBKIT_DISABLE_DMABUF_RENDERER=1`.

---

## 2026-09-25 — Linux: radius on both GTK nodes + single shadow fixes corner tips

- Zoomed screenshots still showed a small opaque square at each extreme corner tip, past the rounded content arc. Proven with a temporary green test: it was the `window.background` node painting square — the radius was only on the `decoration` child. Fix: `window.background.tauri-app { border-radius: 16px }` plus `window.background.tauri-app decoration { border-radius: 16px; box-shadow: 0 3px 12px rgba(0, 0, 0, 0.5) }` (`lib.rs:697`).
- The single `box-shadow` matters: an earlier revision styled the shadow on both nodes and the stacked shadows left a dense patch at the tips.
- Verified at 6x zoom on all four corners: clean antialiased arcs, soft shadow, no nubs — with `transparent: true` retained.

---

---

## 2026-09-27 — Linux: frameless + opaque, square corners accepted (supersedes the CSD arc above)

- The rounded CSD corners worked, but transparent tips stayed visible at the extreme corners and the machinery never paid for itself: GTK provider CSS (`tauri-app` class, 16px radius on both nodes), input-shape grip (`apply_grip_input_shape`, `install_linux_resize_grip`, `find_webview`), two resize paths, `allow-set-theme` + `useNativeTheme`. Deliberate decision: `tauri.linux.conf.json` → `decorations: false` + `transparent: false`, square system corners as part of the platform.
- Removed: `install_linux_frame`, `install_linux_resize_grip`, `apply_grip_input_shape`, `find_webview`, `edge_from_position`/`edge_cursor_name` (+ their `lib.rs` tests), `useNativeTheme`, the `core:window:allow-set-theme` permission, and the input-shape probe (`scripts/probe-input-shape.sh`, which had measured `GDK_REGION_SET` = replace). Kept: `start_window_resize` (a frameless window gets no WM handles — the inner 6px edge still drives `begin_resize_drag`), `WEBKIT_DISABLE_DMABUF_RENDERER=1`, the glass veto.
- `setup()` centers the window and calls `window.show()`: born hidden (`visible: false`), shown already centered. Verified: `cargo check` + `cargo fmt` + `pnpm typecheck` + `lint` + `test` green.

## 2026-09-29 — Public-ready: skills, mobile icons, physical devices

- **`linux-build` skill** (`.claude/skills/linux-build/`) absorbs `scripts/build-linux.sh` (+ `.cmd`): SSH-only Linux builds on the Ubuntu-arm-docker box (Cinnamon/X11), rsync without `.git` (never clones), `--debug` = fast `--no-bundle`, `--verify` = `assistant windows+shot+ocr`; auto-starts Vite for debug runs (devUrl `:1420`). Makefile: `build-linux` → fast loop, new `linux-release`, `build-windows` (cargo-xwin).
- **Mobile icons fixed at the root**: `branding/icon-1024.png` is the master (`branding.json` `icons.master`); `scripts/mobile/mobile-icons-regen.sh` (post-init in `apple-xcode.sh`/`android-autogen.sh`) runs `tauri icon` + composes the iOS 1024 marketing trio (light/dark/tinted) that this CLI version never generates. The vendored mobile templates ship neutral placeholders — a fresh `gen/` can never carry foreign artwork. Positives: the `xcodegen`-based generator is gone from docs (vendored CLI init is the only one).
- **Branding**: `make rebrand` now also propagates `authors` + `description` (Cargo.toml, package.json) and warns the Linux box follow-up (skill derives the binary from Cargo.toml).
- **iOS fleet**: `.env` loads automatically in make (include+export) and `apple-xcode.sh` sources it; `APPLE_DEVELOPMENT_TEAM` translated from `DEVELOPMENT_TEAM` with `scripts/.team-id` fallback; every make recipe resolves `cargo`/`rustc` through rustup (Homebrew cargo lacks the cross std → E0463). Verified end-to-end on a physical iPhone 15 Pro Max (Personal Team, free 7-day provisioning) and on a physical ARM32 Android device (armv7 APK, `INSTALL_FAILED_NO_MATCHING_ABIS` → `--target armv7`).
- **`install-skills.sh --verify` is content-aware** (hash every file; MISSING/STALE/EXTRA + exit code; portable md5).
- **Android status bar, two grave bugs fixed**: (1) launch flash was the Material3 default lavender/purple window background — the android template now sets `tauri_window_bg` (frontend tokens: `#FFFFFF` / zinc-950 `#18181B`) in `values{-night}/themes.xml` + `values-v31` splash; (2) after backgrounding+re-entering, the resume/focus handlers re-applied the SYSTEM night state, so a light app on a dark system (or vice versa) got invisible icons — `MainActivity` now persists the FRONTEND-resolved style (`lastJsNight`/`resolvedNight`) and re-applies that. Verified on the physical armv7 device with pixel probes (launch frame = `#18181B`, no purple; icons visible after return: 10.3% dark pixels in the bar strip) and logcat (old: resumes said night=true after the JS call; new: style kept).
- **Linux theme bridge + chrome E2E** (Cinnamon box, `decorations:false` kept after 4 experiments — `decorations:true` always brings muffin's native titlebar; GTK3 has no overlay): new Rust command `set_linux_theme` pushes the app's RESOLVED theme into GTK (`gtk-application-prefer-dark-theme`), invoked by the theme provider like `set_status_bar_style`, so WebKitGTK scrollbars/native controls stop following the system when app and system disagree (log-verified `prefer-dark=false/true/false` on toggles). Resize grip band 6px→8px (`RESIZE_BAND`, native frames feel better because their grab is forgiving). E2E with xdotool on the box: drag delta exact (+120,+60), west resize exact (−100/+100), double-click maximize (1920×1040) and restore (1300×800). AGENTS §4 Linux row updated.
- **Pre-publication sweep**: removed leftover supabase bits from the old project — CSP `connect-src https://*.supabase.co` (base + macOS conf) and the `build.rs` EMBED_KEYS / `validate_supabase_url` (which would PANIC a release build whose backend was not *.supabase.co). Added `.gitattributes` (LF for scripts/configs, binary markers — Windows clones keep working) and a root `CONTRIBUTING.md`. Fixed the Tailwind CSS warning: `env()` inside arbitrary values is emitted as invalid `env(...)` by Tailwind v4 / lightningcss (the header `pt-[env(safe-area-inset-top)]` class never applied and the `h-[calc(3.5rem+env(...))]` calc broke the CSS optimizer) — safe-area top padding + mobile header height now live as plain CSS on `.app-header` (`html.ios/.android`), build is warning-free. LICENSE holder set to Yanx Studio; `make doctor` reports cargo-tauri via the real `cargo tauri` invocation. GitHub repo metadata set (description + topics).
- **CI semanal por schedule** (decisión con la cuenta gratuita en mente): `.github/workflows/ci.yml` corre solo lunes 18:00 UTC + `workflow_dispatch` (nada de push/PR). Los jobs solo llaman targets del Makefile — `make ci-frontend` y `make ci-rust` (ubuntu-latest, `permissions: contents: read`); móvil y bundles nativos siguen fuera (pipeline manual de 5 OS). Dependencias del sistema Tauri instaladas para clippy/fmt/test; `.nvmrc`/engines y rust-cache reutilizados. Documentación EN/ES del "sin CI" corregida (README, testing, AGENTS, scripts) y changelog EN+ES (buena parte con especificación externa).
- **Rust cleaned to pedantic+nursery zero-warning**: full manual review of `lib.rs` (750L) + platform stubs + `main.rs` + `build.rs`. clippy `-D warnings -W pedantic -W nursery` now reports 0 lints on the host AND on the Linux box (word `cfg(linux)` paths): const-extracted constants, `ptr.cast`, `Self::` arms, semicolons, doc backticks + `# Panics`, `eprintln!` → `log::info!`, targeted `#[allow]` with reasons where Tauri's command contract requires owned args/`Result` (window_effects_set, set_status_bar_style, set_linux_theme). `make ci-rust` stays on standard clippy per the CI spec.
- **Maintainability guards** (local, kept OUT of the CI spec): `make check-docs` runs `scripts/check-docs-parity.sh` (file list + per-level heading counts + order proxy — translation legitimately changes heading words, so structure, not titles, is compared — plus the docs/README router coverage) and `scripts/check-agents-anchors.sh` (AGENTS + fresh docs `file:line` anchors resolved via the filename map; changelogs excluded because history cites old lines on purpose). Both catch the two drift modes we actually hit (parity slips, anchors ~100 lines off).
- **Maintainability recommendations applied**: (1) versioning policy written in contributing.md (EN+ES) — when to bump TEMPLATE_VERSION/tag, semver mapping, rebrand+regen+verify on bumps; (2) `make check-docs` wired into `.husky/pre-commit` (parity + anchors now block commits); (3) weekly-CI maintenance documented in testing.md (EN+ES) — manual dispatch, what a red Monday means, "don't silence the job"; (4) einui registry risk documented in contributing.md (EN+ES) — committed components are self-contained; the registry is only needed for NEW ones.
- **i18n compliance sweep (frontend)**: the footer built its sentence with hardcoded strings ('Built with'/'Hecho con', ' and '/' y ') and a hardcoded "© Yanx Studio" — violating the AGENTS §5 keyed-strings rule and blocking adopter rebrands. Footer now renders the existing `footer.builtWith` key and a new `footer.copyright` key (`© {{year}} Yanx Studio`, editable — adopters rebrand without touching JSX). The greet demo stopped string-replacing the backend reply (locale-fixed + brittle) — display text comes from the new keyed `status.greeted` with interpolation, while the IPC call stays as the error-path demo. en/es key sets stay identical (checked). All frontend keys now flow through `t()`.
- **Capabilities hardened**: `opener:allow-open-url` now explicit in default.json (the main.tsx external-link interceptor depends on it — `opener:default`''s set could change across plugin versions; the explicit grant makes the system-browser behavior a guaranteed contract instead of a default-set accident). Verified via cargo check (capabilities validated against the schema).
- **Web identity**: the web layer was the last un-branded surface — `apps/web/public` did not exist, so the favicon link pointed at a missing `/vite.svg` (blank icon in browsers/webviews), and `index.html` `<title>`/`og:title` stayed template-branded after a rebrand. `branding-update.sh` now sets title/og:title (Title-Case display name via python3 — portable, no GNU sed) and generates `public/favicon.png` (128px) from the icon master; index.html now references `/favicon.png`. Root `package.json` gained the missing npm metadata: `license: MIT`, `repository`, `homepage` (adopter-facing completeness).
- **Greet i18n bug found by the new interp guard**: the `status.greeted` locale key used single braces `{name}` but i18next interpolates `{{name}}` — the greeting rendered literally "Hello, {name}!". Fixed both locales. `.husky/pre-commit` lacked `set -euo pipefail`: a failing `lint-staged` could be masked when the trailing `make check-docs` passed (commit went through). Guard added. `check-docs-parity.sh` gained a 4th check: single-brace interpolation detection, anchored `(?<!\{)\{…\}(?!\})` — the first naive regex backtracked inside `{{year}}` (false positives on every `{{…}}`), caught and replaced with the anchored version (verified on samples: 0 false positives, real singles flagged).
- **Frontend audit fixes (agent A, batch 1)**: H1 mobile header — `html.ios`/`html.android` were never added (title-bar gated everything on desktop), so the safe-area height rule was dead code; every known platform now gets its class (unknown strings are ignored — never throw on classList) + regression tests. H2 `apps/web` typecheck was a no-op (solution-style tsconfig + `tsc --noEmit`); now `tsc -p tsconfig.app.json && tsconfig.node.json` (26 src files checked, was 0). H3 theme toggle from `system`+dark wrote "dark" (no-op first click) — the provider now exposes `resolvedTheme` and the toggle flips from it (+ tests). M1 glass no longer applies before the platform resolves in the Tauri shell (Linux boot flash). M4 the resize band no longer steals clicks from controls inside the top 8px and stops the drag hook from double-firing (one IPC per press). M5 focus ring visible in light+glass; iOS tap-highlight suppressed. M7 greet text translates at render (no locale freeze). Skip link + main-nav label keyed; dead i18n keys removed; hero hint no longer prints "D" twice. +9 regression tests (17 total in web).
- Nits: `biome.json` schema 2.5.14, `turbo.json` test `outputs: []`, template `authors`, `IOS_DEVICE` → `iPhone 18 Pro` everywhere, `AGENTS.md` §4 invariant `file:line` refs re-pinned to current code.

### Audit sweep 2 — backend/configs/tooling truth pass
- **Real bugs fixed**: `scripts/build-windows.sh` Linux LLVM PATH (`/usr/lib/llvm-*/bin` was quoted → a literal `*` that never expands, so cargo-xwin could not find `llvm-rc`/`lld-link`; now a glob loop); `scripts/branding-update.sh` used BSD-only `sed -i ''` (aborts GNU sed under `set -e` → rebrand broken on Linux/Git Bash; now portable python3); `env_logger` was declared but never initialized (every `log::*` call in the crate was a silent no-op — now `Builder::from_env` at the top of `run()`); the vendored CLI test contradicted MOD-1 (`fetch_options` falls back instead of erroring — assertion fixed; `cargo test --lib mobile::` green); `detect-project.sh` identity grep missed the capital-T crate name (case-insensitive now).
- **CSP unified**: `https://*.supabase.co` removed from `tauri.windows.conf.json` + `tauri.android.conf.json` — the four targets now ship the identical CSP (base + macOS were already clean), so the `tauri.md` "one strict policy on all targets" claim is true. The `SUPABASE_*` validation claims in `tauri.md`/`getting-started.md`/`.env.example` are gone (the code never had them).
- **Dead weight removed**: `build.rs` actool → `TAURI_ASSETS_CAR` path (nothing consumed the env var; tauri-bundler only reads `.car`/`.icon` entries from `bundle.icon`, so the "themed AppIcon" never shipped — `icon.icns` was always the real icon) + `CFBundleIconName` from `Info.plist`; `src-tauri/vendor/tao-0.35.3` + `swift-rs` (unreferenced, 1.6 MB); the Prettier VS Code recommendation (repo is Biome-only); unused `tokio` deps (macOS target dep + dev-dep, zero uses); the phantom `TAURI_CLI` env row (nothing reads it).
- **Rebrand robustness**: the Xcode phase hardcoded the source lib name (`libtauri_react_template_lib.a`, lowercase — worked on case-insensitive APFS only and would break for every rebranded adopter) → now a `lib*.a` glob (the crate name changes with branding; the linked name `libapp.a` does not). Validated with a full `apple-xcode.sh --build` on macOS.
- **Info.plist**: dropped `NSAllowsArbitraryLoads` (kept `NSAllowsLocalNetworking` — devUrl is local), bilingual `NSLocalNetworkUsageDescription`.
- **Docs truth pass**: `hotreload` retired everywhere it was still documented as a live config (scripts/README, mobile, troubleshooting, mods.md, xcode-dev.command, README — EN+ES): the 2.12 rebase made `debug` the dev/HMR flow, and the 2.11-era JSON-RPC probe prose is gone. The `__TAURI_DEVELOPMENT_TEAM__` sentinel claim replaced with reality (`APPLE_DEVELOPMENT_TEAM` exported by `apple-xcode.sh`, consumed at `ios init`). `pnpm dev:web` → the real `make dev:web`. Resize band 6px → 8px everywhere current (README, testing, tauri, native-feel, troubleshooting). `TPL`/`TAURI_CLI` → `TMPL_DIR`/`CARGO_TAURI` in the rebase skill. Windows binary naming (`Tauri-react-template.exe`). scripts/README inventory completed (branding-update, check-*, mobile/*.swift). `Cargo.toml` metadata gained `license` + `repository`.
- **Anchors re-pinned**: every `lib.rs:NNN` across AGENTS + docs re-resolved against the current file (the env_logger insertion shifted ~+7 lines; older entries cited three different eras), plus `header.tsx`, `window-controls.tsx`, `globals.css`, `App.tsx`, `Cargo.toml` and `capabilities/default.json` refs. A naive auto-fixer was tried and reverted (it corrupted 9 files and mis-resolved symbols to comment mentions) — the final pass used explicit verified line pairs.

## Lessons for future changes

- If you see `// HuLa fix`, that line survived multiple platform bugs. Read the commit before touching it.
- Linux `backdrop-blur` is vetoed for a reason — any re-enable must handle DMABUF + NVIDIA + Wayland and keep RAM flat on resize.
- Traffic lights: never remove one of the three mechanisms — each covers a different timing (general, macOS 26, live-drag).
- Linux titlebar: the window is frameless + opaque (`decorations: false`, `transparent: false`), square system corners by design — the CSD arc (latched `GtkHeaderBar`, `tauri-app` class, input shape) was removed deliberately on 2026-09-27. The app still draws its own titlebar (`header.tsx` + `WindowControls`) and the inner 8px edge still drives `begin_resize_drag` (`start_window_resize`). Never re-add radius CSS or a GTK provider to round the corners.
- `src-tauri/gen/` is always disposable — the real Xcode source is `vendor/tauri-cli-*/templates/mobile/ios/` (now rebased on stock 2.12.0 + local tweaks; the mobile2 `[patch]` is gone since 0.22.5 shipped the Xcode 27 fix).

Next: [Contributing →](./contributing.md) · [Native Feel →](./native-feel.md)
