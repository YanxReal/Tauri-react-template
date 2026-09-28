# Scripts & Tooling

> **Audience:** everyone — what to run and when.

## Root scripts

`package.json:11`:

| Command | Runs |
|---------|------|
| `pnpm dev` | `turbo dev` (web, TUI) |
| `pnpm build` | `turbo build` |
| `pnpm lint` | `biome check .` |
| `pnpm lint:fix` | `biome check --write .` |
| `pnpm format` / `pnpm format:check` | same as lint (Biome formats too) |
| `pnpm typecheck` | `turbo typecheck` |
| `pnpm test` | `turbo test` (vitest) |
| `pnpm tauri` | `tauri` (CLI passthrough) |
| `pnpm tauri:dev` / `pnpm tauri:build` | `tauri dev` / `tauri build` |

`Makefile`:

| Target | Effect |
|--------|--------|
| `make dev` | `tauri dev` (desktop), respects `APPLE_SIGNING_IDENTITY` |
| `make dev:web` | `pnpm --filter web dev` |
| `make dev:ios` | `pnpm tauri ios dev "iPhone 17"` (simulator, uses `IOS_DEVICE`) |
| `make dev-ios-physical` | `cargo tauri ios dev "iPhone 17" --host $(IOS_DEV_HOST)` (needs `make install-tauri-cli`) |
| `make dev-android-emulator` | boot `$ANDROID_AVD` + `tauri android dev --target $ANDROID_TARGET` |
| `make gen-apple` | `scripts/Xcode/apple-xcode.sh` (xcodegen → `gen/apple`) |
| `make install-tauri-cli` | Builds vendored `src-tauri/vendor/tauri-cli-2.12.0` (stock 2.12.0 + 3 local tweaks: standalone fallback, `_Apple` target) → `~/.cargo/bin/cargo-tauri` |
| `make lint` / `make build` | aliases |
| `make help` / `make doctor` | list commands / check toolchain |

Per-OS build shells: `scripts/build-linux.sh`, `scripts/build-windows.sh`, `scripts/Xcode/apple-xcode.sh`.

## Linux build (`scripts/build-linux.sh`)

Builds the Linux bundles, and can compile **and run** the app on a Linux dev box over SSH.
Two backends: `--remote [HOST]` (push over SSH and build there) and `--native` (build on a
Linux host). With no mode flag: native on Linux, remote when the dev box answers — and if the
box is unreachable the script stops with instructions instead of building anywhere else.

| Flag | Effect |
|------|--------|
| `--remote [HOST]` | rsync → SSH build box (default `$LINUX_BUILD_REMOTE` or `ubuntu-vnc`) |
| `--native` | build on this host (must be Linux) |
| `--release` / `--debug` | build profile (release default; debug is much faster) |
| `--dev` | `tauri dev` (Vite + app, hot reload) instead of a bundle; implies `--debug` |
| `--run` | after building, launch the app on the target display |
| `--bundles LIST` | `deb` (default) \| `appimage` \| `rpm` \| `all` |
| `--target ARCH` | `aarch64` \| `x86_64` \| a rust triple (must match the box) |
| `--display :N` | X display used by `--dev`/`--run` (default `:1`) |
| `--fetch` | copy the built bundles back to `./dist-linux` |
| `--sync-only` / `--no-sync` | only push the sources / reuse what is already on the remote |
| `--logs` / `--stop` | follow / kill the remote dev server or app (remote only) |

```bash
./scripts/build-linux.sh --remote --dev                  # compile + run on the dev box
./scripts/build-linux.sh --remote --debug --run          # fast build, then launch
./scripts/build-linux.sh --remote --release --bundles all --fetch
./scripts/build-linux.sh                                 # auto: remote, or native on Linux
./scripts/build-linux.sh --native                        # force a local Linux build
```

The remote backend drives `pnpm tauri` (the CLI pinned in `devDependencies`, so no
`cargo install tauri-cli` step) and expects the box to provide Rust, Node 24 and the
WebKitGTK/GTK dev headers. It covers the whole loop over SSH: build (release or debug),
`--dev`, `--run`, `--logs`, `--stop`. Sync uses `rsync` when both ends have it and falls
back to `tar` otherwise.

