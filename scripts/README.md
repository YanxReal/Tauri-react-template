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
- [Without Xcode](#-without-xcode-linuxwindowsmacos-without-xcode)

Related: [`docs/en/scripts.md`](../../docs/en/scripts.md) (flags reference),
[`docs/en/mobile.md`](../../docs/en/mobile.md) (iOS/Android flows),
[`MODS.md`](../../MODS.md) (CLI vendor modifications).

## 📋 Inventory

| Script | Purpose |
|---|---|
| `scripts/build-linux.sh` | Linux bundles; compile + run on a Linux box over SSH (`--remote`) or locally (`--native`). Profiles `--release`/`--debug`; `--dev`, `--run`, `--fetch`, `--logs`, `--stop` |
| `scripts/build-windows.sh` | Windows x64 cross-compile from macOS/Linux (`cargo-xwin` + NSIS) |
| `scripts/box-shot.sh` | Screenshot the Ubuntu-arm-docker box over VNC (`VNC_PASSWORD`, default `/tmp/box-shot.png`) |
| `scripts/patch-tauri-cli.sh` | Applies the 3 local tweaks onto a stock `tauri-cli` copy (refuses unknown versions) |
| `scripts/Xcode/apple-xcode.sh` | Regenerates `src-tauri/gen/apple` (xcodegen); `--build` also compiles iOS sim + macOS host |
| `scripts/Xcode/xcode-dev-parent.command` | Double-clickable `tauri ios dev --open` launcher (Terminal) |
| `apps/web/scripts/xcode/xcode-dev-server.command` | Double-clickable Vite dev server (`:1420` + HMR) |

Supporting build inputs (not scripts, but part of the system):

- `src-tauri/build.rs` compiles `Assets.xcassets` via `actool` only when Xcode exists; without Xcode it falls back to `icon.icns` with a `cargo:warning` (desktop works without Xcode).
- `rust-toolchain.toml` pins `stable` + `aarch64-apple-ios*` and Android targets for `cargo check --target ...` and mobile builds.
- `src-tauri/Assets.xcassets` + `Info.plist` + `tauri.macos.conf.json` (`titleBarStyle Overlay`, `transparent`) replicate the generic macOS/Xcode layer.

## 🔨 Build per OS

| Script | Does |
|---|---|
| `scripts/build-linux.sh` | Linux bundles plus compile/launch. Backends `--remote [HOST]` (SSH, primary) and `--native`. Profiles `--release`/`--debug`; extras `--dev`, `--run`, `--fetch`, `--logs`, `--stop`. Full flags: `docs/en/scripts.md`. |
| `scripts/build-windows.sh` | Windows x64 cross-compile from macOS/Linux (`cargo-xwin` + NSIS). One-time setup: `brew install llvm lld makensis`, `cargo install cargo-xwin --locked`, `rustup target add x86_64-pc-windows-msvc`. MSI/WiX needs a Windows host. |

## 📱 Xcode unified (iOS + macOS in ONE target)

The source of truth for the Xcode project is the template:

    src-tauri/vendor/tauri-cli-2.12.0/templates/mobile/ios/

`src-tauri/gen/apple` regenerates **entirely** from it (gitignored, does NOT persist):

    scripts/Xcode/apple-xcode.sh             # regenerate + xcodegen
    scripts/Xcode/apple-xcode.sh --build     # plus iOS sim (via CLI) + macOS host

Rule: ALWAYS edit the template (`project.yml`, `apple.xcconfig`, entitlements, `Assets.xcassets`),
NEVER the generated `.xcodeproj` or its Info.plist.

- Single target `tauri-react-template_Apple`, iOS + macOS via `apple.xcconfig`
  (`SUPPORTED_PLATFORMS = macosx iphoneos iphonesimulator`) with `PLATFORM_NAME`
  branches in the "Build Rust Code" phase.
- **Three build configs** (XcodeGen `configs:`): `debug`, `release`, `hotreload`.
  The phase ("Build Rust Code") picks the pipeline:
  - macOS → standalone (`cargo build --lib` host). `debug`/`release` embed the
    frontend (`custom-protocol`); `hotreload` opens Terminal in front with Vite
    (`apps/web`, devUrl :1420 + HMR) and builds the app WITHOUT custom-protocol
    so it consumes the dev server → `Externals/macosx/...`.
  - iOS `debug` → **same as release but fast**: standalone with the embedded
    frontend (`--features tauri/custom-protocol`) like release, **no Vite, no CLI**:
    full app runs and ⌘R incremental = Rust-only fast compile (JS untouched
    unless dist changes). For HMR use `hotreload`.
  - iOS `hotreload` → honest hot reload: FIRST **probes** the parent
    `tauri ios dev --open` with a real JSON-RPC WebSocket handshake and 1.5s
    timeout on the IPC address file
    (`$TMPDIR/com.tauri-react-template.app-server-addr` — the CLI runs a
    jsonrpsee server with the `options` method). If alive → runs `xcode-script`
    (full IPC: features, config merges, `TAURI_DEV_HOST`…). If not (stale addr
    pointing at e.g. the Vite WS, closed port, or missing file — the stock
    `read_options` would hang Xcode forever, which is why this probe NEVER
    lets the build hang) → opens the parent `tauri ios dev --open` in Terminal
    (with `--host <LAN>` for physical devices), waits ~40s and retries. With
    no parent → opens the dev-server terminal
    (`apps/web/scripts/xcode/xcode-dev-server.command`), warns, falls back
    to standalone.
  - `release` → standalone with `--features tauri/custom-protocol` for
    production (builds from scratch: correct for release).
- Foreground Terminal without AppleScript: the phase uses `open -a Terminal
  <script>.command` (LaunchServices → no TCC permissions, `open` never blocks
  the phase). Two runscripts in the repo (survive regen):
  `apps/web/scripts/xcode/xcode-dev-server.command` (Vite :1420 + HMR) and
  `scripts/Xcode/xcode-dev-parent.command` (`tauri ios dev --open`, with
  `--host <LAN>` when there is a network).
- Double-Vite warning: in hotreload, the parent starts Vite (its
  `beforeDevCommand`) and fails if `:1420` is already taken
  ("beforeDevCommand terminated with a non-zero..."). Don't leave a previous
  preview/dev Vite running before launching the `hotreload` config.
- `xcode-script` (cargo-mobile) stages `Externals/<arch>/<PROFILE>` (`debug`
  for anything != release); the phase also copies that lib to the per-SDK path
  the target links (`Externals/<PLATFORM_NAME>/<CONFIGURATION>`), so the fresh
  lib always wins.
- Closing `hotreload` (⌘. / stop app) does **not** stop the parent:
  `tauri ios dev --open` keeps sleeping (~24h) with its options IPC server and
  Vite on `:1420`. To free ports: close the Terminal window (⌘W) or Ctrl+C →
  SIGHUP kills parent and Vite. A stale addr file breaks nothing: the probe
  discards it fast (closed port). `hotreload` also compiles fast: incremental
  debug Rust + Vite HMR (only the first from-scratch build is long).
- So the Xcode "Run" button means: `debug`/`release` = full standalone app
  without a parent CLI (fast debug, optimized release); `hotreload` =
  auto-opens Terminal with the parent and does real frontend HMR (plus Rust
  on physical devices).
- Scheme `tauri-react-template_Apple` for Xcode/macOS. Scheme
  `tauri-react-template_iOS` (shim building the `_Apple` target) +
  `_iOS/Info.plist`: required by cargo-mobile2, which uses `config.scheme()`
  = `<app>_iOS` for `tauri ios dev|build`.
- Static per-platform entitlements (ios.entitlements / macos.entitlements) via
  `CODE_SIGN_ENTITLEMENTS[sdk=...]`.

## 🔏 Signing / DEVELOPMENT_TEAM (auto-injection)

The template **never hardcodes the Team ID**: it carries a
`__TAURI_DEVELOPMENT_TEAM__` sentinel that `scripts/Xcode/apple-xcode.sh`
resolves BEFORE `xcodegen`, on the `gen/` copy. Priority:

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
target — see `MODS.md` at the repo root):

