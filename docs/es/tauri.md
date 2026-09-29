# Backend Tauri (`src-tauri`)

> **Audiencia:** devs Rust — comandos, setup por SO, plugins.

Rust + Tauri v2. Entradas: `src-tauri/src/lib.rs:382` (`run()`) y `src-tauri/src/main.rs`.

## Comandos

Registrados en `lib.rs:607`:

```rust
tauri::generate_handler![
  greet, platform_info, start_window_resize,
  window_effects_set, set_status_bar_style, set_linux_theme
]
```

| Comando | Firma | Descripción |
|---------|-------|-------------|
| `greet` | `fn greet(name: &str) -> String` | Devuelve saludo (demo) — `lib.rs:12` |
| `platform_info` | `fn platform_info() -> String` | Devuelve `platform::current_platform()` — `lib.rs:17` |
| `window_effects_set` | `fn window_effects_set(window, enabled: bool, dark: Option<bool>) -> Result<(), String>` | Aplica/limpia translucidez nativa — `lib.rs:169` |
| `start_window_resize` | `fn start_window_resize(window, direction: String) -> Result<(), String>` | Linux frameless: mapea un nombre de borde GDK a `begin_resize_drag` — `lib.rs:131` |
| `set_status_bar_style` | `fn set_status_bar_style(dark: bool) -> Result<(), String>` | Android: contraste de iconos de la status bar vía JNI (`MainActivity.setStatusBarDark`) — `lib.rs:189` |
| `set_linux_theme` | `fn set_linux_theme(dark: bool) -> Result<(), String>` | Linux: empuja el tema resuelto de la app a GTK (`gtk-application-prefer-dark-theme`) para que scrollbars/controles de WebKitGTK sigan a la app, no al sistema — `lib.rs:208` |

Uso en frontend (`apps/web/src/App.tsx:34`):

```ts
import { invoke } from "@tauri-apps/api/core"
await invoke<string>("greet", { name: "Tauri" })
```

`window_effects_set` es **sync** (corre en el hilo principal) — lo exige `window-vibrancy` que debe ejecutarse en el main thread (`lib.rs:31`). Nunca lo hagas `async`.

Dispatch por plataforma para `set_window_effect` (`lib.rs:31`):

- `macOS` → `window_vibrancy::apply_vibrancy` con `HudWindow` (dark) / `UnderWindowBackground` (light)
- `Windows` → `window_vibrancy::apply_mica(window, dark)`
- `other` (Linux/móvil) → `Err("unsupported")` — el frontend oculta el toggle.

`platform::current_platform()` (`src/platform/`) es el string de OS que consume el frontend (`usePlatform()`).

## Configuración

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
    "security": { "csp": "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self' ipc: http://ipc.localhost https://*.supabase.co; object-src 'none'; base-uri 'self'" }
  }
}
```

Overlays por OS (merged en build): `tauri.macos.conf.json`, `tauri.windows.conf.json`, `tauri.linux.conf.json`, `tauri.ios.conf.json`, `tauri.android.conf.json`. Mantén `dragDropEnabled:false` + `zoomHotkeysEnabled:false` en **los cuatro** configs de escritorio — no solo macOS.

## Content Security Policy

**Offline-first / solo-local.** La app NO carga nada de la nube en runtime: fuentes, CSS, JS e iconos van empaquetados en el build. Una política estricta en **todos** los targets (base `tauri.conf.json:26`, idéntica en `tauri.android.conf.json:4`, `tauri.macos.conf.json:21`, `tauri.windows.conf.json:20`; Linux/iOS heredan la base) y hace imposible que el webview alcance cualquier host externo automáticamente:

- `default-src 'self'` + `object-src 'none'` + `base-uri 'self'` — sin plugins ni secuestro de `<base>`.
- `script-src 'self'` — sin scripts inline. Seguro: `dist/index.html` trae un solo bundle modular externo, las fuentes vienen de `@fontsource-variable/inter` (empaquetadas, no Google Fonts en runtime).
- `style-src 'self' 'unsafe-inline'` — React pone estilos inline; sin esto la UI se rompe.
- `img-src 'self' data:` — Vite convierte los assets pequeños en URIs `data:`.
- `connect-src 'self' ipc: http://ipc.localhost https://*.supabase.co` — IPC de Tauri más el backend opcional de Supabase (`build.rs:135` embebe/valida `SUPABASE_*`). Sin Supabase → quita ese host.
- Dev/HMR no se afecta: esta política ya venía en macOS/Windows con todos los flujos dev funcionando. Si añades Turnstile u otro tercero, extiende `script-src`/`connect-src` explícitamente (el allowance viejo de `challenges.cloudflare.com` se quitó por no usarse).

`src-tauri/capabilities/` — sets de permisos Tauri v2 (opener, window effects, etc.).

## Build script

`src-tauri/build.rs:1`:

