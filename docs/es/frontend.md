# Frontend (`apps/web`)

> **Audiencia:** devs web — React 19 + Vite 8 + TypeScript 5.9 estricto + shadcn/Base UI. Fuente en `apps/web/src`.

## App shell

`App.tsx:1` es la UI raíz:

- `app-shell` recorta (no scrollea); `.app-scroll` — el único hijo que scrollea — lleva `main` + `Footer`, así el header queda fuera de la scrollbar. Marco por SO: frameless + caption buttons propios en Windows **y** Linux, titlebar Overlay con traffic lights en macOS (ver [Sensación nativa](./native-feel.md)).
- Landmarks semánticos: `<header><nav><main><section><footer>` + skip-link + nav etiquetada + `role=status` para el output de greet.
- `Header` — nav, toggle de idioma, toggle de tema, `GlassControls` (vibrancy + tarjetas glass, dos switches independientes); renderiza `WindowControls` en Win/Linux.
- `Hero` / `Features` — secciones de marketing, keys i18n.
- Sección `status` — demo de `invoke("greet")` con traducción ES (`App.tsx:35`) y fallback glass-vs-sólido (`effectiveGlass`).

`main.tsx:1` arranca los providers (anidados `Theme → Vibrancy → GlassCards → App`, compuestos una sola vez en `app-providers.tsx:14` — también los usa `App.test.tsx`) más la config [i18n](./i18n.md) y `globals.css`. `TitleBar` monta las clases `html.titlebar*` (ver [Estilos](./styling.md)).

Guards nativos en `main.tsx:21`: `dragstart` → bloqueado, `ctrl/meta + wheel` → bloqueado (zoom lock), externos `a[href^=http]` → `openUrl` vía `plugin-opener` (nunca dentro del webview).

## Config Vite

`vite.config.ts:1`: plugins `react()` + `tailwindcss()`, `@` → `./src`, `:1420` + `strictPort` + `host: true` (todas las interfaces, para que pase el health-check LAN de `tauri ios dev`), HMR con `TAURI_DEV_HOST`, `watch.ignored: ["**/src-tauri/**"]`. Vitest: `jsdom` + `setupFiles`.

## Añadir un componente shadcn

```bash
pnpm dlx shadcn@latest add button -c apps/web
# cae en packages/ui/src/components (vendorizado, no publicado en npm)
```

```tsx
import { Button } from "@workspace/ui/components/button"
```

Personaliza en `packages/ui/src/components/*`. `components.json` apunta `aliases.ui` a `@workspace/ui`.

## Estado y libs UI

Iconos `lucide-react`; primitivas `@base-ui/react` + `radix-ui`; `framer-motion`, `recharts`, `embla-carousel`, `react-day-picker`, `zod`, `cmdk` (ver `packages/ui/package.json:12`).

## Testing

Modo run + watch de Vitest; los tests renderizan dentro de `AppProviders` (mismo stack que el arranque del webview — renderizar `App` a pelo lanza excepción). Matriz completa: [Testing](./testing.md).

## TypeScript y lint

```bash
pnpm --filter web typecheck     # tsc --noEmit
pnpm --filter web lint          # biome check .
```

`biome.json` excluye `src-tauri/vendor/**` y desactiva reglas dentro de `src-tauri/**` + internos shadcn; dos reglas CSS solo están off para `globals.css`, donde los overrides `!important` de plataforma son load-bearing.

## Convenciones

- `useTranslation()` + `t("ns.key")` — nunca hardcodees strings visibles.
- Prefiere componentes `@workspace/ui` antes que duplicados locales.
- Mantén los wrappers de layout finos; la lógica va en `hooks/` o providers.

Siguiente: [Backend Tauri →](./tauri.md)
