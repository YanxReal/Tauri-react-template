// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/

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
        .invoke_handler(tauri::generate_handler![greet, platform_info])
        .setup(|app| {
            // Ventana frameless en Windows: DWM no redondea WS_POPUP por defecto.
            // Prestly lo hace vía windows crate + DwmSetWindowAttribute(DWMWCP_ROUND).
            // Para template genérico lo dejamos como comentario documentado;
            // descomenta si quieres bordes redondeados nativos en Windows 11.
            #[cfg(target_os = "windows")]
            {
                // use windows::Win32::Foundation::HWND;
                // use windows::Win32::Graphics::Dwm::{DwmSetWindowAttribute, DWM_WINDOW_CORNER_PREFERENCE, DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND};
                // if let Some(window) = app.get_webview_window("main") {
                //     if let Ok(hwnd) = window.hwnd() {
                //         let pref = DWM_WINDOW_CORNER_PREFERENCE(DWMWCP_ROUND.0);
                //         unsafe { let _ = DwmSetWindowAttribute(HWND(hwnd.0), DWMWA_WINDOW_CORNER_PREFERENCE, &pref as *const _ as *const _, std::mem::size_of_val(&pref) as u32); }
                //     }
                // }
            }

            // Centrado forzado en desktop — `center:true` en tauri.conf no siempre
            // se honra si el OS restaura la posición previa (Windows/macOS resume).
            #[cfg(desktop)]
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.center();
            }

            // En release (perfil sin `debug_assertions`) eliminamos el menú
            // contextual NATIVO del webview — Recargar/Volver/Adelante en
            // WKWebView (macOS), WebView2 (Windows) y WebKitGTK (Linux); en
            // iOS/Android suprime el menú de long-press. Se intercepta el
            // evento `contextmenu` desde el frontend (la única vía oficial en
            // Tauri v2, igual en todos los OS). Debug conserva el menú: el
            // "Recargar" es útil en desarrollo.
            if !cfg!(debug_assertions) {
                for (_, window) in app.webview_windows() {
                    let _ = window.eval(
                        "(function(){ try { document.addEventListener('contextmenu', function(e){ e.preventDefault(); }, false); } catch(_){} })();",
                    );
                }
            }

            // Log plataforma al iniciar (útil para debug multi-OS)
            log::info!("backend started on {}", platform::current_platform());
            let _ = app;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
