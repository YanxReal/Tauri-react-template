# Tauri React Template — Documentation (EN)

Bilingual template: **Tauri v2 + React 19 + Vite 8 + Tailwind v4** — private starter ready for desktop (macOS, Windows, Linux) and mobile (iOS, Android).

## Contents

| # | Document | What you will find |
|---|----------|--------------------|
| 1 | [Getting Started](./getting-started.md) | Requirements, install, dev / build commands |
| 2 | [Architecture](./architecture.md) | Monorepo layout, workspaces, Turborepo, aliases |
| 3 | [Frontend](./frontend.md) | `apps/web` — Vite, React, routing, testing |
| 4 | [Tauri Backend](./tauri.md) | `src-tauri` — Rust, commands, config, capabilities |
| 5 | [Styling & Theming](./styling.md) | Tailwind v4, globals.css, OKLCH, dark mode, glass |
| 6 | [i18n](./i18n.md) | i18next EN/ES, adding locales, translation workflow |
| 7 | [Mobile](./mobile.md) | iOS (Xcode unified target) & Android, hot-reload |
| 8 | [Native Feel](./native-feel.md) | Traffic lights, drag, zoom lock, vibrancy/Mica, Linux shadows |
| 9 | [Scripts & Tooling](./scripts.md) | Makefile, Xcode helpers, Biome, Husky, CI |
| 10 | [Troubleshooting](./troubleshooting.md) | Common pitfalls and fixes per OS |
| 11 | [Contributing](./contributing.md) | Conventions, parity rule, quality checks |
| 12 | [Changelog](./changelog.md) | Full git history (20 commits) with design rationale |

> **Language:** This is the English tree. Spanish mirror lives at [`../es/README.md`](../es/README.md). **Parity rule:** every change here must be mirrored in `es/` and vice-versa — see [`/AGENTS.md`](../../AGENTS.md:1).

## Stack at a glance

- **Runtime:** Node `>=24`, pnpm `>=10`, Rust stable `1.85+` (edition 2021)
- **Frontend:** React `19.2`, Vite `8.2`, TypeScript `5.9` strict, Tailwind `4.3` (`@tailwindcss/vite`), Biome `2.5`, Vitest `4` + Testing Library, i18next
- **Desktop:** Tauri `2.11` (`@tauri-apps/api` + `plugin-opener`), `window-vibrancy 0.8`
- **Monorepo:** Turborepo `2.10`, workspaces `apps/*` + `packages/*`, alias `@` → `apps/web/src`, `@workspace/ui/*`
- **UI:** shadcn + Base UI (`@base-ui/react`), Radix primitives, `Inter Variable`

## 30-second start

```bash
pnpm install
pnpm dev          # web on http://localhost:1420
pnpm tauri:dev    # Tauri desktop (needs Rust)
pnpm build        # turbo build
pnpm typecheck && pnpm lint && pnpm test
```

Next: [Getting Started →](./getting-started.md)
