# Sensación nativa — multiplataforma

> **Esta es una app multiplataforma** (desktop: **macOS, Windows, Linux**; móvil: **iOS, Android**) — cualquier cambio debe funcionar y testearse en todos los sistemas. Nunca asumas solo macOS/iOS.

## Guards compartidos (todas las ventanas / todos los OS)

Derivados del commit `c9ae1a4`:

- `tauri*.conf.json` (los 4 configs): `dragDropEnabled: false` + `zoomHotkeysEnabled: false` en cada entrada `windows[]` — no solo macOS.
- `apps/web/index.html:5` — viewport `user-scalable=no, maximum-scale=1.0, viewport-fit=cover`
- `packages/ui/src/styles/globals.css:137` — `* { user-select:none; -webkit-user-drag:none; touch-action: pan-x pan-y }` (inputs/textarea/contenteditable reactivan selección). Sin `overscroll-behavior:none`.
- `apps/web/src/main.tsx:21` — bloqueo `dragstart`, bloqueo de zoom por rueda (`ctrl/meta + wheel`), links externos → `openUrl` vía `plugin-opener`.
- `src-tauri/src/lib.rs:330` — `tauri-plugin-prevent-default` con `Flags::debug()`: en **release** bloquea defaults del webview (menú contextual, devtools, reload); en **debug** los conserva. Nunca toca el scroll del documento.

Móvil (menú long-press iOS, Android) usa las mismas reglas CSS/JS (`touch-action: manipulation` mata el double-tap zoom en iOS).

## macOS — traffic lights (live-resize sin flicker)

Referencia: `wry#1747`, `tauri#13044`. `titleBarStyle: Overlay` + `hiddenTitle` deja el webview **debajo** de los traffic lights. AppKit los resetea a `12px` nativos en cada pase de layout (`setContentView:`, carga del webview, `NSWindowDidResize`, `NSViewFrameDidChange`), y `drawRect:` en `WryWebViewParent` no basta. En macOS 26 el race es peor.

**Fix HuLa (3 mecanismos en `src-tauri/src/lib.rs:116`)**

