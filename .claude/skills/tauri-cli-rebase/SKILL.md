---
name: Tauri CLI Rebase
description: Rebase the vendored tauri-cli copy (src-tauri/vendor/tauri-cli-*) onto a NEW stock tauri-cli release by re-applying the 5 local modifications (MOD-1 fallback_options, MOD-2 unified _Apple target, MOD-3 simplified app.name path replace, MOD-4 Android status-bar/theme overlays, MOD-5 rustup cargo phase), then update references/mods.md, pins and docs. Use when upgrading tauri-cli or its vendored copy, when a new tauri/tauri-cli version is released, or when the vendored CLI is out of date.
metadata:
  opencode/autoinvoke: false
---

# Tauri CLI Rebase

Rebase the **vendored** `tauri-cli` (this repo keeps a full stock copy at
`src-tauri/vendor/tauri-cli-*/` so builds work offline) onto a **new upstream
version**. The local modifications — documented in `references/mods.md` — must be
**re-applied semantically**, not by blind text find/replace: the stock code
owner -v2.0 re-arranges these functions between releases, so a rigid script
that searches for an exact byte anchor fails the moment upstream reshapes it.

> **Prime directive:** these tweaks are LOAD-BEARING for the mobile/build
> flows (standalone IDE builds, the unified `_Apple` iOS+macOS target, nested
> template path expansion). Remove or mis-apply any of them and iOS/macOS
> builds degrade or break. When in doubt, STOP and ask — never half-patch.

---

## 0. Preflight & decision gate

Before touching anything, confirm the actual situation:

- Read `references/mods.md` — it is the spec for the 5 MODs and the rebase check­list.
- Read `TEMPLATE_VERSION` and the current vendored dir name
  `src-tauri/vendor/tauri-cli-*`.
- Determine the target stock version: the latest tauri-cli / tauri version the
  repo wants to track (from `package.json` `@tauri-apps/cli`, `Cargo.toml`
  `tauri`, or an explicit user request).

**STOP and ask** if:
- You cannot tell which version the repo currently pins vs the target.
- The vendored dir is missing or corrupt (a full stock copy must exist first).
- You are not in a git working tree you can revert (the update should create
  its own commits).

If the target == current pinned version, report "already current" and stop.

---

## 1. Snapshot & isolation

Make the rebase reversible and isolated — never edit the existing vendor
in place and "hope".

1. `git status --porcelain` → clean, or the changes are only yours. Do NOT run
   on a dirty tree without recording the pre-state.
2. Record `git rev-parse HEAD` as `$BASE`.
3. Fetch the new stock source (choose ONE, prefer crates.io as the immutable
   source):
   ```bash
   curl -fsSL "https://crates.io/api/v1/crates/tauri-cli/$NEW/download" -o /tmp/tauri-cli-$NEW.crate
   ```
   If the user instead points at an existing extracted stock tree, use that.
4. The OLD vendor stays untouched as the comparison base; the NEW tree is a
   sibling, never a replacement of the old (until verified).

---

## 2. Extract & place the new stock

1. Extract the new crate alongside the old one:
   ```bash
   mkdir -p src-tauri/vendor/tauri-cli-$NEW
   tar -xzf /tmp/tauri-cli-$NEW.crate -C src-tauri/vendor/tauri-cli-$NEW --strip-components=1
   # it extracts to tauri-cli-<V>/; strip to the vendor dir
   ```
   The result must look like a tauri-cli source tree: `Cargo.toml` + `src/`
   (+ `templates/`, `config.schema.json`, mobile templates).
2. **Keep the OLD vendor dir** in place until the new one is verified — the old
   one is what the current build/toolchain still depends on.

---

## 3. Re-apply the 5 MODs — SEMANTICALLY (this is the core)

For each of the local modifications in `references/mods.md`, do the following — do NOT
paste the old block's exact text and search for it; that is the failed approach
of the old script.

