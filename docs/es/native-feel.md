# Sensación nativa — multiplataforma

> **Esta es una app multiplataforma** (desktop: **macOS, Windows, Linux**; móvil: **iOS, Android**) — cualquier cambio debe funcionar y testearse en todos los sistemas. Nunca asumas solo macOS/iOS.

## Guards compartidos (todas las ventanas / todos los OS)

Derivados del commit `c9ae1a4`:

- `tauri*.conf.json` (los 4 configs): `dragDropEnabled: false` + `zoomHotkeysEnabled: false` en cada entrada `windows[]` — no solo macOS.
- `apps/web/index.html:5` — viewport `user-scalable=no, maximum-scale=1.0, viewport-fit=cover`
- `packages/ui/src/styles/globals.css:137` — `* { user-select:none; -webkit-user-drag:none; touch-action: pan-x pan-y }` (inputs/textarea/contenteditable reactivan selección). Sin `overscroll-behavior:none`.
- `apps/web/src/main.tsx:21` — bloqueo `dragstart`, bloqueo de zoom por rueda (`ctrl/meta + wheel`), links externos → `openUrl` vía `plugin-opener`.
- `src-tauri/src/lib.rs:612` — `tauri-plugin-prevent-default` con `Flags::debug()`: en **release** bloquea defaults del webview (menú contextual, devtools, reload); en **debug** los conserva. Nunca toca el scroll del documento.

Móvil (menú long-press iOS, Android) usa las mismas reglas CSS/JS (`touch-action: manipulation` mata el double-tap zoom en iOS).

## macOS — traffic lights (live-resize sin flicker)

Referencia: `wry#1747`, `tauri#13044`. `titleBarStyle: Overlay` + `hiddenTitle` deja el webview **debajo** de los traffic lights. AppKit los resetea a `12px` nativos en cada pase de layout (`setContentView:`, carga del webview, `NSWindowDidResize`, `NSViewFrameDidChange`), y `drawRect:` en `WryWebViewParent` no basta. En macOS 26 el race es peor.

**Fix HuLa (3 mecanismos en `src-tauri/src/lib.rs:205`)**

