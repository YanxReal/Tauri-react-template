# Tauri-react-template

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
4. [What you can build per OS](#-what-you-can-build-per-os)
5. [Quick Start](#-quick-start)
6. [Project structure](#-project-structure)
7. [Window model](#-window-model)
8. [Configuration](#-configuration)
9. [Make Targets](#-make-targets)
10. [Development workflow](#-development-workflow)
11. [Verification](#-verification)
12. [Data & Persistence](#-data--persistence)
13. [Security](#-security)
14. [Troubleshooting](#-troubleshooting)
15. [Roadmap](#-roadmap)
16. [Documentation](#-documentation)
17. [Contributing](#-contributing)
18. [License](#-license)
19. [Acknowledgements](#-acknowledgements)
20. [Links](#-links)

---

## 🔭 Overview

A public template for shipping a **native-feel desktop + mobile app** from a single React codebase. Every window is drawn per-OS (macOS Overlay traffic lights, Windows frameless + Snap Layouts, Linux frameless, unified iOS/macOS Xcode target, Android emulator), with the full matrix covered by docs, checks and scripts.

| | |
|---|---|
| 🖥️ **Five targets** | macOS, Windows, Linux, iOS, Android from one codebase |
| 📐 **Native chrome** | App-drawn 44px titlebar on Win/Linux, Overlay lights on macOS |
| 🌐 **Bilingual** | UI (i18next EN/ES) + mirrored `docs/en` + `docs/es` + agent parity rule |
| 🤖 **Agent-ready** | `AGENTS.md` contract: invariants, parity checklist, verify gates |
| 🧰 **Tooled** | Make-driven dev, Linux box over SSH, Xcode regen script, weekly CI |

---

## ✨ Features

- **React 19.3 + Vite 8.3 + TypeScript 7.0 (strict)**, Tailwind v4.3, Biome 2.5, Vitest 5 + Testing Library, Turborepo 2.11 monorepo (`apps/*`, `packages/*`).
- **Design system** (`packages/ui`): 45 shadcn components + einui liquid-glass (`glass-*`), OKLCH tokens, Inter Variable.
- **i18n**: `i18next` + browser detector + `localStorage` cache, `en.json`/`es.json`, header toggle syncs `document.documentElement.lang`.
- **HTML5 semantics**: landmarks, skip link, labelled nav — tested (`App.test.tsx`).
- **Tauri v2 backend**: `greet` / `platform_info` / `start_window_resize` / `window_effects_set` commands, `plugin-opener`, `prevent-default` (`Flags::debug()`).
- **Crystal effect**: native translucency toggle (macOS vibrancy, Windows Mica), independent from glass cards; forced OFF on Linux.
- **Unified iOS + macOS Xcode target** (`tauri-react-template_Apple`): debug / release configs, `DEVELOPMENT_TEAM` auto-injection, vendored CLI 2.12.0 + documented local tweaks (`.claude/skills/tauri-cli-rebase/references/mods.md`).

---

## 📦 Requirements

| Dependency | Version | Install | Required |
|---|---|---|---|
| **Node.js** | ≥ 24 | `nvm use` / nodejs.org | ✅ |
| **pnpm** | ≥ 10 | `corepack enable && corepack prepare pnpm@latest --activate` | ✅ |
| **Rust** | stable 1.85+ | `rustup` (or Homebrew `rust`) | ✅ |
| **rustup targets** | iOS/Android triples | `rustup show` (`rust-toolchain.toml`) | ◻️ mobile only |
| **Xcode** | 26+ | App Store | ◻️ iOS/macOS builds |
| **cargo-tauri (vendored CLI)** | 2.12.0 | `make install-tauri-cli` | ◻️ Xcode/Android gen |
| **Android SDK** | cmdline-tools + emulator + arm64 image | Android Studio | ◻️ Android only |
| **cargo-xwin + LLVM** | latest | `cargo install cargo-xwin --locked`, `brew install llvm lld` | ◻️ Windows cross-compile |
| **Docker** | Desktop 4.x | — | ◻️ Linux box only |
| **cargo-tauri 2.12.0** | vendored + tweaks | `make install-tauri-cli` | ◻️ iOS flows |

> Windows-only note: the MSI/WiX bundler and installer signing need a Windows host; from macOS/Linux use `--bundles nsis`.

## 🔀 What you can build per OS

The OS you develop on decides what you can ship — native webviews + bundlers are
per-platform, and **iOS requires Xcode (macOS only)**. So:

| Develop on → produce | macOS | Windows | Linux | **iOS** | **Android** |
|---|---|---|---|---|---|
| **macOS** (Apple Silicon) | ✅ native | ⚠️ cross (`cargo-xwin`) | ❌ Linux box | ✅ only on macOS | ✅ |
| **Windows** | ❌ | ✅ native | ❌ | ❌ no iOS (no Xcode) | ✅ |
| **Linux** | ❌ | ⚠️ cross (`cargo-xwin`) | ✅ native | ❌ no iOS (no Xcode) | ✅ |

- Only **macOS** builds iOS (Xcode); Windows/Linux can't.
- **macOS** and **Linux** desktop apps build only on their own OS; a macOS dev uses the
  Linux box for Linux bundles (`make build-linux` / `make linux-release` — the `linux-build` skill).
- **Android** builds on all three (Android Studio SDK/NDK/JDK).
- **Windows** cross-compiles from macOS/Linux via `cargo-xwin` (`scripts/build-windows.sh`);
  MSI + installer signing stay Windows-only.

See [`docs/en/getting-started.md`](docs/en/getting-started.md) for the full matrix.

---

## 🚀 Quick Start

```bash
# 0. Toolchain
node --version   # v24.x
pnpm --version   # 10.x
rustc --version  # 1.85+

# 1. Clone + install
git clone https://github.com/YanxReal/Tauri-react-template.git
cd Tauri-react-template
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

## 🔁 Keep in sync with the template

When this template releases a new version, update your app **without breaking your own code, renames, or customizations** using the bundled `template-update` skill (Anthropic Agent Skills format — works in Claude Code, OpenAI Codex, and OpenCode):

```bash
make install-skills                # install all project agent skills
make install-skills SKILLS_GLOBAL=1  # same, for all your projects
```

The version you are on is tracked in `TEMPLATE_VERSION` at the repo root. The skill's safe-update protocol (snapshot → classify template-owned vs user-owned → consent → apply → verify invariants + identifiers → gates green before bump) is documented in `.claude/skills/template-update/SKILL.md`; the ownership semantics live in `.claude/skills/template-update/references/ownership.md`.

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
└── src-tauri/               # Tauri v2 backend (Rust)
│   ├── src/lib.rs           # commands + per-OS setup
│   ├── capabilities/        # default.json + windows.json
│   ├── tauri.conf.json      # base (merged with tauri.{os}.conf.json)
│   ├── vendor/              # tauri-cli 2.12.0 + templates (see .claude/skills/tauri-cli-rebase/references/mods.md)
│   └── Info.plist           # template for macOS + iOS
├── scripts/                 # Xcode/, Android/, build-windows.sh, ...
├── docs/en + docs/es        # mirrored docs (parity rule)
├── .claude/skills/linux-build  # Linux builds over SSH (skill) + script
├── .claude/skills/tauri-cli-rebase  # vendored CLI rebase skill + spec
├── AGENTS.md                # agent contract
├── biome.json               # formatter + linter (no ESLint)
├── turbo.json               # pipeline
├── TEMPLATE_VERSION         # which template release this app is on
├── branding.json            # single source of truth for app identity (make rebrand)
└── .claude/skills/          # agent skills (template-update) — Claude/Codex/OpenCode
```

`src-tauri/gen/` is autogen (gitignored) — never edit it; edit the template instead.

---

## 🪟 Window model

One 44px app-drawn titlebar (drag band + caption buttons) on Win/Linux; native chrome elsewhere:

| OS | Frame | Corners | Resize | Notes |
|---|---|---|---|---|
| **macOS** | `titleBarStyle: Overlay`, `hiddenTitle` | native | native + HuLa 3-mechanism traffic-light fix | 52px band, dots at `17.5/39.5/61.5` |
| **Windows** | frameless + `tauri-plugin-decorum` | `DWMWCP_ROUND` | native (`WM_NCHITTEST`) | Snap Layouts on maximize hover (620 ms) |
| **Linux** | frameless, opaque | **square by design** | app 8px edge → `begin_resize_drag` | glass OFF (WebKitGTK veto) |
| **iOS** | unified `_Apple` target | — | — | sim via `cargo tauri`, device via `--host` |
| **Android** | emulator AVD | — | — | `make dev-android-emulator` |

Details: [`docs/en/native-feel.md`](docs/en/native-feel.md) · [`docs/en/mobile.md`](docs/en/mobile.md) · [`docs/en/tauri.md`](docs/en/tauri.md)

---

## ⚙️ Configuration

All settings live in env / `Makefile` vars / `.env`-style files (nothing hardcoded):

| Variable | Default | Description |
|---|---|---|
| `DEVELOPMENT_TEAM` / `scripts/.team-id` | — (manual in Xcode) | iOS signing team, injected on regen |
| `CARGO_TAURI` | vendored `cargo-tauri` (`~/.cargo/bin`) | CLI for mobile init/build (via `make install-tauri-cli`) |
| `IOS_DEVICE` | `iPhone 18 Pro` | Simulator/device selector |
| `IOS_DEV_HOST` | link-local auto-detect | Dev host for physical iPhone (USB) |
| `ANDROID_AVD` / `ANDROID_DEVICE` | `Resizable_Experimental` | Emulator + target device (adb model/AVD name) |
| `ANDROID_HOME` | `~/Library/Android/sdk` | SDK location |
| `LINUX_BUILD_REMOTE` / `LINUX_BUILD_DIR` | `ubuntu-arm` / `/workspace/Tauri-react-template` | Linux SSH build box ([Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker)) |
| `APPLE_SIGNING_IDENTITY` / `src-tauri/keys/macos-signing-identity.txt` | — (optional) | Stable macOS signing identity |

> After editing, `make reload`-style flows are per-target (`make restart`, regen scripts); nothing is read at runtime except `localStorage` theme/i18n keys.

---

## 🛠️ Make Targets

```bash
make dev                  # tauri dev (desktop)
make dev:web              # pnpm --filter web dev
make dev:ios              # pnpm tauri ios dev "iPhone 18 Pro" (simulator)
make dev-ios-physical     # cargo tauri ios dev + --host (USB iPhone)
make dev-android-emulator # boot AVD + pnpm tauri android dev
make gen-apple            # regen src-tauri/gen/apple (Xcode, branding-aware)
make gen-android          # regen src-tauri/gen/android (branding-aware)
make build-windows        # Windows cross-compile (cargo-xwin), debug
make install-tauri-cli    # build vendor/tauri-cli → ~/.cargo/bin/cargo-tauri
make install-skills       # install all project agent skills
make rebrand              # propagate branding.json identity everywhere
make lint / make build    # aliases
make help / make doctor   # list commands / check toolchain
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

Then test **scroll + click + no-zoom** in a real bundle per OS (`pnpm tauri:build`, `make build-linux` / `make linux-release` — Linux via the `linux-build` skill —, `scripts/build-windows.sh`) — full matrix: [`docs/en/testing.md`](docs/en/testing.md). A weekly scheduled CI (`.github/workflows/ci.yml`, Monday 18:00 UTC + manual dispatch) runs the JS+Rust gates via `make ci-frontend` / `make ci-rust`; gates also run locally — see Verification above.

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
| [Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker) | separate repo | current Linux box (Ubuntu 26.04 + Cinnamon 6.4 on X11/Xvfb, Tauri toolchain) — project at `/workspace/Tauri-react-template` |

Box volumes live in the Ubuntu-arm-docker compose project (`admin-home`, `ssh-host-keys`); this repo has no destroy target.

---

## 🔐 Security

> Intended as a **public starting point** — defaults favor local development speed.

- **CSP**: one strict `default-src 'self'` policy ships on **all four targets** (base + per-OS merged): Tauri IPC only in `connect-src`.
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
| Port 1420 in use | Kill the stray Vite before a dev build |
| `pnpm install` fails | Node ≥ 24 + pnpm ≥ 10 (`package.json:engines`) |
| iOS `EBADARCH` / arch mismatch | `make install-tauri-cli`, then `cargo tauri` (not `pnpm tauri`) |

Full table: [`docs/en/troubleshooting.md`](docs/en/troubleshooting.md)

---

## 🗺️ Roadmap

This roadmap only announces **future value for the template** — nothing here
is operational backlog. It is about what the *starting point* of your project
will offer next. What is already shipped lives in the changelog.

### Phase A — Ready for v3 (now → Tauri v3 stable)

Tauri v3 is in alpha (`3.0.0-alpha.x`, Sept 2026): GTK4/WebKitGTK 6.0 on
Linux, swappable webview runtimes (wry / CEF), MSRV 1.95 + edition 2024,
modern updater and ACL. Everything below keeps the template ahead of the jump
instead of catching up:

- **Two release lines**: `main` stays on stable v2, a `v3-preview` branch
  tracks the v3 alphas/betas so the migration is exercised continuously (the
  container + VMs already verify every reload).
- **Linux GTK4 plan documented in advance**: frameless window, resize band,
  app theme bridge and glass fallback are re-designed for GTK4/WebKitGTK 6.0
  before the stable jump.
- **Auto-update today on v2**: `tauri-plugin-updater` integrated with signing
  docs (macOS/Linux/Windows) — adopters ship updates from day one.

### Phase B — Tauri v3 adoption (when stable)

The headline item. The template moves to v3 as one coherent change:

- Full migration in one commit: runtime crates (`tauri-runtime-wry`), MSRV
  1.95 / edition 2024, new ACL, modern updater, per-runtime devtools.
- **Linux GTK4 rework** completed and verified in the container + real
  Wayland sessions.
- **Optional CEF profile** (`make init --runtime cef`): the same Chromium
  rendering on every desktop for complex UIs, packaged with the vendored-CLI
  rebase flow.
- Vendored CLI v3 + `tauri-cli-rebase` skill updated, 5-OS matrix
  re-verified on real bundles.

### Phase C — Beyond v3

- Bilingual docs site (static, from `docs/en` + `docs/es`) and a scaffold
  installer (`pnpm create tauri-react-template`).
- Store publishing runbooks using the release APIs (App Store Connect,
  Google Play, MSIX).
- **AI-ready template**: agent skills + MCP so any AI agent can clone,
  rebrand, and publish the template with zero friction.
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

Rules that matter: **bilingual docs parity** (every `en/` change needs its `es/` mirror), **no `src-tauri/gen/` edits**, **cross-platform invariants** (`AGENTS.md` §4.3). Gates run weekly in CI + locally.

---

## 📄 License

MIT © Tauri-react-template — see [LICENSE](LICENSE).

---

## 🙏 Acknowledgements

- [Tauri](https://tauri.app/) + [wry](https://github.com/tauri-apps/wry)/[tao](https://github.com/tauri-apps/tao) for the webview runtime
- [shadcn/ui](https://ui.shadcn.com) + [einui](https://ui.eindev.ir) for the design system
- [decorum](https://github.com/clearlysid/tauri-plugin-decorum) for the Windows overlay titlebar

---

## 🔗 Links

- **Repo:** https://github.com/YanxReal/Tauri-react-template
- **Docs:** [`docs/en/README.md`](docs/en/README.md) · [`docs/es/README.md`](docs/es/README.md) · [router](docs/README.md)
- **Tauri v2:** https://tauri.app · **Vite:** https://vite.dev · **Tailwind:** https://tailwindcss.com · **Biome:** https://biomejs.dev