### MOD-1 — `fallback_options()` for standalone IDE builds
**Intent:** when the IDE (Xcode) builds without a `tauri ios|android dev|build`
parent, the options-server file is missing → stock `fetch_options` fails. Add
`fallback_options()` and make `fetch_options` return it instead of erroring,
driven by the IDE's `CONFIGURATION` env var (`release` → `tauri/custom-protocol`,
anything else → dev semantics).

**How to apply on new stock:**
1. `grep -n "fn fetch_options\|fn read_options\|OptionsServerInfo" \
   src/mobile/mod.rs` (name may have changed across versions).
2. Locate the block that reads the server file and errors on failure.
3. Insert a `fallback_options() -> CliOptions` fn (mirror the semantics; the
   exact impl is in the OLD vendor `src/mobile/mod.rs`).
4. Replace the hard error returns with `return Ok(fallback_options());` /
   final `Ok(options.unwrap_or_else(fallback_options))`.
5. If a now-unused `not_running` closure remains, drop it (else a warning).

### MOD-2 — unified `_Apple` target lookup
**Intent:** stock looks up the Xcode scheme/target by the `_iOS` suffix and
creates a `*_iOS` dir; this repo's Xcode project is ONE unified target named
`<app>_Apple` (iOS + macOS). Both lookups must use `_Apple` and `project.rs`
must create `*_Apple`.

**How to apply:**
1. `grep -n "_iOS" src/mobile/ios/mod.rs src/mobile/ios/project.rs`
2. Confirm stock still maps the scheme/target/dir to a literal `_iOS` suffix.
3. Replace `_iOS` → `_Apple` in those lookup/replace sites (watch for the
   `{}_iOS` positional format).
4. Verify afterwards: `grep -n _iOS src/mobile/ios/` prints NOTHING
   (`grep` exit code 1) — that is the success check from `references/mods.md`.

### MOD-3 — simplified `{{app.name}}` path replacement
**Intent:** stock walks `path.components()` and replaces only the FIRST
component containing `{{app.name}}`; ours replaces on the whole path string
(so nested template dirs expand too).

**How to apply:**
1. `grep -n "path.components()\|{{app.name}}" src/mobile/ios/project.rs`
2. Find the loop that iterates components looking for `{{app.name}}`.
3. Replace with a whole-string replace and `dest.join(path)`.
4. Prune now-unused imports (`ffi::OsString`, `path::Component`, `PathBuf`)
   that the simplification removes.

---

## 4. Overlay the durable templates

The tweaks above touch the CLI *source*. Separately, the repo carries
customized **mobile templates** + icons that ship in the vendored tree:
- `templates/mobile/ios/` (unified `project.yml`, `apple.xcconfig`,
  `ExportOptions-{appstore,developerid}.plist`, `{{app.name}}_Apple/`
  entitlements, `Assets.xcassets`).
- The 3 Android icons (`ic_launcher_*`).

