# Local modifications in the vendored tauri-cli (durable spec for the skill)

> Mirror of root `MODS.md` for this skill's base directory. When you edit the
> skill, keep this in sync with root `MODS.md`. Base: stock `tauri-cli` from
> crates.io (immutable). See `SKILL.md` for the full rebase procedure.

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

## Templates (not stock)

Unified `project.yml` (single `_Apple` target, debug/hotreload/release configs,
Terminal-opening hotreload phase, `__TAURI_DEVELOPMENT_TEAM__` sentinel),
`apple.xcconfig`, `ExportOptions-{appstore,developerid}.plist`,
`{{app.name}}_Apple/` entitlements, `Assets.xcassets` icons, and the Android
`ic_launcher_*` files.

Ported upstream into our `project.yml`: `{{ shell-escape tauri-binary }}` +
quoted vars on the `xcode-script` line (spaces-in-paths fix). NOT ported
(already covered): `excludes: ["**/*.a"]` — our template omits `Externals`
from sources entirely.

## Rebase checklist (next CLI upgrade)

1. Download the stock crate of the target version; extract as a sibling.
2. Re-apply MOD-1/2/3 semantically (see `SKILL.md` §3).
3. Overlay `templates/mobile/ios/` + the 3 Android icon files from the old
   vendor; `diff` stock-vs-ours `project.yml` for portable upstream fixes.
4. Delete the old vendor dir. Update pins: `package.json` (`@tauri-apps/cli`),
   `scripts/Xcode/apple-xcode.sh` (`TPL`, `TAURI_CLI`), `Makefile`
   `install-tauri-cli`, `scripts/README.md`.
5. `pnpm install`, `make install-tauri-cli`, verify `cargo-tauri --version` +
   `cargo-mobile2` in the vendor `Cargo.lock`.
6. Update `docs/en|es/mobile.md`, `README.md`, `scripts/README.md` (EN/ES
   parity). Run full checks.