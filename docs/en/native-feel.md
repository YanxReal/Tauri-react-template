# Native Feel — Cross-Platform

> **This is a multi-platform app** (desktop: **macOS, Windows, Linux**; mobile: **iOS, Android**) — every change must work and be tested on all systems. Never assume macOS/iOS only.

## Shared guards (all windows / all OS)

Derived from commit `c9ae1a4`:

- `tauri*.conf.json` (all 4 configs): `dragDropEnabled: false` + `zoomHotkeysEnabled: false` in every `windows[]` entry — not just macOS.
- `apps/web/index.html:5` — viewport `user-scalable=no, maximum-scale=1.0, viewport-fit=cover`
- `packages/ui/src/styles/globals.css:136` — `* { user-select:none; -webkit-user-drag:none; touch-action: pan-x pan-y }` (inputs/textarea/contenteditable re-enable text selection). No `overscroll-behavior:none`.
- `apps/web/src/main.tsx:17` — `dragstart` block, wheel zoom (`ctrl/meta + wheel`) block, external links → `openUrl` via `plugin-opener`.
- `src-tauri/src/lib.rs:390` — `tauri-plugin-prevent-default` with `Flags::debug()`: in **release** blocks webview defaults (context menu, devtools, reload); in **debug** keeps them. Never touches document scroll.

Mobile (iOS long-press menu, Android) relies on the same CSS/JS (`touch-action: manipulation` kills double-tap zoom on iOS).

## macOS — traffic lights (live-resize without flicker)

Reference: `wry#1747`, `tauri#13044`. `titleBarStyle: Overlay` + `hiddenTitle` leaves the webview **under** the traffic lights. AppKit resets buttons to `12px` native on every layout pass (`setContentView:`, webview load, `NSWindowDidResize`, `NSViewFrameDidChange`), and `drawRect:` in `WryWebViewParent` isn't enough. On macOS 26 the race is worse.

**HuLa fix (3 mechanisms in `src-tauri/src/lib.rs:107`)**

