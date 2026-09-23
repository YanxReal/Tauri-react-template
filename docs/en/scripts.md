# Scripts & Tooling

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
| `make dev-android-emulator` | Android APK → emulator |
| `make install-tauri-cli` | Builds vendored `src-tauri/vendor/tauri-cli-2.11.4` → `~/.cargo/bin/cargo-tauri` (Xcode 26 patch) |
| `make lint` / `make build` | aliases |

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

## Windows cross-compile (`cargo-xwin`)

`scripts/build-windows.sh [--bundles nsis] [tauri build args]` builds the Windows x64 bundle from macOS/Linux — it resolves the keg-only LLVM/lld paths itself and calls `pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles nsis`.

One-time setup: `brew install llvm lld makensis` (macOS; `makensis` is only needed for the NSIS bundle), `cargo install cargo-xwin --locked` and `rustup target add x86_64-pc-windows-msvc`. Outputs: `src-tauri/target/x86_64-pc-windows-msvc/release/tauri-react-template.exe` (app) and `.../bundle/nsis/tauri-react-template_0.1.0_x64-setup.exe` (installer; ~200 MB because `webviewInstallMode: offlineInstaller` embeds WebView2).

Notes: the MSI/WiX bundler only runs on a Windows host (`--bundles nsis` is the macOS/Linux default); installer signing also needs Windows unless you set `bundle > windows > signCommand`. `cargo xwin check --target x86_64-pc-windows-msvc` is the fast way to type-check the Windows-only code paths.

## Xcode helper

`scripts/Xcode/apple-xcode.sh` (`scripts/README.md:8`):

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

## CI

`.github/workflows/frontend.yml:1` — on PR/push touching `apps/web/**`, `packages/**`: `pnpm install` → `typecheck` → `lint` → `test` → `build` (Node 24, pnpm 10).

`.github/workflows/rust.yml:1` — on PR/push touching `src-tauri/**`, `rust-toolchain.toml`: `cargo check` + `cargo fmt --check` (stable + cache).

## Node / pnpm pinning

- `.nvmrc` + `.node-version` — Node 24
- `.npmrc` — pnpm settings
- `pnpm-lock.yaml` frozen in CI (`--frozen-lockfile`)

Next: [Troubleshooting →](./troubleshooting.md)
