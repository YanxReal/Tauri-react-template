# Getting Started

## Requirements

| Tool | Version | Notes |
|------|---------|-------|
| Node.js | `>=24` | Enforced by `package.json:engines` |
| pnpm | `>=10` | `packageManager: pnpm@10.34.5` |
| Rust | `stable 1.85+` | `edition 2021`, see `rust-toolchain.toml` |
| Xcode | `26+` | Only for iOS/macOS targets |
| Android SDK/NDK | latest | Only for Android targets |

Install the Rust targets once:

```bash
rustup show   # installs from rust-toolchain.toml (iOS + Android targets)
```

## Installation

```bash
git clone <your-repo> tauri-react-template
cd tauri-react-template
pnpm install
```

Verify:

```bash
pnpm typecheck
pnpm lint
pnpm test
pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
```

## Development

### Web only (fastest)

```bash
pnpm dev              # turbo dev → Vite on http://localhost:1420
# or without Turbo TUI (useful when tauri dev kills the TUI):
pnpm --filter web dev
make dev:web
```

### Desktop (Tauri)

```bash
pnpm tauri:dev        # Tauri v2 dev (beforeDevCommand = pnpm --filter web dev)
make dev              # alias — also centers the window and handles signing identity
```

`src-tauri/tauri.conf.json:build` config:

```json
{
  "beforeDevCommand": "pnpm --filter web dev",
  "devUrl": "http://localhost:1420",
  "beforeBuildCommand": "pnpm build",
  "frontendDist": "../apps/web/dist"
}
```

Why `pnpm --filter web dev` and not `turbo dev`? Turbo enables its TUI (`?1000h` mouse mode). When `tauri dev` kills it with `SIGTERM` the terminal is left in mouse mode and prints `35;22;36M`. Direct Vite avoids that — see `docs/en/native-feel.md` and `src-tauri/src/lib.rs:410`.

### Environment variables

Public vars are embedded at compile time by `src-tauri/build.rs` (`EMBED_KEYS`):

- `VITE_API_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`

Provide them via:

- `src-tauri/.env` (gitignored, file is read at build time), or
- Process env (`cargo:rerun-if-env-changed`).

In **release**, `SUPABASE_URL` must be `https://` and host `*.supabase.co` or the build panics (see `build.rs:135`).

## Build

```bash
pnpm build            # turbo build → apps/web/dist
pnpm tauri:build      # Tauri bundle (all targets in bundle.targets)
cargo check --manifest-path src-tauri/Cargo.toml
```

Per-OS shells are available:

```bash
./scripts/build-linux.sh
./scripts/build-windows.sh
```

`scripts/build-linux.sh` builds the Linux bundles — and can compile and run the app — on a Linux dev box over SSH (`--remote [HOST]`, default `ubuntu-vnc`), or locally with `--native`. Details in `docs/en/scripts.md`.

`scripts/build-windows.sh` cross-compiles the Windows x64 bundle from macOS/Linux with `cargo-xwin` (NSIS installer; MSI/WiX needs a Windows host). One-time setup: `brew install llvm lld makensis`, `cargo install cargo-xwin --locked`, `rustup target add x86_64-pc-windows-msvc` — full details in `docs/en/scripts.md`.

## Scripts reference (root)

| Command | Effect |
|---------|--------|
| `pnpm dev` | `turbo dev` (web) |
| `pnpm build` | `turbo build` |
| `pnpm lint` / `pnpm lint:fix` | `biome check` / `biome check --write` |
| `pnpm format` / `pnpm format:check` | `biome check --write` / `biome check` |
| `pnpm typecheck` | `turbo typecheck` |
| `pnpm test` | `turbo test` (vitest) |
| `pnpm tauri:dev` / `pnpm tauri:build` | `tauri dev` / `tauri build` |
| `make dev` / `make dev:ios` / `make dev-ios-physical` | Desktop / iOS sim / iOS device |
| `make install-tauri-cli` | Builds vendored `cargo-tauri` with Xcode 26 patch |

## IDE

VS Code is the recommended editor — see `.vscode/settings.json:1` and `.vscode/extensions.json`:

- `tauri-vscode`, `rust-analyzer`, `biome`, `tailwindcss`
- `editor.formatOnSave` + `source.fixAll.biome` + `source.organizeImports.biome`

## Private repo setup

```bash
gh repo create tauri-react-template --private --source=. --push
# or
git remote add origin git@github.com:YOUR_USER/tauri-react-template.git
git push -u origin master
```

Next: [Architecture →](./architecture.md)
