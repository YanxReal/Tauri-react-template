# Native Feel — Cross-Platform

> **This is a multi-platform app** (desktop: **macOS, Windows, Linux**; mobile: **iOS, Android**) — every change must work and be tested on all systems. Never assume macOS/iOS only.

## Shared guards (all windows / all OS)

Derived from commit `c9ae1a4`:

- `tauri*.conf.json` (all 4 configs): `dragDropEnabled: false` + `zoomHotkeysEnabled: false` in every `windows[]` entry — not just macOS.
- `apps/web/index.html:5` — viewport `user-scalable=no, maximum-scale=1.0, viewport-fit=cover`
- `packages/ui/src/styles/globals.css:137` — `* { user-select:none; -webkit-user-drag:none; touch-action: pan-x pan-y }` (inputs/textarea/contenteditable re-enable text selection). No `overscroll-behavior:none`.
- `apps/web/src/main.tsx:21` — `dragstart` block, wheel zoom (`ctrl/meta + wheel`) block, external links → `openUrl` via `plugin-opener`.
- `src-tauri/src/lib.rs:330` — `tauri-plugin-prevent-default` with `Flags::debug()`: in **release** blocks webview defaults (context menu, devtools, reload); in **debug** keeps them. Never touches document scroll.

Mobile (iOS long-press menu, Android) relies on the same CSS/JS (`touch-action: manipulation` kills double-tap zoom on iOS).

## macOS — traffic lights (live-resize without flicker)

Reference: `wry#1747`, `tauri#13044`. `titleBarStyle: Overlay` + `hiddenTitle` leaves the webview **under** the traffic lights. AppKit resets buttons to `12px` native on every layout pass (`setContentView:`, webview load, `NSWindowDidResize`, `NSViewFrameDidChange`), and `drawRect:` in `WryWebViewParent` isn't enough. On macOS 26 the race is worse.

**HuLa fix (3 mechanisms in `src-tauri/src/lib.rs:116`)**

