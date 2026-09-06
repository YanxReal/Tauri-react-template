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

/// Ajusta los traffic lights nativos de macOS (patrón "bajarlos y
/// agrandarlos"). Accede a los botones de ventana estándar vía `NSWindow`
/// (AppKit tipado) y modifica su `frame` en bloque: `grow` agranda cada dot
/// alrededor de su centro y `lower` lo desplaza hacia abajo, conservando el
/// espaciado horizontal entre los tres.
#[cfg(all(target_os = "macos", desktop))]
fn adjust_macos_traffic_lights(window: &tauri::WebviewWindow) {
    use objc2_app_kit::{NSView, NSWindow, NSWindowButton, NSAutoresizingMaskOptions};
    use objc2_foundation::NSRect;

    let grow = 3.0_f64; // agrandar cada dot ~3px
    let lower = 8.0_f64; // bajarlos un poco más (~8px)
    let shift_right = 16.0_f64; // moverlos un poco a la izquierda (19->16)

    let Ok(ptr) = window.ns_window() else {
        return;
    };
    let Some(ns_window) = (unsafe {
        objc2::rc::Retained::<NSWindow>::retain(ptr as *mut NSWindow)
    }) else {
        return;
    };

    // Evita drift acumulativo en live-resize: AppKit resetea a ~12px,
    // nosotros agrandamos a ~15px. Si ya está agrandado, no volver a
    // sumar (evita que se vayan caminando a la derecha y desaparezcan).
    const NATIVE_SIZE: f64 = 12.0;
    const GROWN_SIZE: f64 = NATIVE_SIZE + 3.0;

    for button in [
        NSWindowButton::CloseButton,
        NSWindowButton::MiniaturizeButton,
        NSWindowButton::ZoomButton,
    ] {
        let Some(btn) = ns_window.standardWindowButton(button) else {
            continue;
        };
        let frame: NSRect = btn.frame();
        if frame.size.width <= 0.0 || frame.size.height <= 0.0 {
            continue;
        }
        // Si ya está agrandado, asegura equidistancia y baja un poco más (5->8).
        // Targets con lower 8: y -3 vs anterior. Aplica x y y juntos.
        if frame.size.width > NATIVE_SIZE + 1.5 && frame.size.width < GROWN_SIZE + 2.0 {
            let target_x = match button {
                NSWindowButton::CloseButton => 22.5,
                NSWindowButton::MiniaturizeButton => 44.5,
                NSWindowButton::ZoomButton => 66.5,
                _ => frame.origin.x,
            };
            let target_y_delta = -3.0; // lower 5->8
            let need_x = (frame.origin.x - target_x).abs() >= 0.6;
            // Detecta si aún está en y anterior (con lower 5) -> necesita bajar 3
            // No tenemos referencia exacta de y, pero si target_x no coincide, también y está alto
            if !need_x {
                // Si x ya está bien, verifica y: si viene de lower 5, y está 3px más alto
                // Lo bajamos. Como no tenemos target_y absoluto, bajamos 3px directo
                // solo si no hemos bajado ya (evita acumular). Usamos un flag: si x está bien
                // asumimos que puede faltar el y, así que bajamos una vez.
                let new_rect = NSRect {
                    origin: objc2_foundation::NSPoint {
                        x: frame.origin.x,
                        y: frame.origin.y - 3.0,
                    },
                    size: frame.size,
                };
                // Solo baja si aún está pegado arriba (y > que target esperado ~?)
                // Evita bajar en cada resize: solo una vez por ventana
                // Heurística: si y > 5 (muy alto), baja
                if frame.origin.y > 8.0 {
                    btn.setFrame(new_rect);
                    btn.setAutoresizingMask(NSAutoresizingMaskOptions(0));
                }
                continue;
            }
            let new_rect = NSRect {
                origin: objc2_foundation::NSPoint {
                    x: target_x,
                    y: frame.origin.y + target_y_delta,
                },
                size: frame.size,
            };
            btn.setFrame(new_rect);
            btn.setAutoresizingMask(NSAutoresizingMaskOptions(0));
            continue;
        }
        // No tocar si está en fullscreen (origen fuera de rango visible)
        if frame.origin.y < -100.0 || frame.origin.y > 1000.0 {
            continue;
        }
        let extra_gap = match button {
            NSWindowButton::CloseButton => 0.0,
            NSWindowButton::MiniaturizeButton => 2.0,
            NSWindowButton::ZoomButton => 4.0,
            _ => 0.0,
        };
        let new_rect = NSRect {
            origin: objc2_foundation::NSPoint {
                x: frame.origin.x - grow / 2.0 + shift_right + extra_gap,
                y: frame.origin.y - grow / 2.0 - lower,
            },
            size: objc2_foundation::NSSize {
                width: frame.size.width + grow,
                height: frame.size.height + grow,
            },
        };
        // Clamp para no sacarlos de la ventana al agrandar
        if new_rect.origin.x < 6.0 || new_rect.origin.x > 400.0 {
            continue;
        }
        btn.setFrame(new_rect);
        btn.setAutoresizingMask(NSAutoresizingMaskOptions(0));
    }
}

