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
| `make gen-apple` | `scripts/Xcode/apple-xcode.sh` — regen `gen/apple` (vendored CLI init, branding-aware) |
| `make gen-android` | `scripts/Android/android-autogen.sh` — regen `gen/android` (vendored CLI init, branding-aware, Linux/Win/macOS) |
| `make build-linux` | `scripts/build-linux.sh --remote --debug --fetch` on `ubuntu-arm` (`LINUX_REMOTE`/`LINUX_DIR` override) |
| `make dev-linux` | `scripts/build-linux.sh --remote --dev` (hot reload on the box) |
| `make linux-logs` / `make linux-stop` | follow / kill the remote dev server or app |
| `make install-tauri-cli` | Builds vendored `src-tauri/vendor/tauri-cli-2.12.0` (stock 2.12.0 + 3 local tweaks: standalone fallback, `_Apple` target) → `~/.cargo/bin/cargo-tauri` |
| `make install-skills` | Installs all project agent skills (macOS/Linux; on Windows run `scripts\install-skills.cmd`) |
| `make rebrand` | Propagates `branding.json` identity (name, version, identifier, icons) to all desktop consumers; warns to regenerate `gen/` for iOS/Android |
| `make lint` / `make build` | aliases |
| `make help` / `make doctor` | list commands / check toolchain |

Per-OS build shells: `scripts/build-linux.sh` (+ `build-linux.cmd` on Windows), `scripts/build-windows.sh`, `scripts/Xcode/apple-xcode.sh`, `scripts/Android/android-autogen.sh`.

## Linux build (`scripts/build-linux.sh`)

Builds the Linux bundles, and can compile **and run** the app on a Linux dev box over SSH.
Two backends: `--remote [HOST]` (push over SSH and build there) and `--native` (build on a
Linux host). With no mode flag: native on Linux, remote when the dev box answers — and if the
box is unreachable the script stops with instructions instead of building anywhere else.

| Flag | Effect |
|------|--------|
| `--remote [HOST]` | rsync → SSH build box (default `$LINUX_BUILD_REMOTE` or `ubuntu-arm`) |
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

**Platforms:** the Linux build always happens in the Ubuntu-arm-docker box via SSH —
macOS and Windows can't run `webkit2gtk` + the Linux bundlers locally. On **macOS**
run the `.sh` directly; on **Windows** run `scripts\build-linux.cmd` (locates Git
Bash; needs an OpenSSH client, rsync optional). Flag `--native` works only on a
Linux host and aborts elsewhere.

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
./scripts/build-linux.sh --remote ubuntu-arm --debug
# then in the box (no GPU — software rendering):
WEBKIT_DISABLE_COMPOSITING_MODE=1 LIBGL_ALWAYS_SOFTWARE=1 dev ./src-tauri/target/debug/tauri-react-template
```

Defaults are already `ubuntu-arm` + `/workspace/Tauri-react-template` (the repo
checkout; the binary itself stays lowercase `tauri-react-template`), so
`make build-linux` / `make dev-linux` need no env. Override with
`LINUX_BUILD_REMOTE=<host>` / `LINUX_BUILD_DIR=<dir>` when needed.
The box may ship a newer pnpm than the pinned `pnpm@10.34.5` — harmless:
every install runs with `--frozen-lockfile`, so the lockfile stays
authoritative.

### Retired in-repo box (`docker/linux-gnome` + `scripts/linux-box.sh`)

Removed: the X11/Xvfb `ubuntu-vnc` box used to live in this repo but was
deleted in favour of Ubuntu-arm-docker above (faster rebuilds, real Wayland
session, no image to maintain here). If you still see `ubuntu-vnc` in an old
`~/.ssh/config`, drop those two `Host` blocks — the only alias in use is
`ubuntu-arm`.

## Windows cross-compile (`cargo-xwin`)

`scripts/build-windows.sh [--bundles nsis] [tauri build args]` builds the Windows x64 bundle from macOS **or** Linux — it resolves the platform's LLVM/lld toolchain and the rustup-managed Rust itself, then calls `pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles nsis`.

One-time setup: `brew install llvm lld makensis` on macOS, or `sudo apt install llvm lld nsis` on Linux (`makensis`/`nsis` only needed for the NSIS bundle), plus `cargo install cargo-xwin --locked` and `rustup target add x86_64-pc-windows-msvc`. Outputs: `src-tauri/target/x86_64-pc-windows-msvc/release/tauri-react-template.exe` (app) and `.../bundle/nsis/tauri-react-template_0.1.0_x64-setup.exe` (installer; ~200 MB because `webviewInstallMode: offlineInstaller` embeds WebView2).

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
