# Frontend (`apps/web`)

> **Audience:** web devs — React 19 + Vite 8 + TypeScript 5.9 strict + shadcn/Base UI. Source in `apps/web/src`.

## App shell

`App.tsx:1` is the root UI:

- `app-shell` clips (no scroll); `.app-scroll` — the only scrolling child — holds `main` + `Footer`, so the header stays outside the scrollbar. Per-OS frame: frameless + app caption buttons on Windows **and** Linux, macOS Overlay titlebar with traffic lights (see [Native Feel](./native-feel.md)).
- Semantic landmarks: `<header><nav><main><section><footer>` + skip-link + labelled nav + `role=status` greet output.
- `Header` — nav, language toggle, theme toggle, `GlassControls` (vibrancy + glass cards, two independent switches); renders `WindowControls` on Win/Linux.
- `Hero` / `Features` — marketing sections, i18n keys.
- `status` section — demo `invoke("greet")` with ES translation (`App.tsx:37`) and glass-vs-solid fallback (`effectiveGlass`, `App.tsx:26`).

`main.tsx:1` bootstraps providers (nested `Theme → Vibrancy → GlassCards → App`, composed once in `app-providers.tsx:14` — also used by `App.test.tsx`) plus the [i18n](./i18n.md) config and `globals.css`. `TitleBar` mounts the `html.titlebar*` classes (see [Styling](./styling.md)).

Native guards in `main.tsx:21`: `dragstart` → blocked, `ctrl/meta + wheel` → blocked (zoom lock), external `a[href^=http]` → `openUrl` via `plugin-opener` (never inside the webview).

## Vite config

`vite.config.ts:1`: `react()` + `tailwindcss()` plugins, `@` → `./src`, `:1420` + `strictPort` + `host: true` (all interfaces, so `tauri ios dev`'s LAN health-check passes), HMR on `TAURI_DEV_HOST`, `watch.ignored: ["**/src-tauri/**"]`. Vitest: `jsdom` + `setupFiles`.

## Adding a shadcn component

```bash
pnpm dlx shadcn@latest add button -c apps/web
# lands in packages/ui/src/components (vendored, not npm-published)
```

```tsx
import { Button } from "@workspace/ui/components/button"
```

Customize in `packages/ui/src/components/*`. `components.json` points `aliases.ui` to `@workspace/ui`.

## State & UI libs

`lucide-react` icons; `@base-ui/react` + `radix-ui` primitives; `framer-motion`, `recharts`, `embla-carousel`, `react-day-picker`, `zod`, `cmdk` (see `packages/ui/package.json:12`).

## Testing

Vitest run + watch mode; tests render inside `AppProviders` (same stack as the webview boot — rendering `App` bare throws). Full matrix: [Testing](./testing.md).

## TypeScript & lint

```bash
pnpm --filter web typecheck     # tsc --noEmit
pnpm --filter web lint          # biome check .
```

`biome.json` excludes `src-tauri/vendor/**` and disables rules inside `src-tauri/**` + shadcn internals; two CSS rules are off only for `globals.css`, where the platform `!important` overrides are load-bearing.

## Conventions

- `useTranslation()` + `t("ns.key")` — never hardcode user-facing strings.
- Prefer `@workspace/ui` components over local duplicates.
- Keep layout wrappers thin; put logic in `hooks/` or providers.

Next: [Tauri Backend →](./tauri.md)