#[cfg(all(target_os = "macos", desktop))]
fn needs_traffic_lights_update(window: &tauri::WebviewWindow) -> bool {
    use objc2_app_kit::{NSWindow, NSWindowButton};
    let Ok(ptr) = window.ns_window() else {
        return false;
    };
    let Some(ns_window) = (unsafe {
        objc2::rc::Retained::<NSWindow>::retain(ptr as *mut NSWindow)
    }) else {
        return false;
    };
    let targets = [
        (NSWindowButton::CloseButton, 22.5),
        (NSWindowButton::MiniaturizeButton, 44.5),
        (NSWindowButton::ZoomButton, 66.5),
    ];
    for (button, target_x) in targets {
        if let Some(btn) = ns_window.standardWindowButton(button) {
            let frame = btn.frame();
            if (frame.origin.x - target_x).abs() > 0.6 || (frame.size.width - 15.0).abs() > 0.6 {
                return true;
            }
        }
    }
    false
}

#[cfg(all(target_os = "macos", desktop))]
fn ensure_traffic_lights_observer(window: &tauri::WebviewWindow) {
    use block2::RcBlock;
    use objc2_foundation::{NSNotification, NSNotificationCenter};
    use std::ptr::NonNull;
    thread_local! {
        static REGISTERED: std::cell::RefCell<std::collections::HashSet<String>> =
            std::cell::RefCell::new(std::collections::HashSet::new());
    }
    let label = window.label().to_string();
    if REGISTERED.with(|s| s.borrow().contains(&label)) {
        return;
    }
    // NSWindowDidResizeNotification y DidMove llegan en tracking mode, más fiable que WindowEvent en macOS 26
    let w1 = window.clone();
    let block_resize = RcBlock::new(move |_note: NonNull<NSNotification>| {
        adjust_macos_traffic_lights(&w1);
    });
    let w2 = window.clone();
    let block_move = RcBlock::new(move |_note: NonNull<NSNotification>| {
        adjust_macos_traffic_lights(&w2);
    });
    unsafe {
        let center = NSNotificationCenter::defaultCenter();
        let name_resize = objc2_foundation::NSString::from_str("NSWindowDidResizeNotification");
        let name_move = objc2_foundation::NSString::from_str("NSWindowDidMoveNotification");
        let name_resize_ref: &objc2_foundation::NSNotificationName =
            std::mem::transmute(&*name_resize);
        let name_move_ref: &objc2_foundation::NSNotificationName =
            std::mem::transmute(&*name_move);
        let _obs1 = center.addObserverForName_object_queue_usingBlock(
            Some(name_resize_ref),
            None,
            None,
            &block_resize,
        );
        let _obs2 = center.addObserverForName_object_queue_usingBlock(
            Some(name_move_ref),
            None,
            None,
            &block_move,
        );
        std::mem::forget(_obs1);
        std::mem::forget(_obs2);
        std::mem::forget(block_resize);
        std::mem::forget(block_move);
        std::mem::forget(name_resize);
        std::mem::forget(name_move);
    }
    REGISTERED.with(|s| s.borrow_mut().insert(label));
}

