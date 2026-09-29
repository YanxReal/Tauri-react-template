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
| `make dev:ios` | `pnpm tauri ios dev "iPhone 18 Pro"` (simulator, uses `IOS_DEVICE`) |
| `make dev-ios-physical` | `cargo tauri ios dev "iPhone 18 Pro" --host $(IOS_DEV_HOST)` (needs `make install-tauri-cli`) |
| `make dev-android-emulator` | boot `$ANDROID_AVD` + `tauri android dev --target $ANDROID_TARGET` |
| `make gen-apple` | `scripts/Xcode/apple-xcode.sh` — regen `gen/apple` (vendored CLI init, branding-aware) |
| `make gen-android` | `scripts/Android/android-autogen.sh` — regen `gen/android` (vendored CLI init, branding-aware, Linux/Win/macOS) |
| `make build-linux` | **linux-build skill**: sync (rsync, no `.git`) + fast debug build + run + `assistant` verify on `ubuntu-arm` (`LINUX_REMOTE`/`LINUX_DIR` override) |
| `make linux-release` | same, release bundle (deb) + fetch to `./dist-linux` (`LINUX_BUNDLES` overrides the bundle list) |
| `make build-windows` | `scripts/build-windows.sh --debug` (cargo-xwin; `WINDOWS_BUNDLES`/`WINDOWS_EXTRA` override) |
| `make dev-linux` | linux-build skill `--remote --dev` (hot reload on the box) |
| `make linux-logs` / `make linux-stop` | follow / kill the remote dev server or app |
| `make install-tauri-cli` | Builds vendored `src-tauri/vendor/tauri-cli-2.12.0` (stock 2.12.0 + 3 local tweaks: standalone fallback, `_Apple` target) → `~/.cargo/bin/cargo-tauri` |
| `make install-skills` | Installs all project agent skills (macOS/Linux; on Windows run `scripts\install-skills.cmd`) |
| `make rebrand` | Propagates `branding.json` identity (name, version, identifier, icons) to all desktop consumers; warns to regenerate `gen/` for iOS/Android |
| `make lint` / `make build` | aliases |
| `make ci-frontend` / `make ci-rust` | the ONLY CI entry points (`.github/workflows/ci.yml` calls these; any new check first becomes a target here) — typecheck+lint+test+build / fmt+clippy+test |
| `make check-docs` | maintainability guards (local, kept out of the CI spec): `scripts/check-docs-parity.sh` (EN/ES mirror) + `scripts/check-agents-anchors.sh` (file:line drift) |
| `make help` / `make doctor` | list commands / check toolchain |

Per-OS build shells: **Linux → the `linux-build` skill** (`.claude/skills/linux-build/scripts/linux-build.sh`, SSH-only, see below), `scripts/build-windows.sh`, `scripts/Xcode/apple-xcode.sh`, `scripts/Android/android-autogen.sh`. App icons: `branding/icon-1024.png` is the master (`branding.json` `icons.master`); both mobile autogen scripts run `scripts/mobile/mobile-icons-regen.sh` after init (`tauri icon` → `icons/` + `gen/apple` + `gen/android`, then composes the iOS 1024 marketing trio the CLI leaves untouched).

## Linux build (skill `linux-build`)

The Linux build happens **over SSH only**, in the Ubuntu-arm-docker box (Docker on
macOS/Windows; Linux is not native there, so `webkit2gtk` + the Linux bundlers can't run
locally). The flow ships as an **agent skill** (`.claude/skills/linux-build/`), replacing the
old in-repo `scripts/build-linux.sh` — installs everywhere with `make install-skills`. The
skill never clones the repo into the box and never manages the container: it synchronises
the sources over SSH with `rsync` (**without `.git`** — the box is a build target, not a
repo), while `node_modules/` and `target/` stay cached on the box, so rebuilds are
incremental (seconds).

| Flag | Effect |
|------|--------|
| `--remote [HOST]` | SSH build box (default `$LINUX_BUILD_REMOTE` or `ubuntu-arm`) |
| `--release` / `--debug` | release (default, bundled) or fast debug profile (debug = `--no-bundle` unless `--bundles` given) |
| `--dev` | `tauri dev` (Vite + app, hot reload) instead of a bundle; implies `--debug` |
| `--run` | after building, launch the app in the box GUI session (via its `dev` session wrapper; debug runs auto-start Vite — the debug binary loads `devUrl :1420`) |
| `--verify` | after `--run`: `assistant windows` + `assistant shot` + `assistant ocr` in the box, then fetch the PNG to `./dist-linux/linux-verify.png` |
| `--bundles LIST` | `deb` (default) \| `appimage` \| `rpm` \| `all` |
| `--target ARCH` | `aarch64` \| `x86_64` \| a rust triple (must match the box) |
| `--fetch` | copy the built bundles back to `./dist-linux` |
| `--sync-only` / `--no-sync` | only push the sources / reuse what is already on the remote |
| `--logs` / `--stop` | follow / kill the remote dev server or app |

