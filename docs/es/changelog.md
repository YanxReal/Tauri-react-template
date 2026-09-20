# Changelog

> Evolución completa de esta plantilla — 20 commits desde `455897d` hasta `9da8602`. Cada entrada explica **el motivo detrás del código no obvio**. Léelo antes de eliminar cualquier línea marcada `// Prestly pattern` o `// HuLa fix`.

## 2026-08-30 — Base

### `455897d` `feat: initial commit`
- Scaffold básico Tauri + Vite.

### `e08ca4a` `feat: modernize template — pnpm + node24, biome, i18n bilingüe, tailwind v4, tauri v2`
- Migra a **pnpm workspaces** (`pnpm-workspace.yaml:1`), Node `>=24`, Biome (`biome.json:1`), i18next EN/ES (`apps/web/src/i18n/config.ts:1`), Tailwind v4 vía `@tailwindcss/vite` (`packages/ui/src/styles/globals.css:1`), Turborepo, Vitest + Testing Library, semántica HTML5 (`App.tsx:19`, `index.html:5`). Define alias `@` → `src` y `@workspace/ui`.

### `653bebc` `feat: shadcn full + einui liquid glass — dual registry`
- Vendorea **45 componentes shadcn** + **einui liquid glass** (`glass-button`, `glass-card`, etc.) en `packages/ui`. Dual registry `@einui` vía `https://ui.eindev.ir/r/{name}.json`. Añade `framer-motion`, `radix-ui`, `recharts`, `@base-ui/react`. Todos los widgets glass viven en `packages/ui/src/components`.

### `10a74e4` `feat: unified iOS+macOS Xcode template — debug/hotreload/release pipelines`
- **Target único Xcode** `tauri-react-template_Apple` (`SUPPORTED_PLATFORMS = macosx iphoneos iphonesimulator` vía `apple.xcconfig`) con 3 configs:
  - `debug` — standalone con frontend embebido (`custom-protocol`), incremental rápido.
  - `hotreload` — probe al parent `tauri ios dev --open` vía **handshake JSON-RPC** (`$TMPDIR/com.tauri-react-template.app-server-addr`, timeout 1.5s), IPC completo (`TAURI_DEV_HOST`, merges, `xcode-script`); abre Terminal vía `open -a Terminal <script>.command` si el parent no está vivo.
  - `release` — producción standalone.
- Sentinel `DEVELOPMENT_TEAM` `__TAURI_DEVELOPMENT_TEAM__` resuelto por `scripts/Xcode/apple-xcode.sh` (`env` → `scripts/.team-id` → manual).
- Vendorea el template móvil `tauri-cli 2.11.4` en `src-tauri/vendor/`. `Info.plist` se convierte en la **plantilla única** para macOS+iOS (`tauri.*.conf.json: bundle`).

## 2026-08-30 — Fundación native-feel

### `f23a894` `feat: disable native webview context menu (Reload/Back) in release — all OS`
- Rust intercepta `contextmenu` para suprimir `Reload`/`Back` en WKWebView/WebView2/WebKitGTK + menús long-press móviles. Debug lo conserva.

### `c9ae1a4` `feat: native-app feel — prevent-default plugin, dragDrop/zoomHotkeys off, CSS+JS multi-OS`
- **El commit grande de sensación nativa:**
  - `dragDropEnabled:false` + `zoomHotkeysEnabled:false` en **las 4** ventanas `tauri.*.conf.json`.
  - Viewport `user-scalable=no, maximum-scale=1.0` (`index.html:5`), CSS `user-select:none` + `-webkit-user-drag:none` + `touch-action: pan-x pan-y` (`globals.css:137`), guards JS `dragstart` + `wheel` (`main.tsx:21`).
  - `tauri-plugin-prevent-default` con `Flags::debug()` (`lib.rs:330`) — bloquea menú/context/reload/devtools en release, los mantiene en debug.
- Por qué `touch-action: pan-x pan-y` y no `manipulation`/`none`: conserva scroll nativo; bloquea pinch-zoom sin matar gestos. Ver `ae5be97`.