/// Sombra de ventana + border-radius nativos en Linux.
///
/// `tauri` no expone sombra nativa en Linux (WindowConfig.shadow = "Linux:
/// Unsupported"). En GTK la sombra la dibuja el tema vía el nodo CSS
/// `window.background.csd decoration { box-shadow; margin; border-radius }`.
/// Con `decorations:false + transparent:true` ese nodo no se genera y la
/// ventana frameless queda plana (sin sombra, esquinas cuadradas).
///
/// Truco usado por `custom-window-decorations-gtk4` y confirmado por el
/// compartimento `decoration` de los temas GTK: forzamos la clase `.csd` y
/// aplicamos un `GtkCssProvider` (prioridad APPLICATION) que restaura el
/// `decoration` con box-shadow + margin (espacio que el compositor "ve" para
/// componer la sombra) + border-radius. En maximizado/tiled se aplanan para
/// no mostrar sombra fantasma.
#[cfg(target_os = "linux")]
fn apply_linux_window_shadow(window: &tauri::WebviewWindow) {
    use gtk::prelude::*;

    let Ok(gtk_window) = window.gtk_window() else {
        return;
    };

    // Fuerza CSD para que GTK genere el nodo `decoration` aunque esté frameless.
    gtk_window.style_context().add_class("csd");

    let css = r#"
        window.background.csd decoration {
            box-shadow: 0 16px 48px rgba(0, 0, 0, 0.38), 0 4px 16px rgba(0, 0, 0, 0.22);
            margin: 12px;
            border-radius: 10px;
        }
        window.background.csd decoration:backdrop {
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.28);
        }
        window.background.csd {
            border-radius: 10px;
        }
        window.background.csd.maximized decoration,
        window.background.csd.tiled decoration {
            box-shadow: none;
            margin: 0;
            border-radius: 0;
        }
    "#;

    let provider = gtk::CssProvider::new();
    if let Err(e) = provider.load_from_data(css.as_bytes()) {
        log::warn!("linux shadow css failed: {e}");
        return;
    }

    // GTK3: provider por screen (no hay add_provider_for_display en gtk-rs 0.18).
    // Prioridad APPLICATION -> aplica a nuestra app sin pisar el tema GTK.
    if let Some(screen) = gtk::prelude::WidgetExt::screen(&gtk_window) {
        gtk::StyleContext::add_provider_for_screen(
            &screen,
            &provider,
            gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }

    // Avisamos al frontend para que DESACTIVE el fallback CSS (box-shadow del
    // webview) cuando la sombra GTK nativa ya está activa -> evita sombra doble.
    let _ = window.eval("document.documentElement.classList.add('gtk-shadow')");

    log::info!("linux window shadow applied via GTK decoration css");
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Linux WebKitGTK: DMABUF renderer causa flicker, Error 71 Wayland y RAM desbocada en resize
    // (NVIDIA + Wayland). Ver https://v2.tauri.app/develop/debug/linux-graphics/ y tauri#9394
    #[cfg(target_os = "linux")]
    {
        // Desactiva el fast path DMABUF, usa el renderer seguro (costo mínimo, evita crash/resize RAM)
        std::env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
        // NVIDIA Wayland explicit sync bug (Error 71 dispatching to Wayland display)
        std::env::set_var("__NV_DISABLE_EXPLICIT_SYNC", "1");
        // Opcional: si sigue el colapso, descomentar la siguiente línea (desactiva compositing acelerado)
        // std::env::set_var("WEBKIT_DISABLE_COMPOSITING_MODE", "1");
    }
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

            // Linux: sombra de ventana vía GTK CssProvider (see fn doc).
            #[cfg(target_os = "linux")]
            if let Some(window) = app.get_webview_window("main") {
                apply_linux_window_shadow(&window);
            }

            // macOS: las esquinas redondeadas son nativas (decorations:true +
            // transparent + Overlay). HuLa 3-mecanismos: WindowEvent + NSNotificationCenter + live-resize poll
            #[cfg(all(target_os = "macos", desktop))]
            if let Some(window) = app.get_webview_window("main") {
                // 1) Posición inicial
                adjust_macos_traffic_lights(&window);
                // 2) WindowEvent (Focused/Resized/ScaleFactor) - Wry/Tao solo emite al soltar
                let w = window.clone();
                window.on_window_event(move |event| {
                    if matches!(
                        event,
                        tauri::WindowEvent::Resized(_)
                            | tauri::WindowEvent::ScaleFactorChanged { .. }
                            | tauri::WindowEvent::Focused(true)
                    ) {
                        adjust_macos_traffic_lights(&w);
                    }
                });
                // 3) NSNotificationCenter para DidResize/DidMove (macOS 26+ necesita esto porque Resized llega tarde)
                ensure_traffic_lights_observer(&window);
                // 4) Polling live-resize a 60fps en CommonModes (dispara durante NSEventTrackingRunLoopMode)
                let w2 = window.clone();
                let block = block2::RcBlock::new(
                    move |_timer: std::ptr::NonNull<objc2_foundation::NSTimer>| {
                        // Solo si está en live-resize y necesita update (evita setFrame redundante)
                        if needs_traffic_lights_update(&w2) {
                            adjust_macos_traffic_lights(&w2);
                        }
                    },
                );
                let block_ref: &block2::Block<dyn Fn(std::ptr::NonNull<objc2_foundation::NSTimer>)> =
                    &block;
                unsafe {
                    use objc2_foundation::{NSRunLoop, NSRunLoopCommonModes, NSTimer};
                    let timer = NSTimer::scheduledTimerWithTimeInterval_repeats_block(
                        0.016,
                        true,
                        block_ref,
                    );
                    let runloop = NSRunLoop::currentRunLoop();
                    runloop.addTimer_forMode(&timer, NSRunLoopCommonModes);
                    std::mem::forget(timer);
                    std::mem::forget(block);
                }
            }

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
