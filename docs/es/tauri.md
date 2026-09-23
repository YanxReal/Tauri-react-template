# Backend Tauri (`src-tauri`)

Rust + Tauri v2. Entradas: `src-tauri/src/lib.rs:396` (`run()`) y `src-tauri/src/main.rs`.

## Comandos

Registrados en `lib.rs:436`:

```rust
tauri::generate_handler![greet, platform_info, window_effects_set]
```

| Comando | Firma | Descripción |
|---------|-------|-------------|
| `greet` | `fn greet(name: &str) -> String` | Devuelve saludo (demo) — `lib.rs:12` |
| `platform_info` | `fn platform_info() -> String` | Devuelve `platform::current_platform()` — `lib.rs:17` |
| `window_effects_set` | `fn window_effects_set(window, enabled: bool, dark: Option<bool>) -> Result<(), String>` | Aplica/limpia translucidez nativa — `lib.rs:82` |

Uso en frontend (`apps/web/src/App.tsx:34`):

```ts
import { invoke } from "@tauri-apps/api/core"
await invoke<string>("greet", { name: "Tauri" })
```

`window_effects_set` es **sync** (corre en el hilo principal) — lo exige `window-vibrancy` que debe ejecutarse en el main thread (`lib.rs:26`). Nunca lo hagas `async`.

Dispatch por plataforma para `set_window_effect` (`lib.rs:31`):

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
- **Env embedding**: lee `src-tauri/.env` (gitignored) + env del proceso para `EMBED_KEYS` (`VITE_API_URL`, `SUPABASE_*`) e inyecta como `cargo:rustc-env`. Valida URLs de Supabase en release (`build.rs:135`).

## Traffic lights de macOS (fix HuLa)

Contexto y fix en `docs/es/native-feel.md`. Implementación en `lib.rs:162`:

- `adjust_macos_traffic_lights` (`lib.rs:162`) — mueve/agranda los 3 `NSWindowButton`s (targets `17.5/39.5/61.5`, histéresis `±0.6px`, `grow 3`, `shift_right 16` + `extra_gap`).
- `traffic_lights_target_y` (`lib.rs:142`) — `y` absoluto para que el centro del dot caiga en `MACOS_HEADER_BAND / 2` (`lib.rs:123` = 26px, mitad del header de 52px de macOS). El frame vive en el superview del botón, que en macOS 26 **no está flipped**: hay que leer `isFlipped()` + la altura del contenedor en vez de asumir "distancia desde arriba".
- `needs_traffic_lights_update` + `ensure_traffic_lights_observer` (`NSWindowDidResizeNotification`/`DidMove`) + **polling a 60 fps** (`NSTimer` en `NSRunLoopCommonModes`) durante `NSEventTrackingRunLoopMode` (live-resize).
- `setAutoresizingMask(0)` evita que AppKit vuelva a resetear.

## Marco de ventana en Linux — titlebar propia + CSD "latched"

`tauri.linux.conf.json:11` → `decorations: true` + `transparent: false` + `visible: false` (`:12`). `install_linux_frame` (`lib.rs:358`) engancha **CSD** con una `GtkHeaderBar` vacía y oculta (más `set_no_show_all(true)`, porque tao muestra la ventana con `show_all()`) y pinta transparente el fondo de ventana de GTK, así que GTK aporta **solo su sombra nativa**. La titlebar la dibuja la app: la banda fija de 44px de `header.tsx` (zona de arrastre) más `WindowControls` (`header.tsx:222`) — el mismo modelo "custom frame" que Windows / Edge / VS Code / Chromium. `globals.css:246` da `border-radius` a `.app-shell` para que las 4 esquinas queden redondeadas.

Por qué no la titlebar nativa: mutter lee `_GTK_THEME_VARIANT` **una sola vez**, al gestionar la ventana (`LOAD_INIT` en `mutter/src/x11/window-props.c`), así que la SSD nunca puede seguir al tema de la app — una app oscura en un escritorio claro mantenía la titlebar blanca; y una `GtkHeaderBar` no es arrastrable cuando tao crea la ventana en modo SSD. `useNativeTheme` (`native-chrome.ts:135`) sigue reflejando el tema en la variante de GTK. Los viejos hacks de `apply_linux_window_shadow` (visual RGBA forzado + `opacity 0.99`) siguen eliminados: forzar el visual GDK después del realize no puede funcionar. Razonamiento completo en `docs/es/native-feel.md`.

También fija `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` antes del `Builder` (`lib.rs:408`) para evitar crashes DMABUF de WebKitGTK.

## Windows — titlebar overlay frameless (`tauri-plugin-decorum`)

`tauri.windows.conf.json:12` → `decorations: false`: la ventana es frameless y la titlebar la dibuja la app (modelo Edge / VS Code). `setup()` llama a `create_overlay_titlebar()` (`lib.rs:462`) del plugin de la comunidad [decorum](https://github.com/clearlysid/tauri-plugin-decorum), registrado solo en Windows (`lib.rs:433`). `transparent: true` se mantiene para que Mica / `window_effects_set` siga viéndose.

Los caption buttons son React (`apps/web/src/components/layout/window-controls.tsx:61`, renderizados por `header.tsx:224`); el hover de 620 ms sobre maximizar invoca `plugin:decorum|show_snap_overlay` (`window-controls.tsx:104`) para abrir el flyout de Snap Layouts de Windows 11. Permisos: `capabilities/default.json:6` (`allow-minimize` / `allow-close` / `allow-is-maximized`) + `capabilities/default.json:15` (`allow-set-focus`, lo exige la cadena `setFocus().then(invoke(...))`) + `capabilities/windows.json:7` (`decorum:allow-show-snap-overlay`, `platforms: ["windows"]` — el plugin es dep `cfg(windows)`, así que un `cargo check` en macOS/Linux rechazaría el permiso si viviera en `default.json`).

`tauri.windows.conf.json:13` → `scrollBarStyle: "fluentOverlay"`: WebView2 dibuja la scrollbar **overlay** (pastilla fina, se auto-oculta, flota sobre el contenido) en vez de la barra clásica con carril y botones de flecha. Necesita WebView2 Runtime >= 125.0.2535.41 y fuera de Windows no hace nada. Cambio hermano obligatorio: el contenedor de scroll es `.app-scroll` (solo contenido), así la barra nunca le roba ancho al header — ver `native-feel.md`.

`lib.rs:466` — `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)` en Windows 11 (solo en deps `target_os = "windows"` — `Cargo.toml:57`): una ventana frameless es cuadrada por defecto, así que esta llamada es la que mantiene las esquinas redondeadas. Razonamiento completo en `docs/es/native-feel.md`.

## Entrada desktop vs móvil

- Desktop: `run()` vía `main.rs` → `lib.rs:396`.
- Target unificado iOS/macOS Xcode: `start_app()` (`lib.rs:106`, `#[no_mangle] extern "C"`) llamado desde `main.mm` del proyecto Xcode generado. Requerido para `cargo check --target aarch64-apple-ios`.
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
