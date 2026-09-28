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
// `window_effects_set { enabled, dark? }` applies or clears
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

/// Resizes the window from the given edge.
///
/// On Linux the frameless window has no resize grips (the WM does not
/// decorate a frameless window), so the app detects the edge
/// (`useWindowResizeEdges`) and it ends here, in GTK's `begin_resize_drag`.
/// On other platforms the WM handles it.
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
            _ => return Err(format!("unknown direction: {direction}")),
        };
        let (root_x, root_y) = gtk::gdk::Display::default()
            .and_then(|display| display.default_seat())
            .and_then(|seat| seat.pointer())
            .map(|pointer| {
                let (_screen, x, y) = pointer.position();
                (x, y)
            })
            .ok_or_else(|| "no pointer device".to_string())?;
        // `GDK_CURRENT_TIME` (= 0): gdk-rs does not export it, so hardcode the value.
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

/// Desktop-Apple shell entry for the unified `tauri-react-template_Apple`
/// Xcode target (see `src-tauri/tauri.macos.conf.json` + `Assets.xcassets`).
/// The Xcode project's `main.mm` calls `start_app()` via FFI. On iOS the
/// symbol comes from `tauri::mobile_entry_point` (cfg `mobile`); here it is
/// exported for macOS so one `staticlib` serves both destinations.
///
/// Without Xcode (plain cargo tauri dev/build) this symbol is unused, but it
/// must exist so `cargo check --target aarch64-apple-ios` and
/// `cargo tauri ios dev` link without errors.
#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn start_app() {
    run()
}

/// Target X position of each macOS traffic light (Close / Miniaturize /
/// Zoom). Was `22.5 / 44.5 / 66.5`; moved 3px then 2px further left
/// (`19.5` → `17.5`). Single const shared by the `adjust_macos_traffic_lights`
/// snap and the `needs_traffic_lights_update` drift detector: on drift the
/// observer re-applies the frame on every 60 fps poll tick.
#[cfg(all(target_os = "macos", desktop))]
const TRAFFIC_LIGHTS_X: [f64; 3] = [17.5, 39.5, 61.5];

/// macOS header band height: must match `HEADER_HEIGHT.macos` in
/// `apps/web/src/components/layout/header.tsx` (`h-[52px]`). Dots center
/// inside this band.
#[cfg(all(target_os = "macos", desktop))]
const MACOS_HEADER_BAND: f64 = 52.0;

/// Target vertical center of the dots (half the header band).
#[cfg(all(target_os = "macos", desktop))]
const TRAFFIC_LIGHTS_CENTER_Y: f64 = MACOS_HEADER_BAND / 2.0;

/// Native dot size before `grow` (12px stock; recent macOS serves 14px,
/// already inside the "grown" range). Shared with the drift detector so the
/// number lives in one place.
#[cfg(all(target_os = "macos", desktop))]
const NATIVE_DOT_SIZE: f64 = 12.0;

/// Target Y of a `size`px dot to center it in the header band. Button
/// `frame`s live in their **superview** coordinates (the titlebar container),
/// which may or may not be flipped: measured on macOS 26 that container is
/// NOT flipped, so writing `y = 26 - size/2` pushed the dots ~9px UP instead
/// of down. `isFlipped()` covers both cases.
#[cfg(all(target_os = "macos", desktop))]
fn traffic_lights_target_y(btn: &objc2_app_kit::NSButton, size: f64) -> f64 {
    let desired_top = TRAFFIC_LIGHTS_CENTER_Y - size / 2.0;
    // SAFETY: `btn` is a live window NSButton; `superview` is pure AppKit.
    let Some(parent) = (unsafe { btn.superview() }) else {
        return desired_top;
    };
    if parent.isFlipped() {
        desired_top
    } else {
        parent.frame().size.height - desired_top - size
    }
}

