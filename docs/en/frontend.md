# Frontend (`apps/web`)

React 19 + Vite 8 + TypeScript 5.9 strict + shadcn/Base UI. Source in `apps/web/src`.

## App shell

`apps/web/src/App.tsx:1` is the root UI:

- `app-shell` (in `globals.css`) is the scroll container inside the frameless window (see `native-feel.md`).
- Semantic landmarks: `<header><nav><main><section><footer>` + skip-link + `aria-label` on nav + `role=status` greet output.
- `Header` — nav, language toggle, theme toggle, `VibrancyToggle`/`GlassEffectToggle`.
- `Hero` / `Features` — marketing sections, i18n keys.
- `status` section — demo `invoke("greet")` call with ES translation (`App.tsx:32`) and glass vs solid fallback (`effectiveGlass`).

`apps/web/src/main.tsx:1` bootstraps:

```tsx
import "@workspace/ui/globals.css"
import "./i18n/config.ts"
import { ThemeProvider } from "@/components/theme-provider.tsx"
import { VibrancyProvider } from "@/components/vibrancy-provider.tsx"
import { GlassCardsProvider } from "@/components/glass-cards-provider.tsx"
```

Providers are nested `Theme → Vibrancy → GlassCards → App`. TitleBar (`components/layout/title-bar.tsx`) mounts `html.titlebar*` classes (see `styling.md`).

Native guards in `main.tsx:17`:

- `dragstart` → `preventDefault`
- `wheel` with `ctrl/meta` → `preventDefault` (zoom lock, extra to `tauri-plugin-prevent-default` + viewport)
- External `a[href^=http]` → `openUrl` via `@tauri-apps/plugin-opener` (never inside the webview)

## Vite config

`apps/web/vite.config.ts:1`:

- `plugins: [react(), tailwindcss()]` (`@tailwindcss/vite`)
- `resolve.alias["@"]` → `./src`
- `server.port: 1420`, `strictPort: true`, `host: host || true` (listen on all interfaces so `tauri ios dev`'s health-check on the LAN IP passes), `hmr` on `TAURI_DEV_HOST` when present, `watch.ignored: ["**/src-tauri/**"]`
- `test` → `jsdom`, `globals`, `setupFiles: ["./src/test/setup.ts"]`, `css: true`

## Adding a shadcn component

```bash
pnpm dlx shadcn@latest add button -c apps/web
pnpm dlx shadcn@latest add dialog -c apps/web
# lands in packages/ui/src/components
```

Import:

```tsx
import { Button } from "@workspace/ui/components/button"
import { GlassCard } from "@workspace/ui/components/glass-card"
```

Customize in `packages/ui/src/components/*` — these are vendored, not npm-published. `components.json` points `aliases.ui` to `@workspace/ui`.

## State & UI libs

- `lucide-react` for icons
- `@base-ui/react` + `radix-ui` + `@radix-ui/*` primitives (switch, dialog, tabs, etc.)
- `framer-motion`, `recharts`, `embla-carousel`, `react-day-picker`, `zod`, `cmdk`, etc. already in `packages/ui/package.json:12`

## Testing

```bash
pnpm --filter web test          # vitest run
pnpm --filter web test:watch    # watch mode
pnpm test                       # turbo (all workspaces)
```

- Config at `vite.config.ts:37`
- Example `apps/web/src/App.test.tsx`, setup `src/test/setup.ts` (jest-dom)
- Coverage output `coverage/**` (turbo.json `test.outputs`)

## TypeScript & lint

```bash
pnpm --filter web typecheck     # tsc --noEmit
pnpm --filter web lint          # biome check .
pnpm lint                       # root turbo lint
```

`biome.json` disables lints/formatting inside `src-tauri/**` and shadcn internals (`overrides:66`).

## Conventions

- Use `useTranslation()` and `t("ns.key")` — never hardcode user-facing strings.
- Prefer `@workspace/ui` components over local duplicates.
- Keep `Header`/`Footer`/`Hero`/`Features` as thin layout wrappers; put logic in `hooks/` or providers.

Next: [Tauri Backend →](./tauri.md)
