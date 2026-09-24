# Sensación nativa — multiplataforma

> **Esta es una app multiplataforma** (desktop: **macOS, Windows, Linux**; móvil: **iOS, Android**) — cualquier cambio debe funcionar y testearse en todos los sistemas. Nunca asumas solo macOS/iOS.

## Guards compartidos (todas las ventanas / todos los OS)

Derivados del commit `c9ae1a4`:

- `tauri*.conf.json` (los 4 configs): `dragDropEnabled: false` + `zoomHotkeysEnabled: false` en cada entrada `windows[]` — no solo macOS.
- `apps/web/index.html:5` — viewport `user-scalable=no, maximum-scale=1.0, viewport-fit=cover`
- `packages/ui/src/styles/globals.css:137` — `* { user-select:none; -webkit-user-drag:none; touch-action: pan-x pan-y }` (inputs/textarea/contenteditable reactivan selección). Sin `overscroll-behavior:none`.
- `apps/web/src/main.tsx:21` — bloqueo `dragstart`, bloqueo de zoom por rueda (`ctrl/meta + wheel`), links externos → `openUrl` vía `plugin-opener`.
- `src-tauri/src/lib.rs:424` — `tauri-plugin-prevent-default` con `Flags::debug()`: en **release** bloquea defaults del webview (menú contextual, devtools, reload); en **debug** los conserva. Nunca toca el scroll del documento.

Móvil (menú long-press iOS, Android) usa las mismas reglas CSS/JS (`touch-action: manipulation` mata el double-tap zoom en iOS).

## macOS — traffic lights (live-resize sin flicker)

Referencia: `wry#1747`, `tauri#13044`. `titleBarStyle: Overlay` + `hiddenTitle` deja el webview **debajo** de los traffic lights. AppKit los resetea a `12px` nativos en cada pase de layout (`setContentView:`, carga del webview, `NSWindowDidResize`, `NSViewFrameDidChange`), y `drawRect:` en `WryWebViewParent` no basta. En macOS 26 el race es peor.

**Fix HuLa (3 mecanismos en `src-tauri/src/lib.rs:162`)**

