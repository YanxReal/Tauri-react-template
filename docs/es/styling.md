# Estilos y theming

Única fuente de verdad: `packages/ui/src/styles/globals.css:1`. Se importa una vez en `apps/web/src/main.tsx:5` como `@workspace/ui/globals.css`.

## Stack

- **Tailwind v4** vía `@tailwindcss/vite` (`apps/web/vite.config.ts:1`, `packages/ui/package.json:60`).
- Sin `tailwind.config.*` — la config vive en CSS vía `@theme inline` (`globals.css:11`) y `shadcn/tailwind.css`.
- Fuente: `Inter Variable` vía `@fontsource-variable/inter` (`globals.css:4`).
- Animaciones: `tw-animate-css`.

## Tokens (OKLCH)

`globals.css:54` define `:root` y `.dark` (OKLCH):

- `background`, `foreground`, `card`, `popover`, `primary`, `secondary`, `muted`, `accent`, `destructive`, `border`, `input`, `ring`, `chart-*`, `sidebar-*`, `radius`.
- `@theme inline` los mapea a tokens Tailwind (`--color-*`, `--radius-*`, `--font-sans`).

Usa `bg-background`, `text-foreground`, `border-border`, etc. Nunca hardcodees hex para superficies tematizadas.

## Dark mode

- Provider: `apps/web/src/components/theme-provider.tsx` (añade `html.dark` / `html.light`, sincroniza con `prefers-color-scheme`, persiste en localStorage).
- `globals.css:89` overrides de `.dark`.
- Overrides glass: `html.light.glass-cards` invierte `bg-white/10`, `text-white`, etc. a tinta oscura para glass en modo claro (`globals.css:344`).

## Shell de layout

Patrón del shell de ventana (`globals.css:209`):

- `html.titlebar` / `html.titlebar-mac` / `html.titlebar-win` / `html.linux` — montadas por el componente `TitleBar` (solo Tauri desktop).
- `html.titlebar body { background: transparent }` — la forma de la ventana es nativa.
- `.app-shell` — el **shell de la ventana**: `height: 100dvh; overflow: hidden; background: var(--background)`. Recorta todo (header incluido) y **no scrollea**. macOS lo redondea vía CSS (`border-radius: 10px`) por la titlebar Overlay transparente. Linux (`globals.css:247`) usa `border-radius: 16px`, igualado por la regla GTK `window.background.tauri-app decoration` (`lib.rs:548`): GTK dibuja la sombra CSD y el marco redondeado mientras la app controla la titlebar. Windows va frameless con redondeo DWM (`decorations: false` + decorum), así que queda cuadrado. Nunca añadas `margin` aquí: un inset dejaría esquinas cortadas.
- `.app-scroll` (`globals.css:231`) — el **contenedor de scroll** (`flex: 1 1 auto; min-height: 0; overflow-y: auto`) y el **único** en desktop. Envuelve `main` + `Footer`, es decir solo el contenido. El header vive **fuera**: es la barra de título, así que la barra de scroll no puede robarle ancho ni pintarse encima de los caption buttons. En la build web el div es inerte y scrollea el documento, por eso el header mantiene `md:sticky`.
- **Las barras de scroll son nativas y no se estilan.** No hay reglas `::-webkit-scrollbar` a propósito: forzarían barras clásicas (carril + flechas) y matarían el overlay. Windows usa `scrollBarStyle: "fluentOverlay"` (`tauri.windows.conf.json:13`), macOS mantiene su overlay auto-oculto y Linux WebKitGTK sigue `gtk-overlay-scrolling` — las tres son pastillas finas flotando sobre el borde del contenido.

## Sistema glass / cristal

Tres capas (`globals.css:171`, `269`):

1. **Vibrancy / Mica** (nativo): `html.vibrancy body` / `html.vibrancy .app-shell` — `color-mix(in oklab, var(--background) 32%, transparent)` (42% en claro) para que la translucidez se vea. El header lleva `blur(16px)` solo en macOS (`html.titlebar-mac.vibrancy .app-header`); Windows ya tiene material Mica. Linux desactiva blur.
2. **Glass cards** (web): `GlassCard` en `@workspace/ui/components/glass-card.tsx` (`bg-white/10`, `backdrop-blur`, etc.). En modo claro `html.light.glass-cards` remapea a tinta oscura. En Linux `html.linux .glass-card` quita `backdrop-filter` y cae a `var(--card)`.
3. **Dos switches independientes**: `GlassControls` (`apps/web/src/components/layout/glass-controls.tsx`) renderiza `VibrancyToggle` (material nativo, oculto si `!supported`) y `GlassCardsToggle` (componentes `glass-*` web, deshabilitado en Linux) uno al lado del otro. Cualquiera funciona solo — vibrancy con tarjetas sólidas, tarjetas glass en ventana opaca, o ambos.

Cadena de providers: `VibrancyProvider` (`vibrancy-provider.tsx` — `localStorage: vibrancy`, default ON donde hay soporte, llama a `invoke("window_effects_set")`) → `GlassCardsProvider` (`glass-cards-provider.tsx` — `localStorage: glass-cards`, default OFF).

## Overrides de sensación nativa (resumen)

`globals.css:132` — `* { user-select:none; -webkit-user-drag:none }` salvo inputs; `html,body { touch-action: pan-x pan-y }` (scroll nativo, sin pinch-zoom).

`globals.css:256` — veto Linux: `backdrop-filter: none !important` en `.app-header` / `.app-shell` (el blur de WebKitGTK es caro y da glitches). El marco en Linux es CSD de GTK (fondo, sombra y nodo `decoration` redondeado); `.app-shell` comparte el radio de 16px. `globals.css:247` oculta además la titlebar que decorum inyecta en Windows.

Ver `docs/es/native-feel.md` para el fundamento completo por OS.

## Añadir estilos

- Nuevos tokens: añade a `:root` + `.dark` + `@theme inline` en `globals.css`.
- Nuevos componentes: usa `class-variance-authority` + `clsx` + `tailwind-merge` (`cn` en `packages/ui/src/lib/utils.ts:1`).
- Evita `@apply` para casos puntuales — prefiere clases Tailwind en JSX.
- Para glass en modo claro, apunta con `html.light.glass-cards .tu-clase` si es necesario.

Siguiente: [i18n →](./i18n.md)
