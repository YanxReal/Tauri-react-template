# Tauri React Template — Documentación (ES)

> **Audiencia:** quien use esta plantilla — empieza en [Primeros pasos](./getting-started.md).
> Agentes: lee [`AGENTS.md`](../../AGENTS.md) primero (regla de paridad EN ↔ ES).

## Contenidos

| Doc | Audiencia | Contenido |
|---|---|---|
| [Primeros pasos](./getting-started.md) | Todos | Requisitos, instalación, primera ejecución, builds |
| [Arquitectura](./architecture.md) | Nuevos contribuidores | Mapa del monorepo, entry points, capas de config |
| [Frontend](./frontend.md) | Devs web | App shell, providers, shadcn, convenciones |
| [Backend Tauri](./tauri.md) | Devs Rust | Comandos, setup por SO, plugins |
| [Estilos](./styling.md) | Devs web | Tokens, modo oscuro, shell, sistema glass |
| [i18n](./i18n.md) | Devs web | Locales, toggle, añadir idiomas |
| [Móvil](./mobile.md) | Devs iOS/Android | Target Xcode, configs, emulador |
| [Sensación nativa](./native-feel.md) | Trabajo de ventana | Chrome por SO, guards, vibrancy, scrollbars |
| [Scripts](./scripts.md) | Todos | `package.json`, Makefile, scripts de build, CI |
| [Testing](./testing.md) | Todos | Unitarios, Rust, matriz manual por SO |
| [Solución de problemas](./troubleshooting.md) | ¿Atascado? | Tablas síntoma → arreglo |
| [Contribuir](./contributing.md) | Contribuidores | Convenciones, paridad, gates |
| [Changelog](./changelog.md) | Curiosos | Evolución completa, commit a commit |
| [Vista previa de Tauri v3](./v3-preview.md) | Roadmap | Rama preview: adopción gradual de v3 (seguimiento de alphas) |

## Stack de un vistazo

Tauri v2 + React 19 + Vite 8 + Tailwind v4 + TypeScript estricto + Biome + Vitest + i18next (EN/ES). Rust 1.85+. Detalle: [Arquitectura](./architecture.md).

## Arranque en 30 segundos

```bash
pnpm install && pnpm dev:web   # web en http://localhost:1420
make dev                        # app desktop (necesita Rust)
```

Pasos completos con salidas esperadas: [Primeros pasos](./getting-started.md).

Siguiente: [Primeros pasos →](./getting-started.md)
