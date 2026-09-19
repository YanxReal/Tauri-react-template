# Scripts y tooling

## Scripts raíz

`package.json:11`:

| Comando | Ejecuta |
|---------|---------|
| `pnpm dev` | `turbo dev` (web, TUI) |
| `pnpm build` | `turbo build` |
| `pnpm lint` | `biome check .` |
| `pnpm lint:fix` | `biome check --write .` |
| `pnpm format` / `pnpm format:check` | igual que lint (Biome también formatea) |
| `pnpm typecheck` | `turbo typecheck` |
| `pnpm test` | `turbo test` (vitest) |
| `pnpm tauri` | `tauri` (passthrough CLI) |
| `pnpm tauri:dev` / `pnpm tauri:build` | `tauri dev` / `tauri build` |

`Makefile`:

| Target | Efecto |
|--------|--------|
| `make dev` | `tauri dev` (desktop), respeta `APPLE_SIGNING_IDENTITY` |
| `make dev:web` | `pnpm --filter web dev` |
| `make dev:ios` | `pnpm tauri ios dev "iPhone 17"` (sim, usa `IOS_DEVICE`) |
| `make dev-ios-physical` | `cargo tauri ios dev "iPhone 17" --host $(IOS_DEV_HOST)` (necesita `make install-tauri-cli`) |
| `make dev-android-emulator` | APK debug → emulator |
| `make install-tauri-cli` | Compila `src-tauri/vendor/tauri-cli-2.11.4` → `~/.cargo/bin/cargo-tauri` (parche Xcode 26) |
| `make lint` / `make build` | alias |

Shells por OS: `scripts/build-linux.sh`, `scripts/build-windows.sh`, `scripts/Xcode/apple-xcode.sh`.

## Cross-compile Windows (`cargo-xwin`)

`scripts/build-windows.sh [--bundles nsis] [args de tauri build]` construye el bundle Windows x64 desde macOS/Linux — resuelve él mismo las rutas keg-only de LLVM/lld y llama a `pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles nsis`.

Setup una sola vez: `brew install llvm lld makensis` (macOS; `makensis` solo hace falta para el bundle NSIS), `cargo install cargo-xwin --locked` y `rustup target add x86_64-pc-windows-msvc`. Salidas: `src-tauri/target/x86_64-pc-windows-msvc/release/tauri-react-template.exe` (app) y `.../bundle/nsis/tauri-react-template_0.1.0_x64-setup.exe` (instalador; ~200 MB porque `webviewInstallMode: offlineInstaller` embebe WebView2).

Notas: el bundler MSI/WiX solo corre en un host Windows (`--bundles nsis` es el default en macOS/Linux); firmar el instalador también requiere Windows salvo que definas `bundle > windows > signCommand`. `cargo xwin check --target x86_64-pc-windows-msvc` es la vía rápida para type-checkear el código Windows.

## Helper Xcode

`scripts/Xcode/apple-xcode.sh` (`scripts/README.md:8`):

- Resuelve el sentinel `DEVELOPMENT_TEAM` → ID real (env `DEVELOPMENT_TEAM` > `scripts/.team-id` > omitido).
- Corre `xcodegen` → `src-tauri/gen/apple`.
- Con `--build` también compila iOS sim + macOS host.

Ver `docs/es/mobile.md` para configs y el parche `cargo-mobile2` de Xcode 26.

## Lint y format (Biome)

`biome.json:1`:

- `formatter: indentStyle space, indentWidth 2, lineWidth 80, lineEnding lf`
- `linter.rules: preset recommended` + `noUnusedVariables:warn`, `noExplicitAny:warn`, `useImportType:error`
- `javascript.formatter: quoteStyle double, semicolons asNeeded, trailingCommas es5`
- `overrides`: desactiva linter/formatter dentro de `src-tauri/**` y `packages/ui/src/components/**` + `apps/web/src/components/*.tsx`

```bash
pnpm lint
pnpm lint:fix
pnpm format:check
biome check --write .   # directo
```

## Git hooks

`package.json:23` `prepare: husky`:

- `.husky/pre-commit` → `lint-staged`
- `lint-staged:25` — `*.{ts,tsx,js,jsx,json,jsonc,css}` → `biome check --write --no-errors-on-unmatched`

## CI

`.github/workflows/frontend.yml:1` — en PR/push que toque `apps/web/**`, `packages/**`: `pnpm install` → `typecheck` → `lint` → `test` → `build` (Node 24, pnpm 10).

`.github/workflows/rust.yml:1` — en PR/push que toque `src-tauri/**`, `rust-toolchain.toml`: `cargo check` + `cargo fmt --check` (stable + cache).

## Pines Node / pnpm

- `.nvmrc` + `.node-version` — Node 24
- `.npmrc` — ajustes pnpm
- `pnpm-lock.yaml` frozen en CI (`--frozen-lockfile`)

Siguiente: [Solución de problemas →](./troubleshooting.md)