- `tauri_build::build()` — genera contexto + aliases cfg `mobile`/`desktop`.
- **Assets macOS**: compila `Assets.xcassets/AppIcon` vía `actool` (Xcode) → `OUT_DIR/assets-car/Assets.car` + var `TAURI_ASSETS_CAR`. Salta con gracia sin Xcode.
- **Env embedding**: lee `src-tauri/.env` (gitignored) + env del proceso para `EMBED_KEYS` (`VITE_API_URL`, `SUPABASE_*`) e inyecta como `cargo:rustc-env`. Valida URLs de Supabase en release (`build.rs:135`).

## Traffic lights de macOS (fix HuLa)

Contexto y fix en `docs/es/native-feel.md`. Implementación en `lib.rs:205`:

- `adjust_macos_traffic_lights` (`lib.rs:205`) — mueve/agranda los 3 `NSWindowButton`s (targets `17.5/39.5/61.5`, histéresis `±0.6px`, `grow 3`, `shift_right 16` + `extra_gap`).
- `traffic_lights_target_y` (`lib.rs:185`) — `y` absoluto para que el centro del dot caiga en `MACOS_HEADER_BAND / 2` (`lib.rs:166` = 26px, mitad del header de 52px de macOS). El frame vive en el superview del botón, que en macOS 26 **no está flipped**: hay que leer `isFlipped()` + la altura del contenedor en vez de asumir "distancia desde arriba".
- `needs_traffic_lights_update` + `ensure_traffic_lights_observer` (`NSWindowDidResizeNotification`/`DidMove`) + **polling a 60 fps** (`NSTimer` en `NSRunLoopCommonModes`) durante `NSEventTrackingRunLoopMode` (live-resize).
- `setAutoresizingMask(0)` evita que AppKit vuelva a resetear.

## Marco de ventana en Linux — frameless + titlebar dibujada por la app

`tauri.linux.conf.json:11` → `decorations: false` + `transparent: false` + `visible: false` (`:12-13`). La ventana es frameless y opaca: esquinas cuadradas del sistema, sin canal alfa — aceptado deliberadamente, ver [Sensación nativa](./native-feel.md#0-linux--ventana-frameless-esquinas-cuadradas-del-sistema-deliberado). La app dibuja su titlebar como un header fijo de 44px con arrastre y caption buttons (`header.tsx:222` + `WindowControls`).

`setup()` centra la ventana y luego llama a `window.show()`: nace oculta y se muestra ya centrada, sin parpadeo.

**Resize:** una ventana frameless no recibe agarres del WM, así que el borde interior de 6px del webview usa `useWindowResizeEdges` + `start_window_resize` (`lib.rs:88`), que lanza `begin_resize_drag` de GTK.

## Windows — titlebar overlay frameless (`tauri-plugin-decorum`)

`tauri.windows.conf.json:12` → `decorations: false`: la ventana es frameless y la titlebar la dibuja la app (modelo Edge / VS Code). `setup()` llama a `create_overlay_titlebar()` (`lib.rs:461`) del plugin de la comunidad [decorum](https://github.com/clearlysid/tauri-plugin-decorum), registrado solo en Windows (`lib.rs:419`). `transparent: true` se mantiene para que Mica / `window_effects_set` siga viéndose.

Los caption buttons son React (`apps/web/src/components/layout/window-controls.tsx:61`, renderizados por `header.tsx:224`); el hover de 620 ms sobre maximizar invoca `plugin:decorum|show_snap_overlay` (`window-controls.tsx:104`) para abrir el flyout de Snap Layouts de Windows 11. Permisos: `capabilities/default.json:6` (`allow-minimize` / `allow-close` / `allow-is-maximized`) + `capabilities/default.json:15` (`allow-set-focus`, lo exige la cadena `setFocus().then(invoke(...))`) + `capabilities/windows.json:7` (`decorum:allow-show-snap-overlay`, `platforms: ["windows"]` — el plugin es dep `cfg(windows)`, así que un `cargo check` en macOS/Linux rechazaría el permiso si viviera en `default.json`).

`tauri.windows.conf.json:13` → `scrollBarStyle: "fluentOverlay"`: WebView2 dibuja la scrollbar **overlay** (pastilla fina, se auto-oculta, flota sobre el contenido) en vez de la barra clásica con carril y botones de flecha. Necesita WebView2 Runtime >= 125.0.2535.41 y fuera de Windows no hace nada. Cambio hermano obligatorio: el contenedor de scroll es `.app-scroll` (solo contenido), así la barra nunca le roba ancho al header — ver `native-feel.md`.

`lib.rs:457` — `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)` en Windows 11 (solo en deps `target_os = "windows"` — `Cargo.toml:57`): una ventana frameless es cuadrada por defecto, así que esta llamada es la que mantiene las esquinas redondeadas. Razonamiento completo en `docs/es/native-feel.md`.

## Entrada desktop vs móvil

- Desktop: `run()` vía `main.rs` → `lib.rs:382`.
- Target unificado iOS/macOS Xcode: `start_app()` (`lib.rs:149`, `#[no_mangle] extern "C"`) llamado desde `main.mm` del proyecto Xcode generado. Requerido para `cargo check --target aarch64-apple-ios`.
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
