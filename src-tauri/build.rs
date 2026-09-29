//! Build script — multi-platform adaptations.
//! - Calls `tauri_build::build()` to generate context + mobile/desktop cfg aliases.
//! - On Android targets: passes `-Wl,-z,max-page-size=16384` so the .so is
//!   16 KB-page compatible (Android 15+ shows no compatibility warning).
//! - On macOS: compiles `Assets.xcassets/AppIcon` via `actool` so the .app uses
//!   the theme-aware AppIcon (instead of just icon.icns). Works without Xcode
//!   (skips with warning) and is ignored on other platforms.
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

    // macOS: compile Assets.xcassets via actool (Xcode) for theme-aware AppIcon.
    #[cfg(target_os = "macos")]
    {
        use std::process::Command;
        let manifest_dir = env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR");
        let assets = Path::new(&manifest_dir).join("Assets.xcassets");
        if assets.exists() {
            println!("cargo:rerun-if-changed={}", assets.display());
            if let Ok(actool) = which_actool() {
                let out_dir = Path::new(&env::var("OUT_DIR").unwrap()).join("assets-car");
                let _ = fs::create_dir_all(&out_dir);
                let output = Command::new(&actool)
                    .args([
                        "--output-format",
                        "human-readable-text",
                        "--notices",
                        "--warnings",
                        "--output-partial-info-plist",
                        out_dir.join("partial.plist").to_str().unwrap(),
                        "--app-icon",
                        "AppIcon",
                        "--compress-pngs",
                        "--enable-on-demand-resources",
                        "NO",
                        "--target-device",
                        "mac",
                        "--minimum-deployment-target",
                        "15.0",
                        "--platform",
                        "macosx",
                        "--compile",
                        out_dir.to_str().unwrap(),
                        assets.to_str().unwrap(),
                    ])
                    .output();
                if let Ok(out) = output {
                    if !out.status.success() {
                        println!(
                            "cargo:warning=actool failed for Assets.xcassets: {}",
                            String::from_utf8_lossy(&out.stderr)
                        );
                    } else {
                        println!(
                            "cargo:rustc-env=TAURI_ASSETS_CAR={}",
                            out_dir.join("Assets.car").display()
                        );
                    }
                }
            } else {
                println!("cargo:warning=actool not found, skipping Assets.xcassets compile (install Xcode for themed AppIcon; icon.icns will be used otherwise)");
            }
        }
    }

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

#[cfg(target_os = "macos")]
fn which_actool() -> Result<String, ()> {
    if let Ok(output) = std::process::Command::new("xcrun")
        .arg("--find")
        .arg("actool")
        .output()
    {
        if output.status.success() {
            return Ok(String::from_utf8_lossy(&output.stdout).trim().to_string());
        }
    }
    if Path::new("/Applications/Xcode.app/Contents/Developer/usr/bin/actool").exists() {
        return Ok("/Applications/Xcode.app/Contents/Developer/usr/bin/actool".to_string());
    }
    Err(())
}
