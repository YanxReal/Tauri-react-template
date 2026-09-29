//! Build script — multi-platform adaptations.
//! - Calls `tauri_build::build()` to generate context + mobile/desktop cfg aliases.
//! - On Android targets: passes `-Wl,-z,max-page-size=16384` so the .so is
//!   16 KB-page compatible (Android 15+ shows no compatibility warning).
//! - Embeds public env vars from `src-tauri/.env` or process env so desktop +
//!   mobile bundles carry them without a runtime .env. Extend the `EMBED_KEYS`
//!   list for your own vars.

use std::{collections::HashMap, env, fs, path::Path};

const EMBED_KEYS: &[&str] = &["VITE_API_URL"];

fn main() {
    tauri_build::build();

    // Android 15+ (16 KB page size): align LOAD segments to 16 KB so the .so
    // is 16 KB-page compatible (no "isn't 16 KB compatible" warning). Only
    // for Android targets — desktop/iOS linkers don't take this flag the
    // same way. `TARGET` is set by cargo for the build script.
    if env::var("TARGET").unwrap_or_default().contains("android") {
        println!("cargo:rustc-link-arg=-Wl,-z,max-page-size=16384");
    }

    // macOS app icon ships as `icons/icon.icns` (from `bundle.icon`). The old
    // `Assets.xcassets` -> actool -> `TAURI_ASSETS_CAR` path was dead code
    // (nothing consumed the env var; tauri-bundler only reads `.car`/`.icon`
    // entries of `bundle.icon`) and was removed 2026-09-29. `Assets.xcassets`
    // stays as the source for a future `.icon`/`.car` entry.

    // Env embedding — public values only, generic: reads src-tauri/.env (gitignored) or process env.
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR");
    let env_file = Path::new(&manifest_dir).join(".env");
    if env_file.exists() {
        println!("cargo:rerun-if-changed={}", env_file.display());
    }
    for key in EMBED_KEYS {
        println!("cargo:rerun-if-env-changed={key}");
    }

    let mut file_values = HashMap::new();
    if let Ok(contents) = fs::read_to_string(&env_file) {
        for line in contents.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            if let Some((k, v)) = line.split_once('=') {
                file_values.insert(
                    k.trim().to_string(),
                    v.trim().trim_matches('"').trim_matches('\'').to_string(),
                );
            }
        }
    }

    for key in EMBED_KEYS {
        let value = env::var(key)
            .ok()
            .or_else(|| file_values.get(*key).cloned());
        if let Some(value) = value {
            println!("cargo:rustc-env={key}={value}");
        }
    }
}
