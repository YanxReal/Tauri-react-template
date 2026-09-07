# Tauri Backend (`src-tauri`)

Rust + Tauri v2. Entry: `src-tauri/src/lib.rs:369` (`run()`) and `src-tauri/src/main.rs`.

## Commands

Registered in `lib.rs:395`:

```rust
tauri::generate_handler![greet, platform_info, window_effects_set]
```

| Command | Signature | Description |
|---------|-----------|-------------|
| `greet` | `fn greet(name: &str) -> String` | Returns greeting (demo) — `lib.rs:8` |
| `platform_info` | `fn platform_info() -> String` | Returns `platform::current_platform()` — `lib.rs:13` |
| `window_effects_set` | `fn window_effects_set(window, enabled: bool, dark: Option<bool>) -> Result<(), String>` | Applies/clears native translucency — `lib.rs:78` |

Frontend usage (`apps/web/src/App.tsx:34`):

```ts
import { invoke } from "@tauri-apps/api/core"
await invoke<string>("greet", { name: "Tauri" })
```

`window_effects_set` is **sync** (runs on the main thread) — required by `window-vibrancy` which must execute on the main thread (`lib.rs:18` comment). Never make it `async`.

Platform dispatch for `set_window_effect` (`lib.rs:27`):

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
- **Env embedding**: reads `src-tauri/.env` (gitignored) + process env for `EMBED_KEYS` (`VITE_API_URL`, `SUPABASE_*`) and injects as `cargo:rustc-env`. Validates Supabase URLs in release (`build.rs:126`).

## macOS traffic lights (HuLa fix)

Background and fix documented in `docs/en/native-feel.md`. Implementation in `lib.rs:107`:

- `adjust_macos_traffic_lights` — moves/grows the 3 `NSWindowButton`s (targets `22.5/44.5/66.5`, `±0.6px` hysteresis, `grow 3`, `lower 8`, `shift_right 16` + `extra_gap`).
- `needs_traffic_lights_update` + `ensure_traffic_lights_observer` (`NSWindowDidResizeNotification`/`DidMove`) + **60 fps polling** (`NSTimer` in `NSRunLoopCommonModes`) during `NSEventTrackingRunLoopMode` (live-resize).
- `setAutoresizingMask(0)` prevents AppKit from re-resetting.

## Linux window shadow — native only

`lib.rs:315` `apply_linux_window_shadow` — 100% native, no webview fallback. Forces `.csd` and registers `GtkCssProvider` **directly on the window's `StyleContext`** via `add_provider(..., APPLICATION)` (Wayland-safe; previously `add_provider_for_screen` was `None` on Wayland). CSS `window.background.csd decoration { box-shadow: 0 16px 48px rgba(0,0,0,.38); margin:12px; border-radius:10px }` (+ `:backdrop`) + `window.background.csd { border-radius:10px }`; maximized/tiled/fullscreen clears it. `globals.css:241` `html.linux .app-shell { border-radius:10px; overflow:hidden }` clips all 4 corners. `gtk4` path (`webkitgtk 6.0`) would use same CSS with `gtk4::CssProvider` + `add_provider_for_display`; current `gtk=0.18` (GTK3) uses per-window provider.

Also sets `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` before `Builder` (`lib.rs:371`) to avoid WebKitGTK DMABUF crashes.

## Windows rounding

`lib.rs:399` — `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)` for `WS_POPUP` windows on Windows 11 (only in `target_os = "windows"` deps — `Cargo.toml:54`).

## Desktop vs mobile entry

- Desktop: `run()` via `main.rs` → `lib.rs:369`.
- iOS/macOS unified Xcode target: `start_app()` (`lib.rs:101`, `#[no_mangle] extern "C"`) called from `main.mm` in the generated Xcode project. Required for `cargo check --target aarch64-apple-ios`.
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
