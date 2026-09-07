# Troubleshooting

## Terminal garbled: `35;22;36M` / `?1000h`

**Cause:** `pnpm dev` (= `turbo dev`) enables Turbo TUI mouse mode. `tauri dev` kills it with `SIGTERM` leaving the terminal in that mode.

**Fix:** `tauri.conf.json:build.beforeDevCommand` is already `pnpm --filter web dev` (direct Vite, no Turbo). Use `make dev` / `pnpm tauri:dev` for desktop. Only run `pnpm dev` standalone (web-only).

Reset a garbled terminal: `reset` or `tput rmcup`.

## macOS traffic lights jump on resize

Ensure `lib.rs:107` `adjust_macos_traffic_lights` + `ensure_traffic_lights_observer` + 60 fps polling are present. They counter AppKit resetting buttons to `12px` on each layout pass. Verify `titleBarStyle: Overlay` + `hiddenTitle` in `tauri.macos.conf.json`. Check they target `22.5/44.5/66.5`.

## No window shadow on Linux / flat window

Native only now (`lib.rs:315` `StyleContext::add_provider` Wayland-safe, no webview fallback). If still flat, check `journalctl` / `RUST_LOG=info` for `linux shadow: provider added via window StyleContext (Wayland/X11 without screen)` vs `via window + screen (X11)` and verify `html.linux .app-shell { border-radius:10px; overflow:hidden }` clips all 4 corners. On Sway/Hyprland or X11 without `picom/compton`, the compositor may ignore `decoration` shadows — native only will be invisible by design per user request.

## Glass yellow glitches / RAM blow-up on Linux

Disable glass — Linux forces `glass OFF` by design (`glass-cards-provider.tsx` + `globals.css:283`). Keep `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` in `lib.rs:371`. See `native-feel.md` Plan A for a degraded-glass alternative.

## `pnpm install` fails / Node version mismatch

Requires **Node >=24** and **pnpm >=10** (`package.json:engines`). Use `nvm use` / `pnpm env use --global 10`.

## `cargo check` fails on iOS target

```bash
cargo check --target aarch64-apple-ios --manifest-path src-tauri/Cargo.toml
```

Requires `rust-toolchain.toml` targets installed (`rustup show`). Without Xcode, desktop `cargo check` still passes.

## `tauri ios dev` EBADARCH / MIInstallerErrorDomain 15

Xcode 26 lists simulators via `devicectl` — unpatched `cargo-mobile2 0.22.4` installs with `-sdk iphoneos` → arch mismatch.

```bash
make install-tauri-cli
cargo tauri ios dev "iPhone 17"   # not pnpm tauri
```

For physical device use `make dev-ios-physical` (needs `--host 169.254.x.x`).

## Port 1420 already in use / hotreload `beforeDevCommand terminated`

Another Vite is running. Kill it (`lsof -i :1420`, `pkill -f vite`) before launching the `hotreload` scheme — it spawns a second Vite via parent `tauri ios dev`.

## `DEVELOPMENT_TEAM` not injected / signing fails

```bash
echo YOUR_TEAM_ID > scripts/.team-id
scripts/Xcode/apple-xcode.sh
xcodebuild -project src-tauri/gen/apple/tauri-react-template.xcodeproj \
  -scheme tauri-react-template_Apple -configuration Debug \
  -showBuildSettings | grep DEVELOPMENT_TEAM
```

Manual selection in Xcode is lost on next regeneration — use `.team-id`.

## Scroll janky / rubber-band broken

Never add `overscroll-behavior:none` or `overflow:hidden` overrides beyond `globals.css`. The app relies on `touch-action: pan-x pan-y` for native scroll. The Rust plugin (`prevent-default` with `Flags::debug()`) does not touch scroll — if you add custom CSS, verify scroll 0↔max with JS.

## Missing translations / fallback shows English unexpectedly

Ensure the key exists in **both** `en.json` and `es.json`. `fallbackLng: "en"` hides missing `es` keys. Check `supportedLngs` includes your locale in `i18n/config.ts:20`.

Next: [Contributing →](./contributing.md)
