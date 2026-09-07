# Tauri React Template — Documentación (ES)

Plantilla bilingüe: **Tauri v2 + React 19 + Vite 8 + Tailwind v4** — starter privado listo para escritorio (macOS, Windows, Linux) y móvil (iOS, Android).

## Índice

| # | Documento | Qué encontrarás |
|---|-----------|-----------------|
| 1 | [Primeros pasos](./getting-started.md) | Requisitos, instalación, comandos dev / build |
| 2 | [Arquitectura](./architecture.md) | Estructura del monorepo, workspaces, Turborepo, alias |
| 3 | [Frontend](./frontend.md) | `apps/web` — Vite, React, routing, testing |
| 4 | [Backend Tauri](./tauri.md) | `src-tauri` — Rust, comandos, config, capabilities |
| 5 | [Estilos y theming](./styling.md) | Tailwind v4, globals.css, OKLCH, dark mode, glass |
| 6 | [i18n](./i18n.md) | i18next EN/ES, añadir locales, flujo de traducción |
| 7 | [Móvil](./mobile.md) | iOS (target unificado Xcode) y Android, hot-reload |
| 8 | [Sensación nativa](./native-feel.md) | Traffic lights, drag, bloqueo de zoom, vibrancy/Mica, sombras en Linux |
| 9 | [Scripts y tooling](./scripts.md) | Makefile, helpers Xcode, Biome, Husky, CI |
| 10 | [Solución de problemas](./troubleshooting.md) | Errores comunes y soluciones por OS |
| 11 | [Contribuir](./contributing.md) | Convenciones, regla de paridad, checks de calidad |
| 12 | [Changelog](./changelog.md) | Historial completo de git (20 commits) con rationale |

> **Idioma:** Este es el árbol en español. El espejo en inglés está en [`../en/README.md`](../en/README.md). **Regla de paridad:** cada cambio aquí debe reflejarse en `en/` y viceversa — ver [`/AGENTS.md`](../../AGENTS.md:1).

## Stack de un vistazo

- **Runtime:** Node `>=24`, pnpm `>=10`, Rust stable `1.85+` (edition 2021)
- **Frontend:** React `19.2`, Vite `8.2`, TypeScript `5.9` strict, Tailwind `4.3` (`@tailwindcss/vite`), Biome `2.5`, Vitest `4` + Testing Library, i18next
- **Desktop:** Tauri `2.11` (`@tauri-apps/api` + `plugin-opener`), `window-vibrancy 0.8`
- **Monorepo:** Turborepo `2.10`, workspaces `apps/*` + `packages/*`, alias `@` → `apps/web/src`, `@workspace/ui/*`
- **UI:** shadcn + Base UI (`@base-ui/react`), primitivas Radix, `Inter Variable`

## Inicio en 30 segundos

```bash
pnpm install
pnpm dev          # web en http://localhost:1420
pnpm tauri:dev    # Tauri desktop (necesita Rust)
pnpm build        # turbo build
pnpm typecheck && pnpm lint && pnpm test
```

Siguiente: [Primeros pasos →](./getting-started.md)
