// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/

#[cfg(desktop)]
use tauri::Manager;
// Windows: overlay titlebar (frameless + Snap Layouts). Ver setup().
#[cfg(target_os = "windows")]
use tauri_plugin_decorum::WebviewWindowExt;

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

/// Redimensiona la ventana desde el borde indicado.
///
/// En Linux la ventana CSD no trae agarres de resize (GTK delega en el WM y el
/// WM no decora una ventana cliente-decorada), asi que el borde lo detecta la
/// app (`useWindowResizeEdges`) y acaba aqui, en el mismo `begin_resize_drag`
/// que usaria GTK. En el resto de plataformas el WM ya lo hace solo.
#[tauri::command]
fn start_window_resize(window: tauri::WebviewWindow, direction: String) -> Result<(), String> {
    #[cfg(target_os = "linux")]
    {
        use gtk::prelude::*;

        let gtk_window = window.gtk_window().map_err(|e| e.to_string())?;
        let edge = match direction.as_str() {
            "North" => gtk::gdk::WindowEdge::North,
            "South" => gtk::gdk::WindowEdge::South,
            "West" => gtk::gdk::WindowEdge::West,
            "East" => gtk::gdk::WindowEdge::East,
            "NorthWest" => gtk::gdk::WindowEdge::NorthWest,
            "NorthEast" => gtk::gdk::WindowEdge::NorthEast,
            "SouthWest" => gtk::gdk::WindowEdge::SouthWest,
            "SouthEast" => gtk::gdk::WindowEdge::SouthEast,
            _ => return Err(format!("direccion desconocida: {direction}")),
        };
        let (root_x, root_y) = gtk::gdk::Display::default()
            .and_then(|display| display.default_seat())
            .and_then(|seat| seat.pointer())
            .map(|pointer| {
                let (_screen, x, y) = pointer.position();
                (x, y)
            })
            .ok_or_else(|| "sin dispositivo de puntero".to_string())?;
        // `GDK_CURRENT_TIME` (= 0): gdk-rs no lo exporta, así que va el valor.
        gtk_window.begin_resize_drag(edge, 1, root_x, root_y, 0);
        Ok(())
    }
    #[cfg(not(target_os = "linux"))]
    {
        let _ = (window, direction);
        Err("unsupported".to_string())
    }
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

/// Posición X objetivo de cada traffic light en macOS (Close / Miniaturize /
/// Zoom). Estaba en `22.5 / 44.5 / 66.5`; se movió 3px y luego 2px más a la
/// izquierda (`19.5` → `17.5`). Vive en una sola const porque la usan el snap de
/// `adjust_macos_traffic_lights` y el detector de drift
/// `needs_traffic_lights_update`: si se separan, el observer re-aplica el frame
/// en cada tick del polling de 60 fps.
#[cfg(all(target_os = "macos", desktop))]
const TRAFFIC_LIGHTS_X: [f64; 3] = [17.5, 39.5, 61.5];

/// Alto de la banda del header en macOS: tiene que coincidir con
/// `HEADER_HEIGHT.macos` de `apps/web/src/components/layout/header.tsx`
/// (`h-[52px]`). Los dots se centran dentro de esta banda.
#[cfg(all(target_os = "macos", desktop))]
const MACOS_HEADER_BAND: f64 = 52.0;

/// Centro vertical objetivo de los dots (la mitad de la banda del header).
#[cfg(all(target_os = "macos", desktop))]
const TRAFFIC_LIGHTS_CENTER_Y: f64 = MACOS_HEADER_BAND / 2.0;

/// Tamaño nativo de un dot antes del `grow` (12px de serie; macOS reciente los
/// sirve a 14px, que ya cae dentro del rango "agrandado"). Compartido con el
/// detector de drift para no tener dos copias del número.
#[cfg(all(target_os = "macos", desktop))]
const NATIVE_DOT_SIZE: f64 = 12.0;

/// Y objetivo de un dot de `size` px para que quede centrado en la banda del
/// header. El `frame` de los botones vive en el sistema de coordenadas de su
/// **superview** (el contenedor de la titlebar), que puede estar flipped o no:
/// medido en macOS 26 ese contenedor NO está flipped, así que escribir
/// `y = 26 - size/2` movía los dots ~9px HACIA ARRIBA en vez de bajarlos.
/// Con `isFlipped()` cubrimos los dos casos.
#[cfg(all(target_os = "macos", desktop))]
fn traffic_lights_target_y(btn: &objc2_app_kit::NSButton, size: f64) -> f64 {
    let desired_top = TRAFFIC_LIGHTS_CENTER_Y - size / 2.0;
    // SAFETY: `btn` es un NSButton vivo de la ventana; `superview` es AppKit puro.
    let Some(parent) = (unsafe { btn.superview() }) else {
        return desired_top;
    };
    if parent.isFlipped() {
        desired_top
    } else {
        parent.frame().size.height - desired_top - size
    }
}

/// Ajusta los traffic lights nativos de macOS (patrón "bajarlos y
/// agrandarlos"). Accede a los botones de ventana estándar vía `NSWindow`
/// (AppKit tipado) y modifica su `frame` en bloque: `grow` agranda cada dot
/// alrededor de su centro y la `y` se fija de forma absoluta para centrarlos
/// verticalmente en la banda del header (`TRAFFIC_LIGHTS_CENTER_Y`),
/// conservando el espaciado horizontal entre los tres.
#[cfg(all(target_os = "macos", desktop))]
fn adjust_macos_traffic_lights(window: &tauri::WebviewWindow) {
    use objc2_app_kit::{NSAutoresizingMaskOptions, NSWindow, NSWindowButton};
    use objc2_foundation::NSRect;

    let grow = 3.0_f64; // agrandar cada dot ~3px
    let shift_right = 16.0_f64; // moverlos un poco a la izquierda (19->16)

    let Ok(ptr) = window.ns_window() else {
        return;
    };
    let Some(ns_window) =
        (unsafe { objc2::rc::Retained::<NSWindow>::retain(ptr as *mut NSWindow) })
    else {
        return;
    };

    // Evita drift acumulativo en live-resize: AppKit resetea a ~12px,
    // nosotros agrandamos a ~15px. Si ya está agrandado, no volver a
    // sumar (evita que se vayan caminando a la derecha y desaparezcan).
    const NATIVE_SIZE: f64 = NATIVE_DOT_SIZE;
    const GROWN_SIZE: f64 = NATIVE_SIZE + 3.0;
    let window_height = ns_window.frame().size.height;

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
        // Ya agrandado: snap absoluto de x e y. La `y` se recalcula desde el
        // superview del botón (ver `traffic_lights_target_y`), así que es
        // idempotente y no depende del historial de resizes (antes se bajaba 3px
        // a ciegas en cada tick y el dot acababa donde AppKit quisiera).
        if frame.size.width > NATIVE_SIZE + 1.5 && frame.size.width < GROWN_SIZE + 2.0 {
            let target_x = match button {
                NSWindowButton::CloseButton => TRAFFIC_LIGHTS_X[0],
                NSWindowButton::MiniaturizeButton => TRAFFIC_LIGHTS_X[1],
                NSWindowButton::ZoomButton => TRAFFIC_LIGHTS_X[2],
                _ => frame.origin.x,
            };
            let target_y = traffic_lights_target_y(&btn, frame.size.height);
            let off_x = (frame.origin.x - target_x).abs() >= 0.6;
            let off_y = (frame.origin.y - target_y).abs() >= 0.6;
            if !off_x && !off_y {
                continue;
            }
            let new_rect = NSRect {
                origin: objc2_foundation::NSPoint {
                    x: target_x,
                    y: target_y,
                },
                size: frame.size,
            };
            btn.setFrame(new_rect);
            btn.setAutoresizingMask(NSAutoresizingMaskOptions(0));
            continue;
        }
        // No tocar si está en fullscreen / fuera de la ventana: AppKit manda los
        // botones fuera de rango visible. (Antes era un `y > 1000` fijo, que en
        // ventanas altas también descartaba una posición normal.)
        if frame.origin.y < -100.0 || frame.origin.y > window_height - 4.0 {
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
                y: traffic_lights_target_y(&btn, frame.size.height + grow),
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
    let Some(ns_window) =
        (unsafe { objc2::rc::Retained::<NSWindow>::retain(ptr as *mut NSWindow) })
    else {
        return false;
    };
    let targets = [
        (NSWindowButton::CloseButton, TRAFFIC_LIGHTS_X[0]),
        (NSWindowButton::MiniaturizeButton, TRAFFIC_LIGHTS_X[1]),
        (NSWindowButton::ZoomButton, TRAFFIC_LIGHTS_X[2]),
    ];
    for (button, target_x) in targets {
        if let Some(btn) = ns_window.standardWindowButton(button) {
            let frame = btn.frame();
            let target_y = traffic_lights_target_y(&btn, frame.size.height);
            if (frame.origin.x - target_x).abs() > 0.6
                || (frame.origin.y - target_y).abs() > 0.6
                || frame.size.width < NATIVE_DOT_SIZE + 1.5
            {
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
        let name_move_ref: &objc2_foundation::NSNotificationName = std::mem::transmute(&*name_move);
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

/// Linux: marco CSD "latched" — patrón Chromium / VS Code / Edge.
///
/// La app dibuja su **propia** titlebar (el header de React + `WindowControls`),
/// igual que en Windows: una sola banda. La `GtkHeaderBar` nativa no sirve
/// porque (a) su variante clara/oscura no puede seguir al tema de la app —
/// mutter lee `_GTK_THEME_VARIANT` una sola vez, al gestionar la ventana
/// (`LOAD_INIT` en `mutter/src/x11/window-props.c`) — y (b) cuando tao crea la
/// ventana en modo SSD, GTK no cablea el arrastre de CSD y la barra no se puede
/// mover (el arrastre del header de la app sí funciona).
///
/// Lo que SÍ se conserva es el **CSD de GTK con su decoración NATIVA**: una
/// `GtkHeaderBar` vacía y oculta deja la ventana en modo cliente-decorado, así
/// que GTK sigue dibujando su fondo y su sombra tal cual, sin overrides de
/// ningún tipo. El contenido solo tiene que respetar el redondeo que GTK ya
/// pinta: `border-top-left/right-radius` = `$window_radius` de Adwaita (8px) en
/// `.app-shell`. Abajo las esquinas son rectas, como en cualquier app GTK3 —
/// GTK3 solo redondea arriba (`decoration { border-radius: r r 0 0 }`).
///
/// La ventana nace oculta (`visible:false` en tauri.linux.conf.json) para
/// instalar todo antes del realize: sin parpadeo. Se muestra siempre al final.
#[cfg(target_os = "linux")]
fn install_linux_frame(window: &tauri::WebviewWindow) {
    use gtk::prelude::*;

    match window.gtk_window() {
        Ok(gtk_window) => {
            // 1) Latch CSD: titlebar vacía y oculta (la app pone la suya).
            //    `no_show_all` es imprescindible: tao muestra la ventana con
            //    `window.show_all()`, que re-mostraría la barra y se comería
            //    43px arriba (comprobado).
            let header = gtk::HeaderBar::new();
            header.set_no_show_all(true);
            gtk_window.set_titlebar(Some(&header));
            header.hide();

            // El Adwaita de GTK3 redondea SOLO las esquinas de arriba
            // (`decoration { border-radius: $window_radius $window_radius 0 0 }`),
            // asi que su sombra es cuadrada abajo. Se reescribe el radio para que
            // la sombra siga el arco en las 4 esquinas — el mismo arreglo que
            // Firefox publico tras `gtk.rounded-bottom-corners` (bugzilla 1964149).
            let provider = gtk::CssProvider::new();
            let _ = provider.load_from_data(b"decoration { border-radius: 8px; }");
            if let Some(screen) = gtk::prelude::WidgetExt::screen(&gtk_window) {
                gtk::StyleContext::add_provider_for_screen(
                    &screen,
                    &provider,
                    gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
                );
            }

            log::info!("install_linux_frame: CSD latch (decoracion nativa de GTK)");
        }
        Err(e) => {
            log::warn!("install_linux_frame: sin GtkWindow ({e}); dejo el marco del sistema");
        }
    }

    if let Err(e) = window.show() {
        log::warn!("install_linux_frame: no pude mostrar la ventana: {e}");
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Linux: la ventana conserva `decorations:true` para que GTK siga en modo
    // CSD y dibuje su SOMBRA nativa, pero la titlebar visible la pone la app
    // (header + `WindowControls`, igual que en Windows) — ver
    // `install_linux_frame`. La decoración la dibuja GTK tal cual (sin overrides
    // ni transparencia): el contenido solo respeta el redondeo de arriba.
    //
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
    let builder = tauri::Builder::default()
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
        );

    // decorum (plugin de la comunidad) — solo Windows: titlebar overlay estilo
    // Edge/VS Code. Linux usa su propio marco CSD (`install_linux_frame`) + la
    // titlebar de React, y macOS el Overlay nativo con traffic lights, así que
    // no se registra ahí.
    #[cfg(target_os = "windows")]
    let builder = builder.plugin(tauri_plugin_decorum::init());

    builder
        .invoke_handler(tauri::generate_handler![
            greet,
            platform_info,
            start_window_resize,
            window_effects_set
        ])
        .setup(|app| {
            // Linux: marco CSD latched (sombra nativa de GTK) + titlebar propia
            // de la app, patrón Chromium/VS Code/Edge — ver `install_linux_frame`.
            #[cfg(target_os = "linux")]
            if let Some(window) = app.get_webview_window("main") {
                install_linux_frame(&window);
            }

            // Windows: ventana FRAMELESS (`decorations:false`) con titlebar
            // propia — `header.tsx` aporta la zona de arrastre + caption buttons
            // y decorum expone `show_snap_overlay` (Win+Z) para el hover de
            // maximizar. El resize lo mantiene tao vía WM_NCHITTEST y las
            // esquinas redondeadas las pone DWM (una frameless es cuadrada).
            #[cfg(target_os = "windows")]
            {
                use windows::Win32::Foundation::HWND;
                use windows::Win32::Graphics::Dwm::{
                    DwmSetWindowAttribute, DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND,
                    DWM_WINDOW_CORNER_PREFERENCE,
                };
                if let Some(window) = app.get_webview_window("main") {
                    let _ = window.create_overlay_titlebar();
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
                let block_ref: &block2::Block<
                    dyn Fn(std::ptr::NonNull<objc2_foundation::NSTimer>),
                > = &block;
                unsafe {
                    use objc2_foundation::{NSRunLoop, NSRunLoopCommonModes, NSTimer};
                    let timer = NSTimer::scheduledTimerWithTimeInterval_repeats_block(
                        0.016, true, block_ref,
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
