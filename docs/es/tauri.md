# Backend Tauri (`src-tauri`)

Rust + Tauri v2. Entradas: `src-tauri/src/lib.rs:369` (`run()`) y `src-tauri/src/main.rs`.

## Comandos

Registrados en `lib.rs:395`:

```rust
tauri::generate_handler![greet, platform_info, window_effects_set]
```

| Comando | Firma | Descripción |
|---------|-------|-------------|
| `greet` | `fn greet(name: &str) -> String` | Devuelve saludo (demo) — `lib.rs:8` |
| `platform_info` | `fn platform_info() -> String` | Devuelve `platform::current_platform()` — `lib.rs:13` |
| `window_effects_set` | `fn window_effects_set(window, enabled: bool, dark: Option<bool>) -> Result<(), String>` | Aplica/limpia translucidez nativa — `lib.rs:78` |

Uso en frontend (`apps/web/src/App.tsx:34`):

```ts
import { invoke } from "@tauri-apps/api/core"
await invoke<string>("greet", { name: "Tauri" })
```

`window_effects_set` es **sync** (corre en el hilo principal) — lo exige `window-vibrancy` que debe ejecutarse en el main thread (`lib.rs:18`). Nunca lo hagas `async`.

Dispatch por plataforma para `set_window_effect` (`lib.rs:27`):

- `macOS` → `window_vibrancy::apply_vibrancy` con `HudWindow` (dark) / `UnderWindowBackground` (light)
- `Windows` → `window_vibrancy::apply_mica(window, dark)`
- `other` (Linux/móvil) → `Err("unsupported")` — el frontend oculta el toggle.

`platform::current_platform()` (`src/platform/`) es el string de OS que consume el frontend (`usePlatform()`).

## Configuración

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

Overlays por OS (merged en build): `tauri.macos.conf.json`, `tauri.windows.conf.json`, `tauri.linux.conf.json`, `tauri.ios.conf.json`, `tauri.android.conf.json`. Mantén `dragDropEnabled:false` + `zoomHotkeysEnabled:false` en **los cuatro** configs de escritorio — no solo macOS.

`src-tauri/capabilities/` — sets de permisos Tauri v2 (opener, window effects, etc.).

## Build script

`src-tauri/build.rs:1`:

- `tauri_build::build()` — genera contexto + aliases cfg `mobile`/`desktop`.
- **Assets macOS**: compila `Assets.xcassets/AppIcon` vía `actool` (Xcode) → `OUT_DIR/assets-car/Assets.car` + var `TAURI_ASSETS_CAR`. Salta con gracia sin Xcode.
- **Env embedding**: lee `src-tauri/.env` (gitignored) + env del proceso para `EMBED_KEYS` (`VITE_API_URL`, `SUPABASE_*`) e inyecta como `cargo:rustc-env`. Valida URLs de Supabase en release (`build.rs:126`).

## Traffic lights de macOS (fix HuLa)

Contexto y fix en `docs/es/native-feel.md`. Implementación en `lib.rs:107`:

- `adjust_macos_traffic_lights` — mueve/agranda los 3 `NSWindowButton`s (targets `22.5/44.5/66.5`, histéresis `±0.6px`, `grow 3`, `lower 8`, `shift_right 16` + `extra_gap`).
- `needs_traffic_lights_update` + `ensure_traffic_lights_observer` (`NSWindowDidResizeNotification`/`DidMove`) + **polling a 60 fps** (`NSTimer` en `NSRunLoopCommonModes`) durante `NSEventTrackingRunLoopMode` (live-resize).
- `setAutoresizingMask(0)` evita que AppKit vuelva a resetear.

## Sombra de ventana en Linux

`lib.rs:315` `apply_linux_window_shadow` — inyecta un `CssProvider` GTK (`STYLE_PROVIDER_PRIORITY_APPLICATION`) que restaura `window.background.csd decoration { box-shadow; margin; border-radius }` cuando `decorations:false transparent:true` lo dejaría plano. El fallback del frontend está en `globals.css` (`html.linux:not(.gtk-shadow) .app-shell`).

También fija `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` antes del `Builder` (`lib.rs:371`) para evitar crashes DMABUF de WebKitGTK.

## Redondeo en Windows

`lib.rs:399` — `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)` para ventanas `WS_POPUP` en Windows 11 (solo en deps `target_os = "windows"` — `Cargo.toml:54`).

## Entrada desktop vs móvil

- Desktop: `run()` vía `main.rs` → `lib.rs:369`.
- Target unificado iOS/macOS Xcode: `start_app()` (`lib.rs:101`, `#[no_mangle] extern "C"`) llamado desde `main.mm` del proyecto Xcode generado. Requerido para `cargo check --target aarch64-apple-ios`.
- Entrada móvil `#[cfg_attr(mobile, tauri::mobile_entry_point)]` envuelve `run()`.

## Añadir un plugin

```bash
pnpm --filter web add @tauri-apps/plugin-xxx
# luego en Cargo.toml:
# tauri-plugin-xxx = "2"
# y en lib.rs: .plugin(tauri_plugin_xxx::init())
# más capabilities JSON.
```

## Checks

```bash
cargo check --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
cargo check --target aarch64-apple-ios --manifest-path src-tauri/Cargo.toml
```

Siguiente: [Estilos y theming →](./styling.md)