1. `WindowEvent::Focused/Resized/ScaleFactorChanged` hook (`lib.rs:390`) — general fallback.
2. `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (`lib.rs:253`) — more reliable than `WindowEvent` on macOS 26.
3. **Live-resize polling @ 60 fps** (`NSTimer` in `NSRunLoopCommonModes` + `needs_update` `±0.6px`) while `inLiveResize` — fires during `NSEventTrackingRunLoopMode`, not just on release (`lib.rs:412`).

Final positions: `Close 22.5 / Mini 44.5 / Zoom 66.5` (22px centers, `15px` with `grow 3`, `lower 8`, `shift_right 16` + `extra_gap 0/2/4`, `pl-[96px] sm:pl-[108px]` in header). `setAutoresizingMask(0)` prevents AppKit from auto-resizing between frames. See `lib.rs:adjust_macos_traffic_lights` + `ensure_traffic_lights_observer`.

Verify: `pnpm typecheck && pnpm lint && pnpm build` + test scroll / click / no-zoom in a real build per platform.

## Glass / vibrancy (window-vibrancy) — toggle

Pattern from **Prestly**: native translucency toggle.

- **Rust** (`lib.rs:26`): `window-vibrancy = "0.8"` crate. Sync command `window_effects_set {enabled, dark?}` (`lib.rs:82`) — vibrancy (`NSVisualEffectView`) on macOS, Mica on Windows 11; Linux/mobile return `unsupported` (no-op). Must be **sync** (main thread).
- **Frontend** (`apps/web/src/components/vibrancy-provider.tsx` + `glass-cards-provider.tsx`): `VibrancyProvider` + `useVibrancy()` persistence in `localStorage` (`vibrancy`), `GlassCardsProvider` (`glass-cards`). `html.vibrancy` toggles `globals.css:177` transparent body. `dark` follows the theme (Mica tint).
- **Toggle**: `VibrancyToggle` / `GlassEffectToggle` (`apps/web/src/components/layout/glass-effect-toggle.tsx`) — shadcn `Switch`, hidden if `!supported` (Linux/mobile/browser). Combined toggle controls `glass-cards` + `vibrancy` together, default **OFF** (Linux forces OFF).
- **CSS** (`globals.css:177`, `269`): `html.vibrancy .app-shell { background: color-mix(... 32%) }` (42% in light), macOS header `backdrop-blur(16px)`; Windows `Mica` provides material; Linux disables blur.

## Windows — overlay titlebar (`tauri-plugin-decorum`)

Edge / VS Code model: the window is **frameless** and the app draws the titlebar (`decorations: false`). The community plugin [decorum](https://github.com/clearlysid/tauri-plugin-decorum) provides the overlay and the Snap Layouts command; the header supplies the drag band and the caption buttons.

- `tauri.windows.conf.json:12` → `decorations: false` (`transparent: true` is kept so Mica / `window_effects_set` still shows through).
- `setup()` calls `create_overlay_titlebar()` (`lib.rs:361`); the plugin is registered only on Windows (`lib.rs:339`).
- Caption buttons: `apps/web/src/components/layout/window-controls.tsx:61` (minimize / maximize-restore / close, lucide icons, `46px` hit area, red hover on close), rendered from `header.tsx:191`. They call `minimize()` / `toggleMaximize()` / `close()` and follow `isMaximized()` + `onResized()`.
- **Snap Layouts:** hovering *maximize* for 620 ms (`window-controls.tsx:8`) focuses the window and invokes `plugin:decorum|show_snap_overlay` (`window-controls.tsx:104`), which presses Win+Z and then Alt to hide the numbered badges. Chromium gets the real hover flyout by answering `WM_NCHITTEST` with `HTMAXBUTTON`; tao does not expose that hook, so Win+Z is the closest equivalent. Permissions: `capabilities/default.json:6` (`allow-minimize` / `allow-close` / `allow-is-maximized`) + `capabilities/default.json:15` (**`core:window:allow-set-focus`** — the chain is `setFocus().then(invoke(...))`, so without it the promise rejects and the flyout never opens; it is not part of `core:window:default`) + `capabilities/windows.json:7` (`decorum:allow-show-snap-overlay`) — the plugin is a `cfg(windows)` dep, so its permission lives in a capability with `platforms: ["windows"]` and non-Windows builds never resolve it (registering it globally breaks `cargo check` on macOS/Linux with `Permission decorum:allow-show-snap-overlay not found`).
- Rounded corners: `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)` (`lib.rs:365`) — a frameless window is square by default.
- Dragging stays custom: `data-tauri-drag-region` + `useWindowDragRegion` (`header.tsx:39`). Decorum also injects its own fixed 32px titlebar with a drag layer at `z-index:100`, which would sit on top of our header and swallow clicks on the buttons — `globals.css:230` hides it.
- Resize borders survive: tao answers `WM_NCHITTEST` for the frame edges of undecorated resizable windows (`src-tauri/vendor/tao-0.35.3/src/platform_impl/windows/event_loop.rs:2182`).

So on Windows the 56px header **is** the titlebar (no double bar); on Linux the OS frame stays on top of the same header (see §0) and macOS keeps the native traffic lights.

## Linux — known issues

### 0. Window frame — full native decorations

`tauri`/`tao` don't support `WindowConfig.shadow` on Linux (*"Linux: Unsupported"*), and faking a client-side shadow from Rust did not hold up: a dummy `HeaderBar` latching CSD + `GtkCssProvider` overriding `window.background` / `decoration` + forcing an RGBA visual after realize + `set_opacity(0.99)` still left artifacts (opaque 1px corners, a square buffer under the rounded `decoration`, everything slightly translucent).

Root cause (why those hacks could not fix it): with `transparent:false` tao never installs an RGBA visual (tao installs it **before realize** and only for transparent windows) and `gtk_widget_set_visual()` after realize has no effect, so the corners can never blend — no CSS can change that.

**Current design — the system draws the whole frame:**

- `tauri.linux.conf.json:11` → `decorations: true` + `transparent: false`. GTK/compositor draw the titlebar with **native minimize / maximize / close**, plus their native shadow and corner radius (CSD on GNOME/X11, SSD on compositors exposing `xdg-decoration`).
- Rust no longer touches GTK: `apply_linux_window_shadow` (CssProvider + dummy HeaderBar + RGBA / opacity / opaque_region hacks) and the `gtk = "0.18"` / `gdk = "0.18"` linux-only deps were **removed**. `run()` only keeps the WebKitGTK env vars (`lib.rs:315`).
- `globals.css:214` — **no** Linux `border-radius` / `margin` / `box-shadow` / `contain` on `.app-shell`. The shell is just the client area inside the native frame; clipping or insetting it would show cut corners under the titlebar.
- The custom drag area stays: the app header keeps `data-tauri-drag-region` + `useWindowDragRegion` (Prestly 56px band) in `apps/web/src/components/layout/header.tsx:39`, so the fused in-app bar is still draggable below the native titlebar.

### 1. Glass + WebKitGTK → yellow glitches & RAM blow-up

`backdrop-blur` + `DMABUF` on WebKitGTK 4.1 (esp. NVIDIA/Wayland) triggers `AcceleratedSurfaceDMABuf was unable to construct a complete framebuffer` + `Error 71` + RAM spike on resize (Tauri `linux-graphics` docs, `wry#1747`).

**Current fix (veto):** Linux forces `glass OFF` — `glass-cards-provider.tsx` returns `false` if `platform==='linux'`, `GlassEffectToggle` disabled with tooltip, and `globals.css:246` does `html.linux .glass-card { backdrop-filter:none; background:var(--card) }`. `lib.rs:315` sets `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` before `Builder`.

**Plan A (degraded glass without blur — not yet implemented):** render `GlassCard` without `backdrop-blur` on Linux — just `bg-white/[0.06] + border` translucent + subtle `box-shadow`. See `README.md` for the code sketch.

## Verify checklist

```bash
pnpm typecheck && pnpm lint && pnpm build
```

Then test **scroll + click + no-zoom** in a real bundle per OS (`pnpm tauri:build` or `scripts/build-*.sh`).

Next: [Scripts & Tooling →](./scripts.md)
