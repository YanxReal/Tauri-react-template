// Platform-specific modules — compilado solo para el target activo.
// Detección de plataforma simplificada para template genérico.
// Cada subdirectorio es una "capa" OS-named; solo el que coincide con
// target_os se compila. El resto es ignorado por el compilador.
// Úsalo para aislar código que solo tiene sentido en un OS
// (ej: vibrancy en macOS/Windows, Keychain en Apple, etc.)

#![allow(non_snake_case)]

#[cfg(target_os = "android")]
pub mod Android;
#[cfg(target_os = "linux")]
pub mod Linux;
#[cfg(not(any(
    target_os = "android",
    target_os = "ios",
    target_os = "macos",
    target_os = "linux",
    target_os = "windows"
)))]
pub mod Web;
#[cfg(target_os = "windows")]
pub mod Windows;
#[cfg(target_os = "ios")]
pub mod iOS;
#[cfg(target_os = "macos")]
pub mod macOS;

/// Helper genérico para detectar plataforma en runtime (útil para logs).
pub fn current_platform() -> &'static str {
    #[cfg(target_os = "android")]
    return "android";
    #[cfg(target_os = "ios")]
    return "ios";
    #[cfg(target_os = "macos")]
    return "macos";
    #[cfg(target_os = "windows")]
    return "windows";
    #[cfg(target_os = "linux")]
    return "linux";
    #[cfg(not(any(
        target_os = "android",
        target_os = "ios",
        target_os = "macos",
        target_os = "windows",
        target_os = "linux"
    )))]
    return "web";
}