Because the box keeps `node_modules` and `target/` on disk, rebuilds are incremental
(seconds) and `--dev` gives Vite + hot reload; a container-per-build backend was dropped
in favour of this, as it could never run the app for testing.

## The Linux box

The current box is **[Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker)** (separate repo): Ubuntu 26.04 + GNOME 50 (Wayland) desktop in Docker for arm64, with noVNC, native VNC, SSH and a ready Tauri v2 toolchain. That is where the app is compiled and looked at now.

| | |
|---|---|
| Repo | [YanxReal/Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker) (`make install`) |
| noVNC / VNC / SSH | `http://localhost:6080/vnc.html` · `localhost:5902` · `ssh ubuntu-arm` (`~/.ssh/config` alias, user `admin`, key auth) |
| Project path | `/workspace/Tauri-react-template` (bind-mounted `./workspace`) |
| Launch GUI apps | `dev <cmd>` wrapper (injects `WAYLAND_DISPLAY` + session bus) |

Target it with this repo's script (sync + build). Note `--run`/`--dev` assume an X11 `DISPLAY`, so on this Wayland box launch via `dev` instead:

```bash
LINUX_BUILD_DIR=/workspace/Tauri-react-template ./scripts/build-linux.sh --remote ubuntu-arm --debug
# then in the box (no GPU — software rendering):
WEBKIT_DISABLE_COMPOSITING_MODE=1 LIBGL_ALWAYS_SOFTWARE=1 dev ./src-tauri/target/debug/tauri-react-template
```

### Minimal in-repo box (`docker/linux-gnome` + `scripts/linux-box.sh`)

A lighter X11 (Xvfb) alternative that lives in this repo: Ubuntu 24.04 (GNOME 46 / mutter / GTK3 / WebKitGTK 4.1 — the exact stack the window-frame work was verified against), the **Ubuntu GNOME session** on Xvfb, and noVNC so you can *see* the window.

```bash
./scripts/linux-box.sh up        # build the image (first time) + create + start
./scripts/linux-box.sh status    # display, WM, VNC, ssh, restart policy
./scripts/linux-box.sh down      # stop it, KEEP the container (caches survive)
./scripts/linux-box.sh destroy   # remove it (--volumes: loses cargo/pnpm caches)
./scripts/linux-box.sh wait      # block until display + WM + ssh answer
./scripts/linux-box.sh ssh       # shell in the box
./scripts/linux-box.sh build …   # shortcut for build-linux.sh --remote
./scripts/linux-box.sh app [--opaque]   # build + launch the app on :1
./scripts/linux-box.sh novnc     # print the noVNC URL
```

**It does not start on its own.** The container is created with `--restart=no`, so Docker
Desktop can boot with the box stopped; you start it when you want it. `down` keeps the
container (and its `target/`, so the next build is incremental); only `destroy` wipes it.

| Piece | Where | Notes |
|-------|-------|-------|
| Image | `docker/linux-gnome/Dockerfile` | Ubuntu 24.04 + WebKitGTK 4.1 dev + Node 24 + pnpm 10.34.5 + Rust stable + `ubuntu-session` + mutter + x11vnc/TightVNC/noVNC + openssh |
| PID 1 | `docker/linux-gnome/entrypoint.sh` | Xvfb → dbus → session → x11vnc → TightVNC → noVNC → sshd, then supervises each by role |
| Control | `scripts/linux-box.sh` | up/down/destroy/status/wait/ssh/novnc/logs/build/app |
| SSH | `~/.ssh/config`, alias `ubuntu-vnc` | `127.0.0.1:2222`, user `dev` (never root: gnome-shell aborts as root) |
| Ports | `2222` ssh, `6080` noVNC, `5901` TightVNC | bound to `127.0.0.1`; raw x11vnc (5900) stays inside the container |
| Password | `dev` | one password for both doors: noVNC (which forwards it to x11vnc) and TightVNC |
| Caches | named volumes | `tauri-cargo-registry`, `tauri-cargo-git`, `tauri-pnpm-store` |

