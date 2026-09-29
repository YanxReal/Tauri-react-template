# Local modifications in the vendored tauri-cli (durable spec for the skill)

> Durable spec for this skill's base directory — root `MODS.md` was removed in
> favour of this file (no duplication). Base: stock `tauri-cli` from crates.io
> (immutable). See `SKILL.md` for the full rebase procedure.

## Why a full vendor copy

`make install-tauri-cli` must build offline from repo contents only, and the
sources stay readable/grep-able in place. Dropped already: the
`[patch.crates-io] cargo-mobile2` section + copy — 2.12.0 requires
`cargo-mobile2 ^0.22.5` (has the Xcode 27 fix upstream).

## MOD-1 — `fallback_options()` for standalone IDE builds

**Where:** `src/mobile/mod.rs` — `fallback_options` ~:561, fallback inside
`fetch_options` ~:584-607 (anchors move per version).

Stock: the IDE build phase asks a *parent* `tauri ios|android dev|build`
process for options over a WebSocket handshake. Opened directly from Xcode,
no parent ever ran → server file missing → stock fails.

Ours: missing/unparseable server file, dead connection, or failed `options`
request fall back to `fallback_options()`, which follows the IDE's
`CONFIGURATION` env var: `release` → `tauri/custom-protocol` (embeds
`frontendDist`); anything else → dev semantics (loads `build.devUrl`).
This is what makes the `debug`/`release` Xcode configs work standalone.

**Porting notes:** was `read_options` in 2.11.4, `fetch_options` in 2.12.0
(restructured around `OptionsServerInfo { addr, token }`). Re-read the current
fn and re-apply the three `let Ok(...) else return fallback` + final
`unwrap_or_else(fallback_options)` touch points. The now-unused `not_running`
closure must go (else a warning).

## MOD-2 — unified `_Apple` target lookup

**Where:** `src/mobile/ios/mod.rs:570,637`, `src/mobile/ios/project.rs:182`.

Stock looks up the Xcode scheme/target/creates a `*_iOS` dir. Our Xcode project
is ONE unified target `<app>_Apple` (iOS + macOS, see `apple.xcconfig`), so
both lookups use `_Apple` and `project.rs` creates `*_Apple`.

**Porting notes:** trivial string change, but verify upstream didn't add more
`_iOS` lookups; `grep -n _iOS src/mobile/ios/` must print NOTHING after.

## MOD-3 — simplified `{{app.name}}` path replacement

**Where:** `src/mobile/ios/project.rs:142`.

Stock walks path components and replaces only the FIRST containing
`{{app.name}}`. Ours replaces on the whole path string (covers nested template
dirs).

**Porting notes:** if upstream simplifies this themselves, drop MOD-3. The
now-unused `ffi::OsString` / `path::{Component, PathBuf}` imports go with it.

## MOD-4 — Android status-bar contrast for edge-to-edge

**Where:** `templates/mobile/android/app/src/main/MainActivity.kt`
(+ `app/proguard-rules.pro`), plus the window-theme overlays in
`templates/mobile/android/app/src/main/res/` (`values/themes.xml`,
`values-night/themes.xml`, `values-v31/themes.xml` splash, `colors.xml` +
`values-night/colors.xml` `tauri_window_bg` = the frontend's light/dark
background tokens — kills the Material3 lavender/purple launch flash).

Stock calls `enableEdgeToEdge()` and nothing else. Ours adds
`applyStatusBarContrast(night, caller)` (called from `onCreate`/`onResume`/
`onWindowFocusChanged`/`onConfigurationChanged`) plus
`setStatusBarDark(isDark)` — invoked from Rust over JNI with the
frontend's RESOLVED theme (see `set_status_bar_style` in the app's `lib.rs`).
The frontend's choice is **persisted in `lastJsNight`** and `resolvedNight()`
(= `lastJsNight` when set, else the system state): returning from the
background re-applies the APP theme, not the system one — otherwise a light
app on a dark system (or vice versa) gets invisible icons every time the
user re-enters (the system resets the bars appearance while app is away).
Why both paths exist: the activity declares `uiMode` in `configChanges`, so
a live system flip fires neither recreate nor `onResume` (flags would go
stale); and the app has its own theme override (toggle/D key/localStorage),
so system-following flags alone paint invisible icons when app and system
disagree. `setStatusBarDark` hops to the UI thread internally, so the Rust
caller thread doesn't matter; the proguard keep rule preserves its name for
release (R8).

**Porting notes:** template files, not CLI source — overlay them from the old
vendor onto the new stock (same as the iOS `project.yml`). If upstream adds an
equivalent, drop MOD-4.

## MOD-5 — iOS "Build Rust Code" phase prefers rustup's cargo

**Where:** `templates/mobile/ios/project.yml` (the `- script:` phase).

Stock exports `PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"`
and runs `cargo`. On hosts where `~/.cargo/bin` has no cargo proxy (Homebrew
rust installed separately), the phase falls back to a Homebrew-only cargo that
**lacks the iOS/Android cross targets** — build dies with `can't find crate
for std` on `aarch64-apple-ios-sim`. Ours prepends the rustup proxy when
present (`$HOME/.cargo/bin` or `/opt/homebrew/opt/rustup/bin`) so the right
cargo runs.

