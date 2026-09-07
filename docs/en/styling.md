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
- Glass overrides: `html.light.glass-cards` inverts `bg-white/10`, `text-white`, etc. to dark ink for light-mode glass (`globals.css:371`).

## Layout shell

Frameless-window pattern (`globals.css:184`):

- `html.titlebar` / `html.titlebar-mac` / `html.titlebar-win` / `html.linux` — mounted by `TitleBar` component (Tauri desktop only).
- `html.titlebar body { background: transparent }` — window shape is native.
- `.app-shell` — the **scroll container** (`height: 100dvh; overflow-y: auto; background: var(--background)`). Only macOS adds `border-radius: 10px` via CSS (Windows uses DWM, Linux via GTK/shadow).
- Header is `sticky top:0` inside `.app-shell`.

## Glass / crystal system

Three layers (`globals.css:171`, `307`):

1. **Vibrancy / Mica** (native): `html.vibrancy body` / `html.vibrancy .app-shell` — `color-mix(in oklab, var(--background) 32%, transparent)` (42% in light) so translucency is visible. Header gets `blur(16px)` on macOS only (`html.titlebar-mac.vibrancy .app-header`); Windows Mica already has material. Linux disables blur.
2. **Glass cards** (web): `GlassCard` in `@workspace/ui/components/glass-card.tsx` (`bg-white/10`, `backdrop-blur`, etc.). In light mode `html.light.glass-cards` remaps to dark ink. In Linux `html.linux .glass-card` strips `backdrop-filter` and falls back to `var(--card)`.
3. **Combined toggle**: `GlassEffectToggle` (`apps/web/src/components/layout/glass-effect-toggle.tsx`) controls `glass-cards` + `vibrancy` together. Linux forces OFF.

Provider chain: `VibrancyProvider` (`vibrancy-provider.tsx` — `localStorage: vibrancy`, default ON where supported, calls `invoke("window_effects_set")`) → `GlassCardsProvider` (`glass-cards-provider.tsx` — `localStorage: glass-cards`, default OFF).

## Native-feel overrides (condensed)

`globals.css:132` — `* { user-select:none; -webkit-user-drag:none }` except inputs; `html,body { touch-action: pan-x pan-y }` (native scroll, no pinch-zoom).

`globals.css:241` — Linux shadow: native only `html.linux .app-shell { border-radius:10px; overflow:hidden }` + GTK `decoration { box-shadow; margin }` in `lib.rs:315` (Wayland-safe `StyleContext::add_provider`), all 4 corners rounded.

See `docs/en/native-feel.md` for the full rationale per OS.

## Adding styles

- New tokens: add to `:root` + `.dark` + `@theme inline` in `globals.css`.
- New components: use `class-variance-authority` + `clsx` + `tailwind-merge` (`cn` in `packages/ui/src/lib/utils.ts:1`).
- Avoid `@apply` for one-offs — prefer Tailwind classes in JSX.
- Target glass in light mode via `html.light.glass-cards .your-class` if needed.

Next: [i18n →](./i18n.md)
