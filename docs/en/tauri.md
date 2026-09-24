# Tauri Backend (`src-tauri`)

Rust + Tauri v2. Entry: `src-tauri/src/lib.rs:396` (`run()`) and `src-tauri/src/main.rs`.

## Commands

Registered in `lib.rs:436`:

```rust
tauri::generate_handler![greet, platform_info, window_effects_set]
```

| Command | Signature | Description |
|---------|-----------|-------------|
| `greet` | `fn greet(name: &str) -> String` | Returns greeting (demo) — `lib.rs:12` |
| `platform_info` | `fn platform_info() -> String` | Returns `platform::current_platform()` — `lib.rs:17` |
| `window_effects_set` | `fn window_effects_set(window, enabled: bool, dark: Option<bool>) -> Result<(), String>` | Applies/clears native translucency — `lib.rs:82` |

Frontend usage (`apps/web/src/App.tsx:34`):

```ts
import { invoke } from "@tauri-apps/api/core"
await invoke<string>("greet", { name: "Tauri" })
```

`window_effects_set` is **sync** (runs on the main thread) — required by `window-vibrancy` which must execute on the main thread (`lib.rs:26` comment). Never make it `async`.

Platform dispatch for `set_window_effect` (`lib.rs:31`):

- `macOS` → `window_vibrancy::apply_vibrancy` with `HudWindow` (dark) / `UnderWindowBackground` (light)
- `Windows` → `window_vibrancy::apply_mica(window, dark)`
- `other` (Linux/mobile) → `Err("unsupported")` — frontend hides the toggle.

`platform::current_platform()` (`src/platform/`) is the single OS string used by the frontend (`usePlatform()` hook).

## Configuration

`src-tauri/tauri.conf.json:1` (base):

```json
{
  "productName": "tauri-react-template",
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
      "title": "tauri-react-template",
      "width": 1024, "height": 768,
      "minWidth": 800, "minHeight": 600,
      "dragDropEnabled": false,
      "zoomHotkeysEnabled": false
    }],
    "security": { "csp": null }
  }
}
```

Per-OS overlays (merged at build): `tauri.macos.conf.json`, `tauri.windows.conf.json`, `tauri.linux.conf.json`, `tauri.ios.conf.json`, `tauri.android.conf.json`. Keep `dragDropEnabled:false` + `zoomHotkeysEnabled:false` in **all** four desktop configs — not just macOS.

`src-tauri/capabilities/` — Tauri v2 permission sets (opener, window effects, etc.).

## Build script

`src-tauri/build.rs:1`:

- `tauri_build::build()` — generates context + `mobile`/`desktop` cfg aliases.
- **macOS Assets**: compiles `Assets.xcassets/AppIcon` via `actool` (Xcode) → `OUT_DIR/assets-car/Assets.car` + `TAURI_ASSETS_CAR` env var. Skips gracefully without Xcode.
- **Env embedding**: reads `src-tauri/.env` (gitignored) + process env for `EMBED_KEYS` (`VITE_API_URL`, `SUPABASE_*`) and injects as `cargo:rustc-env`. Validates Supabase URLs in release (`build.rs:135`).

## macOS traffic lights (HuLa fix)

Background and fix documented in `docs/en/native-feel.md`. Implementation in `lib.rs:162`:

- `adjust_macos_traffic_lights` (`lib.rs:162`) — moves/grows the 3 `NSWindowButton`s (targets `17.5/39.5/61.5`, `±0.6px` hysteresis, `grow 3`, `shift_right 16` + `extra_gap`).
- `traffic_lights_target_y` (`lib.rs:142`) — absolute `y` so the dot centre lands at `MACOS_HEADER_BAND / 2` (`lib.rs:123` = 26px, middle of the 52px macOS header). The frame lives in the button's superview, which on macOS 26 is **not flipped**: read `isFlipped()` + the container height instead of assuming "distance from the top".
- `needs_traffic_lights_update` + `ensure_traffic_lights_observer` (`NSWindowDidResizeNotification`/`DidMove`) + **60 fps polling** (`NSTimer` in `NSRunLoopCommonModes`) during `NSEventTrackingRunLoopMode` (live-resize).
- `setAutoresizingMask(0)` prevents AppKit from re-resetting.

## Linux window frame — app-drawn titlebar + latched CSD

