# Tauri Backend (`src-tauri`)

Rust + Tauri v2. Entry: `src-tauri/src/lib.rs:304` (`run()`) and `src-tauri/src/main.rs`.

## Commands

Registered in `lib.rs:342`:

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

Background and fix documented in `docs/en/native-feel.md`. Implementation in `lib.rs:116`:

- `adjust_macos_traffic_lights` — moves/grows the 3 `NSWindowButton`s (targets `22.5/44.5/66.5`, `±0.6px` hysteresis, `grow 3`, `lower 8`, `shift_right 16` + `extra_gap`).
- `needs_traffic_lights_update` + `ensure_traffic_lights_observer` (`NSWindowDidResizeNotification`/`DidMove`) + **60 fps polling** (`NSTimer` in `NSRunLoopCommonModes`) during `NSEventTrackingRunLoopMode` (live-resize).
- `setAutoresizingMask(0)` prevents AppKit from re-resetting.

## Linux window frame — native decorations

`tauri.linux.conf.json:11` → `decorations: true` + `transparent: false`: GTK / the compositor draw the titlebar (native minimize / maximize / close), the shadow and the corner radius. Rust has **no** GTK code anymore — `apply_linux_window_shadow` (CssProvider + dummy `HeaderBar` + forced RGBA visual + `opacity 0.99`) and the linux-only `gtk` / `gdk` deps were removed, because forcing a GDK visual after realize cannot work (tao installs it before realize and only for `transparent: true`). Full rationale in `docs/en/native-feel.md`.

Also sets `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` before `Builder` (`lib.rs:315`) to avoid WebKitGTK DMABUF crashes.

## Windows — frameless overlay titlebar (`tauri-plugin-decorum`)

`tauri.windows.conf.json:12` → `decorations: false`: the window is frameless and the app draws the titlebar (Edge / VS Code model). `setup()` calls `create_overlay_titlebar()` (`lib.rs:361`) from the community plugin [decorum](https://github.com/clearlysid/tauri-plugin-decorum), registered only on Windows (`lib.rs:339`). `transparent: true` is kept so Mica / `window_effects_set` still shows through.

The caption buttons are React (`apps/web/src/components/layout/window-controls.tsx:61`, rendered by `header.tsx:191`); hovering maximize for 620 ms invokes `plugin:decorum|show_snap_overlay` (`window-controls.tsx:104`) to open the Windows 11 Snap Layouts flyout. Permissions: `capabilities/default.json:6` (`allow-minimize` / `allow-close` / `allow-is-maximized`) + `capabilities/default.json:15` (`allow-set-focus`, required by the `setFocus().then(invoke(...))` chain) + `capabilities/windows.json:7` (`decorum:allow-show-snap-overlay`, `platforms: ["windows"]` — the plugin is a `cfg(windows)` dep, so a macOS/Linux `cargo check` would reject the permission if it lived in `default.json`).

`lib.rs:365` — `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)` on Windows 11 (only in `target_os = "windows"` deps — `Cargo.toml:57`): a frameless window is square by default, so this call is what keeps the rounded corners. Full rationale in `docs/en/native-feel.md`.

## Desktop vs mobile entry

- Desktop: `run()` via `main.rs` → `lib.rs:304`.
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
