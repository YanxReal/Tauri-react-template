# Tauri React Template — Documentation (EN)

> **Audience:** anyone using this template — start at [Getting Started](./getting-started.md).
> Agents: read [`AGENTS.md`](../../AGENTS.md) first (parity rule EN ↔ ES).

## Contents

| Doc | Audience | Covers |
|---|---|---|
| [Getting Started](./getting-started.md) | Everyone | Requirements, install, first run, builds |
| [Architecture](./architecture.md) | New contributors | Monorepo map, entry points, config layering |
| [Frontend](./frontend.md) | Web devs | App shell, providers, shadcn, conventions |
| [Tauri Backend](./tauri.md) | Rust devs | Commands, setup per OS, plugins |
| [Styling](./styling.md) | Web devs | Tokens, dark mode, shell, glass system |
| [i18n](./i18n.md) | Web devs | Locales, toggle, adding languages |
| [Mobile](./mobile.md) | iOS/Android devs | Xcode target, configs, emulator |
| [Native Feel](./native-feel.md) | Window work | Per-OS chrome, guards, vibrancy, scrollbars |
| [Scripts](./scripts.md) | Everyone | `package.json`, Makefile, build scripts, CI |
| [Testing](./testing.md) | Everyone | Unit, Rust, manual per-OS matrix |
| [Troubleshooting](./troubleshooting.md) | Stuck? | Symptom → fix tables |
| [Contributing](./contributing.md) | Contributors | Conventions, parity, gates |
| [Changelog](./changelog.md) | Curious | Full evolution, commit by commit |
| [Tauri v3 Preview](./v3-preview.md) | Roadmap | Preview branch: gradual v3 adoption (alpha tracking) |

## Stack at a glance

Tauri v2 + React 19 + Vite 8 + Tailwind v4 + TypeScript strict + Biome + Vitest + i18next (EN/ES). Rust 1.85+. Details: [Architecture](./architecture.md).

## 30-second start

```bash
pnpm install && pnpm dev:web   # web on http://localhost:1420
make dev                        # desktop app (needs Rust)
```

Full steps with expected outputs: [Getting Started](./getting-started.md).

Next: [Getting Started →](./getting-started.md)
