# Troubleshooting

## Terminal garbled: `35;22;36M` / `?1000h`

**Cause:** `pnpm dev` (= `turbo dev`) enables Turbo TUI mouse mode. `tauri dev` kills it with `SIGTERM` leaving the terminal in that mode.

**Fix:** `tauri.conf.json:build.beforeDevCommand` is already `pnpm --filter web dev` (direct Vite, no Turbo). Use `make dev` / `pnpm tauri:dev` for desktop. Only run `pnpm dev` standalone (web-only).

Reset a garbled terminal: `reset` or `tput rmcup`.

## macOS traffic lights jump on resize

Ensure `lib.rs:116` `adjust_macos_traffic_lights` + `ensure_traffic_lights_observer` + 60 fps polling are present. They counter AppKit resetting buttons to `12px` on each layout pass. Verify `titleBarStyle: Overlay` + `hiddenTitle` in `tauri.macos.conf.json`. Check they target `22.5/44.5/66.5`.

## Linux window flat / no shadow / square corners

By design the app does **not** draw its own frame: `tauri.linux.conf.json:11` uses `decorations: true`, so GTK (CSD) or the compositor (SSD) draws the titlebar, the shadow and the corner radius. If you see none of that, the problem is the session/theme, not the app — check `echo $XDG_SESSION_TYPE` and that a GTK theme is set. Never re-add `box-shadow` / `border-radius` / `margin` on `.app-shell` for Linux: the shell is the client area inside the native frame and those rules show up as cut corners under the titlebar.

## Windows: no caption buttons / no Snap Layouts

Windows is frameless (`tauri.windows.conf.json:12` → `decorations: false`) and the titlebar is the app's own: `header.tsx:191` renders `window-controls.tsx` and `lib.rs:361` calls `create_overlay_titlebar()`. If the buttons don't appear, check that `platform === 'windows'` resolved (the Rust `platform_info` command) and that `capabilities/default.json:6` still lists `allow-minimize` / `allow-close` / `allow-is-maximized` / `allow-set-focus` (`capabilities/default.json:15`) plus `capabilities/windows.json:7` for `decorum:allow-show-snap-overlay` (Windows-only capability; keep it out of `default.json` or `cargo check` fails on macOS/Linux). Snap Layouts only open via the 620 ms hover on maximize (`window-controls.tsx:8` → `show_snap_overlay`), which is decorum's Win+Z equivalent — tao cannot answer `WM_NCHITTEST` with `HTMAXBUTTON`, so there is no true native hover flyout. If the plugin's injected 32px bar ever shows up over the header, the `[data-tauri-decorum-tb]` rule (`globals.css:247`) was removed.

## Scrollbar with arrows / header not reaching the right edge

**Symptom:** the Windows build shows the classic scrollbar (grey gutter + up/down arrow buttons) at the window edge, and the header stops ~12px short of the right border, pushing the caption buttons inwards.

**Cause:** `.app-shell` used to be the scroll container, so the scrollbar belonged to the *shell* (header + content) instead of the content, and WebView2 was drawing the default (non-overlay) bar.

**Fix (two parts, both required):**
1. `tauri.windows.conf.json:13` → `scrollBarStyle: "fluentOverlay"` so WebView2 draws the Fluent **overlay** scrollbar (thin, auto-hiding, floating over the content). Needs WebView2 Runtime >= 125.0.2535.41.
2. `.app-scroll` (`globals.css:231`, `apps/web/src/App.tsx:52`) is the only scroller and wraps `main` + `Footer` only, so the header stays outside it.

Do **not** "fix" it with CSS: `::-webkit-scrollbar` rules override the native overlay and bring back the classic bar with a reserved gutter and arrow buttons (and adding `scrollbar-width`/`scrollbar-color` makes Chromium ignore the webkit pseudo-elements entirely, which is how the arrows sneak back in). On Linux the overlay comes from the GTK setting `gtk-overlay-scrolling`; on macOS it is native and auto-hides.

## Glass yellow glitches / RAM blow-up on Linux

## Windows: black window / "could not create the data directory" (WebView2)

**Symptom:** the app opens and the client area stays black/dark, or a WebView2 dialog says Microsoft Edge cannot read or write `…\EBWebView`.

**Cause:** WebView2 never created its user-data folder — this is **not** a rendering, GPU or Mica problem, so don't chase `transparent` / `window_effects_set`. It shows up when the process is started from a **service context**: an SSH session, `PsExec -i 1`, a SYSTEM scheduled task or WinRM. Those tokens run without the interactive profile loaded, so `%LOCALAPPDATA%\com.tauri-react-template.app\EBWebView` is not writable for that identity.

**Fix:** launch the app the normal way, as the logged-in desktop user (shortcut / `pnpm tauri:dev`). To pin the folder explicitly, set `WEBVIEW2_USER_DATA_FOLDER=C:\some\writable\dir` before starting (note the cmd gotcha: `set VAR=value && app.exe` captures the trailing space, so quote it: `set "VAR=value" && app.exe`). Debug tip: `scripts/build-windows.sh` + `PsExec64 -i 1 -s` reproduces the failure, so it is useless for checking UI work — copy the exe to a real session and double-click it instead.

Disable glass — Linux forces `glass OFF` by design (`glass-cards-provider.tsx` + `globals.css:247`). Keep `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` in `lib.rs:315`. See `native-feel.md` Plan A for a degraded-glass alternative.

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