1. `WindowEvent::Focused/Resized/ScaleFactorChanged` hook (`lib.rs:437`) — general fallback.
2. `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (`lib.rs:250`) — more reliable than `WindowEvent` on macOS 26.
3. **Live-resize polling @ 60 fps** (`NSTimer` in `NSRunLoopCommonModes` + `needs_update` `±0.6px`) while `inLiveResize` — fires during `NSEventTrackingRunLoopMode`, not just on release (`lib.rs:449`).

Final positions: `Close 22.5 / Mini 44.5 / Zoom 66.5` (22px centers, `15px` with `grow 3`, `lower 8`, `shift_right 16` + `extra_gap 0/2/4`, `pl-[96px] sm:pl-[108px]` in header). `setAutoresizingMask(0)` prevents AppKit from auto-resizing between frames. See `lib.rs:adjust_macos_traffic_lights` + `ensure_traffic_lights_observer`.

Verify: `pnpm typecheck && pnpm lint && pnpm build` + test scroll / click / no-zoom in a real build per platform.

## Glass / vibrancy (window-vibrancy) — toggle

Pattern from **Prestly**: native translucency toggle.

- **Rust** (`lib.rs:18`): `window-vibrancy = "0.8"` crate. Sync command `window_effects_set {enabled, dark?}` (`lib.rs:78`) — vibrancy (`NSVisualEffectView`) on macOS, Mica on Windows 11; Linux/mobile return `unsupported` (no-op). Must be **sync** (main thread).
- **Frontend** (`apps/web/src/components/vibrancy-provider.tsx` + `glass-cards-provider.tsx`): `VibrancyProvider` + `useVibrancy()` persistence in `localStorage` (`vibrancy`), `GlassCardsProvider` (`glass-cards`). `html.vibrancy` toggles `globals.css:177` transparent body. `dark` follows the theme (Mica tint).
- **Toggle**: `VibrancyToggle` / `GlassEffectToggle` (`apps/web/src/components/layout/glass-effect-toggle.tsx`) — shadcn `Switch`, hidden if `!supported` (Linux/mobile/browser). Combined toggle controls `glass-cards` + `vibrancy` together, default **OFF** (Linux forces OFF).
- **CSS** (`globals.css:177`, `307`): `html.vibrancy .app-shell { background: color-mix(... 32%) }` (42% in light), macOS header `backdrop-blur(16px)`; Windows `Mica` provides material; Linux disables blur.

## Linux — known issues

### 0. Window shadow (`shadow` unsupported) — native only

`tauri`/`tao` don't support `WindowConfig.shadow` on Linux (*"Linux: Unsupported"*). With `decorations:false transparent:true` the GTK `window.background.csd decoration { box-shadow; margin; border-radius }` node doesn't generate → flat window.

**Fix — native only in `lib.rs:315` `apply_linux_window_shadow` (no CSS fallback):**

- `window.gtk_window()` + `.add_class("csd")` forces the `decoration` node even though the window is frameless.
- `GtkCssProvider` is attached **directly to the window's `StyleContext`** via `add_provider(..., APPLICATION)` — this works on both X11 and Wayland. The previous implementation used `add_provider_for_screen`, which returns `None` on pure Wayland (`screen == None`) and was the reason shadows were invisible despite the code running. As a compatibility shim, if a `GdkScreen` exists (X11) we also call `add_provider_for_screen`.
- CSS: `window.background.csd decoration { box-shadow: 0 16px 48px rgba(0,0,0,.38); margin:12px; border-radius:10px }` + `:backdrop` variant + `window.background.csd { border-radius:10px }`. Maximized/tiled/fullscreen → `box-shadow:none; margin:0; border-radius:0`.
- No webview fallback (`html.linux:not(.gtk-shadow) .app-shell { box-shadow }` has been removed). The window's own border-radius lives in `globals.css:241` `html.linux .app-shell { border-radius:10px }`.

Build requirement: `gtk = "0.18"` (`Cargo.toml:67`, linux target only, GTK3 `webkit2gtk 4.1`). If the project migrates to `webkitgtk 6.0` + `gtk4`, the same CSS can be used with `gtk4::CssProvider` + `add_provider_for_display(&display, ...)`, but the current fix uses `StyleContext::add_provider` which is Wayland-safe on GTK3.

### 1. Rounded corners without glass

`decorations:false transparent:true` leaves the window square. Fix: `html.linux .app-shell {border-radius:10px}` + header/footer `rounded-none` — `app-shell` clips to 10px. See `globals.css:224`.

### 2. Glass + WebKitGTK → yellow glitches & RAM blow-up

`backdrop-blur` + `DMABUF` on WebKitGTK 4.1 (esp. NVIDIA/Wayland) triggers `AcceleratedSurfaceDMABuf was unable to construct a complete framebuffer` + `Error 71` + RAM spike on resize (Tauri `linux-graphics` docs, `wry#1747`).

**Current fix (veto):** Linux forces `glass OFF` — `glass-cards-provider.tsx` returns `false` if `platform==='linux'`, `GlassEffectToggle` disabled with tooltip, and `globals.css:283` does `html.linux .glass-card { backdrop-filter:none; background:var(--card) }` + `contain:paint`. `lib.rs:371` sets `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` before `Builder`.

**Plan A (degraded glass without blur — not yet implemented):** render `GlassCard` without `backdrop-blur` on Linux — just `bg-white/[0.06] + border` translucent + subtle `box-shadow`. See `README.md` for the code sketch.

## Verify checklist

```bash
pnpm typecheck && pnpm lint && pnpm build
```

Then test **scroll + click + no-zoom** in a real bundle per OS (`pnpm tauri:build` or `scripts/build-*.sh`).

Next: [Scripts & Tooling →](./scripts.md)
