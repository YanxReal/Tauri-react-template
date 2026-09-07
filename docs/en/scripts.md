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
