# tauri-react-template

**Tauri v2 + React 19 multi-platform starter** — one codebase, native windows on macOS, Windows, Linux, iOS and Android, with bilingual docs (EN/ES) and an agent contract.

[![Tauri 2](https://img.shields.io/badge/tauri-2-FFC131?logo=tauri&logoColor=white)](https://tauri.app)
[![React 19](https://img.shields.io/badge/react-19-61DAFB?logo=react&logoColor=white)](https://react.dev)
[![Node 24](https://img.shields.io/badge/node-%3E%3D24-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![pnpm 10](https://img.shields.io/badge/pnpm-%3E%3D10-F69220?logo=pnpm&logoColor=white)](https://pnpm.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> 🌐 **Language:** **English** | [Español](README.es.md)

[Overview](#-overview) • [Features](#-features) • [Requirements](#-requirements) • [Quick Start](#-quick-start) • [Window model](#-window-model) • [Configuration](#-configuration) • [Make Targets](#-make-targets) • [Verification](#-verification) • [Security](#-security) • [Troubleshooting](#-troubleshooting) • [Roadmap](#-roadmap) • [Documentation](#-documentation) • [Docs](docs/en/README.md)

---

## Table of Contents

1. [Overview](#-overview)
2. [Features](#-features)
3. [Requirements](#-requirements)
4. [Quick Start](#-quick-start)
5. [Project structure](#-project-structure)
6. [Window model](#-window-model)
7. [Configuration](#-configuration)
8. [Make Targets](#-make-targets)
9. [Development workflow](#-development-workflow)
10. [Verification](#-verification)
11. [Data & Persistence](#-data--persistence)
12. [Security](#-security)
13. [Troubleshooting](#-troubleshooting)
14. [Roadmap](#-roadmap)
15. [Documentation](#-documentation)
16. [Contributing](#-contributing)
17. [License](#-license)
18. [Acknowledgements](#-acknowledgements)
19. [Links](#-links)

---

## 🔭 Overview

A private template for shipping a **native-feel desktop + mobile app** from a single React codebase. Every window is drawn per-OS (macOS Overlay traffic lights, Windows frameless + Snap Layouts, Linux frameless, unified iOS/macOS Xcode target, Android emulator), with the full matrix covered by docs, checks and scripts.

| | |
|---|---|
| 🖥️ **Five targets** | macOS, Windows, Linux, iOS, Android from one codebase |
| 📐 **Native chrome** | App-drawn 44px titlebar on Win/Linux, Overlay lights on macOS |
| 🌐 **Bilingual** | UI (i18next EN/ES) + mirrored `docs/en` + `docs/es` + agent parity rule |
| 🤖 **Agent-ready** | `AGENTS.md` contract: invariants, parity checklist, verify gates |
| 🧰 **Tooled** | Make-driven dev, Linux box over SSH, Xcode regen script, CI on 3 OS |

---

## ✨ Features

- **React 19.2 + Vite 8.2 + TypeScript 5.9 (strict)**, Tailwind v4.3, Biome 2.5, Vitest 4 + Testing Library, Turborepo 2.10 monorepo (`apps/*`, `packages/*`).
- **Design system** (`packages/ui`): 45 shadcn components + einui liquid-glass (`glass-*`), OKLCH tokens, Inter Variable.
- **i18n**: `i18next` + browser detector + `localStorage` cache, `en.json`/`es.json`, header toggle syncs `document.documentElement.lang`.
- **HTML5 semantics**: landmarks, skip link, labelled nav — tested (`App.test.tsx`).
- **Tauri v2 backend**: `greet` / `platform_info` / `start_window_resize` / `window_effects_set` commands, `plugin-opener`, `prevent-default` (`Flags::debug()`).
- **Crystal effect**: native translucency toggle (macOS vibrancy, Windows Mica), independent from glass cards; forced OFF on Linux.
- **Unified iOS + macOS Xcode target** (`tauri-react-template_Apple`): debug / hotreload / release configs, `DEVELOPMENT_TEAM` auto-injection, vendored CLI 2.12.0 + documented local tweaks (`MODS.md`).

---

## 📦 Requirements

| Dependency | Version | Install | Required |
|---|---|---|---|
| **Node.js** | ≥ 24 | `nvm use` / nodejs.org | ✅ |
| **pnpm** | ≥ 10 | `corepack enable && corepack prepare pnpm@latest --activate` | ✅ |
| **Rust** | stable 1.85+ | `rustup` (or Homebrew `rust`) | ✅ |
| **rustup targets** | iOS/Android triples | `rustup show` (`rust-toolchain.toml`) | ◻️ mobile only |
| **Xcode** | 26+ | App Store | ◻️ iOS/macOS builds |
| **xcodegen** | latest | `brew install xcodegen` | ◻️ Xcode regen |
| **Android SDK** | cmdline-tools + emulator + arm64 image | Android Studio | ◻️ Android only |
| **cargo-xwin + LLVM** | latest | `cargo install cargo-xwin --locked`, `brew install llvm lld` | ◻️ Windows cross-compile |
| **Docker** | Desktop 4.x | — | ◻️ Linux box only |
| **cargo-tauri 2.12.0** | vendored + tweaks | `make install-tauri-cli` | ◻️ iOS flows |

> Windows-only note: the MSI/WiX bundler and installer signing need a Windows host; from macOS/Linux use `--bundles nsis`.

---

## 🚀 Quick Start

```bash
# 0. Toolchain
node --version   # v24.x
pnpm --version   # 10.x
rustc --version  # 1.85+

# 1. Clone + install
git clone https://github.com/YanxReal/tauri-react-template.git
cd tauri-react-template
pnpm install
# Done in ~1m (581 packages) + `husky` prepare hook

# 2. Web only (Vite :1420 + HMR :1421)
pnpm dev:web     # or: pnpm --filter web dev

# 3. Desktop app (needs Rust)
make dev          # or: pnpm tauri:dev

# 4. Checks (all must pass)
pnpm typecheck && pnpm lint && pnpm test && pnpm build
```

iOS / Android / Linux-box flows live under [Window model](#-window-model), [Make Targets](#-make-targets) and [`docs/en/scripts.md`](docs/en/scripts.md).

---

## 📁 Project structure

```
.
├── apps/web                 # Vite React app (semantic HTML, i18n)
│   ├── index.html           # meta, OG, theme-color
│   └── src/
│       ├── App.tsx          # header/main/section/footer + i18n
│       ├── i18n/            # en.json / es.json
│       ├── components/layout/{header,hero,features,footer}.tsx
│       └── test/setup.ts
├── packages/ui              # design system (shadcn + glass-*)
│   └── src/{components,lib,styles/globals.css}
├── src-tauri/               # Tauri v2 backend (Rust)
│   ├── src/lib.rs           # commands + per-OS setup
│   ├── capabilities/        # default.json + windows.json
│   ├── tauri.conf.json      # base (merged with tauri.{os}.conf.json)
│   ├── vendor/              # tauri-cli 2.12.0 + templates (see MODS.md)
│   └── Info.plist           # template for macOS + iOS
├── scripts/                 # build-linux.sh, box-shot.sh, Xcode/, ...
├── docs/en + docs/es        # mirrored docs (parity rule)
├── MODS.md                  # CLI vendor modifications (root)
├── AGENTS.md                # agent contract
├── biome.json               # formatter + linter (no ESLint)
└── turbo.json               # pipeline
```

`src-tauri/gen/` is autogen (gitignored) — never edit it; edit the template instead.

---

## 🪟 Window model

One 44px app-drawn titlebar (drag band + caption buttons) on Win/Linux; native chrome elsewhere:

| OS | Frame | Corners | Resize | Notes |
|---|---|---|---|---|
| **macOS** | `titleBarStyle: Overlay`, `hiddenTitle` | native | native + HuLa 3-mechanism traffic-light fix | 52px band, dots at `17.5/39.5/61.5` |
| **Windows** | frameless + `tauri-plugin-decorum` | `DWMWCP_ROUND` | native (`WM_NCHITTEST`) | Snap Layouts on maximize hover (620 ms) |
| **Linux** | frameless, opaque | **square by design** | app 6px edge → `begin_resize_drag` | glass OFF (WebKitGTK veto) |
| **iOS** | unified `_Apple` target | — | — | sim via `cargo tauri`, device via `--host` |
| **Android** | emulator AVD | — | — | `make dev-android-emulator` |

Details: [`docs/en/native-feel.md`](docs/en/native-feel.md) · [`docs/en/mobile.md`](docs/en/mobile.md) · [`docs/en/tauri.md`](docs/en/tauri.md)

---

## ⚙️ Configuration

All settings live in env / `Makefile` vars / `.env`-style files (nothing hardcoded):

| Variable | Default | Description |
|---|---|---|
| `DEVELOPMENT_TEAM` / `scripts/.team-id` | — (manual in Xcode) | iOS signing team, injected on regen |
| `TAURI_CLI` | `@tauri-apps/cli@2.12.0` | CLI for `--build` regen flows |
| `XCODEGEN` | `xcodegen` | Xcode project generator binary |
| `IOS_DEVICE` | `iPhone 17` | Simulator/device selector |
| `IOS_DEV_HOST` | link-local auto-detect | Dev host for physical iPhone (USB) |
| `ANDROID_AVD` / `ANDROID_TARGET` | `Resizable_Experimental` / `aarch64` | Emulator + arch |
| `ANDROID_HOME` | `~/Library/Android/sdk` | SDK location |
| `LINUX_BUILD_REMOTE` / `LINUX_BUILD_DIR` | `ubuntu-arm` / `/workspace/tauri-react-template` | Linux SSH build box ([Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker)) |
| `APPLE_SIGNING_IDENTITY` / `src-tauri/keys/macos-signing-identity.txt` | — (optional) | Stable macOS signing identity |

> After editing, `make reload`-style flows are per-target (`make restart`, regen scripts); nothing is read at runtime except `localStorage` theme/i18n keys.

---

## 🛠️ Make Targets

```bash
make dev                  # tauri dev (desktop)
make dev:web              # pnpm --filter web dev
make dev:ios              # pnpm tauri ios dev "iPhone 17" (simulator)
make dev-ios-physical     # cargo tauri ios dev + --host (USB iPhone)
make dev-android-emulator # boot AVD + pnpm tauri android dev
make gen-apple            # regenerate src-tauri/gen/apple (xcodegen)
make install-tauri-cli    # build vendor/tauri-cli → ~/.cargo/bin/cargo-tauri
make lint / make build    # aliases
```

---

## 🔧 Development workflow

```tsx
// i18n — never hardcode user-facing strings
const { t, i18n } = useTranslation()
t("hero.title") // EN/ES auto
await i18n.changeLanguage("es")
```

```bash
# shadcn (land in packages/ui/src/components)
pnpm dlx shadcn@latest add button -c apps/web
```

```tsx
import { Button } from "@workspace/ui/components/button"
```

```bash
# Tauri plugin: JS package + Cargo dep + capability
pnpm --filter web add @tauri-apps/plugin-xxx
# then: tauri-plugin-xxx = "2" in Cargo.toml + capabilities JSON
```

---

## ✅ Verification

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
```

Then test **scroll + click + no-zoom** in a real bundle per OS (`pnpm tauri:build`, `scripts/build-linux.sh`, `scripts/build-windows.sh`) — full matrix: [`docs/en/testing.md`](docs/en/testing.md). Gates run locally (no CI) — see Verification above.

---

## 💾 Data & Persistence

| Path | Type | Purpose |
|---|---|---|
| `src-tauri/gen/` | autogen (gitignored) | Xcode/Android projects — regenerable, never edit |
| `src-tauri/target/` | build (gitignored) | cargo output (incl. `target/tauri-cli/`) |
| `node_modules/`, `dist/` | build (gitignored) | deps + bundles |
| `dist-linux/` | fetched (gitignored) | bundles copied back from the Linux box |
| `scripts/.team-id` | local (gitignored) | persistent Apple Team ID |
| `tauri-*` Docker volumes | named volumes | cargo/pnpm caches of the minimal Linux box |
| [Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker) | separate repo | current Linux box (Ubuntu 26.04 + GNOME 50, Tauri toolchain) — project at `/workspace/tauri-react-template` |

Box volumes live in the Ubuntu-arm-docker compose project (`admin-home`, `ssh-host-keys`); this repo has no destroy target.

---

## 🔐 Security

> Intended as a **private template** — defaults favor local development speed.

- **CSP**: strict `default-src 'self'` policies ship on the Windows/macOS configs; base + mobile configs use `csp: null` — tighten before any public release.
- **`prevent-default`**: `Flags::debug()` keeps context menu/devtools/reload in **debug** and blocks everything (Ctrl+P/S, zoom, native menu) in **release**. Verify you test the release profile.
- **Ports**: dev servers listen on all interfaces (`host: true`, needed for iOS LAN reload) — `1420` (Vite) + `1421` (HMR). Don't expose them beyond your LAN.
- **Signing**: Team ID and macOS identity live in gitignored files, never in the repo.
- **Dev boxes**: default VNC/SSH passwords (`dev`/`admin`) are local-only conveniences behind `127.0.0.1` — change them + use SSH keys for anything beyond localhost.

---

## 🆘 Troubleshooting

| Symptom | Fix |
|---|---|
| Garbled terminal (`35;22;36M`) | Use `make dev` (direct Vite, no Turbo TUI); `reset` to recover |
| Traffic lights jump on resize | Check HuLa trio (`lib.rs:205/331` + 60 fps poll) + Overlay config |
| No caption buttons / Snap Layouts (Win) | Check `platform` resolve + `default.json` permits + `windows.json` decorum permit |
| Yellow glitches / RAM on Linux | Glass stays OFF (veto); keep `WEBKIT_DISABLE_DMABUF_RENDERER=1` |
| Port 1420 in use | Kill the stray Vite before `hotreload` scheme |
| `pnpm install` fails | Node ≥ 24 + pnpm ≥ 10 (`package.json:engines`) |
| iOS `EBADARCH` / arch mismatch | `make install-tauri-cli`, then `cargo tauri` (not `pnpm tauri`) |

Full table: [`docs/en/troubleshooting.md`](docs/en/troubleshooting.md)

---

## 🗺️ Roadmap

- [ ] Right-edge resize on Wayland: confirm serial-vs-detection, then fix + verify all 8 edges
- [ ] Verify frameless Linux on real hardware (NVIDIA/Wayland + X11 sessions)
- [ ] iOS physical-device pipeline end-to-end (Team ID + USB iPhone)
- [ ] Android release bundle + store metadata path
- [ ] Plan A degraded glass on Linux (spec'd in native-feel, not implemented)

---

## 📚 Documentation

Full guides live in [`docs/en/`](docs/en/README.md) (mirror: [`docs/es/`](docs/es/README.md)) — same pages, same order, both languages:

| Doc | Audience | Covers |
|---|---|---|
| [Getting Started](docs/en/getting-started.md) | Everyone | Requirements, install, first run, builds |
| [Architecture](docs/en/architecture.md) | New contributors | Monorepo map, entry points, config layering |
| [Frontend](docs/en/frontend.md) | Web devs | App shell, providers, shadcn, conventions |
| [Tauri Backend](docs/en/tauri.md) | Rust devs | Commands, setup per OS, plugins |
| [Styling](docs/en/styling.md) | Web devs | Tokens, dark mode, shell, glass system |
| [i18n](docs/en/i18n.md) | Web devs | Locales, toggle, adding languages |
| [Mobile](docs/en/mobile.md) | iOS/Android devs | Xcode target, configs, emulator |
| [Native Feel](docs/en/native-feel.md) | Window work | Per-OS chrome, guards, vibrancy, scrollbars |
| [Scripts](docs/en/scripts.md) | Everyone | `package.json`, Makefile, build scripts, CI |
| [Testing](docs/en/testing.md) | Everyone | Unit, Rust, manual per-OS matrix |
| [Troubleshooting](docs/en/troubleshooting.md) | Stuck? | Symptom → fix tables |
| [Contributing](docs/en/contributing.md) | Contributors | Conventions, parity, gates |
| [Changelog](docs/en/changelog.md) | Curious | Full evolution, commit by commit |

Parity rule: every `en/` page has an identical-structure `es/` mirror (`AGENTS.md` §3).

---

## 🤝 Contributing

```bash
git checkout -b feat/my-change
# code + mirrored docs/en + docs/es (parity rule — see AGENTS.md §3)
pnpm typecheck && pnpm lint && pnpm test && pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
# open a PR with the parity checklist
```

Rules that matter: **bilingual docs parity** (every `en/` change needs its `es/` mirror), **no `src-tauri/gen/` edits**, **cross-platform invariants** (`AGENTS.md` §4.3). Gates run locally.

---

## 📄 License

MIT © tauri-react-template — see [LICENSE](LICENSE). Private template for personal use:

```bash
gh repo create tauri-react-template --private --source=. --push
```

---

## 🙏 Acknowledgements

- [Tauri](https://tauri.app/) + [wry](https://github.com/tauri-apps/wry)/[tao](https://github.com/tauri-apps/tao) for the webview runtime
- [shadcn/ui](https://ui.shadcn.com) + [einui](https://ui.eindev.ir) for the design system
- [decorum](https://github.com/clearlysid/tauri-plugin-decorum) for the Windows overlay titlebar
- [noVNC](https://github.com/novnc/noVNC) for browser-based testing

---

## 🔗 Links

- **Repo:** https://github.com/YanxReal/tauri-react-template
- **Docs:** [`docs/en/README.md`](docs/en/README.md) · [`docs/es/README.md`](docs/es/README.md) · [router](docs/README.md)
- **Tauri v2:** https://tauri.app · **Vite:** https://vite.dev · **Tailwind:** https://tailwindcss.com · **Biome:** https://biomejs.dev