Open **http://localhost:6080/vnc.html** to see and control the desktop (password `dev`).
For a native client use TightVNC against `127.0.0.1:5901`, same password. `DISPLAY=:1` is
exported for every session (via `/etc/environment`, so plain `ssh host 'cmd'` gets it), and
`scrot` / `xdotool` / `wmctrl` / `xrandr` are installed for screenshots and scripted checks.

### Making GNOME work in a container (measured, not guessed)

Getting a real GNOME session up under Xvfb took several rounds of pixel-level measurement.
Each item below was verified by comparing screenshots (`standard_deviation` per row: a frozen
screen is `0` on every row); the wrong value is recorded too, so nobody re-introduces it.

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Failed to get session bus: The connection is closed`; session falls back to bare mutter | the session bus was started by **root**; `dbus-daemon --session` only lets the user that created it connect | start it as the session user (`setpriv --reuid=dev …`) |
| Shell alive, answers D-Bus, but the screen **freezes** on one colour and opening a window changes 0 px | the bus was started inside `$(…)`: the daemon inherited the substitution pipe, blocked writing to it and **hung** (socket + process alive, no replies) | fixed `--address=` + output redirected to a **file**, never a pipe |
| `gnome-shell` dies with **signal 11** at startup (`background.js` → `loginManager.js`) | `misc/loginManager.js` picks `LoginManagerSystemd` when `/run/systemd/seats` exists; with no logind the call throws and `main.js` aborts | `rm -rf /run/systemd` (systemd does not run in the container) |
| `gnome-session` shows its failure dialog; no `ubuntu` session found | only `gnome.session` exists without the `ubuntu-session` package, and the only shell mode is `ubuntu.json` | install `ubuntu-session` + `ubuntu-settings`, run `gnome-session --session=ubuntu` |
| Session starts but the screen stays flat | `GNOME_SHELL_SESSION_MODE=x11` — **that mode does not exist** (valid: `ubuntu`, `gnome`); `gnome-shell --x11` is a flag, not a mode | `GNOME_SHELL_SESSION_MODE=ubuntu` + the Ubuntu env (`XDG_CURRENT_DESKTOP=ubuntu:GNOME`, `DESKTOP_SESSION=ubuntu`, `XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg`) |
| **Whole screen covered by "Oh no! Something has gone wrong", clicking does nothing** | a component listed in `RequiredComponents` of `ubuntu.session` dies: `org.gnome.SettingsDaemon.Power` (needs **logind**) and `org.gnome.SettingsDaemon.ScreensaverProxy` (needs `org.gnome.ScreenSaver`), plus `UsbProtection` which SIGSEGVs for the same reason. `gnome-session` then declares the session failed and `gnome-session-failed` draws that fullscreen screen (a 1600x1000 window — visible in `xwininfo -root -tree`) | the entrypoint writes `box.session` to `/usr/local/share/gnome-session/sessions/` with those laptop-only components removed from `RequiredComponents`, and runs `gnome-session --session=box`. Check with `grep -c gnome-session-failed` on the window tree: it must be **0** |
| Desktop renders once, then freezes for good | `GSK_RENDERER=cairo` forces GTK4 to Cairo and GNOME Shell 46 needs GL for its compositor | do not set it — llvmpipe is already software, GL is what the shell wants |
| Same freeze, introduced while "fixing" the overview | `MESA_GL_VERSION_OVERRIDE=4.5` / `MESA_GLSL_VERSION_OVERRIDE=450` | do not set them; `glxinfo -B` already reports `Max core profile version: 4.5` |
| `dbus-send`/apps cannot reach the a11y bus | `at-spi2-core` missing (and `NO_AT_BRIDGE=1` was set) | install `at-spi2-core`, do not disable the bridge |
| `x11vnc` exits with `BadAccess` on `X_ShmAttach` | MIT-SHM cannot attach inside the container | `-noshm` (the flag is **not** `-noshmem`, which aborts as an unknown option) |
| `tightvncserver` aborts: `The USER environment variable is not set` | `setpriv` does not set `USER` | pass `USER=dev` |
| Session works but **no dock**, no tray icons, no desktop icons | the `ubuntu` shell mode asks for `ubuntu-dock@ubuntu.com`, `ubuntu-appindicators@ubuntu.com` and `ding@rastersoft.com` in `/usr/share/gnome-shell/modes/ubuntu.json`, but `--no-install-recommends` skipped all three packages | install `gnome-shell-extension-ubuntu-dock`, `gnome-shell-extension-appindicator`, `gnome-shell-extension-desktop-icons-ng`. Check the dock with `convert shot.png -crop 1x1000+40+0` → row `standard_deviation` ~17 instead of ~5 |

`GSK_RENDERER` and the Mesa overrides are worth repeating: both were added as fixes and both
**caused** the freeze they were meant to cure. The rule that came out of it is to measure
before and after with row `standard_deviation` rather than trusting a plausible-sounding
variable.

## Windows cross-compile (`cargo-xwin`)

`scripts/build-windows.sh [--bundles nsis] [tauri build args]` builds the Windows x64 bundle from macOS/Linux — it resolves the keg-only LLVM/lld paths itself and calls `pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles nsis`.

One-time setup: `brew install llvm lld makensis` (macOS; `makensis` is only needed for the NSIS bundle), `cargo install cargo-xwin --locked` and `rustup target add x86_64-pc-windows-msvc`. Outputs: `src-tauri/target/x86_64-pc-windows-msvc/release/tauri-react-template.exe` (app) and `.../bundle/nsis/tauri-react-template_0.1.0_x64-setup.exe` (installer; ~200 MB because `webviewInstallMode: offlineInstaller` embeds WebView2).

Notes: the MSI/WiX bundler only runs on a Windows host (`--bundles nsis` is the macOS/Linux default); installer signing also needs Windows unless you set `bundle > windows > signCommand`. `cargo xwin check --target x86_64-pc-windows-msvc` is the fast way to type-check the Windows-only code paths.

## Xcode helper

`scripts/Xcode/apple-xcode.sh` (see `scripts/README.md:46` — Xcode unified section):

- Resolves `DEVELOPMENT_TEAM` sentinel → real ID (env `DEVELOPMENT_TEAM` > `scripts/.team-id` > omitted).
- Runs `xcodegen` → `src-tauri/gen/apple`.
- With `--build` also compiles iOS sim + macOS host.

See `docs/en/mobile.md` for configs and the Xcode 26 `cargo-mobile2` patch.

## Lint & format (Biome)

`biome.json:1`:

- `formatter: indentStyle space, indentWidth 2, lineWidth 80, lineEnding lf`
- `linter.rules: preset recommended` + `noUnusedVariables:warn`, `noExplicitAny:warn`, `useImportType:error`
- `javascript.formatter: quoteStyle double, semicolons asNeeded, trailingCommas es5`
- `overrides`: disables linter/formatter inside `src-tauri/**` and `packages/ui/src/components/**` + `apps/web/src/components/*.tsx`

```bash
pnpm lint
pnpm lint:fix
pnpm format:check
biome check --write .   # direct
```

## Git hooks

`package.json:23` `prepare: husky`:

- `.husky/pre-commit` → `lint-staged`
- `lint-staged:25` — `*.{ts,tsx,js,jsx,json,jsonc,css}` → `biome check --write --no-errors-on-unmatched`

## CI (removed)

No CI workflows — they only burned GitHub resources. The same gates run locally (see [Testing](./testing.md)); Husky + lint-staged guard every commit.

## Node / pnpm pinning

- `.nvmrc` + `.node-version` — Node 24
- `.npmrc` — pnpm settings
- `pnpm-lock.yaml` frozen on install (`--frozen-lockfile`)

Next: [Troubleshooting →](./troubleshooting.md)