1. Hook `WindowEvent::Focused/Resized/ScaleFactorChanged` (`lib.rs:675`) — fallback general.
2. `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (`lib.rs:331`) — más fiable que `WindowEvent` en macOS 26.
3. **Polling live-resize a 60 fps** (`NSTimer` en `NSRunLoopCommonModes` + `needs_update` `±0.6px`) mientras `inLiveResize` — dispara durante `NSEventTrackingRunLoopMode`, no solo al soltar (`lib.rs:702`).

Posiciones finales: `Close 17.5 / Mini 39.5 / Zoom 61.5` (dots de 14px en macOS 26, `grow 3` cuando AppKit todavía los sirve a 12px, `shift_right 16` + `extra_gap 0/2/4`, `pl-[96px] sm:pl-[108px]` en header). `setAutoresizingMask(0)` evita que AppKit vuelva a auto-resize entre frames. Ver `lib.rs:205` `adjust_macos_traffic_lights` + `lib.rs:331` `ensure_traffic_lights_observer`.

**Centrado vertical (`traffic_lights_target_y`, `lib.rs:185`)** — el `frame` de un `standardWindowButton` vive en el sistema de coordenadas de su **superview** (el contenedor de la titlebar), no en el de la ventana. En macOS 26 ese contenedor **no está flipped**, así que escribir el `y` absoluto `26 - size/2` (la "distancia desde arriba" que asumía el código anterior) mandaba los dots *hacia arriba*: medidos desde el borde superior pasaban de `9–23px` (nativos) a `0–13px`. Ahora `traffic_lights_target_y` pregunta al superview por `isFlipped()` + su altura y devuelve la `y` que deja el centro del dot en `MACOS_HEADER_BAND / 2` (`lib.rs:166`) = **26px**, la mitad del header de 52px de macOS (`header.tsx:29`). Como el objetivo es absoluto es idempotente, así que el detector de drift de 60 fps deja de re-aplicar el frame en cada tick.

Verifica: `pnpm typecheck && pnpm lint && pnpm build` + testear scroll / click / no-zoom en un build real por plataforma.

## Efecto cristal / glass (window-vibrancy) — toggle

Patrón de **Prestly**: toggle nativo de translucidez.

- **Rust** (`lib.rs:26`): crate `window-vibrancy = "0.8"`. Comando sync `window_effects_set {enabled, dark?}` (`lib.rs:125`) — vibrancy (`NSVisualEffectView`) en macOS, Mica en Windows 11; Linux/móvil devuelven `unsupported` (no-op). Debe ser **sync** (main thread).
- **Frontend** (`apps/web/src/components/vibrancy-provider.tsx` + `glass-cards-provider.tsx`): `VibrancyProvider` + `useVibrancy()` persistido en `localStorage` (`vibrancy`), `GlassCardsProvider` (`glass-cards`). `html.vibrancy` activa `globals.css:177` body transparente. `dark` sigue al tema (tint de Mica).
- **Toggles**: dos switches INDEPENDIENTES en `GlassControls` (`apps/web/src/components/layout/glass-controls.tsx`) — `VibrancyToggle` (`vibrancy-toggle.tsx`, material nativo, oculto si `!supported`: Linux/móvil/navegador) y `GlassCardsToggle` (`glass-cards-toggle.tsx`, los componentes `glass-*` web, deshabilitado en Linux). Antes eran un único toggle combinado; ahora cualquier mezcla es válida (vibrancy + tarjetas sólidas, tarjetas glass en ventana opaca, ambos). Por defecto **OFF** cada uno.
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
- `setup()` llama a `create_overlay_titlebar()` (`lib.rs:651`); el plugin solo se registra en Windows (`lib.rs:621`).
- Caption buttons: `apps/web/src/components/layout/window-controls.tsx:61` (minimizar / maximizar-restaurar / cerrar, iconos lucide, zona de `46px`, hover rojo en cerrar), renderizados desde `header.tsx:224`. Llaman a `minimize()` / `toggleMaximize()` / `close()` y siguen `isMaximized()` + `onResized()`.
- **Snap Layouts:** el hover sobre *maximizar* durante 620 ms (`window-controls.tsx:8`) enfoca la ventana e invoca `plugin:decorum|show_snap_overlay` (`window-controls.tsx:104`), que pulsa Win+Z y luego Alt para ocultar los números. Chromium consigue el flyout real de hover respondiendo `WM_NCHITTEST` con `HTMAXBUTTON`; tao no expone ese hook, así que Win+Z es el equivalente más cercano. Permisos: `capabilities/default.json:6` (`allow-minimize` / `allow-close` / `allow-is-maximized`) + `capabilities/default.json:15` (**`core:window:allow-set-focus`** — la cadena es `setFocus().then(invoke(...))`, así que sin él la promesa se rechaza y el flyout nunca abre; no viene en `core:window:default`) + `capabilities/windows.json:7` (`decorum:allow-show-snap-overlay`) — el plugin es dep `cfg(windows)`, así que su permiso vive en una capability con `platforms: ["windows"]` y las builds no-Windows nunca lo resuelven (registrarlo global rompe `cargo check` en macOS/Linux con `Permission decorum:allow-show-snap-overlay not found`).
- Esquinas redondeadas: `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)` (`lib.rs:655`) — una ventana frameless es cuadrada por defecto.
- **Banda con alto fijo (no quitar `shrink-0`):** `header.tsx:29` clava la titlebar de Win/Linux en `h-11` (44px) + `shrink-0` — el alto al que el flex-column la comprimía antes, y la misma banda compacta que usa Edge. Sin `shrink-0` el flex-column del shell comprimía el header hasta su altura min-content, así que el alto de la titlebar cambiaba con la longitud del contenido de cada página. El arrastre mide el header en runtime (`native-chrome.ts:14`, fallback 52 macOS / 44 Win-Linux) en vez de duplicar su alto, así la banda y la zona de arrastre no pueden desincronizarse.
- Los controles del header (idioma / tema) comparten un único token de hover, `hover:bg-black/10 dark:hover:bg-white/15` (`header.tsx:18`), aplicado a **las dos** ramas, shadcn y glass, y mantienen `hover:scale-100` en la variante glass. Los valores por defecto no se leían sobre la banda de la titlebar: `bg-muted` / `dark:bg-muted/50` desaparecen sobre la banda oscura translúcida, el `hover:bg-white/10` de glass se invierte a sólo 6 % de negro en tema claro (`globals.css:403`) y `hover:scale-105` hacía que la pastilla creciera fuera de la banda.
- El arrastre sigue siendo propio: `data-tauri-drag-region` + `useWindowDragRegion` (`header.tsx:68`). Decorum además inyecta su propia titlebar fija de 32px con una capa de arrastre en `z-index:100`, que se pondría encima de nuestro header y se tragaría los clics de los botones — `globals.css:247` la oculta.
- Los bordes de resize se conservan: tao responde `WM_NCHITTEST` para los cantos de ventanas undecorated redimensionables (`src-tauri/vendor/tao-0.35.3/src/platform_impl/windows/event_loop.rs:2182`).

Así, en Windows y Linux el header fijo de 44px **es** la titlebar dibujada por la app (sin doble barra; Linux conserva el marco/sombra CSD de GTK, ver §0); macOS mantiene los traffic lights nativos con su propia banda de 52px.

## Linux — issues conocidos

### 0. Linux — marco CSD de GTK + titlebar dibujada por la app (inspirado en Chromium)

La ventana sigue **decorada y transparente** (`decorations: true`, `transparent: true`). GTK es dueño del marco CSD/fondo/sombra con canal alfa real; la app dibuja una única titlebar React de 44px con zona de arrastre y caption buttons.

- `install_linux_frame` (`lib.rs:527`) engancha CSD con una `GtkHeaderBar` vacía y oculta (`set_no_show_all(true)`, porque tao muestra la ventana con `show_all()`). La clase propia `tauri-app` se añade al nodo GTK `window.background` (`APP_FRAME_CLASS`, `lib.rs:385`).
- **El marco tiene radio de 16px en las cuatro esquinas.** El provider CSS de la app selecciona el nodo hijo real de decoración con `window.background.tauri-app decoration { border-radius: 16px }` (`lib.rs:548`); `.app-shell` usa el mismo radio (`globals.css:247`). Probé el selector con un borde de color temporal y quité la regla de prueba. Los temas/hojas CSS GTK del usuario pueden seleccionar `window.background.tauri-app` para estilar el marco de esta app.
- **El resize usa el arrastre nativo de GTK, iniciado por la app.** `install_linux_resize_grip` (`lib.rs:441`) amplía la región de entrada GTK al margen CSD, elige el `WindowEdge` y llama a `gtk_window_begin_resize_drag`. Solo los 8px exteriores quedan click-through. El borde interior de 6px del webview usa `useWindowResizeEdges` / `start_window_resize` (`lib.rs:88`). Se probaron los ocho bordes/esquinas; varios arrastres por el borde derecho cambiaron el ancho de 1100 a 1220px.
- `transparent: true` es lo que mezcla las esquinas: tao instala el visual RGBA antes del realize (solo para ventanas transparentes), así el compositor suaviza el arco de 16px y se ve el escritorio. Verificado con barrido de píxeles y capturas ampliadas en temas claro y oscuro, más arrastre, resize de margen/contenido y minimizar/maximizar/restaurar sin errores de WebKit.

**Qué hace Chromium:** el [`BrowserFrameViewLinux`](https://chromium.googlesource.com/chromium/src/+/main/chrome/browser/ui/views/frame/browser_frame_view_linux.cc) actual es más que una titlebar GTK: usa su propio `OpaqueBrowserFrameView`, dibuja marco/sombra, calcula el clip redondeado y hace hit-test de las zonas no cliente de resize. El código devuelve radios solo arriba (`radius, radius, 0, 0`). Chromium documenta su convención de clases GTK en [Integración de temas GTK en Linux](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/linux/gtk_theme_integration.md). Tomamos el patrón de titlebar propia, clase CSS GTK con nombre e hit-testing explícito, pero mantenemos la sombra/decoración CSD de GTK en vez de sustituir el marco entero por Chromium Views. Los nodos CSD y el resize GTK se describen en [`Gtk.Window`](https://docs.gtk.org/gtk3/class.Window.html).

### 1. Glass + WebKitGTK → glitches amarillos y RAM disparada

`backdrop-blur` + `DMABUF` en WebKitGTK 4.1 (sobre todo NVIDIA/Wayland) dispara `AcceleratedSurfaceDMABuf was unable to construct a complete framebuffer` + `Error 71` + RAM al redimensionar (docs `linux-graphics` de Tauri, `wry#1747`).

**Fix actual (veto):** en Linux se fuerza `glass OFF` — `glass-cards-provider.tsx` expone `supported: false` (`platform==='linux'`) y colapsa `enabled` a `false`, `GlassCardsToggle` deshabilitado con tooltip, y `globals.css:247` pone `html.linux .glass-card { backdrop-filter:none; background:var(--card) }`. `lib.rs:596` fija `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` antes del `Builder`.

**Plan A (glass degradado sin blur — no implementado):** renderizar `GlassCard` sin `backdrop-blur` en Linux — solo `bg-white/[0.06] + border` translúcido + `box-shadow` sutil. Ver `README.md` para el sketch.

## Checklist de verificación

```bash
pnpm typecheck && pnpm lint && pnpm build
```

Luego testea **scroll + click + no-zoom** en un bundle real por OS (`pnpm tauri:build` o `scripts/build-*.sh`).

Siguiente: [Scripts y tooling →](./scripts.md)