1. Hook `WindowEvent::Focused/Resized/ScaleFactorChanged` (`lib.rs:486`) — fallback general.
2. `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (`lib.rs:288`) — más fiable que `WindowEvent` en macOS 26.
3. **Polling live-resize a 60 fps** (`NSTimer` en `NSRunLoopCommonModes` + `needs_update` `±0.6px`) mientras `inLiveResize` — dispara durante `NSEventTrackingRunLoopMode`, no solo al soltar (`lib.rs:513`).

Posiciones finales: `Close 17.5 / Mini 39.5 / Zoom 61.5` (dots de 14px en macOS 26, `grow 3` cuando AppKit todavía los sirve a 12px, `shift_right 16` + `extra_gap 0/2/4`, `pl-[96px] sm:pl-[108px]` en header). `setAutoresizingMask(0)` evita que AppKit vuelva a auto-resize entre frames. Ver `lib.rs:162` `adjust_macos_traffic_lights` + `lib.rs:288` `ensure_traffic_lights_observer`.

**Centrado vertical (`traffic_lights_target_y`, `lib.rs:142`)** — el `frame` de un `standardWindowButton` vive en el sistema de coordenadas de su **superview** (el contenedor de la titlebar), no en el de la ventana. En macOS 26 ese contenedor **no está flipped**, así que escribir el `y` absoluto `26 - size/2` (la "distancia desde arriba" que asumía el código anterior) mandaba los dots *hacia arriba*: medidos desde el borde superior pasaban de `9–23px` (nativos) a `0–13px`. Ahora `traffic_lights_target_y` pregunta al superview por `isFlipped()` + su altura y devuelve la `y` que deja el centro del dot en `MACOS_HEADER_BAND / 2` (`lib.rs:123`) = **26px**, la mitad del header de 52px de macOS (`header.tsx:29`). Como el objetivo es absoluto es idempotente, así que el detector de drift de 60 fps deja de re-aplicar el frame en cada tick.

Verifica: `pnpm typecheck && pnpm lint && pnpm build` + testear scroll / click / no-zoom en un build real por plataforma.

## Efecto cristal / glass (window-vibrancy) — toggle

Patrón de **Prestly**: toggle nativo de translucidez.

- **Rust** (`lib.rs:26`): crate `window-vibrancy = "0.8"`. Comando sync `window_effects_set {enabled, dark?}` (`lib.rs:82`) — vibrancy (`NSVisualEffectView`) en macOS, Mica en Windows 11; Linux/móvil devuelven `unsupported` (no-op). Debe ser **sync** (main thread).
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
- `setup()` llama a `create_overlay_titlebar()` (`lib.rs:462`); el plugin solo se registra en Windows (`lib.rs:433`).
- Caption buttons: `apps/web/src/components/layout/window-controls.tsx:61` (minimizar / maximizar-restaurar / cerrar, iconos lucide, zona de `46px`, hover rojo en cerrar), renderizados desde `header.tsx:224`. Llaman a `minimize()` / `toggleMaximize()` / `close()` y siguen `isMaximized()` + `onResized()`.
- **Snap Layouts:** el hover sobre *maximizar* durante 620 ms (`window-controls.tsx:8`) enfoca la ventana e invoca `plugin:decorum|show_snap_overlay` (`window-controls.tsx:104`), que pulsa Win+Z y luego Alt para ocultar los números. Chromium consigue el flyout real de hover respondiendo `WM_NCHITTEST` con `HTMAXBUTTON`; tao no expone ese hook, así que Win+Z es el equivalente más cercano. Permisos: `capabilities/default.json:6` (`allow-minimize` / `allow-close` / `allow-is-maximized`) + `capabilities/default.json:15` (**`core:window:allow-set-focus`** — la cadena es `setFocus().then(invoke(...))`, así que sin él la promesa se rechaza y el flyout nunca abre; no viene en `core:window:default`) + `capabilities/windows.json:7` (`decorum:allow-show-snap-overlay`) — el plugin es dep `cfg(windows)`, así que su permiso vive en una capability con `platforms: ["windows"]` y las builds no-Windows nunca lo resuelven (registrarlo global rompe `cargo check` en macOS/Linux con `Permission decorum:allow-show-snap-overlay not found`).
- Esquinas redondeadas: `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)` (`lib.rs:466`) — una ventana frameless es cuadrada por defecto.
- **Banda con alto fijo (no quitar `shrink-0`):** `header.tsx:29` clava la titlebar de Win/Linux en `h-11` (44px) + `shrink-0` — el alto al que el flex-column la comprimía antes, y la misma banda compacta que usa Edge. Sin `shrink-0` el flex-column del shell comprimía el header hasta su altura min-content, así que el alto de la titlebar cambiaba con la longitud del contenido de cada página. El arrastre mide el header en runtime (`native-chrome.ts:14`, fallback 52 macOS / 44 Win-Linux) en vez de duplicar su alto, así la banda y la zona de arrastre no pueden desincronizarse.
- Los controles del header (idioma / tema) comparten un único token de hover, `hover:bg-black/10 dark:hover:bg-white/15` (`header.tsx:18`), aplicado a **las dos** ramas, shadcn y glass, y mantienen `hover:scale-100` en la variante glass. Los valores por defecto no se leían sobre la banda de la titlebar: `bg-muted` / `dark:bg-muted/50` desaparecen sobre la banda oscura translúcida, el `hover:bg-white/10` de glass se invierte a sólo 6 % de negro en tema claro (`globals.css:403`) y `hover:scale-105` hacía que la pastilla creciera fuera de la banda.
- El arrastre sigue siendo propio: `data-tauri-drag-region` + `useWindowDragRegion` (`header.tsx:68`). Decorum además inyecta su propia titlebar fija de 32px con una capa de arrastre en `z-index:100`, que se pondría encima de nuestro header y se tragaría los clics de los botones — `globals.css:247` la oculta.
- Los bordes de resize se conservan: tao responde `WM_NCHITTEST` para los cantos de ventanas undecorated redimensionables (`src-tauri/vendor/tao-0.35.3/src/platform_impl/windows/event_loop.rs:2182`).

Así, en Windows el header fijo de 44px **es** la titlebar (sin doble barra); en Linux el marco del OS queda encima del mismo header (ver §0) y macOS mantiene los traffic lights nativos con su propia banda de 52px.

## Linux — issues conocidos

### 0. Marco de ventana — CSD "latched", GTK conserva su decoración nativa

`tauri`/`tao` no soportan `WindowConfig.shadow` en Linux (*"Linux: Unsupported"*), y falsear la sombra desde Rust no funcionó: un `HeaderBar` dummy para forzar CSD + `GtkCssProvider` reescribiendo `window.background` / `decoration` + forzar el visual RGBA después del realize + `set_opacity(0.99)` seguía dejando artefactos. Causa raíz: con `transparent:false` tao nunca instala un visual RGBA, así que en las esquinas no hay nada que mezclar — ningún CSS lo cambia.

**Diseño actual — GTK conserva su decoración intacta; la app solo dibuja la titlebar:**

- `tauri.linux.conf.json:11` → `decorations: true` + `transparent: false`; la ventana nace oculta (`visible: false`, `:12`) para que el marco entre antes de que GTK la realice.
- `install_linux_frame` (`lib.rs:359`) solo engancha **CSD**: una `GtkHeaderBar` vacía queda como titlebar de la ventana y se oculta (`set_no_show_all(true)` — tao muestra la ventana con `show_all()`, que si no re-mostraría la barra y se comería 43px). GTK sigue dibujando **su propio** fondo y su sombra: sin overrides de radio, sin clips de forma, sin transparencia.
- La **titlebar la dibuja la app**: `header.tsx` es la banda fija de 44px (`data-tauri-drag-region` + `useWindowDragRegion`) y `WindowControls` pinta los caption buttons para Win/Linux (`header.tsx:222`).
- El radio se pone **dos veces** y las dos hacen falta: `globals.css:247` da a `.app-shell` `border-radius: 8px` (el `$window_radius = $button_radius + 3` de Adwaita) para que el contenido no tape el arco, e `install_linux_frame` sobreescribe `decoration { border-radius: 8px }` para que la **sombra** de GTK siga esa forma. El Adwaita de GTK3 trae `decoration { border-radius: $window_radius $window_radius 0 0 }` — solo arriba, sombra cuadrada abajo — el bug que Firefox arregló tras `gtk.rounded-bottom-corners` (bugzilla 1964149).
- **El resize lo hace la app.** Una ventana CSD no tiene agarre del WM (GTK delega los bordes en el gestor de ventanas, y una ventana cliente-decorada no lleva marco del WM), y Tauri 2.11 no expone `startResizing`. Así que `useWindowResizeEdges` (`native-chrome.ts`, solo Linux) detecta el `mousedown` a menos de 6px del borde del webview, pone el cursor de resize correspondiente y llama al comando `start_window_resize` (`lib.rs`), que ejecuta el mismo `gtk_window_begin_resize_drag` que usaría GTK. Ojo: el agarre está en el borde del **contenido**, no en el del rect X11: el margen de la sombra queda ~26px por fuera (`_GTK_FRAME_EXTENTS`), que es justo donde apunta el usuario.
- Por qué no se toca nada más: `transparent: true` necesita canal alfa, y con el renderer **software** que Linux necesita (`WEBKIT_DISABLE_DMABUF_RENDERER=1`) la superficie del webview sigue opaca, así que las esquinas revelarían el fondo del webview en vez del escritorio; y recortar esa superficie con una forma X11 pierde el clip cada vez que WebKit recrea su ventana de render (una recarga de la página). Dejando la decoración nativa de GTK se evita todo eso: las esquinas redondeadas de arriba las rellena el fondo del webview (el color de ventana de Adwaita), que es justo el aspecto de una ventana GTK3 nativa.
- Detalle cosmético conocido: con tema **oscuro** las esquinas de arriba muestran el color de ventana del tema (`#1e1e1e`) contra el `--background` de la app (`#0a0a0a`), así que se leen como un borde redondeado algo más claro — el color del marco nativo. En tema claro ambos son blancos y es continuo.
- **¿Por qué no la titlebar nativa?** (a) mutter lee `_GTK_THEME_VARIANT` **una sola vez**, al gestionar la ventana (`LOAD_INIT` en `mutter/src/x11/window-props.c`), así que la SSD nunca puede seguir al tema de la app; (b) cuando tao crea la ventana en modo SSD, GTK no cablea el arrastre de CSD, así que una `GtkHeaderBar` no se puede arrastrar en absoluto (el arrastre del header de la app sí funciona — por eso la banda es de la app).
- `useNativeTheme` (`native-chrome.ts:135`, enganchado en `title-bar.tsx:20`) refleja el tema resuelto en la variante de GTK (`window.setTheme()` → `gtk-application-prefer-dark-theme`), así el fondo del marco queda en el mismo claro/oscuro que la app.

