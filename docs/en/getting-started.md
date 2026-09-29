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
| **cargo-tauri (vendored CLI)** | 2.12.0 | `make install-tauri-cli` | ◻️ Xcode/Android gen |
| **Android SDK** | cmdline-tools + emulator + arm64 image | Android Studio | Android only |
| **Docker** | Desktop 4.x | — | Linux box only |
| **cargo-tauri 2.12.0** | vendored + tweaks | `make install-tauri-cli` | iOS flows |

`package.json:engines` enforces Node + pnpm.

## Cross-platform build matrix

Which desktop/mobile targets each **development OS** can produce. Tauri builds the
backend against the host's native webview + bundlers, so the hard limits are set by
the OS, not the template:

| Build on → produces | macOS | Windows | Linux | **iOS** | **Android** |
|---|---|---|---|---|---|
| **macOS** (Apple Silicon) | ✅ native | ⚠️ cross (`cargo-xwin`) | ❌ needs a Linux box | ✅ **only place it's possible** (Xcode) | ✅ |
| **Windows** | ❌ | ✅ native | ❌ | ❌ **not possible** (no Xcode) | ✅ |
| **Linux** | ❌ | ⚠️ cross (`cargo-xwin`) | ✅ native | ❌ **not possible** (no Xcode) | ✅ |

Key rules (source: [`Tauri prerequisites`](https://v2.tauri.app/start/prerequisites)):

- **iOS requires Xcode → only a macOS host can build it.** "iOS development requires
  Xcode and is only available on macOS." Windows and Linux cannot produce an iOS build.
- **macOS desktop → only on macOS** (AppKit + Xcode aren't on other OSes).
- **Linux desktop → only on Linux** (needs `webkit2gtk`; the deb/rpm/AppImage bundlers
  only run on Linux). This is the one target a macOS developer cannot build locally →
  it goes to the Linux box (`make build-linux` — the `linux-build` skill).
- **Android → buildable on all three OSes** (Android Studio/SDK/NDK/JDK exist on
  macOS, Windows and Linux).
- **Windows desktop → native on Windows; cross-compiled from macOS/Linux via
  `cargo-xwin`** (`scripts/build-windows.sh`). Installer signing + MSI still need a
  Windows host.

## Installation

```bash
git clone <your-repo> Tauri-react-template
cd Tauri-react-template
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
# Linux box (separate repo):
#   cd ../Ubuntu-arm-docker && make install   # Ubuntu 26.04 + Cinnamon (X11) desktop
#   ssh ubuntu-arm                             # admin, key auth
```

### Environment variables

Public vars are embedded at compile time by `src-tauri/build.rs` (`EMBED_KEYS`):
`VITE_API_URL`. Provide it via `src-tauri/.env` (gitignored) or process env.
Extend `EMBED_KEYS` in `build.rs` for your own public vars.

## Build

```bash
pnpm build            # turbo build → apps/web/dist
pnpm tauri:build      # Tauri bundle (all targets in bundle.targets)
```

Per-OS shells: **Linux** via the `linux-build` skill (`make build-linux` / `make linux-release`
— SSH to the box, no native build) and `./scripts/build-windows.sh` (`cargo-xwin` cross-compile, NSIS;
MSI/WiX needs a Windows host). Details: [Scripts](./scripts.md).

## IDE

VS Code + `tauri-vscode` + `rust-analyzer` + `biome` + `tailwindcss`
(see `.vscode/extensions.json`). Recommended settings (`formatOnSave` +
`source.fixAll.biome`) live in `.vscode/settings.json`.

## Publish to a remote repo

```bash
gh repo create Tauri-react-template --public --source=. --push
# or (public, or create it private on GitHub first and use SSH):
git remote add origin git@github.com:YOUR_USER/Tauri-react-template.git
git push -u origin master
```

Next: [Architecture →](./architecture.md)
