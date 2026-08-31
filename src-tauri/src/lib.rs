// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/

#[cfg(desktop)]
use tauri::Manager;

pub mod platform;

#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[tauri::command]
fn platform_info() -> String {
    platform::current_platform().to_string()
}

// --- Window translucency ("efecto cristal") -----------------------------------
// Prestly pattern: `window_effects_set { enabled, dark? }` applies or clears
// the native window material — vibrancy on macOS (NSVisualEffectView) and
// Mica on Windows 11. Linux / mobile / other report "unsupported" so the
// frontend hides the toggle instead of pretending the effect exists.
// IMPORTANT: `window-vibrancy` can only run on the MAIN thread (§144.10), so
// this command must stay SYNC — Tauri runs sync commands on the main thread.
// `dark` drives the material so the crystal effect follows the app theme:
// macOS picks a dark / light material, Windows Mica picks the matching tint.
#[cfg(target_os = "macos")]
fn set_window_effect(
    window: &tauri::WebviewWindow,
    enabled: bool,
    dark: Option<bool>,
) -> Result<(), String> {
    // NSVisualEffectMaterial: dark theme -> smoother/darker material, light
    // theme -> lighter one. `UnderWindowBackground` adapts to the system, so
    // we pick explicitly so the crystal matches the in-app theme.
    let material = match dark {
        Some(true) => window_vibrancy::NSVisualEffectMaterial::HudWindow,
        _ => window_vibrancy::NSVisualEffectMaterial::UnderWindowBackground,
    };
    if enabled {
        window_vibrancy::apply_vibrancy(
            window,
            material,
            Some(window_vibrancy::NSVisualEffectState::Active),
            None,
        )
        .map_err(|e| e.to_string())
    } else {
        window_vibrancy::clear_vibrancy(window)
            .map(|_| ())
            .map_err(|e| e.to_string())
    }
}

#[cfg(target_os = "windows")]
fn set_window_effect(
    window: &tauri::WebviewWindow,
    enabled: bool,
    dark: Option<bool>,
) -> Result<(), String> {
    if enabled {
        window_vibrancy::apply_mica(window, dark).map_err(|e| e.to_string())
    } else {
        let _ = window_vibrancy::clear_mica(window);
        Ok(())
    }
}

#[cfg(not(any(target_os = "macos", target_os = "windows")))]
fn set_window_effect(
    _window: &tauri::WebviewWindow,
    _enabled: bool,
    _dark: Option<bool>,
) -> Result<(), String> {
    Err("unsupported".to_string())
}

#[tauri::command]
fn window_effects_set(
    window: tauri::WebviewWindow,
    enabled: bool,
    dark: Option<bool>,
) -> Result<(), String> {
    let result = set_window_effect(&window, enabled, dark);
    match &result {
        Ok(()) => log::info!("window_effects_set: enabled={enabled} ok"),
        Err(e) => log::error!("window_effects_set: enabled={enabled} failed: {e}"),
    }
    result
}

/// Desktop-Apple shell entry para el target unificado `tauri-react-template_Apple`
/// de Xcode (ver `src-tauri/tauri.macos.conf.json` + `Assets.xcassets`).
/// `main.mm` del Xcode project llama a `start_app()` vía FFI. En iOS el
/// símbolo lo genera `tauri::mobile_entry_point` (cfg `mobile`), aquí lo
/// exportamos para macOS para que un solo `staticlib` sirva a ambos destinos.
///
/// Sin Xcode (cargo tauri dev/build puro) este símbolo no se usa, pero
/// debe existir para que `cargo check --target aarch64-apple-ios` y
/// `cargo tauri ios dev` compilen sin errores de linker.
#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn start_app() {
    run()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        // Native-app feel (multi-OS): bloquea atajos/menús de "sitio web".
        // `Flags::debug()` deja activos en DEBUG context-menu (Recargar por
        // clic derecho), DevTools (Ctrl/Cmd+Shift+I) y Reload (F5, Cmd+R);
        // en RELEASE bloquea TODO (Ctrl+P/S, zoom rueda, menú contextual
        // nativo del webview, fuente, etc.). El zoom por teclado se apaga
        // además con `zoomHotkeysEnabled:false` en tauri.conf.json.
        .plugin(
            tauri_plugin_prevent_default::Builder::new()
                .with_flags(tauri_plugin_prevent_default::Flags::debug())
                .build(),
        )
        .invoke_handler(tauri::generate_handler![greet, platform_info, window_effects_set])
        .setup(|app| {
            // Ventana frameless en Windows: DWM no redondea WS_POPUP por defecto.
            // Prestly patrón: DwmSetWindowAttribute(DWMWCP_ROUND) restaura las
            // esquinas curvas nativas de Windows 11.
            #[cfg(target_os = "windows")]
            {
                use windows::Win32::Foundation::HWND;
                use windows::Win32::Graphics::Dwm::{
                    DwmSetWindowAttribute, DWM_WINDOW_CORNER_PREFERENCE,
                    DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND,
                };
                if let Some(window) = app.get_webview_window("main") {
                    if let Ok(hwnd) = window.hwnd() {
                        let preference = DWM_WINDOW_CORNER_PREFERENCE(DWMWCP_ROUND.0);
                        unsafe {
                            let _ = DwmSetWindowAttribute(
                                HWND(hwnd.0),
                                DWMWA_WINDOW_CORNER_PREFERENCE,
                                &preference as *const DWM_WINDOW_CORNER_PREFERENCE
                                    as *const std::ffi::c_void,
                                std::mem::size_of::<DWM_WINDOW_CORNER_PREFERENCE>() as u32,
                            );
                        }
                    }
                }
            }

            // macOS: NO necesita código nativo para esquinas redondeadas —
            // con `decorations: true` (default), `transparent: true` y
            // `titleBarStyle: Overlay`, el marco nativo de macOS dibuja
            // esquinas redondeadas en las 4 esquinas a cualquier tamaño.
            // Windows necesita DWMWCP_ROUND porque decorations:false crea
            // un WS_POPUP cuadrado por defecto.

            // Centrado forzado en desktop — `center:true` en tauri.conf no siempre
            // se honra si el OS restaura la posición previa (Windows/macOS resume).
            #[cfg(desktop)]
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.center();
            }

            // En release, el plugin `prevent-default` (registrado arriba con
            // `Flags::debug()`) ya suprime el menú contextual NATIVO del
            // webview (Recargar/Volver en WKWebView, WebView2, WebKitGTK) y el
            // de long-press móvil, sin tocar código por perfil aquí.

            // Log plataforma al iniciar (útil para debug multi-OS)
            log::info!("backend started on {}", platform::current_platform());
            let _ = app;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