Copy the OLD vendor's customized files onto the NEW stock (the new stock only
ships vanilla versions), then `diff` the old `project.yml` against stock to
catch any portable upstream fixes worth merging (see `references/mods.md` "Rebase
checklist" step 3).

---

## 5. Verify & gate (green before you call it done)

Run the gates and the negative checks that PROVE the tweaks landed:

```bash
cargo check --manifest-path src-tauri/Cargo.toml
cargo test --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
grep -n _iOS src-tauri/vendor/tauri-cli-$NEW/src/mobile/ios/   # MUST print nothing (exit 1)
```

`cargo check/test/fmt/clippy` here compile the **host** app; the vendored CLI
built through `make install-tauri-cli` is what exercises the tweaks' code.
Also run the Linux box checks if the vendored source is host-independent in a
way that only a Linux target-check catches (see `docs/en/testing.md`).

A RED gate blocks the bump + the "done" report — no exceptions.

---

## 6. Update pins, references/mods.md, docs; remove old vendor

After the new vendor passes gates:

1. **Replace** the old vendor dir with the new:
   ```bash
   rm -rf src-tauri/vendor/tauri-cli-$OLD
   mv src-tauri/vendor/tauri-cli-$NEW $OLD 2>/dev/null || true
   ```
   (i.e. the active vendored dir is the new one; keep the `tauri-cli-<V>` name
    of the NEW version, and remove the OLD one.)
2. **Update the version pins** (search the repo for the old version string):
   - `package.json` → `@tauri-apps/cli` (npm dev dependency).
   - `scripts/Xcode/apple-xcode.sh` → `TMPL_DIR` (the vendored templates path) + `CARGO_TAURI`.
   - `.claude/skills/tauri-cli-rebase/` if it references a version.
   - `Makefile` → any `tauri-cli-<V>` in `install-tauri-cli`.
   - `src-tauri/Cargo.toml` → `tauri` / `tauri-build` if bumped.
3. **PROTECT the desktop runtime (hard gate):** the rebase only legitimately
   touches `src-tauri/vendor/**`, `src-tauri/icons/**` (regenerated) and pins
  /docs. `git status --short` must show NO diffs in the desktop source list
   (`src-tauri/src/lib.rs`, `tauri.{macos,windows,linux}.conf.json`,
   `apps/web/src/components/layout/*`, `Assets.xcassets`, `build.rs`) — see
   "Desktop runtime — OUT OF SCOPE" in `references/mods.md`. Any diff there is
   a regression: revert before continuing.
3. **Update `references/mods.md`**: reflect the new base version, update the porting notes /
   line hints / `BASES` + any diff noted in the overlay step. Keep the `MOD-1/2/3`
   intents intact.
4. **Bump `TEMPLATE_VERSION`** marker? Only if the template's own version
   aligns with the CLI bump — else leave it; verify with the user.
5. Update docs (`docs/en|es/mobile.md`, `README.md`, `scripts/README.md`) with
   any changed paths/versions, keeping EN/ES parity.
6. Remove the downloaded `.crate` from `/tmp`.

---

## 7. Build the vendored CLI (offline) & smoke test

```bash
make install-tauri-cli   # builds the vendored cargo-tauri -> ~/.cargo/bin
cargo-tauri --version    # must show the NEW version + the tweaks present
```
Then a quick iOS scaffold smoke test is ideal but optional:
`cargo tauri ios init` regenerating `gen/apple` and confirming the customized
phase survives (see the `scripts/Xcode/xcode-dev.command` path in the generated
`project.pbxproj`). If a real device/simulator is available, build.

---

## 8. Report & rollback

Report: old version → new version; each of MOD-1/2/3 applied (or skipped, with
reason); templates overlaid; pins/docs updated; gates green. Provide rollback:
`git reset --hard $BASE` (the snapshot from §1) restores everything,
including the untouched old vendor dir if you kept it until §6.

---

## 9. Idempotency & edge cases

- **Already current** → report and stop.
- **Anchors moved** → this is the skill's whole reason to exist: re-derive the
  semantic site, mirror the intent, don't force the old bytes.
- **Stock removed a feature** (e.g. `fetch_options` renamed) → update `references/mods.md`'s
  "Porting notes" and the intent mapping; do NOT silently drop a tweak.
- **Partial/interrupted** → rely on per-step commits + `$BASE`; don't continue
  a half-applied vendor.
- **Offline** → you cannot fetch the crate: STOP, use a user-supplied tree.

---

## References

- `references/mods.md` — the durable spec of MOD-1/2/3 + the rebase checklist
  (durable spec, root `MODS.md` was removed — no duplication).
- `references/mods.md` — source of truth for "why these tweaks exist".
- `docs/en/scripts.md` + `docs/es/scripts.md` — build & CLI flow.
- Root `TEMPLATE_VERSION` — template release marker.