**Also ours (same phase):** the LIB source path is a `lib*.a` glob, NOT a
hardcoded crate name — the crate's `[lib] name` changes with every rebrand and
the old lowercase hardcode only worked on case-insensitive APFS. The linked
name is the CLI constant `libapp.a` (`LIB_OUTPUT_FILE_NAME`, `mobile/ios/mod.rs`),
never the crate's.

**Porting notes:** the phase is embedded in the CLI binary (`include_dir!`) —
after editing the template, REBUILD it (`make install-tauri-cli`), clear
DerivedData, then re-init (`scripts/Xcode/apple-xcode.sh`). If upstream carries
the rustup fallback, drop MOD-5.

## Templates (not stock)

Unified `project.yml` (single `_Apple` target, debug/release configs — the 2.12
rebase retired the old `hotreload` config; `debug` is the dev/HMR flow,
Terminal-opening dev phase, `APPLE_DEVELOPMENT_TEAM` consumed at init),
`apple.xcconfig`, `ExportOptions-{appstore,developerid}.plist`,
`{{app.name}}_Apple/` entitlements, and the **neutral placeholder** icon sets:
`templates/mobile/ios/Assets.xcassets/AppIcon.appiconset/**` (21 PNGs) and the
Android `res/**/ic_launcher*` PNGs (16) — flat gray, deliberately brand-less.
Real icons NEVER live in the templates: after every `tauri ios|android init`,
`scripts/mobile/mobile-icons-regen.sh` (called by `apple-xcode.sh` and
`android-autogen.sh`) regenerates `icons/` + `gen/apple` + `gen/android` from
`branding.json` `icons.master` (`branding/icon-1024.png`) via `tauri icon`, then
composes the iOS 1024 marketing trio (light/dark/tinted) that this CLI version
does not generate. A rebase therefore overlays the OLD neutral placeholders as-is
— never any brand-specific artwork.

## Desktop runtime — OUT OF SCOPE (protected, never touched by a rebase)

The CLI regen ONLY produces the mobile/Xcode layers (`gen/apple`,
`gen/android`) and the generated `icons/` set. The DESKTOP runtime — where the
native feel actually lives — has NO regen layer and must NEVER be modified by
this skill or by an upgrade:

- `src-tauri/src/lib.rs` (traffic lights + snap + `TRAFFIC_LIGHTS_X`, vibrancy
  `window_effects_set`, Linux resize edges + frameless setup, Windows decorum
  `DWMWCP_ROUND`, `prevent-default` flags, status-bar JNI) — plain repo source
- `src-tauri/tauri.{macos,windows,linux}.conf.json` + `tauri.conf.json` guards
- `apps/web/src/components/layout/*` (`header.tsx`, `window-controls.tsx`,
  `native-chrome.ts`), `assets`/`globals.css` window layer
- `src-tauri/Assets.xcassets` + `src-tauri/build.rs` (macOS icon compile)

**Rebase checklist addition:** after re-applying the MODs and regenerating
`gen/`, verify `git status` shows NO diffs outside
`src-tauri/vendor/**`, `src-tauri/gen/**` (ignored), `src-tauri/icons/**`
(regenerated) and the files this skill intentionally bumps (pins/docs). Any
diff in the desktop list above is a regression — revert it before shipping.

Ported upstream into our `project.yml`: `{{ shell-escape tauri-binary }}` +
quoted vars on the `xcode-script` line (spaces-in-paths fix). NOT ported
(already covered): `excludes: ["**/*.a"]` — our template omits `Externals`
from sources entirely.

## Rebase checklist (next CLI upgrade)

1. Download the stock crate of the target version; extract as a sibling.
2. Re-apply MOD-1/2/3 semantically (see `SKILL.md` §3).
3. Overlay `templates/mobile/ios/` + `templates/mobile/android/` from the old
   vendor (project.yml, xcconfig, entitlements, and the NEUTRAL placeholder
   icon sets — keep them brand-less); `diff` stock-vs-ours `project.yml` for
   portable upstream fixes. MOD-4 (`MainActivity.kt`) and MOD-5 (`project.yml`
   rustup cargo phase) are part of the same overlay.
3b. Icon flow note: post-init icon regeneration lives in `scripts/mobile/`
    (outside the CLI) — after a rebase, verify `apple-xcode.sh` /
    `android-autogen.sh` still call `mobile-icons-regen.sh` and that a fresh
    `gen/` carries the user's `branding/icon-1024.png` (spot-check the iOS
    AppIcon-1024 PNG hash against the composite reference).
4. Delete the old vendor dir. Update pins: `package.json` (`@tauri-apps/cli`),
   `scripts/Xcode/apple-xcode.sh` (`TMPL_DIR`, `CARGO_TAURI`), `Makefile`
   `install-tauri-cli`, `scripts/README.md`.
5. `pnpm install`, `make install-tauri-cli`, verify `cargo-tauri --version` +
   `cargo-mobile2` in the vendor `Cargo.lock`.
5b. Vendor tests must be green: `cargo test --lib` in the vendor tree (119
    tests). The `helpers::pbxproj` tests need the upstream fixtures that
    crates.io omits — `tests/fixtures/pbxproj/project.pbxproj` +
    `snapshots/tauri_cli__helpers__pbxproj__tests__*.snap` (fetch from the
    `tauri-cli-v<ver>` git tag). Keep them when re-vendoring, and re-align the
    MOD-1 assertion in `src/mobile/mod.rs` if upstream changes
    `fetch_options` semantics again.
6. Update `docs/en|es/mobile.md`, `README.md`, `scripts/README.md` (EN/ES
   parity). Run full checks.