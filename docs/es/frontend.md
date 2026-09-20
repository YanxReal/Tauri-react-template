# Frontend (`apps/web`)

React 19 + Vite 8 + TypeScript 5.9 strict + shadcn/Base UI. Fuente en `apps/web/src`.

## App shell

`apps/web/src/App.tsx:1` es la UI raíz:

- `app-shell` (en `globals.css`) es el shell de la ventana (recorta, no scrollea); `.app-scroll` — el único hijo que scrollea — lleva `main` + `Footer`, así el header queda fuera de la barra de scroll. Marco por OS: nativo en Linux, overlay de decorum + caption buttons propios en Windows, titlebar Overlay con traffic lights en macOS (ver `native-feel.md`).
- Landmarks semánticos: `<header><nav><main><section><footer>` + skip-link + `aria-label` en nav + `role=status` para el output de greet.
- `Header` — nav, toggle de idioma, toggle de tema, `GlassControls` (vibrancy + tarjetas glass, dos switches independientes), y en Windows los caption buttons (`window-controls.tsx`) porque la ventana es frameless.
- `Hero` / `Features` — secciones de marketing, keys i18n.
- Sección `status` — demo de `invoke("greet")` con traducción ES (`App.tsx:32`) y fallback glass vs sólido (`effectiveGlass`).

`apps/web/src/main.tsx:1` arranca:

```tsx
import "@workspace/ui/globals.css"
import "./i18n/config.ts"
import { ThemeProvider } from "@/components/theme-provider.tsx"
import { VibrancyProvider } from "@/components/vibrancy-provider.tsx"
import { GlassCardsProvider } from "@/components/glass-cards-provider.tsx"
```

Providers anidados `Theme → Vibrancy → GlassCards → App`, compuestos una sola vez en `apps/web/src/components/app-providers.tsx:14` (`AppProviders`) — los usan `main.tsx:51` y `App.test.tsx`. TitleBar (`components/layout/title-bar.tsx`) monta las clases `html.titlebar*` (ver `styling.md`).

Guards nativos en `main.tsx:21`:

- `dragstart` → `preventDefault`
- `wheel` con `ctrl/meta` → `preventDefault` (bloqueo de zoom, extra a `tauri-plugin-prevent-default` + viewport)
- Enlaces externos `a[href^=http]` → `openUrl` vía `@tauri-apps/plugin-opener` (nunca dentro del webview)

## Config de Vite

`apps/web/vite.config.ts:1`:

- `plugins: [react(), tailwindcss()]` (`@tailwindcss/vite`)
- `resolve.alias["@"]` → `./src`
- `server.port: 1420`, `strictPort: true`, `host: host || true` (escucha en todas las interfaces para que el health-check de `tauri ios dev` en la IP LAN pase), `hmr` en `TAURI_DEV_HOST` cuando existe, `watch.ignored: ["**/src-tauri/**"]`
- `test` → `jsdom`, `globals`, `setupFiles: ["./src/test/setup.ts"]`, `css: true`

## Añadir un componente shadcn

```bash
pnpm dlx shadcn@latest add button -c apps/web
pnpm dlx shadcn@latest add dialog -c apps/web
# cae en packages/ui/src/components
```

Import:

```tsx
import { Button } from "@workspace/ui/components/button"
import { GlassCard } from "@workspace/ui/components/glass-card"
```

Personaliza en `packages/ui/src/components/*` — están vendoreados, no publicados en npm. `components.json` apunta `aliases.ui` a `@workspace/ui`.

## Estado y libs UI

- `lucide-react` para iconos
- `@base-ui/react` + `radix-ui` + `@radix-ui/*` primitivas (switch, dialog, tabs, etc.)
- `framer-motion`, `recharts`, `embla-carousel`, `react-day-picker`, `zod`, `cmdk`, etc. ya en `packages/ui/package.json:12`

## Testing

```bash
pnpm --filter web test          # vitest run
pnpm --filter web test:watch    # watch mode
pnpm test                       # turbo (todos los workspaces)
```

- Config en `vite.config.ts:37`
- Ejemplo `apps/web/src/App.test.tsx`, setup `src/test/setup.ts` (jest-dom)
- Los tests renderizan `App` dentro de `AppProviders` (`apps/web/src/components/app-providers.tsx:14`) — mismo stack que el arranque del webview (`main.tsx:51`): Theme → Vibrancy → GlassCards. Renderizar `App` sin providers lanza error.
- Salida coverage `coverage/**` (turbo.json `test.outputs`)

## TypeScript y lint

```bash
pnpm --filter web typecheck     # tsc --noEmit
pnpm --filter web lint          # biome check .
pnpm lint                       # root turbo lint
```

`biome.json` excluye `src-tauri/vendor/**` (plantillas Handlebars vendoreadas que Biome no puede parsear) y desactiva lints/formatting dentro de `src-tauri/**` y los internos de shadcn (`overrides:68`). Dos reglas CSS (`noImportantStyles`, `noDescendingSpecificity`) están off solo en `packages/ui/src/styles/globals.css`, donde los overrides de plataforma con `!important` son load-bearing.

## Convenciones

- Usa `useTranslation()` y `t("ns.key")` — nunca hardcodees strings visibles.
- Prefiere componentes de `@workspace/ui` antes que duplicados locales.
- Mantén `Header`/`Footer`/`Hero`/`Features` como wrappers finos de layout; pon la lógica en `hooks/` o providers.

Siguiente: [Backend Tauri →](./tauri.md)
