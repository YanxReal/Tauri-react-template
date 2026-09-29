// Platform-specific modules — compiled only for the active target.
// Simplified platform detection for a generic template.
// Each subdirectory is an OS-named "layer"; only the one matching
// target_os compiles. The rest is ignored by the compiler.
// Use it to isolate code that only makes sense on one OS
// (e.g. vibrancy on macOS/Windows, Keychain on Apple, etc.)

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

/// Generic runtime platform detection helper (handy for logs).
/// Runtime platform tag ("macos", "windows", "linux", "ios",
/// "android", or "web" for anything else).
#[must_use]
pub const fn current_platform() -> &'static str {
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
