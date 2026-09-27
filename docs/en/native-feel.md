# Native Feel — Cross-Platform

> **Audience:** window work — per-OS chrome, guards, vibrancy, scrollbars. All changes here must be tested on every target.

> **This is a multi-platform app** (desktop: **macOS, Windows, Linux**; mobile: **iOS, Android**) — every change must work and be tested on all systems. Never assume macOS/iOS only.

## Shared guards (all windows / all OS)

Derived from commit `c9ae1a4`:

- `tauri*.conf.json` (all 4 configs): `dragDropEnabled: false` + `zoomHotkeysEnabled: false` in every `windows[]` entry — not just macOS.
- `apps/web/index.html:5` — viewport `user-scalable=no, maximum-scale=1.0, viewport-fit=cover`
- `packages/ui/src/styles/globals.css:137` — `* { user-select:none; -webkit-user-drag:none; touch-action: pan-x pan-y }` (inputs/textarea/contenteditable re-enable text selection). No `overscroll-behavior:none`.
- `apps/web/src/main.tsx:21` — `dragstart` block, wheel zoom (`ctrl/meta + wheel`) block, external links → `openUrl` via `plugin-opener`.
- `src-tauri/src/lib.rs:403` — `tauri-plugin-prevent-default` with `Flags::debug()`: in **release** blocks webview defaults (context menu, devtools, reload); in **debug** keeps them. Never touches document scroll.

Mobile (iOS long-press menu, Android) relies on the same CSS/JS (`touch-action: pan-x pan-y` kills double-tap zoom on iOS).

## macOS — traffic lights (live-resize without flicker)

Reference: `wry#1747`, `tauri#13044`. `titleBarStyle: Overlay` + `hiddenTitle` leaves the webview **under** the traffic lights. AppKit resets buttons to `12px` native on every layout pass (`setContentView:`, webview load, `NSWindowDidResize`, `NSViewFrameDidChange`), and `drawRect:` in `WryWebViewParent` isn't enough. On macOS 26 the race is worse.

**HuLa fix (3 mechanisms in `src-tauri/src/lib.rs:205`)**