1. Hook `WindowEvent::Focused/Resized/ScaleFactorChanged` (`lib.rs:390`) — fallback general.
2. `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (`lib.rs:253`) — más fiable que `WindowEvent` en macOS 26.
3. **Polling live-resize a 60 fps** (`NSTimer` en `NSRunLoopCommonModes` + `needs_update` `±0.6px`) mientras `inLiveResize` — dispara durante `NSEventTrackingRunLoopMode`, no solo al soltar (`lib.rs:412`).

Posiciones finales: `Close 22.5 / Mini 44.5 / Zoom 66.5` (centros de 22px, `15px` con `grow 3`, `lower 8`, `shift_right 16` + `extra_gap 0/2/4`, `pl-[96px] sm:pl-[108px]` en header). `setAutoresizingMask(0)` evita que AppKit vuelva a auto-resize entre frames. Ver `lib.rs:adjust_macos_traffic_lights` + `ensure_traffic_lights_observer`.

Verifica: `pnpm typecheck && pnpm lint && pnpm build` + testear scroll / click / no-zoom en un build real por plataforma.

## Efecto cristal / glass (window-vibrancy) — toggle

Patrón de **Prestly**: toggle nativo de translucidez.

- **Rust** (`lib.rs:26`): crate `window-vibrancy = "0.8"`. Comando sync `window_effects_set {enabled, dark?}` (`lib.rs:82`) — vibrancy (`NSVisualEffectView`) en macOS, Mica en Windows 11; Linux/móvil devuelven `unsupported` (no-op). Debe ser **sync** (main thread).
- **Frontend** (`apps/web/src/components/vibrancy-provider.tsx` + `glass-cards-provider.tsx`): `VibrancyProvider` + `useVibrancy()` persistido en `localStorage` (`vibrancy`), `GlassCardsProvider` (`glass-cards`). `html.vibrancy` activa `globals.css:177` body transparente. `dark` sigue al tema (tint de Mica).
- **Toggle**: `VibrancyToggle` / `GlassEffectToggle` (`apps/web/src/components/layout/glass-effect-toggle.tsx`) — `Switch` de shadcn, oculto si `!supported` (Linux/móvil/navegador). El toggle combinado controla `glass-cards` + `vibrancy` juntos, por defecto **OFF** (Linux fuerza OFF).
- **CSS** (`globals.css:177`, `269`): `html.vibrancy .app-shell { background: color-mix(... 32%) }` (42% en claro), header macOS `backdrop-blur(16px)`; Windows aporta material Mica; Linux desactiva blur.

## Scrollbars y contenedor de scroll (todas las plataformas de escritorio)

Dos reglas, ambas load-bearing:

1. **El header queda fuera del scroller.** `.app-shell` es `height:100dvh; overflow:hidden` (solo recorta) y un único hijo — `.app-scroll` (`globals.css:231`) — tiene `overflow-y:auto` y envuelve `main` + `Footer`. Si `.app-shell` fuera el scroller (header + contenido), la barra de scroll se comería ~12px del header y empujaría los caption buttons hacia dentro; con una barra *overlay* se pintaría encima del botón de cerrar. El header es la barra de título, así que siempre tiene que llegar al borde derecho. La build web no cambia (el div es inerte y scrollea el documento), por eso el header conserva `md:sticky`.
2. **Las barras de scroll son nativas — nunca estilar `::-webkit-scrollbar`.** Esos pseudo-elementos fuerzan barras clásicas (carril reservado + botones de flecha) y matan el overlay de la plataforma. En su lugar cada OS usa su overlay nativo:
   - **Windows:** `"scrollBarStyle": "fluentOverlay"` en `tauri.windows.conf.json:13` — la barra overlay Fluent de WebView2 (pastilla fina, se auto-oculta, flota sobre el contenido). Requiere WebView2 Runtime >= 125.0.2535.41; en runtimes más viejos no hace nada y fuera de Windows no está soportado. La propia doc de Tauri avisa de que "los estilos CSS que modifican la scrollbar se aplican encima de la apariencia nativa", así que añadir reglas webkit encima lo anula.
   - **macOS:** las scrollbars overlay de WebKit, sin tocar — se auto-ocultan con trackpad y, si macOS está en "mostrar siempre", solo afectan al contenido, nunca al header.
   - **Linux:** WebKitGTK sigue el ajuste GTK `gtk-overlay-scrolling` (activado por defecto en GNOME). Si está desactivado sale la barra clásica del tema — solo dentro del área de contenido, el header intacto.

Ambas están cubiertas por invariantes junto a `window-controls`: mira la fila `Scrollbars` de `AGENTS.md` antes de tocar `.app-shell` / `.app-scroll` o de añadir CSS de scrollbar.

## Windows — titlebar overlay (`tauri-plugin-decorum`)

Modelo Edge / VS Code: la ventana es **frameless** y la titlebar la dibuja la app (`decorations: false`). El plugin de la comunidad [decorum](https://github.com/clearlysid/tauri-plugin-decorum) aporta el overlay y el comando de Snap Layouts; el header pone la banda de arrastre y los caption buttons.

- `tauri.windows.conf.json:12` → `decorations: false` (`transparent: true` se mantiene para que Mica / `window_effects_set` siga viéndose).
- `setup()` llama a `create_overlay_titlebar()` (`lib.rs:361`); el plugin solo se registra en Windows (`lib.rs:339`).
- Caption buttons: `apps/web/src/components/layout/window-controls.tsx:61` (minimizar / maximizar-restaurar / cerrar, iconos lucide, zona de `46px`, hover rojo en cerrar), renderizados desde `header.tsx:191`. Llaman a `minimize()` / `toggleMaximize()` / `close()` y siguen `isMaximized()` + `onResized()`.
- **Snap Layouts:** el hover sobre *maximizar* durante 620 ms (`window-controls.tsx:8`) enfoca la ventana e invoca `plugin:decorum|show_snap_overlay` (`window-controls.tsx:104`), que pulsa Win+Z y luego Alt para ocultar los números. Chromium consigue el flyout real de hover respondiendo `WM_NCHITTEST` con `HTMAXBUTTON`; tao no expone ese hook, así que Win+Z es el equivalente más cercano. Permisos: `capabilities/default.json:6` (`allow-minimize` / `allow-close` / `allow-is-maximized`) + `capabilities/default.json:15` (**`core:window:allow-set-focus`** — la cadena es `setFocus().then(invoke(...))`, así que sin él la promesa se rechaza y el flyout nunca abre; no viene en `core:window:default`) + `capabilities/windows.json:7` (`decorum:allow-show-snap-overlay`) — el plugin es dep `cfg(windows)`, así que su permiso vive en una capability con `platforms: ["windows"]` y las builds no-Windows nunca lo resuelven (registrarlo global rompe `cargo check` en macOS/Linux con `Permission decorum:allow-show-snap-overlay not found`).
- Esquinas redondeadas: `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)` (`lib.rs:365`) — una ventana frameless es cuadrada por defecto.
- El arrastre sigue siendo propio: `data-tauri-drag-region` + `useWindowDragRegion` (`header.tsx:39`). Decorum además inyecta su propia titlebar fija de 32px con una capa de arrastre en `z-index:100`, que se pondría encima de nuestro header y se tragaría los clics de los botones — `globals.css:247` la oculta.
- Los bordes de resize se conservan: tao responde `WM_NCHITTEST` para los cantos de ventanas undecorated redimensionables (`src-tauri/vendor/tao-0.35.3/src/platform_impl/windows/event_loop.rs:2182`).

Así, en Windows el header de 56px **es** la titlebar (sin doble barra); en Linux el marco del OS queda encima del mismo header (ver §0) y macOS mantiene los traffic lights nativos.

## Linux — issues conocidos

### 0. Marco de ventana — decoración nativa completa

`tauri`/`tao` no soportan `WindowConfig.shadow` en Linux (*"Linux: Unsupported"*), y falsear la sombra desde Rust no funcionó: un `HeaderBar` dummy para forzar CSD + `GtkCssProvider` reescribiendo `window.background` / `decoration` + forzar el visual RGBA después del realize + `set_opacity(0.99)` seguía dejando artefactos (esquinas opacas de 1px, buffer cuadrado bajo el `decoration` redondeado, todo ligeramente translúcido).

Causa raíz (por qué esos hacks no podían arreglarlo): con `transparent:false` tao nunca instala un visual RGBA (tao lo instala **antes del realize** y solo para ventanas transparentes) y `gtk_widget_set_visual()` después del realize no tiene efecto, así que las esquinas nunca pueden mezclarse — ningún CSS lo cambia.

**Diseño actual — el sistema dibuja todo el marco:**

- `tauri.linux.conf.json:11` → `decorations: true` + `transparent: false`. GTK/compositor dibujan la titlebar con **minimizar / maximizar / cerrar nativos**, más su sombra y radio de esquinas nativos (CSD en GNOME/X11, SSD en compositores con `xdg-decoration`).
- Rust ya no toca GTK: `apply_linux_window_shadow` (CssProvider + HeaderBar dummy + hacks de RGBA / opacity / opaque_region) y las deps linux `gtk = "0.18"` / `gdk = "0.18"` se **eliminaron**. `run()` solo conserva las env vars de WebKitGTK (`lib.rs:315`).
- `globals.css:215` — **sin** `border-radius` / `margin` / `box-shadow` / `contain` de Linux en `.app-shell`. El shell es simplemente el área cliente dentro del marco nativo; recortarlo o meterle margen dejaría esquinas cortadas bajo la titlebar.
- El área de arrastre personalizada sigue: el header mantiene `data-tauri-drag-region` + `useWindowDragRegion` (banda Prestly de 56px) en `apps/web/src/components/layout/header.tsx:39`, así la barra fusionada de la app se sigue arrastrando bajo la titlebar nativa.

### 1. Glass + WebKitGTK → glitches amarillos y RAM disparada

`backdrop-blur` + `DMABUF` en WebKitGTK 4.1 (sobre todo NVIDIA/Wayland) dispara `AcceleratedSurfaceDMABuf was unable to construct a complete framebuffer` + `Error 71` + RAM al redimensionar (docs `linux-graphics` de Tauri, `wry#1747`).

**Fix actual (veto):** en Linux se fuerza `glass OFF` — `glass-cards-provider.tsx` devuelve `false` si `platform==='linux'`, `GlassEffectToggle` deshabilitado con tooltip, y `globals.css:247` pone `html.linux .glass-card { backdrop-filter:none; background:var(--card) }`. `lib.rs:315` fija `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` antes del `Builder`.

**Plan A (glass degradado sin blur — no implementado):** renderizar `GlassCard` sin `backdrop-blur` en Linux — solo `bg-white/[0.06] + border` translúcido + `box-shadow` sutil. Ver `README.md` para el sketch.

## Checklist de verificación

```bash
pnpm typecheck && pnpm lint && pnpm build
```

Luego testea **scroll + click + no-zoom** en un bundle real por OS (`pnpm tauri:build` o `scripts/build-*.sh`).

Siguiente: [Scripts y tooling →](./scripts.md)
