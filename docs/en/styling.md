# Styling & Theming

Single source of truth: `packages/ui/src/styles/globals.css:1`. Imported once in `apps/web/src/main.tsx:5` as `@workspace/ui/globals.css`.

## Stack

- **Tailwind v4** via `@tailwindcss/vite` (`apps/web/vite.config.ts:1`, `packages/ui/package.json:60`).
- No `tailwind.config.*` — config lives in CSS via `@theme inline` (`globals.css:11`) and `shadcn/tailwind.css`.
- Fonts: `Inter Variable` via `@fontsource-variable/inter` (`globals.css:4`).
- Animations: `tw-animate-css`.

## Tokens (OKLCH)

`globals.css:54` defines `:root` and `.dark` tokens (OKLCH):

- `background`, `foreground`, `card`, `popover`, `primary`, `secondary`, `muted`, `accent`, `destructive`, `border`, `input`, `ring`, `chart-*`, `sidebar-*`, `radius`.
- `@theme inline` maps them to Tailwind tokens (`--color-*`, `--radius-*`, `--font-sans`).

Use `bg-background`, `text-foreground`, `border-border`, etc. Never hardcode hex for themed surfaces.

## Dark mode

- Provider: `apps/web/src/components/theme-provider.tsx` (adds `html.dark` / `html.light`, syncs with `prefers-color-scheme`, persists in localStorage).
- `globals.css:89` `.dark` overrides.
- Glass overrides: `html.light.glass-cards` inverts `bg-white/10`, `text-white`, etc. to dark ink for light-mode glass (`globals.css:344`).

## Layout shell

Window shell pattern (`globals.css:209`):

- `html.titlebar` / `html.titlebar-mac` / `html.titlebar-win` / `html.linux` — mounted by `TitleBar` component (Tauri desktop only).
- `html.titlebar body { background: transparent }` — window shape is native.
- `.app-shell` — the **window shell**: `height: 100dvh; overflow: hidden; background: var(--background)`. It clips everything (header included) and **does not scroll**. macOS rounds it via CSS (`border-radius: 10px`) for the transparent Overlay titlebar. Linux and Windows run frameless (`decorations: false`) so both stay square — DWM rounds Windows, Linux keeps the system square corners by design. No GTK frame, no radius. Never add `margin` here: an inset would show cut corners.
- `.app-scroll` (`globals.css:231`) — the **scroll container** (`flex: 1 1 auto; min-height: 0; overflow-y: auto`) and the **only** one on desktop. It wraps `main` + `Footer`, i.e. content only. The header lives **outside** it: it is the titlebar, so the scrollbar can never steal width from it nor paint over the caption buttons. In the browser build the div is inert and the document scrolls, which is why the header keeps `md:sticky`.
- **Scrollbars are native, never styled.** `::-webkit-scrollbar` rules are deliberately absent: they would force classic bars (gutter + arrow buttons) and kill the overlay. Windows uses `scrollBarStyle: "fluentOverlay"` (`tauri.windows.conf.json:13`), macOS keeps its auto-hiding overlay and Linux WebKitGTK follows `gtk-overlay-scrolling` — all three are thin pills floating over the content edge.

## Glass / crystal system

Three layers (`globals.css:171`, `269`):

1. **Vibrancy / Mica** (native): `html.vibrancy body` / `html.vibrancy .app-shell` — `color-mix(in oklab, var(--background) 32%, transparent)` (42% in light) so translucency is visible. Header gets `blur(16px)` on macOS only (`html.titlebar-mac.vibrancy .app-header`); Windows Mica already has material. Linux disables blur.
2. **Glass cards** (web): `GlassCard` in `@workspace/ui/components/glass-card.tsx` (`bg-white/10`, `backdrop-blur`, etc.). In light mode `html.light.glass-cards` remaps to dark ink. In Linux `html.linux .glass-card` strips `backdrop-filter` and falls back to `var(--card)`.
3. **Two independent switches**: `GlassControls` (`apps/web/src/components/layout/glass-controls.tsx`) renders `VibrancyToggle` (native material, hidden if `!supported`) and `GlassCardsToggle` (web `glass-*` components, disabled on Linux) side by side. Either works alone — vibrancy with solid cards, glass cards on an opaque window, or both.

Provider chain: `VibrancyProvider` (`vibrancy-provider.tsx` — `localStorage: vibrancy`, default ON where supported, calls `invoke("window_effects_set")`) → `GlassCardsProvider` (`glass-cards-provider.tsx` — `localStorage: glass-cards`, default OFF).

## Native-feel overrides (condensed)

`globals.css:132` — `* { user-select:none; -webkit-user-drag:none }` except inputs; `html,body { touch-action: pan-x pan-y }` (native scroll, no pinch-zoom).

`globals.css:258` — Linux veto: `backdrop-filter: none !important` on `.app-header` / `.app-shell` (WebKitGTK blur is expensive and glitchy). Linux has no GTK frame (frameless + opaque); `.app-shell` stays square. `globals.css:253` also hides the titlebar decorum injects on Windows.

See `docs/en/native-feel.md` for the full rationale per OS.

## Adding styles

- New tokens: add to `:root` + `.dark` + `@theme inline` in `globals.css`.
- New components: use `class-variance-authority` + `clsx` + `tailwind-merge` (`cn` in `packages/ui/src/lib/utils.ts:1`).
- Avoid `@apply` for one-offs — prefer Tailwind classes in JSX.
- Target glass in light mode via `html.light.glass-cards .your-class` if needed.

Next: [i18n →](./i18n.md)