1. `WindowEvent::Focused/Resized/ScaleFactorChanged` hook (`lib.rs:485`) — general fallback.
2. `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (`lib.rs:331`) — more reliable than `WindowEvent` on macOS 26.
3. **Live-resize polling @ 60 fps** (`NSTimer` in `NSRunLoopCommonModes` + `needs_update` `±0.6px`) while `inLiveResize` — fires during `NSEventTrackingRunLoopMode`, not just on release (`lib.rs:512`).

Final positions: `Close 17.5 / Mini 39.5 / Zoom 61.5` (14px dots on macOS 26, `grow 3` when AppKit still serves 12px, `shift_right 16` + `extra_gap 0/2/4`, `pl-[96px] sm:pl-[108px]` in header). `setAutoresizingMask(0)` prevents AppKit from auto-resizing between frames. See `lib.rs:205` `adjust_macos_traffic_lights` + `lib.rs:331` `ensure_traffic_lights_observer`.

**Vertical centering (`traffic_lights_target_y`, `lib.rs:185`)** — a `standardWindowButton` frame lives in the coordinate system of its **superview** (the titlebar container), not of the window. On macOS 26 that container is **not flipped**, so writing the absolute `y = 26 - size/2` (the "distance from the top" the buggy code assumed) pushed the dots *up*: measured from the window top they went from `9–23px` (native) to `0–13px`. `traffic_lights_target_y` now asks the superview for `isFlipped()` + its height and returns the `y` that puts the dot centre at `MACOS_HEADER_BAND / 2` (`lib.rs:166`) = **26px**, the middle of the 52px macOS header (`header.tsx:29`). Because the target is absolute it is idempotent, so the 60 fps drift detector stops and no longer re-applies a frame on every tick.

Verify: `pnpm typecheck && pnpm lint && pnpm build` + test scroll / click / no-zoom in a real build per platform.

## Glass / vibrancy (window-vibrancy) — toggle

Pattern from **Prestly**: native translucency toggle.

- **Rust** (`lib.rs:31`): `window-vibrancy = "0.8"` crate. Sync command `window_effects_set {enabled, dark?}` (`lib.rs:125`) — vibrancy (`NSVisualEffectView`) on macOS, Mica on Windows 11; Linux/mobile return `unsupported` (no-op). Must be **sync** (main thread).
- **Frontend** (`apps/web/src/components/vibrancy-provider.tsx` + `glass-cards-provider.tsx`): `VibrancyProvider` + `useVibrancy()` persistence in `localStorage` (`vibrancy`), `GlassCardsProvider` (`glass-cards`). `html.vibrancy` toggles `globals.css:177` transparent body. `dark` follows the theme (Mica tint).
- **Toggles**: two INDEPENDENT switches in `GlassControls` (`apps/web/src/components/layout/glass-controls.tsx`) — `VibrancyToggle` (`vibrancy-toggle.tsx`, native material, hidden if `!supported`: Linux/mobile/browser) and `GlassCardsToggle` (`glass-cards-toggle.tsx`, the web `glass-*` components, disabled on Linux). They used to be one combined switch; now any mix is valid (vibrancy + solid cards, glass cards on an opaque window, both). Default **OFF** each.
- **CSS** (`globals.css:177`, `286`): `html.vibrancy .app-shell { background: color-mix(... 32%) }` (42% in light), macOS header `backdrop-blur(16px)`; Windows `Mica` provides material; Linux disables blur.

## Scrollbars & scroll container (all desktop platforms)

Two rules, both load-bearing:

1. **The header is outside the scroller.** `.app-shell` is `height:100dvh; overflow:hidden` (it only clips) and a single child — `.app-scroll` (`globals.css:231`) — owns `overflow-y:auto` and wraps `main` + `Footer`. If `.app-shell` were the scroller (header + content), the scrollbar would eat ~12px of the header and push the caption buttons inwards; with an *overlay* scrollbar it would instead paint on top of the close button. The header is the titlebar, so it must always reach the right edge. The browser build is unaffected (the div is inert and the document scrolls), which is why the header keeps `md:sticky`.
2. **Scrollbars are native — never style `::-webkit-scrollbar`.** Those pseudo-elements force classic scrollbars (reserved gutter + arrow buttons) and kill the platform overlay behaviour. Instead each OS uses its native overlay:
   - **Windows:** `"scrollBarStyle": "fluentOverlay"` in `tauri.windows.conf.json:13` — the WebView2 Fluent overlay scrollbar (thin pill, auto-hides, floats over the content). Requires WebView2 Runtime ≥ 125.0.2535.41; it is a no-op on older runtimes and unsupported off-Windows. Tauri's own docs note that "CSS styles that modify the scrollbar are applied on top of the native appearance", so adding webkit rules on top would defeat it.
   - **macOS:** the WebKit overlay scrollbars, unchanged — auto-hide on trackpad, and when macOS is set to "always show scrollbars" they only affect the content, never the header.
   - **Linux:** WebKitGTK follows the GTK setting `gtk-overlay-scrolling` (on by default in GNOME). With it off you get the theme's classic scrollbar — inside the content area only, header untouched.

Both are checked by `window-controls`-adjacent invariants: see the `Scrollbars` row in `AGENTS.md` before touching `.app-shell` / `.app-scroll` or adding scrollbar CSS.

## Windows — overlay titlebar (`tauri-plugin-decorum`)

Edge / VS Code model: the window is **frameless** and the app draws the titlebar (`decorations: false`). The community plugin [decorum](https://github.com/clearlysid/tauri-plugin-decorum) provides the overlay and the Snap Layouts command; the header supplies the drag band and the caption buttons.

- `tauri.windows.conf.json:12` → `decorations: false` (`transparent: true` is kept so Mica / `window_effects_set` still shows through).
- `setup()` calls `create_overlay_titlebar()` (`lib.rs:461`); the plugin is registered only on Windows (`lib.rs:419`).
- Caption buttons: `apps/web/src/components/layout/window-controls.tsx:61` (minimize / maximize-restore / close, lucide icons, `46px` hit area, red hover on close), rendered from `header.tsx:224`. They call `minimize()` / `toggleMaximize()` / `close()` and follow `isMaximized()` + `onResized()`.
- **Snap Layouts:** hovering *maximize* for 620 ms (`window-controls.tsx:8`) focuses the window and invokes `plugin:decorum|show_snap_overlay` (`window-controls.tsx:104`), which presses Win+Z and then Alt to hide the numbered badges. Chromium gets the real hover flyout by answering `WM_NCHITTEST` with `HTMAXBUTTON`; tao does not expose that hook, so Win+Z is the closest equivalent. Permissions: `capabilities/default.json:6` (`allow-minimize` / `allow-close` / `allow-is-maximized`) + `capabilities/default.json:15` (**`core:window:allow-set-focus`** — the chain is `setFocus().then(invoke(...))`, so without it the promise rejects and the flyout never opens; it is not part of `core:window:default`) + `capabilities/windows.json:7` (`decorum:allow-show-snap-overlay`) — the plugin is a `cfg(windows)` dep, so its permission lives in a capability with `platforms: ["windows"]` and non-Windows builds never resolve it (registering it globally breaks `cargo check` on macOS/Linux with `Permission decorum:allow-show-snap-overlay not found`).
- Rounded corners: `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)` (`lib.rs:457`) — a frameless window is square by default.
- **Fixed band height (do not remove `shrink-0`):** `header.tsx:29` pins the Win/Linux titlebar to `h-11` (44px) + `shrink-0` — the height the flex column used to squeeze it down to, and the same compact band Edge uses. Without `shrink-0` the shell's flex column squeezed the header down to its min-content height, so the titlebar height changed with every page's content length. The drag handler measures the header at runtime (`native-chrome.ts:14`, fallback 52 macOS / 44 Win-Linux) instead of duplicating its height, so band and drag zone can never drift apart.
- Header controls (language / theme) share one hover token, `hover:bg-black/10 dark:hover:bg-white/15` (`header.tsx:18`), used by **both** the shadcn and the glass branch, and keep `hover:scale-100` in the glass variant. The defaults were unreadable on the titlebar band: `bg-muted` / `dark:bg-muted/50` disappear against the translucent dark band, the glass `hover:bg-white/10` inverts to a mere 6 % black in the light theme (`globals.css:403`), and `hover:scale-105` made the pill grow out of the band.
- Dragging stays custom: `data-tauri-drag-region` + `useWindowDragRegion` (`header.tsx:68`). Decorum also injects its own fixed 32px titlebar with a drag layer at `z-index:100`, which would sit on top of our header and swallow clicks on the buttons — `globals.css:253` hides it.
- Resize borders survive: tao answers `WM_NCHITTEST` for the frame edges of undecorated resizable windows (`src-tauri/vendor/tao-0.35.3/src/platform_impl/windows/event_loop.rs:2182`).

So on Windows and Linux the fixed 44px header **is** the app-drawn titlebar (no double bar on either; Linux corners are square by design, see §0); macOS keeps the native traffic lights with its own 52px band.

## Linux — known issues

### 0. Linux — frameless window, square system corners (deliberate)

The window is **frameless and opaque** (`decorations: false`, `transparent: false` in `tauri.linux.conf.json:11-13`). Like Windows, the app draws one 44px React titlebar with drag region and caption buttons (`header.tsx` + `WindowControls`); the OS draws no frame — square corners are part of the platform, accepted deliberately (2026-09-27).

Background: several iterations chased rounded CSD corners (latched `GtkHeaderBar`, `tauri-app` GTK class, 16px radius on both GTK nodes, shadow-margin resize grip, input-shape probe — see `changelog.md`). The corners did round, but transparent tips stayed visible at the extremes and the machinery (provider CSS, input shape, two resize paths, `allow-set-theme`) never paid for itself. The CSD frame also could not follow the in-app theme (mutter reads `_GTK_THEME_VARIANT` once, at manage time).

What remains:

- `window.show()` after `center()` in `setup()` (`lib.rs`): the window is born hidden (`visible: false`) and shown already centered — no flash.
- Inner 6px webview-edge resize via `useWindowResizeEdges` / `start_window_resize` (`lib.rs:88`): a frameless window gets no WM resize handles, so the app still detects the edge and drives GTK's `begin_resize_drag`.
- `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` before `Builder` (`lib.rs`): unchanged, still required (WebKitGTK software-rendering path).
- Glass veto unchanged (see §1 below).

### 1. Glass + WebKitGTK → yellow glitches & RAM blow-up

`backdrop-blur` + `DMABUF` on WebKitGTK 4.1 (esp. NVIDIA/Wayland) triggers `AcceleratedSurfaceDMABuf was unable to construct a complete framebuffer` + `Error 71` + RAM spike on resize (Tauri `linux-graphics` docs, `wry#1747`).

**Current fix (veto):** Linux forces `glass OFF` — `glass-cards-provider.tsx` exposes `supported: false` (`platform==='linux'`) and collapses `enabled` to `false`, `GlassCardsToggle` disabled with tooltip, and `globals.css:265` does `html.linux .glass-card { backdrop-filter:none; background:var(--card) }`. `lib.rs:394` sets `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` before `Builder`.

**Plan A (degraded glass without blur — not yet implemented):** render `GlassCard` without `backdrop-blur` on Linux — just `bg-white/[0.06] + border` translucent + subtle `box-shadow`. See `README.md` for the code sketch.

## Verify checklist

```bash
pnpm typecheck && pnpm lint && pnpm build
```

Then test **scroll + click + no-zoom** in a real bundle per OS (`pnpm tauri:build` or `scripts/build-*.sh`).

Next: [Scripts & Tooling →](./scripts.md)
