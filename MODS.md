# MODS.MD — local modifications in this vendored `tauri-cli` copy

> Base: stock `tauri-cli 2.12.0` from crates.io (immutable, checksum-verified).
> Everything below is OUR diff on top of it. The rebase that produced it is
> automated in `scripts/patch-tauri-cli.sh` (same repo) — if that script fails
> on a new upstream version, update the script AND this file.
>
> Why a full vendor copy instead of `.patch` files: `make install-tauri-cli`
> must build offline from repo contents only, and the sources stay
> grep-able/readable in place (see AGENTS.md: evidence-driven workflow).
> What was already dropped: the `[patch.crates-io] cargo-mobile2` section +
> `cargo-mobile2-0.22.4/` copy — 2.12.0 requires `cargo-mobile2 ^0.22.5`,
> which contains the Xcode 27 fix upstream (`ee65fb1`).

## MOD-1 — `fallback_options()` for standalone IDE builds
## (`src/mobile/mod.rs`: `fallback_options` at ~:561, fallback in `fetch_options` at ~:584-607)
##
## Stock behavior: `xcode-script` (the Xcode build phase) asks the parent
## `tauri ios|android dev|build` process for options over a local WebSocket
## handshake. Opening Xcode directly and hitting Build means no parent ever
## ran, so the options-server file is missing — stock fails the build.
##
## Our behavior: missing/unparseable server file, dead connection, or failed
## `options` request all fall back to `fallback_options()`, which follows the
## IDE-provided `CONFIGURATION` env var: `release` → production semantics
## (`tauri/custom-protocol`, embeds `frontendDist`), anything else → dev
## semantics (loads `build.devUrl` with hot reload). This is what makes the
## `debug`/`release` Xcode configs work standalone (see `scripts/README.md`).
##
## Porting notes: the stock function this hooks into was `read_options` in
## 2.11.4 and is `fetch_options` in 2.12.0 (restructured around
## `OptionsServerInfo { addr, token }`). On upgrade, re-read `fetch_options`
## and re-apply the three `let Ok(...) else return fallback` + final
## `unwrap_or_else(fallback_options)` touch points. The now-unused
## `not_running` closure must go with them (else a warning).

## MOD-2 — unified `_Apple` target lookup
## (`src/mobile/ios/mod.rs:570,637`, `src/mobile/ios/project.rs:182`)
##
## Stock looks up the Xcode scheme/target by the `_iOS` suffix comment and
## creates a `*_iOS` dir. Our Xcode project is ONE unified target
## `tauri-react-template_Apple` (iOS + macOS, see `apple.xcconfig`), so both
## lookups use `_Apple` and `project.rs` creates `*_Apple`.
##
## Porting notes: trivial string change, but verify upstream didn't add more
## `_iOS` lookups (`grep -n _iOS src/mobile/ios/` must print nothing after).

## MOD-3 — simplified `{{app.name}}` path replacement
## (`src/mobile/ios/project.rs:142`)
##
## Stock walks path components and replaces only the FIRST one containing
## `{{app.name}}`. Ours replaces on the whole path string (covers nested
## template dirs). The now-unused `ffi::OsString` / `path::{Component,
## PathBuf}` imports go away with it (else warnings).
##
## Porting notes: if upstream simplifies this themselves, drop MOD-3.

## Templates (`templates/mobile/ios/` + 3 Android icon files)
##
## NOT stock: unified `project.yml` (single `_Apple` target, debug / hotreload
## / release configs, Terminal-opening hotreload phase, `__TAURI_DEVELOPMENT_TEAM__`
## sentinel), `apple.xcconfig`, `ExportOptions-{appstore,developerid}.plist`,
## `{{app.name}}_Apple/` entitlements, our `Assets.xcassets` icons, and the
## Android `ic_launcher_*` files.
##
## Ported from upstream 2.12.0 into our `project.yml`: `{{ shell-escape
## tauri-binary }}` + quoted vars on the `xcode-script` line (upstream fix for
## spaces in paths; the `shell-escape` helper is registered in
## `src/mobile/init.rs`). NOT ported (already covered): `excludes:
## ["**/*.a"]` on `Externals` — our template omits `Externals` from sources
## entirely, which avoids the same "Multiple commands produce libapp.a" bug.

## Rebase checklist (next CLI upgrade)

1. `curl https://crates.io/api/v1/crates/tauri-cli/<V>/download`, extract to
   `src-tauri/vendor/tauri-cli-<V>/` next to (not over) the current one.
2. Run `scripts/patch-tauri-cli.sh <new-dir>`; fix whatever it rejects.
3. Overlay `templates/mobile/ios/` + the 3 Android icon files from the old
   vendor copy; then `diff` stock-vs-ours `project.yml` for portable upstream
   fixes (this round's example: `excludes`, `shell-escape`).
4. Delete the old vendor dir. Update pins: `package.json`
   (`@tauri-apps/cli`), `scripts/Xcode/apple-xcode.sh` (`TPL`, `TAURI_CLI`),
   `scripts/Xcode/xcode-dev-parent.command`, `scripts/README.md`.
5. `pnpm install`, `make install-tauri-cli`, verify `cargo-tauri --version`
   and `cargo-mobile2` in the vendor `Cargo.lock`.
6. Update `docs/en|es/mobile.md` + `README.md` + this file's paths, keeping
   EN/ES parity. Run the full checks
   (`cargo check/fmt/clippy`, `pnpm typecheck/lint/test/build`).
