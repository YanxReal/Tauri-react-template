# Mobile — iOS & Android

Template is **multi-platform**: desktop (macOS, Windows, Linux) **and** mobile (iOS, Android). All changes must be tested cross-platform.

## Source of truth vs generated

- **Template (edit here):** `src-tauri/vendor/tauri-cli-2.11.4/templates/mobile/ios/` — `project.yml`, `apple.xcconfig`, entitlements, `Assets.xcassets`. This is the source for the Xcode project.
- **Generated (never edit):** `src-tauri/gen/apple/` and `src-tauri/gen/android/` — gitignored, regenerated on every `scripts/Xcode/apple-xcode.sh` or `tauri ios init`.

Rule: **never touch `src-tauri/gen/`** — all manual edits are lost on regeneration.

## iOS — unified Xcode target (iOS + macOS in one)

`scripts/Xcode/apple-xcode.sh` is the entrypoint (see `scripts/README.md:8`):

```bash
scripts/Xcode/apple-xcode.sh            # xcodegen → src-tauri/gen/apple
scripts/Xcode/apple-xcode.sh --build    # + iOS simulator (CLI) + macOS host
make gen-apple                          # alias
```

What it does:

- Resolves `DEVELOPMENT_TEAM` sentinel → real Team ID (see below) → `xcodegen`
- Single target `tauri-react-template_Apple` whose `SUPPORTED_PLATFORMS = macosx iphoneos iphonesimulator` via `apple.xcconfig` and branches on `PLATFORM_NAME` in the "Build Rust Code" phase.

### Three build configs (XcodeGen)

| Config | macOS | iOS |
|--------|-------|-----|
| `debug` | standalone with embedded frontend (`custom-protocol`) | same — standalone, fast, no Vite/CLI |
| `release` | standalone, optimized | standalone, optimized |
| `hotreload` | opens Terminal with Vite dev server (`apps/web`, `:1420` + HMR), no `custom-protocol` | probes parent `tauri ios dev --open` via JSON-RPC handshake (1.5s timeout) on `$TMPDIR/com.tauri-react-template.app-server-addr`; if alive → `xcode-script` with full IPC (`TAURI_DEV_HOST` etc.), else opens parent in Terminal; if no parent → standalone fallback |

Details in `scripts/README.md:22`.

### iOS commands (always use patched CLI)

The stock `cargo tauri` may be a modified Prestly build (`com.yanxstudio.prestly`). Use the **stock CLI**:

```bash
pnpm dlx @tauri-apps/cli@2.11.4 ios build --target aarch64-sim --debug
pnpm dlx @tauri-apps/cli@2.11.4 android build --debug --target aarch64
make dev:ios            # iOS simulator (patched cargo tauri + simctl, no EBADARCH)
make dev-ios-physical   # iPhone over USB (needs --host 169.254.x.x)
```

`Makefile:34` — `dev:ios` uses `pnpm tauri ios dev "$(IOS_DEVICE)"` (sim path). `dev-ios-physical` uses `cargo tauri ios dev "$(IOS_DEVICE)" --host $(IOS_DEV_HOST)` (physical device over USB link-local IP).

### Xcode 26 patch — vendored `cargo-mobile2`

Xcode 26's `xcrun devicectl list devices --json-output` now lists **simulators** as devices (`reality: "simulated"`). `cargo-mobile2 0.22.4` didn't filter → `tauri ios dev` treated a simulator as physical → `aarch64-apple-ios`/`-sdk iphoneos`/`devicectl install` → `MIInstallerErrorDomain 15 / EBADARCH`.

**Fix in this template** (not in `gen`):

- `src-tauri/vendor/cargo-mobile2-0.22.4/src/apple/device/devicectl/device_list.rs` adds `reality: Option<String>` + filter `reality != "simulated"`.
- `src-tauri/vendor/tauri-cli-2.11.4/Cargo.toml` patches `[patch.crates-io] cargo-mobile2 = { path = "../cargo-mobile2-0.22.4" }`.

Install once per clone:

```bash
make install-tauri-cli   # builds vendor/tauri-cli → ~/.cargo/bin/cargo-tauri
cargo tauri ios dev "iPhone 17"
```

`pnpm tauri ios dev` (Node CLI) still uses the unpatched registry copy — for iOS use `cargo tauri`.

> **When `cargo-mobile2 0.22.5` ships** (already in dev `ee65fb1`, not yet on crates.io as of Apr 29 2025) the patch can be removed. Re-vendor the new version and reapply or drop the patch.

### Info.plist

Edit the **template only**: `src-tauri/Info.plist` — it is the source for macOS (`tauri.macos.conf.json: bundle.macOS.infoPlist`) **and** iOS (`tauri.ios.conf.json: bundle.iOS.infoPlist`). Add `NSAppTransportSecurity` (`NSAllowsLocalNetworking` + `NSAllowsArbitraryLoads` for `http://192.0.0.2:1420`/`ws://` HMR), `NSLocalNetworkUsageDescription`, `NSBonjourServices` there.

`src-tauri/gen/apple/.../Info.plist` is autogen.

### DEVELOPMENT_TEAM

Template never hardcodes the Team ID — sentinel `__TAURI_DEVELOPMENT_TEAM__` is resolved by `scripts/Xcode/apple-xcode.sh` **before** `xcodegen`. Priority:

1. env `DEVELOPMENT_TEAM`
2. file `scripts/.team-id` (gitignored, persists)
3. omitted → choose in Xcode → Signing & Capabilities

```bash
echo YOUR_TEAM_ID > scripts/.team-id
scripts/Xcode/apple-xcode.sh
# verify:
xcodebuild -project src-tauri/gen/apple/tauri-react-template.xcodeproj \
  -scheme tauri-react-template_Apple -configuration Debug \
  -showBuildSettings | grep DEVELOPMENT_TEAM
```

Needed for `tauri ios dev|build`; not needed for Xcode sim builds (ad-hoc `CODE_SIGN_STYLE[sdk=iphonesimulator*]`) or macOS.

## Android

```bash
make dev-android-emulator   # APK debug → emulator (aarch64)
pnpm dlx @tauri-apps/cli@2.11.4 android build --debug --target aarch64
```

`ANDROID_AVD` / `ANDROID_TARGET` are Makefile vars (`Resizable_Experimental` / `aarch64`).

## Dev without Turbo TUI

`pnpm dev` = `turbo dev` (TUI `?1000h`). `tauri dev` kills it with `SIGTERM` leaving mouse mode on. `tauri.conf.json:build.beforeDevCommand` is `pnpm --filter web dev` (direct Vite, no Turbo) so `tauri ios dev` never enables `?1000h`.

## Hot reload (full IPC)

`apps/web/vite.config.ts:25` — `host: host || true` (all interfaces). `tauri ios dev` negotiates `devUrl` on a LAN IP; Vite must be reachable on that IP + `ws://:1421` HMR.

- Physical iPhone: `tauri ios dev --host 192.168.x.x "iPhone Studio"` → xcodebuild/devicectl + Rust watcher.
- Simulator + `hotreload` scheme: if parent `tauri ios dev --open` is alive, `xcode-script` consumes its options + `TAURI_DEV_HOST`; otherwise opens parent in Terminal.

Next: [Native Feel →](./native-feel.md)
