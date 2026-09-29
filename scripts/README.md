# Scripts — Multi-platform helpers

> 🌐 **Language:** **English** | [Español](README.es.md)

Repo automation: OS build shells, Xcode tooling, CLI patching. The `Makefile`
(at the repo root) is the source of truth for daily dev/build commands; the
files here implement them.

- [Inventory](#-inventory)
- [Build per OS](#-build-per-os)
- [Xcode unified target](#-xcode-unified-ios--macos-in-one-target)
- [Signing / DEVELOPMENT_TEAM](#-signing--development_team-auto-injection)
- [CLI](#-cli)
- [Hot reload (full IPC)](#-hot-reload-full-ipc--tauri-ios-dev)

Related: [`docs/en/scripts.md`](../../docs/en/scripts.md) (flags reference),
[`docs/en/mobile.md`](../../docs/en/mobile.md) (iOS/Android flows),
[`references/mods.md`](../../.claude/skills/tauri-cli-rebase/references/mods.md) (CLI vendor modifications).

## 📋 Inventory

| Script | Purpose |
|---|---|
| Skill `.claude/skills/linux-build/` | **Linux bundles over SSH** (the only Linux path: Docker box on macOS/Windows). SSH-only — rsync sync without `.git` (no clone), never manages the container. Script: `.claude/skills/linux-build/scripts/linux-build.sh`; profiles `--release`/`--debug` (debug = `--no-bundle`), extras `--dev`, `--run`, `--verify` (assistant shot/ocr), `--fetch`, `--logs`, `--stop` |
| `scripts/build-windows.sh` | Windows x64 cross-compile from macOS/Linux (`cargo-xwin` + NSIS) |
| `scripts/Xcode/apple-xcode.sh` | Regenerates `src-tauri/gen/apple` (vendored CLI init, branding-aware); `--build` also compiles iOS sim + macOS host |
| `scripts/Android/android-autogen.sh` | Regenerates `src-tauri/gen/android` (vendored CLI init, branding-aware, Linux/Win/macOS + `.cmd`); `--build` also compiles the debug APK |
| Skill `.claude/skills/tauri-cli-rebase/` | Rebase the vendored `tauri-cli` — re-applies the 5 local modifications (MOD-1..MOD-5) semantically onto a new stock version (`.claude/skills/tauri-cli-rebase/references/mods.md`) |
| `scripts/Xcode/xcode-dev.command` | Unified dev helper — `server` (visible Vite `:1420` + HMR, default) or `parent` (`tauri ios dev --open` full-IPC) |
| `scripts/install-skills.sh` (+ `.cmd`) | Installs all project agent skills; `.cmd` is the Windows launcher (runs the `.sh` via Git Bash) |
| `scripts/branding-update.sh` | `make rebrand` — propagates `branding.json` identity everywhere (configs, Cargo/package, index.html title/og, favicon from the master) |
| `scripts/check-docs-parity.sh` / `scripts/check-agents-anchors.sh` | `make check-docs` guards: EN/ES mirror (files, structure, router, i18n interpolation) + `file:line` anchor drift |
| `scripts/mobile/icon-composite.swift` / `icon-flat.swift` | Compose the iOS 1024 marketing icons from the master / generate neutral template placeholders |

Supporting build inputs (not scripts, but part of the system):

- `src-tauri/build.rs` embeds public env vars (`EMBED_KEYS`) and aligns Android 16 KB pages; the macOS app icon ships from `bundle.icon` (`icons/icon.icns`).
- `rust-toolchain.toml` pins `stable` + `aarch64-apple-ios*` and Android targets for `cargo check --target ...` and mobile builds.
- `src-tauri/Assets.xcassets` + `Info.plist` + `tauri.macos.conf.json` (`titleBarStyle Overlay`, `transparent`) replicate the generic macOS/Xcode layer.

## 🔨 Build per OS

| Script | Does |
|---|---|
| `.claude/skills/linux-build/scripts/linux-build.sh` | Linux bundles plus compile/launch/verify. **SSH-only** (`--remote [HOST]`); `--release`/`--debug` (debug = `--no-bundle`), `--verify` (assistant windows/shot/ocr + PNG to `dist-linux/`), extras `--dev`, `--run`, `--fetch`, `--logs`, `--stop`. Full flags: `docs/en/scripts.md`. |
| `scripts/build-windows.sh` | Windows x64 cross-compile from macOS/Linux (`cargo-xwin` + NSIS). One-time setup: `brew install llvm lld makensis`, `cargo install cargo-xwin --locked`, `rustup target add x86_64-pc-windows-msvc`. MSI/WiX needs a Windows host. |

## 📱 Xcode unified (iOS + macOS in ONE target)

The source of truth for the Xcode project is the template:

    src-tauri/vendor/tauri-cli-2.12.0/templates/mobile/ios/

`src-tauri/gen/apple` regenerates **entirely** from it (gitignored, does NOT persist):

    scripts/Xcode/apple-xcode.sh             # regenerate (vendored CLI init)
    scripts/Xcode/apple-xcode.sh --build     # plus iOS sim (via CLI) + macOS host

Android is the same idea, mirrored under `scripts/Android/`:

    scripts/Android/android-autogen.sh       # regenerate gen/android (branding-aware)
    scripts/Android/android-autogen.sh --build   # + debug APK (aarch64)

Rule: ALWAYS edit the template (`project.yml`, `apple.xcconfig`, entitlements, `Assets.xcassets`),
NEVER the generated `.xcodeproj` or its Info.plist.

- Single target `tauri-react-template_Apple`, iOS + macOS via `apple.xcconfig`
  (`SUPPORTED_PLATFORMS = macosx iphoneos iphonesimulator`) with `PLATFORM_NAME`
  branches in the "Build Rust Code" phase.
- **Two build configs** (XcodeGen `configs:`): `debug`, `release`. The old
  `hotreload` config was retired in the tauri-cli 2.12 rebase — the `debug`
  config plays that role now (it consumes the Vite dev server). The phase
  ("Build Rust Code") picks the pipeline:
  - macOS `release` → `pnpm build` + `cargo build --lib --release --features
    tauri/custom-protocol` (frontend embedded).
  - macOS `debug` → `cargo build --lib` WITHOUT custom-protocol (loads
    `devUrl` :1420); when Vite is not already serving, the phase opens
    `scripts/Xcode/xcode-dev.command` in a Terminal. Stages
    `Externals/macosx/<config>/`.
  - iOS `release` → `pnpm build` first, then `xcode-script --configuration
    release` (the CLI applies `custom-protocol` → standalone).
  - iOS `debug` → **dev/HMR flow**: opens `xcode-dev.command` when Vite is
    down, then `xcode-script --configuration debug`; the vendored CLI's
    fallback (MOD-1, see `.claude/skills/tauri-cli-rebase/references/mods.md`)
    gives dev semantics — loads `devUrl`, HMR through Vite.
- Foreground Terminal without AppleScript: the phase uses `open -a Terminal
  <script>.command` (LaunchServices → no TCC permissions, `open` never blocks
  the phase). One unified runscript in the repo (survives regen):
  `scripts/Xcode/xcode-dev.command` — `server` (Vite :1420 + HMR, default,
  used by the phase) or `parent` (`tauri ios dev --open`, with `--host <LAN>`
  when there is a network).
- Double-Vite warning: a parent `tauri ios dev` starts Vite (its
  `beforeDevCommand`) and fails if `:1420` is already taken
  ("beforeDevCommand terminated with a non-zero..."). Don't leave a previous
  Vite running before a dev build.
- `xcode-script` (cargo-mobile) stages `Externals/<arch>/<PROFILE>` (`debug`
  for anything != release); the phase also copies that lib to the per-SDK path
  the target links (`Externals/<PLATFORM_NAME>/<CONFIGURATION>`), so the fresh
  lib always wins.
- Closing the dev flow (⌘. / stop app) does **not** stop a `tauri ios dev
  --open` parent: it keeps sleeping (~24h) with its options IPC server and
  Vite on `:1420`. To free ports: close the Terminal window (⌘W) or Ctrl+C →
  SIGHUP kills parent and Vite. Dev builds compile fast: incremental debug
  Rust + Vite HMR (only the first from-scratch build is long).
- So the Xcode "Run" button means: `release` = full standalone app
  (optimized); `debug` = the dev/HMR flow (Vite + incremental Rust; opens
  Terminal when the dev server is down).
- Scheme `tauri-react-template_Apple` for Xcode/macOS. Scheme
  `tauri-react-template_iOS` (shim building the `_Apple` target) +
  `_iOS/Info.plist`: required by cargo-mobile2, which uses `config.scheme()`
  = `<app>_iOS` for `tauri ios dev|build`.
- Static per-platform entitlements (ios.entitlements / macos.entitlements) via
  `CODE_SIGN_ENTITLEMENTS[sdk=...]`.

## 🔏 Signing / DEVELOPMENT_TEAM (auto-injection)

The template **never hardcodes the Team ID**: `scripts/Xcode/apple-xcode.sh`
reads it and exports `APPLE_DEVELOPMENT_TEAM` — the variable the vendored CLI
consumes at `ios init` to fill `{{apple.development-team}}` in the generated
project. Priority:

1. env `DEVELOPMENT_TEAM`
2. file `scripts/.team-id` (gitignored, persists across regens)
3. none → line omitted, pick manually in Xcode

When a team is needed: ALWAYS for the `tauri ios dev|build` pipeline
(cargo-mobile goes through device + archive/export — modern Xcode lists sims
via `devicectl` as devices). Not needed for direct Xcode builds on **sim**
(ad-hoc `-`/Manual via `CODE_SIGN_STYLE[sdk=iphonesimulator*]`) or macOS.

How (pick ONE):

```bash
# (1) one-shot: single generation with team
DEVELOPMENT_TEAM=ABCDE12345 scripts/Xcode/apple-xcode.sh

# (2) durable: write the team and regenerate (recommended)
echo ABCDE12345 > scripts/.team-id
scripts/Xcode/apple-xcode.sh

# (3) manual: no config, regenerate and pick in Xcode →
#     Target → Signing & Capabilities. NOTE: manual picks are lost on
#     regen (gen/ rebuilds fully) → use .team-id to persist.
```

Your Team ID is in Xcode → Target → Signing & Capabilities (or Apple ID →
Membership Details). Verify Xcode received it:

```bash
xcodebuild -project src-tauri/gen/apple/tauri-react-template.xcodeproj \
  -scheme tauri-react-template_Apple -configuration Debug \
  -showBuildSettings | grep DEVELOPMENT_TEAM        # → "DEVELOPMENT_TEAM = ABCDE12345"
```

Without a team configured the grep must return nothing (manual pick).

## 🧰 CLI

The `cargo-tauri` for iOS flows is built from the vendored
`tauri-cli 2.12.0` (stock + 3 local tweaks: standalone fallback, `_Apple`
target — see `.claude/skills/tauri-cli-rebase/references/mods.md`):

```bash
make install-tauri-cli   # builds vendor/tauri-cli → ~/.cargo/bin/cargo-tauri
cargo tauri ios dev "iPhone 18 Pro"
```

For one-off stock operations (no local tweaks needed):

```bash
pnpm dlx @tauri-apps/cli@2.12.0 ios build --target aarch64-sim --debug
pnpm dlx @tauri-apps/cli@2.12.0 android build --debug --target aarch64
```

### Hot reload (full IPC) — `tauri ios dev`

The `apps/web` dev frontend listens on ALL interfaces (`host: true` in
`vite.config.ts`): `tauri ios dev` negotiates devUrl on a host LAN IP and
must reach the server on that IP.

- **Physical iPhone**: `tauri ios dev --host 192.168.x.x "iPhone 18 Pro"` →
  build+archive+export+install via xcodebuild/devicectl + Rust hot reload
  (CLI watcher). The project's `debug` config uses the same shape: if the
  parent is not alive, the phase opens it in Terminal with `--host <LAN>`
  (hence the Vite `host: true` fix).
- **Simulator**: since Xcode 26, `devicectl` lists sims as devices and
  cargo-mobile tried `devicectl device install app` on a sim → unsupported
  ("Install Application is not supported"). For SIM: `tauri ios dev --open`
  (keeps the parent alive: IPC + options) and run the `debug` config of
  the `tauri-react-template_Apple` scheme in Xcode on the sim → each ⌘R
  compiles via `xcode-script` with the parent's options and the frontend does
  HMR via Vite. Sim Rust auto-reload stays limited by upstream CLI; `debug`
  keeps the standalone no-CLI path. (Officially fixed for device listing in
  `cargo-mobile2 0.22.5`; see `.claude/skills/tauri-cli-rebase/references/mods.md`.)