/// Adjusts the native macOS traffic lights (lower + grow). Reaches the
/// standard window buttons via `NSWindow` (typed AppKit) and edits their
/// `frame` in bulk: `grow` enlarges each dot
/// alrededor de su centro y la `y` se fija de forma absoluta para centrarlos
/// verticalmente en la banda del header (`TRAFFIC_LIGHTS_CENTER_Y`),
/// conservando el espaciado horizontal entre los tres.
#[cfg(all(target_os = "macos", desktop))]
fn adjust_macos_traffic_lights(window: &tauri::WebviewWindow) {
    use objc2_app_kit::{NSAutoresizingMaskOptions, NSWindow, NSWindowButton};
    use objc2_foundation::NSRect;

    let grow = 3.0_f64; // grow each dot ~3px
    let shift_right = 16.0_f64; // nudge left (19->16)

    let Ok(ptr) = window.ns_window() else {
        return;
    };
    let Some(ns_window) =
        (unsafe { objc2::rc::Retained::<NSWindow>::retain(ptr as *mut NSWindow) })
    else {
        return;
    };

    // Avoid cumulative drift on live-resize: AppKit resets to ~12px, we grow
    // to ~15px. If already grown, do not add again (keeps dots from walking
    // right until they disappear).
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
        // Already grown: absolute x/y snap. `y` is recomputed from the button
        // superview (see `traffic_lights_target_y`), so it is idempotent and
        // history-free (a blind -3px per tick used to land wherever AppKit went).
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
        // Skip when fullscreen / off-window: AppKit sends buttons out of the
        // visible range. (A fixed `y > 1000` used to discard normal positions
        // on tall windows too.)
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
        // Clamp to keep them inside the window when growing
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
    // NSWindowDidResizeNotification + DidMove arrive in tracking mode — more reliable than WindowEvent on macOS 26
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

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Linux: frameless window (`decorations:false` + `transparent:false` in
    // tauri.linux.conf.json) with the app-drawn titlebar, same as Windows:
    // square system corners, no alpha channel. Deliberate (2026-09-27):
    // the rounded CSD frame left visible transparent tips and was not
    // worth it.
    //
    // Linux WebKitGTK: DMABUF renderer causes flicker, Wayland Error 71 and runaway RAM on resize
    // (NVIDIA + Wayland). See https://v2.tauri.app/develop/debug/linux-graphics/ and tauri#9394
    #[cfg(target_os = "linux")]
    {
        // Disable the DMABUF fast path, use the safe renderer (minimal cost, avoids crash/resize RAM)
        std::env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
        // NVIDIA Wayland explicit sync bug (Error 71 dispatching to Wayland display)
        std::env::set_var("__NV_DISABLE_EXPLICIT_SYNC", "1");
        // Optional: if collapse persists, uncomment below (disables accelerated compositing)
        // std::env::set_var("WEBKIT_DISABLE_COMPOSITING_MODE", "1");
    }
    let builder = tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        // Native-app feel (multi-OS): blocks "website" shortcuts/menus.
        // `Flags::debug()` keeps context-menu (right-click Reload),
        // DevTools (Ctrl/Cmd+Shift+I) and Reload (F5, Cmd+R) in DEBUG;
        // in RELEASE it blocks everything (Ctrl+P/S, wheel zoom, native
        // webview context menu, etc.). Keyboard zoom is additionally off
        // via `zoomHotkeysEnabled:false` in tauri.conf.json.
        .plugin(
            tauri_plugin_prevent_default::Builder::new()
                .with_flags(tauri_plugin_prevent_default::Flags::debug())
                .build(),
        );

    // decorum (community plugin) — Windows only: Edge/VS Code style overlay
    // titlebar. Linux is already frameless (`decorations:false`) with the
    // React titlebar, and macOS uses the native Overlay with traffic lights,
    // so it is not registered there.
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
            // Forced centering on desktop — `center:true` in tauri.conf is not
            // always honored when the OS restores the previous position
            // (Windows/macOS resume). Goes FIRST: on Linux the window is born
            // hidden (`visible:false`) and shown later, so centering last would
            // flash it uncentered and then jump a frame.
            #[cfg(desktop)]
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.center();
            }

            // Linux: frameless window (`decorations:false`). Born hidden
            // (`visible:false`), shown here already centered: no flash.
            #[cfg(target_os = "linux")]
            if let Some(window) = app.get_webview_window("main") {
                if let Err(e) = window.show() {
                    log::warn!("could not show the Linux window: {e}");
                }
            }

            // Windows: FRAMELESS window (`decorations:false`) with its own
            // titlebar — `header.tsx` provides the drag region + caption buttons
            // and decorum exposes `show_snap_overlay` (Win+Z) for the maximize
            // hover. Resize stays with tao via WM_NCHITTEST; DWM supplies the
            // rounded corners (a frameless window is square by default).
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

            // macOS: rounded corners are native (decorations:true +
            // transparent + Overlay). HuLa 3-mechanism fix: WindowEvent + NSNotificationCenter + live-resize poll
            #[cfg(all(target_os = "macos", desktop))]
            if let Some(window) = app.get_webview_window("main") {
                // 1) Initial position
                adjust_macos_traffic_lights(&window);
                // 2) WindowEvent (Focused/Resized/ScaleFactor) - Wry/Tao only fires on release
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
                // 3) NSNotificationCenter for DidResize/DidMove (macOS 26+ needs this: Resized arrives late)
                ensure_traffic_lights_observer(&window);
                // 4) 60fps live-resize polling in CommonModes (fires during NSEventTrackingRunLoopMode)
                let w2 = window.clone();
                let block = block2::RcBlock::new(
                    move |_timer: std::ptr::NonNull<objc2_foundation::NSTimer>| {
                        // Only while live-resizing and needing an update (avoids redundant setFrame)
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

            // In release, the `prevent-default` plugin (registered above with
            // `Flags::debug()`) already suppresses the webview NATIVE context
            // menu (Reload/Back in WKWebView, WebView2, WebKitGTK) and the
            // mobile long-press one, with no per-profile code here.

            // Log platform at startup (handy for multi-OS debugging)
            log::info!("backend started on {}", platform::current_platform());
            let _ = app;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