### `ae5be97` `fix: restore normal scrolling in WebKit — touch-action manipulation instead of pan-x pan-y` (superseded)
- Prueba con `touch-action: manipulation` — luego se asentó en `pan-x pan-y` como valor saludable para WebKit.

### `45d5f34` `docs: multiplataforma — notas native-feel`
- Documenta que `dragDropEnabled`/`zoomHotkeysEnabled` deben estar en **las 4 configs**, no solo macOS.

## 2026-08-30 — Crystal / glass

### `f997723` `feat: efecto cristal — toggle de translucidez nativa (window-vibrancy)`
- Crate `window-vibrancy 0.8`, comando **sync** `window_effects_set {enabled, dark?}` (`lib.rs:26`, `lib.rs:82`) — `NSVisualEffectView` en macOS (`HudWindow`/`UnderWindowBackground`), Mica en Windows 11; `unsupported` en resto. `VibrancyProvider` (`vibrancy-provider.tsx`) + `localStorage: vibrancy` + `html.vibrancy` → `globals.css:177` body transparente.

### `efc552c` `feat: el efecto cristal sigue el tema de la app`
- `VibrancyProvider` observa `html.dark` vía `MutationObserver` y re-aplica material al cambiar de tema. macOS elige material según `dark` (el cristal sigue el tema de la app, no el del sistema).

### `5fb6077` `feat: ventana nativa - esquinas redondeadas, arrastre y cristal por tema`
- Corrige `window-vibrancy` bajo `[target.'cfg(windows)']` — lo mueve a `[dependencies]` principal para que macOS lo enlace. Añade crate `windows = "0.61"` DWM (`Cargo.toml:57`). `DwmSetWindowAttribute(DWMWCP_ROUND)` para frameless Windows 11 (`lib.rs:365`). Nuevo `native-chrome.ts` (`usePlatform`, `useMacDragRegion`), header con botones nativos (`header.tsx`).

### `73d445a` `fix: ventana nativa — arrastre con banda reservada y cristal de fondo`
- Reserva **banda de 36px** (`--native-titlebar-height`) para drag, padding `app-shell`, header sticky en `top:36px`. Cristal de ventana completa: `color-mix(var(--background) 62%, transparent)` para que la translucidez siga el tema.

### `aa83704` `fix: arrastre macOS fiable (patron Prestly, banda 20px)`
- Drag intermitente: selección del webview + header sticky tapando la banda. Fix: `useMacDragRegion` replica exacto Prestly — `mousedown` a nivel document, `preventDefault` + `startDragging` en banda, doble-clic → maximize, excluye targets interactivos. Encoje banda a **20px** (`1.25rem`), header sticky en `top: var(--native-titlebar-height)`.

## 2026-08-31 — Ventana cross-platform

### `9177b88` `fix: ventana arrastrable y esquinas redondeadas en las 3 plataformas`
- Añade `core:window:allow-start-dragging` a `capabilities/default.json` (sin ello `startDragging` falla en silencio). `app-shell` se convierte en **contenedor de scroll** (`overflow-y: auto`) con `border-radius:10px` en macOS; header con `data-tauri-drag-region` en Windows/Linux. `html/body` transparentes en desktop — `app-shell` es dueño del background.

