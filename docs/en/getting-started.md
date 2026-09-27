# Getting Started

> **Audience:** first clone to first running app. Time: ~10 min (plus Rust builds).

## Requirements

| Tool | Version | Install | Needed for |
|---|---|---|---|
| **Node.js** | ≥ 24 | `nvm use` | everything |
| **pnpm** | ≥ 10 | `corepack enable && corepack prepare pnpm@latest --activate` | everything |
| **Rust** | stable 1.85+ | `rustup` (or Homebrew `rust`) | desktop / mobile builds |
| **rustup targets** | iOS + Android | `rustup show` (reads `rust-toolchain.toml`) | mobile only |
| **Xcode** | 26+ | App Store | iOS / macOS |
| **xcodegen** | latest | `brew install xcodegen` | Xcode regen |
| **Android SDK** | cmdline-tools + emulator + arm64 image | Android Studio | Android only |
| **Docker** | Desktop 4.x | — | Linux box only |
| **cargo-tauri 2.12.0** | vendored + tweaks | `make install-tauri-cli` | iOS flows |

`package.json:engines` enforces Node + pnpm.

## Installation

```bash
git clone <your-repo> tauri-react-template
cd tauri-react-template
pnpm install
# Done in ~1m · 581 packages · husky prepare hook
```

Verify the install (all green before you continue):

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
```

## Development

### Web only (fastest)

```bash
pnpm dev:web
# Vite on http://localhost:1420, HMR on :1421 (no Turbo TUI)
```

`pnpm dev` (= `turbo dev`) also works but enables Turbo's TUI mouse mode
(`?1000h`) — `tauri dev` kills it with `SIGTERM` and leaves the terminal
garbled (`35;22;36M`). `tauri.conf.json:build` already uses the direct form:

```json
{
  "beforeDevCommand": "pnpm --filter web dev",
  "devUrl": "http://localhost:1420",
  "beforeBuildCommand": "pnpm build",
  "frontendDist": "../apps/web/dist"
}
```

### Desktop (Tauri)

```bash
make dev          # tauri dev + window centering + signing identity
# or: pnpm tauri:dev
```

### Mobile and Linux box

iOS simulator / device, Android emulator and the Linux SSH box each have
their own flow — see [Mobile](./mobile.md) and [Scripts](./scripts.md):

```bash
make dev:ios                # iPhone simulator
make dev-android-emulator   # boot AVD + android dev
./scripts/linux-box.sh up   # start the Linux box
```

### Environment variables

Public vars are embedded at compile time by `src-tauri/build.rs` (`EMBED_KEYS`):
`VITE_API_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `VITE_SUPABASE_URL`,
`VITE_SUPABASE_ANON_KEY`. Provide them via `src-tauri/.env` (gitignored) or
process env. In **release**, `SUPABASE_URL` must be `https://*.supabase.co`
or the build panics (`build.rs:135`).

## Build

```bash
pnpm build            # turbo build → apps/web/dist
pnpm tauri:build      # Tauri bundle (all targets in bundle.targets)
```

Per-OS shells: `./scripts/build-linux.sh` (bundles + optional `--run` on the
Linux box) and `./scripts/build-windows.sh` (`cargo-xwin` cross-compile, NSIS;
MSI/WiX needs a Windows host). Details: [Scripts](./scripts.md).

## IDE

VS Code + `tauri-vscode` + `rust-analyzer` + `biome` + `tailwindcss`
(see `.vscode/extensions.json`). Recommended settings (`formatOnSave` +
`source.fixAll.biome`) live in `.vscode/settings.json`.

## Private repo setup

```bash
gh repo create tauri-react-template --private --source=. --push
# or:
git remote add origin git@github.com:YOUR_USER/tauri-react-template.git
git push -u origin master
```

Next: [Architecture →](./architecture.md)