```bash
make build-linux                      # sync + fast debug build + run + verify
make build-linux LINUX_BUNDLES=all    # (extras pass through LINUX_* overrides)
make linux-release                    # release .deb bundle + fetch
make linux-release LINUX_BUNDLES=appimage
make dev-linux                        # hot reload on the box
make linux-logs / make linux-stop     # follow / kill remote app or dev server
```

The script drives `pnpm tauri` (the CLI pinned in `devDependencies` — no `cargo install
tauri-cli`) and expects the box to provide Rust, Node 24 and the WebKitGTK/GTK dev headers.
Sync uses `rsync` when both ends have it and falls back to `tar` otherwise.

## The Linux box

The current box is **[Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker)** (separate repo): Ubuntu 26.04 + **Cinnamon 6.4 on X11** (Xvfb `:1`) in Docker for arm64, with noVNC, native VNC (multi-client `x11vnc`), SSH and a ready Tauri v2 toolchain. That is where the app is compiled and looked at now.

| | |
|---|---|
| Repo | [YanxReal/Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker) (`make install`) |
| noVNC / VNC / SSH | `http://localhost:6080/vnc.html` · `localhost:5902` · `ssh ubuntu-arm` (`~/.ssh/config` alias, user `admin`, key auth) |
| Project path | `/workspace/Tauri-react-template` (bind-mounted `./workspace`) |
| Launch GUI apps | `dev <cmd>` wrapper (injects `DISPLAY=:1` + `XAUTHORITY` + `DBUS_SESSION_BUS_ADDRESS`) |
| AI control | `assistant` CLI — `shot`/`region` (real X11 capture), `ocr`, `click`/`type`/`key` (real `xdotool` input), `windows`/`winmove`, `record`, `wd` (isolated GTK) |

`make build-linux` covers the whole loop: sync + fast debug build + launch in the GUI
session + `assistant` verification (window list, screenshot, OCR). Deep background: the
`linux-build` skill (`SKILL.md` + `references/box.md`).

Defaults are already `ubuntu-arm` + `/workspace/Tauri-react-template` (the repo
checkout; the binary name follows `src-tauri/Cargo.toml` `[package] name`), so the
make targets need no env. Override with `LINUX_REMOTE=<host>` /
`LINUX_BUILD_DIR=<dir>` when needed. The box may ship a newer pnpm than the pinned
`pnpm@10.34.5` — harmless: every install runs with `--frozen-lockfile`, so the
lockfile stays authoritative.

### Retired in-repo box (`docker/linux-gnome` + `scripts/linux-box.sh`)

Removed: the X11/Xvfb `ubuntu-vnc` box used to live in this repo but was
deleted in favour of Ubuntu-arm-docker above (faster rebuilds, real X11 session
with actual capture + input for the AI via `assistant`, no image to maintain
here). If you still see `ubuntu-vnc` in an old `~/.ssh/config`, drop those two
`Host` blocks — the only alias in use is `ubuntu-arm`.

## Windows cross-compile (`cargo-xwin`)

`scripts/build-windows.sh [--bundles nsis] [tauri build args]` builds the Windows x64 bundle from macOS **or** Linux — it resolves the platform's LLVM/lld toolchain and the rustup-managed Rust itself, then calls `pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles nsis`.

One-time setup: `brew install llvm lld makensis` on macOS, or `sudo apt install llvm lld nsis` on Linux (`makensis`/`nsis` only needed for the NSIS bundle), plus `cargo install cargo-xwin --locked` and `rustup target add x86_64-pc-windows-msvc`. Outputs: `src-tauri/target/x86_64-pc-windows-msvc/release/tauri-react-template.exe` (app) and `.../bundle/nsis/tauri-react-template_0.1.0_x64-setup.exe` (installer; ~200 MB because `webviewInstallMode: offlineInstaller` embeds WebView2).

Notes: the MSI/WiX bundler only runs on a Windows host (`--bundles nsis` is the macOS/Linux default); installer signing also needs Windows unless you set `bundle > windows > signCommand`. `cargo xwin check --target x86_64-pc-windows-msvc` is the fast way to type-check the Windows-only code paths.

## Xcode helper

`scripts/Xcode/apple-xcode.sh` (see `scripts/README.md:46` — Xcode unified section):

- Resolves `DEVELOPMENT_TEAM` sentinel → real ID (env `DEVELOPMENT_TEAM` > `scripts/.team-id` > omitted).
- Runs the vendored CLI `ios init` → `src-tauri/gen/apple`.
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

## CI (weekly, free-tier friendly)

`.github/workflows/ci.yml` runs **once a week** (Monday 18:00 UTC) plus manual
`workflow_dispatch` — never on push/PR. It only invokes Makefile targets:
`make ci-frontend` (typecheck + lint + test + build) and `make ci-rust`
(fmt + clippy + test) on ubuntu-latest; mobile and native Tauri bundles stay
out of CI (the 5-OS pipeline runs on the maintainer's machine / Linux box).
Husky + lint-staged still guard every commit.

## Node / pnpm pinning

- `.nvmrc` + `.node-version` — Node 24
- `.npmrc` — pnpm settings
- `pnpm-lock.yaml` frozen on install (`--frozen-lockfile`)

Next: [Troubleshooting →](./troubleshooting.md)