### 1. Glass + WebKitGTK → glitches amarillos y RAM disparada

`backdrop-blur` + `DMABUF` en WebKitGTK 4.1 (sobre todo NVIDIA/Wayland) dispara `AcceleratedSurfaceDMABuf was unable to construct a complete framebuffer` + `Error 71` + RAM al redimensionar (docs `linux-graphics` de Tauri, `wry#1747`).

**Fix actual (veto):** en Linux se fuerza `glass OFF` — `glass-cards-provider.tsx` expone `supported: false` (`platform==='linux'`) y colapsa `enabled` a `false`, `GlassCardsToggle` deshabilitado con tooltip, y `globals.css:247` pone `html.linux .glass-card { backdrop-filter:none; background:var(--card) }`. `lib.rs:408` fija `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` antes del `Builder`.

**Plan A (glass degradado sin blur — no implementado):** renderizar `GlassCard` sin `backdrop-blur` en Linux — solo `bg-white/[0.06] + border` translúcido + `box-shadow` sutil. Ver `README.md` para el sketch.

## Checklist de verificación

```bash
pnpm typecheck && pnpm lint && pnpm build
```

Luego testea **scroll + click + no-zoom** en un bundle real por OS (`pnpm tauri:build` o `scripts/build-*.sh`).

Siguiente: [Scripts y tooling →](./scripts.md)