`tauri.linux.conf.json:11` → `decorations: true` + `transparent: true` (`:13`) + `visible: false` (`:12`). `install_linux_frame` (`lib.rs:412`) latches **CSD** with an empty, hidden `GtkHeaderBar` (plus `set_no_show_all(true)`, because tao shows the window with `show_all()`) and then:

1. **rewrites the frame radius** (`window.background` + `decoration { border-radius: 10px }` via a `GtkCssProvider`): GTK3's Adwaita only rounds the **top** corners (`decoration { border-radius: $window_radius $window_radius 0 0 }`), so its shadow is square at the bottom — the bug Firefox fixed behind `gtk.rounded-bottom-corners` (bugzilla 1964149);
2. **clips the webview's surface to the same rounded rect** (`clip_webview_to_rounded`, `lib.rs:360`), because with the software renderer Linux requires the webview surface is opaque and a square "shoulder" shows outside the rounded corners (Firefox bug 1509931). Re-applied on `size-allocate` and `realize`.

`transparent: true` is required: with `transparent: false` the window has no alpha, so the corners cannot be transparent and the webview's own background (Adwaita base `#1e1e1e`) fills them. The titlebar itself is the app's: the fixed 44px `header.tsx` band (drag region) plus `WindowControls` (`header.tsx:222`) — the same "custom frame" model as Windows / Edge / VS Code / Chromium. `globals.css:246` gives `.app-shell` the same `border-radius`.

Why not the native titlebar: mutter reads `_GTK_THEME_VARIANT` **once**, when the window is managed (`LOAD_INIT` in `mutter/src/x11/window-props.c`), so the SSD can never follow the app theme — a dark app on a light desktop kept a white titlebar; and a `GtkHeaderBar` is not draggable when tao creates the window in SSD mode. `useNativeTheme` (`native-chrome.ts:135`) still mirrors the theme into GTK's variant. The old `apply_linux_window_shadow` hacks (forced RGBA visual + `opacity 0.99`) stay removed: forcing a GDK visual after realize cannot work. Full rationale in `docs/en/native-feel.md`.

Also sets `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` before `Builder` (`lib.rs:408`) to avoid WebKitGTK DMABUF crashes.

## Windows — frameless overlay titlebar (`tauri-plugin-decorum`)

`tauri.windows.conf.json:12` → `decorations: false`: the window is frameless and the app draws the titlebar (Edge / VS Code model). `setup()` calls `create_overlay_titlebar()` (`lib.rs:462`) from the community plugin [decorum](https://github.com/clearlysid/tauri-plugin-decorum), registered only on Windows (`lib.rs:433`). `transparent: true` is kept so Mica / `window_effects_set` still shows through.

The caption buttons are React (`apps/web/src/components/layout/window-controls.tsx:61`, rendered by `header.tsx:224`); hovering maximize for 620 ms invokes `plugin:decorum|show_snap_overlay` (`window-controls.tsx:104`) to open the Windows 11 Snap Layouts flyout. Permissions: `capabilities/default.json:6` (`allow-minimize` / `allow-close` / `allow-is-maximized`) + `capabilities/default.json:15` (`allow-set-focus`, required by the `setFocus().then(invoke(...))` chain) + `capabilities/windows.json:7` (`decorum:allow-show-snap-overlay`, `platforms: ["windows"]` — the plugin is a `cfg(windows)` dep, so a macOS/Linux `cargo check` would reject the permission if it lived in `default.json`).

`tauri.windows.conf.json:13` → `scrollBarStyle: "fluentOverlay"`: WebView2 draws the **overlay** scrollbar (thin pill, auto-hides, floats over the content) instead of the classic bar with a gutter and arrow buttons. It needs WebView2 Runtime >= 125.0.2535.41 and is a no-op elsewhere. Required companion change: the scroll container is `.app-scroll` (content only) so the bar never steals width from the header — see `native-feel.md`.

`lib.rs:466` — `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)` on Windows 11 (only in `target_os = "windows"` deps — `Cargo.toml:57`): a frameless window is square by default, so this call is what keeps the rounded corners. Full rationale in `docs/en/native-feel.md`.

## Desktop vs mobile entry

- Desktop: `run()` via `main.rs` → `lib.rs:396`.
- iOS/macOS unified Xcode target: `start_app()` (`lib.rs:106`, `#[no_mangle] extern "C"`) called from `main.mm` in the generated Xcode project. Required for `cargo check --target aarch64-apple-ios`.
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