### `938f89a` `fix: traffic lights live-resize sin flicker + header alineado + windows NSIS/Wix`
- **Fix HuLa 3-mecanismos para traffic lights de macOS** (`lib.rs:116`):
  1. `WindowEvent::Focused/Resized/ScaleFactorChanged` (`lib.rs:390`)
  2. `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (`lib.rs:253`)
  3. **Polling a 60 fps** (`NSTimer` en `NSRunLoopCommonModes` + `needs_update` `±0.6px`, `lib.rs:412`) — dispara durante `NSEventTrackingRunLoopMode`
  - Targets `Close 22.5 / Mini 44.5 / Zoom 66.5`, `grow 3`, `lower 8`, `shift 16` + `extra_gap`, `setAutoresizingMask(0)`, header `pl-[96px] sm:pl-[108px]`.
- También: assets instalador Windows NSIS/Wix (`nsis-header.bmp`, `wix-banner.bmp`), `LICENSE.rtf`, iconos multi-tamaño `src-tauri/icons/`.
- Verificación: `pnpm build` + `cargo check` en macOS + Linux (docker `webkit2gtk-4.1`).

## 2026-09-02 — Glass y curvas en Linux

### `93657d3` `fix: linux glass veto + curvas ventana + toggle combinado`
- **Glitches amarillos Linux** (`a2.png`) — WebKitGTK 4.1 + DMABUF + NVIDIA/Wayland + `backdrop-blur` → `AcceleratedSurfaceDMABuf was unable to…` + `Error 71` + RAM. Fix: `GlassCardsProvider` retorna `false` si `platform==='linux'`, `GlassEffectToggle` deshabilitado, `globals.css:237` quita `backdrop-filter` → `var(--card)`, `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` antes de `Builder` (`lib.rs:315`). `html.linux .app-shell {border-radius:10px}` corrige ventana plana (`a1.png`). Nuevo `scripts/build-linux.sh`.

## 2026-09-05 — Sombra en Linux

### `9da8602` `fix: sombra de ventana nativa en Linux via GTK CssProvider + fallback webview`
> **Histórico — reemplazado.** Todo lo de abajo se eliminó; ver la sección 2026-09-07 → 2026-09-18.

- `tauri`/`tao` NO soportan `WindowConfig.shadow` en Linux (`"Linux: Unsupported"`). Con `decorations:false transparent:true` el nodo `window.background.csd decoration { box-shadow }` nunca se genera → ventana plana.
  - **Primaria:** `apply_linux_window_shadow` — `gtk_window()` + `CssProvider` (prioridad APPLICATION) fuerza `.csd`, restaura `decoration { box-shadow: 0 16px 48px rgba(0,0,0,.38); margin:12px; border-radius:10px }` + `:backdrop`, añade `html.gtk-shadow` vía `window.eval`.
  - **Fallback:** `html.linux:not(.gtk-shadow) .app-shell` → `margin:12px + box-shadow` — para Sway/Hyprland/X11 donde se ignora CSD. Maximizado/fullscreen → `0`.
- Añade `gtk = "0.18"` (solo linux) + `useWindowStateClasses` para `window-maximized`/`window-fullscreen` vía capability `allow-is-fullscreen`.

## 2026-09-07 → 2026-09-18 — saga de la sombra Linux, revertida

12 commits (`83042a6` … `98966ab`) persiguieron el marco en Linux: sombra híbrida → nativa solo con `StyleContext::add_provider` → CSD forzado con `HeaderBar` oculto → `transparent:false` → visual RGBA forzado + `opaque_region` → `set_opacity(0.99)`.

**Resultado — Linux deja de dibujar su propio marco.** `tauri.linux.conf.json:11` usa `decorations: true` + `transparent: false`, así que GTK / el compositor dibujan la titlebar con minimizar / maximizar / cerrar nativos, sombra y radio de esquinas. Se eliminaron `apply_linux_window_shadow`, las deps linux `gtk` / `gdk` y todas las reglas de marco en `.app-shell` (`border-radius` / `margin` / `box-shadow` / `contain` / scroll interno). Windows también pasó a `decorations: true` aquí, pero se revirtió un día después — ver la entrada del 2026-09-19. El **área de arrastre** personalizada se mantiene (`data-tauri-drag-region` + `useWindowDragRegion`, banda Prestly de 56px).

Por qué los hacks no podían funcionar: con `transparent:false` tao nunca instala un visual RGBA (lo hace **antes del realize**, solo para ventanas transparentes) y `gtk_widget_set_visual()` después del realize no tiene efecto, así que las esquinas nunca podían mezclarse — las esquinas blancas/opacas de 1px y el buffer cuadrado bajo el `decoration` redondeado eran eso, no un bug de CSS.

Mínimo privilegio: se quitaron `core:window:allow-minimize` / `allow-close` / `allow-is-maximized` / `allow-is-fullscreen` de `capabilities/default.json:6` (solo existían para los caption buttons y `useWindowStateClasses`). Se mantienen `allow-start-dragging`, `allow-internal-toggle-maximize` (script inyectado de Tauri para `data-tauri-drag-region`) y `allow-toggle-maximize` (fallback de doble-clic en `useWindowDragRegion`). `allow-is-fullscreen` sigue sin uso; `allow-minimize` / `allow-close` / `allow-is-maximized` volvieron con los caption buttons de Windows el 2026-09-19.

## 2026-09-19 — Scroll: header fuera del scroller + scrollbars overlay nativas

La ventana usaba la barra de scroll por defecto del OS en las tres plataformas — en Windows eso es la clásica: carril gris, botones de flecha arriba/abajo y una columna propia en el borde. Peor: pertenecía al *shell* (header + contenido), así que además le robaba ~12px al header y empujaba los caption buttons hacia dentro.

- **El scroller se movió al contenido.** `.app-shell` ahora es `height:100dvh; overflow:hidden` (solo recorta) y un nuevo `.app-scroll` (`globals.css:231`) tiene `overflow-y:auto` y envuelve solo `main` + `Footer` (`apps/web/src/App.tsx:52`). El header — que *es* la barra de título — queda fuera, así que una barra de scroll no puede estrecharlo ni pintarse encima del botón de cerrar. La build web no cambia (el div es inerte, scrollea el documento) y conserva `md:sticky`.
- **Las scrollbars overlay vienen de la plataforma, no del CSS.** Windows: `"scrollBarStyle": "fluentOverlay"` (`tauri.windows.conf.json:13`, WebView2 >= 125.0.2535.41) → barra overlay Fluent (pastilla fina, se auto-oculta, flota sobre el contenido). macOS mantiene su overlay auto-oculto nativo; Linux sigue `gtk-overlay-scrolling` en WebKitGTK.
- **Primer intento descartado (no repetir):** una pastilla custom con `::-webkit-scrollbar` (carril de 12px, thumb de 6px, track transparente, sin botones) se veía bien pero fuerza la barra *clásica* no-overlay tanto en WebKit como en Chromium — en macOS mata el auto-ocultado nativo y pelea con `scrollBarStyle`. Añadir `scrollbar-width`/`scrollbar-color` lo empeoró: en Chromium esas propiedades estándar tienen prioridad e **ignoran** los pseudo-elementos webkit, que es como volvieron los botones de flecha. No queda CSS de scrollbar.
- Verificado en Windows 11 build 26200: el header llega a la esquina redondeada sin carril, no hay barra en reposo, aparece una pastilla overlay fina al scrollear, y la rueda y PageDown mueven el contenedor nuevo.

## 2026-09-19 — Windows: titlebar overlay con decorum (estilo Edge)

Windows vuelve a ser frameless (`tauri.windows.conf.json:12` → `decorations: false`, `transparent: true` se mantiene por Mica) y la titlebar la dibuja la app: el plugin de la comunidad [decorum](https://github.com/clearlysid/tauri-plugin-decorum) (deps solo para el target Windows en `Cargo.toml`; `lib.rs:339`) más `create_overlay_titlebar()` en `setup()` (`lib.rs:361`). Es el modelo Edge / VS Code — una sola banda fija de 44px en vez del marco del OS encima del header.

- `apps/web/src/components/layout/window-controls.tsx:61` pinta minimizar / maximizar-restaurar / cerrar (iconos lucide, zona de 46px, hover rojo en cerrar), montado por `header.tsx:224` solo si `platform === 'windows'`.
- Los botones quedan **pegados al borde derecho** (`window-controls.tsx:120`, sin `pr-2`): el botón de cerrar de 46px termina exactamente en el borde del cliente, así que su hover rojo llega a la esquina y DWM lo recorta con el radio de la ventana. Misma geometría que Edge/Chromium (46px de ancho, icono a ~23px del borde).
- Snap Layouts: hover de 620 ms sobre maximizar (`window-controls.tsx:8`) enfoca la ventana e invoca `plugin:decorum|show_snap_overlay` (`window-controls.tsx:104`) — decorum pulsa Win+Z y luego Alt para ocultar los números. Chromium responde `WM_NCHITTEST` con `HTMAXBUTTON` para el flyout real de hover; tao no expone ese hook, así que este es el equivalente más cercano. Verificado en una VM Windows 11 build 26200: minimizar / maximizar / restaurar / cerrar funcionan, arrastrar por el header mueve la ventana, `DwmGetWindowAttribute` devuelve `corner = 2` (`DWMWCP_ROUND`), `WS_THICKFRAME` sigue puesto (redimensionable) y el flyout abre tras el hover — ver `troubleshooting.md` para el gotcha de la ventana negra cuando la app se lanza desde un contexto de servicio.
- `globals.css:230` oculta la titlebar de 32px que inyecta decorum (`[data-tauri-decorum-tb]`), que taparía el header y se tragaría los clics de los botones; la banda de arrastre sigue siendo nuestra (`data-tauri-drag-region` + `useWindowDragRegion`, `header.tsx:68`). El resize sigue funcionando (tao hace hit-test de los cantos en ventanas undecorated redimensionables) y `DWMWCP_ROUND` (`lib.rs:365`) mantiene las esquinas redondeadas.
- Permisos: `allow-minimize` / `allow-close` / `allow-is-maximized` / `allow-set-focus` de vuelta en `capabilities/default.json:6` (el último está en `capabilities/default.json:15`; sin él `setFocus()` se rechaza y el `catch` de `window-controls.tsx` se lo traga, así que el flyout de Snap Layouts nunca abre en silencio), y `decorum:allow-show-snap-overlay` en su propia `capabilities/windows.json:7` con `platforms: ["windows"]` — el plugin es dep `cfg(windows)`, así que tener el permiso en `default.json` hacía fallar cualquier `cargo check` en macOS/Linux con `Permission decorum:allow-show-snap-overlay not found`. Linux mantiene la decoración nativa completa; macOS intacto.

## 2026-09-19 — Titlebar: banda fija de 44px + hover legible en los controles

- `header.tsx:29` — `HEADER_HEIGHT` clava la banda por plataforma (`h-[52px]` macOS, `h-11` = 44px Win/Linux, `h-14` móvil) en vez de un único `h-14`. 44px es lo que el flex-column del shell ya comprimía el header (min-content), o sea la banda que el usuario veía; `shrink-0` + la clase fija sólo evitan que dependa del contenido de la página. Los caption buttons (`h-full`) llenan la banda y los controles de idioma / tema siguen en 32px, así la pastilla no se recorta.
- `native-chrome.ts:12` — la banda de arrastre Prestly deja de hardcodear 56px: `headerBandHeight()` mide `.app-header` en runtime (fallbacks 52 macOS / 44 Win-Linux), así banda y zona de arrastre no pueden desincronizarse.
- `header.tsx:18` — los botones de idioma / tema comparten un único token de hover, `hover:bg-black/10 dark:hover:bg-white/15`, aplicado a **las dos** ramas, shadcn y glass. Los valores viejos no se leían sobre la banda: `bg-muted` / `dark:bg-muted/50` desaparecen sobre la barra oscura translúcida, y el `hover:bg-white/10` de glass se invierte a 6 % de negro en tema claro (`globals.css:403`). Los botones glass mantienen `hover:scale-100`, así la pastilla no crece fuera de la titlebar.
- Verificado en la VM Windows 11 build 26200 (VNC + sonda de píxeles): la banda de la titlebar mide 44px (48 px capturados con el escala ~1,09 de la VM = rect de hover de los caption buttons + borde de 1px), el hover de tema / idioma pasa de `(11,11,11)` a `(49,49,49)` en oscuro y de `(254,254,254)` a `(228,228,228)` en claro, el hover rojo de cerrar sigue ocupando los últimos 46px (x=1350..1399, borde del cliente 1400) y arrastrar la banda mueve la ventana exactamente lo mismo que el puntero.

## 2026-09-19 — Traffic lights de macOS: 2px más a la izquierda

- `TRAFFIC_LIGHTS_X` (`lib.rs:117`) pasa a `17.5 / 39.5 / 61.5` (antes `19.5 / 41.5 / 63.5`): 2px más cerca del borde izquierdo, con el centrado vertical y `grow 3` / `shift_right 16` + `extra_gap` intactos.
- Verificado con captura de pantalla: dots a `17.5–75px` del borde izquierdo y centro a `26px` del superior (mitad del header de 52px).

## 2026-09-19 — Traffic lights de macOS centrados en la banda de 52px del header

- `traffic_lights_target_y` (`lib.rs:142`) ahora deriva la `y` del **superview** del botón (`isFlipped()` + altura del contenedor) en vez de asumir que la `y` del frame es la distancia desde el borde superior. En macOS 26 ese contenedor de la titlebar **no está flipped**, así que el antiguo `y` absoluto `26 - size/2` empujaba los dots ~9px *hacia arriba*: medidos desde el borde superior pasaban de `9–23px` (nativos) a `0–13px`.
- Resultado: los centros de los dots quedan en `MACOS_HEADER_BAND / 2` (`lib.rs:123` = 26px) — la mitad del header de macOS (`header.tsx:29`, `h-[52px]`). Verificado con captura de pantalla: centro nativo `15.8px` → `25.8px`.
- `adjust_macos_traffic_lights` (`lib.rs:162`) elimina los empujones a ciegas `lower 8` / `−3px`: el objetivo absoluto hace la escritura idempotente, así que el detector de drift de 60 fps (`needs_traffic_lights_update`, `lib.rs:257`) deja de re-aplicar el frame en cada tick.

## 2026-09-19 — Traffic lights de macOS: 3px a la izquierda

- `lib.rs:116` — los tres dots hacen snap en `19.5 / 41.5 / 63.5` (antes `22.5 / 44.5 / 66.5`): 3px más cerca del borde izquierdo de la ventana, con `grow 3` / `lower 8` / `shift 16` + `extra_gap` intactos.
- La X objetivo ahora vive en `TRAFFIC_LIGHTS_X` (`lib.rs:116`), compartida por `adjust_macos_traffic_lights` (`lib.rs:124`) y el detector de drift `needs_traffic_lights_update` (`lib.rs:234`). Tener dos copias a mano era lo que hacía que el observer de 60 fps re-aplicara el frame en cada tick; los punteros `lib.rs:116` de los docs se actualizaron con el cambio.

## 2026-09-18 — cross-compile de Windows funcionando

`scripts/build-windows.sh` ahora cross-compila el bundle Windows x64 desde macOS/Linux con `cargo-xwin` (antes invocaba el `cargo-tauri` con branding de Prestly y caía en `--bundles msi`, que no puede correr fuera de Windows). Resuelve las rutas keg-only de LLVM/lld, valida `cargo-xwin` / el target MSVC / `makensis`, y usa el CLI stock: `pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles nsis`. Genera `tauri-react-template.exe` + el `.exe` instalador NSIS. Docs: `docs/es/scripts.md` § Cross-compile Windows.

---

## Lecciones para futuros cambios

- Si ves `// Prestly pattern` o `// HuLa fix`, esa línea sobrevivió a múltiples bugs de plataforma. Lee el commit antes de tocarla.
- `backdrop-blur` en Linux está vetado por motivo — cualquier re-activación debe manejar DMABUF + NVIDIA + Wayland y mantener RAM plana al redimensionar.
- Traffic lights: nunca elimines uno de los tres mecanismos — cada uno cubre un timing distinto (general, macOS 26, live-drag).
- `src-tauri/gen/` siempre es desechable — la fuente real de Xcode es `vendor/tauri-cli-*/templates/mobile/ios/`.

Siguiente: [Contribuir →](./contributing.md) · [Sensación nativa →](./native-feel.md)
