# Tauri Backend (`src-tauri`)

> **Audience:** Rust devs — commands, per-OS setup, plugins.

Rust + Tauri v2. Entry: `src-tauri/src/lib.rs:588` (`run()`) and `src-tauri/src/main.rs`.

## Commands

Registered in `lib.rs:635`:

```rust
tauri::generate_handler![
  greet, platform_info, start_window_resize,
  window_effects_set, set_status_bar_style, set_linux_theme
]
```

| Command | Signature | Description |
|---------|-----------|-------------|
| `greet` | `fn greet(name: &str) -> String` | Returns greeting (demo) — `lib.rs:16` |
| `platform_info` | `fn platform_info() -> String` | Returns `platform::current_platform()` — `lib.rs:21` |
| `window_effects_set` | `fn window_effects_set(window, enabled: bool, dark: Option<bool>) -> Result<(), String>` | Applies/clears native translucency — `lib.rs:174` |
| `start_window_resize` | `fn start_window_resize(window, direction: String) -> Result<(), String>` | Linux frameless: maps a GDK edge name to `begin_resize_drag` — `lib.rs:134` |
| `set_status_bar_style` | `fn set_status_bar_style(dark: bool) -> Result<(), String>` | Android: status-bar icon contrast via JNI (`MainActivity.setStatusBarDark`) — `lib.rs:198` |
| `set_linux_theme` | `fn set_linux_theme(dark: bool) -> Result<(), String>` | Linux: pushes the app's resolved theme into GTK (`gtk-application-prefer-dark-theme`) so WebKitGTK scrollbars/controls match the app, not the system — `lib.rs:218` |

Frontend usage (`apps/web/src/App.tsx:37`):

```ts
import { invoke } from "@tauri-apps/api/core"
await invoke<string>("greet", { name: "Tauri" })
```

`window_effects_set` is **sync** (runs on the main thread) — required by `window-vibrancy` which must execute on the main thread (`lib.rs:30` comment). Never make it `async`.

Platform dispatch for `set_window_effect` (`lib.rs:30`):

- `macOS` → `window_vibrancy::apply_vibrancy` with `HudWindow` (dark) / `UnderWindowBackground` (light)
- `Windows` → `window_vibrancy::apply_mica(window, dark)`
- `other` (Linux/mobile) → `Err("unsupported")` — frontend hides the toggle.

`platform::current_platform()` (`src/platform/`) is the single OS string used by the frontend (`usePlatform()` hook).

## Configuration

`src-tauri/tauri.conf.json:1` (base):

```json
{
  "productName": "Tauri-react-template",
  "identifier": "com.tauri-react-template.app",
  "build": {
    "beforeDevCommand": "pnpm --filter web dev",
    "devUrl": "http://localhost:1420",
    "beforeBuildCommand": "pnpm build",
    "frontendDist": "../apps/web/dist"
  },
  "app": {
    "macOSPrivateApi": true,
    "windows": [{
      "title": "Tauri-react-template",
      "width": 1024, "height": 768,
      "minWidth": 800, "minHeight": 600,
      "dragDropEnabled": false,
      "zoomHotkeysEnabled": false
    }],
    "security": { "csp": "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self' ipc: http://ipc.localhost; object-src 'none'; base-uri 'self'" }
  }
}
```

Per-OS overlays (merged at build): `tauri.macos.conf.json`, `tauri.windows.conf.json`, `tauri.linux.conf.json`, `tauri.ios.conf.json`, `tauri.android.conf.json`. Keep `dragDropEnabled:false` + `zoomHotkeysEnabled:false` in **all** four desktop configs — not just macOS.

## Content Security Policy

**Offline-first / local-only.** The app loads NOTHING from the cloud at runtime: fonts, CSS, JS and icons are all bundled into the build. One strict policy ships on **all** targets (base `tauri.conf.json:26`, identical in `tauri.android.conf.json:4`, `tauri.macos.conf.json:21`, `tauri.windows.conf.json:20`; Linux/iOS inherit the base) and makes it impossible for the webview to reach any external host automatically:

- `default-src 'self'` + `object-src 'none'` + `base-uri 'self'` — no plugins, no `<base>` hijack.
- `script-src 'self'` — no inline scripts. Safe: `dist/index.html` ships a single external module bundle, fonts come from `@fontsource-variable/inter` (bundled, not Google Fonts at runtime).
- `style-src 'self' 'unsafe-inline'` — React sets inline styles; without it the UI breaks.
- `img-src 'self' data:` — Vite inlines small assets as `data:` URIs.
- `connect-src 'self' ipc: http://ipc.localhost` — Tauri IPC only. Add your own backend host here if you integrate one (`build.rs` `EMBED_KEYS` can inject public values at compile time).
- Dev/HMR is unaffected: this policy already shipped on macOS/Windows while all dev flows worked. If you add Turnstile or another third party, extend `script-src`/`connect-src` explicitly (the old `challenges.cloudflare.com` allowance was removed as unused).

`src-tauri/capabilities/` — Tauri v2 permission sets (opener, window effects, etc.).

## Build script

`src-tauri/build.rs:1`:

- `tauri_build::build()` — generates context + `mobile`/`desktop` cfg aliases.
- **Android 16 KB pages**: aligns LOAD segments for Android 15+ compatibility.
- **Env embedding**: reads `src-tauri/.env` (gitignored) + process env for `EMBED_KEYS` (`VITE_API_URL`) and injects them as `cargo:rustc-env`. Extend the list for your own public vars.
- **macOS icon**: ships as `icons/icon.icns` (`bundle.icon`). `Assets.xcassets` is kept as the source for a future `.icon`/`.car` bundle entry — the old actool/`TAURI_ASSETS_CAR` path was dead code and was removed.

## macOS traffic lights (HuLa fix)

Background and fix documented in `docs/en/native-feel.md`. Implementation in `lib.rs:403`:

- `adjust_macos_traffic_lights` (`lib.rs:403`) — moves/grows the 3 `NSWindowButton`s (targets `17.5/39.5/61.5`, `±0.6px` hysteresis, `grow 3`, `shift_right 16` + `extra_gap`).
- `traffic_lights_target_y` (`lib.rs:383`) — absolute `y` so the dot centre lands at `MACOS_HEADER_BAND / 2` (`lib.rs:365` = 26px, middle of the 52px macOS header). The frame lives in the button's superview, which on macOS 26 is **not flipped**: read `isFlipped()` + the container height instead of assuming "distance from the top".
- `needs_traffic_lights_update` + `ensure_traffic_lights_observer` (`NSWindowDidResizeNotification`/`DidMove`) + **60 fps polling** (`NSTimer` in `NSRunLoopCommonModes`) during `NSEventTrackingRunLoopMode` (live-resize).
- `setAutoresizingMask(0)` prevents AppKit from re-resetting.

## Linux window frame — frameless + app-drawn titlebar

`tauri.linux.conf.json:11` → `decorations: false` + `transparent: false` + `visible: false` (`:12-13`). The window is frameless and opaque: square system corners, no alpha channel — accepted deliberately, see [Native Feel](./native-feel.md#0-linux--frameless-window-square-system-corners-deliberate). The app draws its titlebar as one fixed 44px header with drag region and caption buttons (`header.tsx:227` + `WindowControls`).

`setup()` centers the window and then calls `window.show()`: born hidden, shown already centered, no flash.

**Resize:** a frameless window gets no WM resize handles, so the inner 6px webview edge uses `useWindowResizeEdges` + `start_window_resize` (`lib.rs:134`), which drives GTK's `begin_resize_drag`.

## Windows — frameless overlay titlebar (`tauri-plugin-decorum`)

`tauri.windows.conf.json:12` → `decorations: false`: the window is frameless and the app draws the titlebar (Edge / VS Code model). `setup()` calls `create_overlay_titlebar()` (`lib.rs:686`) from the community plugin [decorum](https://github.com/clearlysid/tauri-plugin-decorum), registered only on Windows (`lib.rs:632`). `transparent: true` is kept so Mica / `window_effects_set` still shows through.

The caption buttons are React (`apps/web/src/components/layout/window-controls.tsx:37`, rendered by `header.tsx:227`); hovering maximize for 620 ms invokes `plugin:decorum|show_snap_overlay` (`window-controls.tsx:111`) to open the Windows 11 Snap Layouts flyout. Permissions: `capabilities/default.json:15` (`allow-minimize` / `allow-close` / `allow-is-maximized`) + `capabilities/default.json:18` (`allow-set-focus`, required by the `setFocus().then(invoke(...))` chain) + `capabilities/windows.json:7` (`decorum:allow-show-snap-overlay`, `platforms: ["windows"]` — the plugin is a `cfg(windows)` dep, so a macOS/Linux `cargo check` would reject the permission if it lived in `default.json`).

`tauri.windows.conf.json:13` → `scrollBarStyle: "fluentOverlay"`: WebView2 draws the **overlay** scrollbar (thin pill, auto-hides, floats over the content) instead of the classic bar with a gutter and arrow buttons. It needs WebView2 Runtime >= 125.0.2535.41 and is a no-op elsewhere. Required companion change: the scroll container is `.app-scroll` (content only) so the bar never steals width from the header — see `native-feel.md`.

`lib.rs:682` — `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)` on Windows 11 (only in `target_os = "windows"` deps — `Cargo.toml:62`): a frameless window is square by default, so this call is what keeps the rounded corners. Full rationale in `docs/en/native-feel.md`.

## Desktop vs mobile entry

- Desktop: `run()` via `main.rs` → `lib.rs:588`.
- iOS/macOS unified Xcode target: `start_app()` (`lib.rs:349`, `#[no_mangle] extern "C"`) called from `main.mm` in the generated Xcode project. Required for `cargo check --target aarch64-apple-ios`.
- Mobile entry point `#[cfg_attr(mobile, tauri::mobile_entry_point)]` wraps `run()`.

## Adding a plugin

```bash
pnpm --filter web add @tauri-apps/plugin-xxx
# then in Cargo.toml:
# tauri-plugin-xxx = "2"
# and in lib.rs: .plugin(tauri_plugin_xxx::init())
# plus capabilities JSON.
```

## Checks

```bash
cargo check --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
cargo check --target aarch64-apple-ios --manifest-path src-tauri/Cargo.toml
```

Next: [Styling & Theming →](./styling.md)