```bash
make install-tauri-cli   # builds vendor/tauri-cli → ~/.cargo/bin/cargo-tauri
cargo tauri ios dev "iPhone 17"
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

- **Physical iPhone**: `tauri ios dev --host 192.168.x.x "iPhone 17"` →
  build+archive+export+install via xcodebuild/devicectl + Rust hot reload
  (CLI watcher). The project's `hotreload` config uses the same shape: if the
  parent is not alive, the phase opens it in Terminal with `--host <LAN>`
  (hence the Vite `host: true` fix).
- **Simulator**: since Xcode 26, `devicectl` lists sims as devices and
  cargo-mobile tried `devicectl device install app` on a sim → unsupported
  ("Install Application is not supported"). For SIM: `tauri ios dev --open`
  (keeps the parent alive: IPC + options) and run the `hotreload` config of
  the `tauri-react-template_Apple` scheme in Xcode on the sim → each ⌘R
  compiles via `xcode-script` with the parent's options and the frontend does
  HMR via Vite. Sim Rust auto-reload stays limited by upstream CLI; `debug`
  keeps the standalone no-CLI path. (Officially fixed for device listing in
  `cargo-mobile2 0.22.5`; see `MODS.md`.)

## 🖥️ Without Xcode (Linux/Windows/macOS without Xcode)

Everything desktop compiles (`pnpm dev`, `pnpm dlx @tauri-apps/cli@2.12.0 dev`, `make dev`).
iOS/Android only with Xcode / Android SDK.
