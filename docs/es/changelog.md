# Changelog

> Evolución completa de esta plantilla — 52 commits desde `455897d` (inicial) hasta HEAD. La tabla de hitos de `AGENTS.md` §1 cubre los 20 primeros; el resto es el arco del marco de ventana Windows/Linux documentado abajo. Cada entrada explica **el motivo detrás del código no obvio**. Léelo antes de eliminar cualquier línea marcada `// HuLa fix`.

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
  - `tauri-plugin-prevent-default` con `Flags::debug()` (`lib.rs:758`) — bloquea menú/context/reload/devtools en release, los mantiene en debug.
- Por qué `touch-action: pan-x pan-y` y no `manipulation`/`none`: conserva scroll nativo; bloquea pinch-zoom sin matar gestos. Ver `ae5be97`.

### `ae5be97` `fix: restore normal scrolling in WebKit — touch-action manipulation instead of pan-x pan-y` (superseded)
- Prueba con `touch-action: manipulation` — luego se asentó en `pan-x pan-y` como valor saludable para WebKit.

### `45d5f34` `docs: multiplataforma — notas native-feel`
- Documenta que `dragDropEnabled`/`zoomHotkeysEnabled` deben estar en **las 4 configs**, no solo macOS.

## 2026-08-30 — Crystal / glass

### `f997723` `feat: efecto cristal — toggle de translucidez nativa (window-vibrancy)`
- Crate `window-vibrancy 0.8`, comando **sync** `window_effects_set {enabled, dark?}` (`lib.rs:31`, `lib.rs:125`) — `NSVisualEffectView` en macOS (`HudWindow`/`UnderWindowBackground`), Mica en Windows 11; `unsupported` en resto. `VibrancyProvider` (`vibrancy-provider.tsx`) + `localStorage: vibrancy` + `html.vibrancy` → `globals.css:177` body transparente.

### `efc552c` `feat: el efecto cristal sigue el tema de la app`
- `VibrancyProvider` observa `html.dark` vía `MutationObserver` y re-aplica material al cambiar de tema. macOS elige material según `dark` (el cristal sigue el tema de la app, no el del sistema).

### `5fb6077` `feat: ventana nativa - esquinas redondeadas, arrastre y cristal por tema`
- Corrige `window-vibrancy` bajo `[target.'cfg(windows)']` — lo mueve a `[dependencies]` principal para que macOS lo enlace. Añade crate `windows = "0.61"` DWM (`Cargo.toml:57`). `DwmSetWindowAttribute(DWMWCP_ROUND)` para frameless Windows 11 (`lib.rs:810`). Nuevo `native-chrome.ts` (`usePlatform`, `useMacDragRegion`), header con botones nativos (`header.tsx`).

### `73d445a` `fix: ventana nativa — arrastre con banda reservada y cristal de fondo`
- Reserva **banda de 36px** (`--native-titlebar-height`) para drag, padding `app-shell`, header sticky en `top:36px`. Cristal de ventana completa: `color-mix(var(--background) 62%, transparent)` para que la translucidez siga el tema.

### `aa83704` `fix: arrastre macOS fiable (patron Prestly, banda 20px)`
- Drag intermitente: selección del webview + header sticky tapando la banda. Fix: `useMacDragRegion` usa `mousedown` a nivel document, `preventDefault` + `startDragging` en banda, doble-clic → maximize, excluye targets interactivos. Encoje banda a **20px** (`1.25rem`), header sticky en `top: var(--native-titlebar-height)`.

## 2026-08-31 — Ventana cross-platform

### `9177b88` `fix: ventana arrastrable y esquinas redondeadas en las 3 plataformas`
- Añade `core:window:allow-start-dragging` a `capabilities/default.json` (sin ello `startDragging` falla en silencio). `app-shell` se convierte en **contenedor de scroll** (`overflow-y: auto`) con `border-radius:10px` en macOS; header con `data-tauri-drag-region` en Windows/Linux. `html/body` transparentes en desktop — `app-shell` es dueño del background.

### `938f89a` `fix: traffic lights live-resize sin flicker + header alineado + windows NSIS/Wix`
- **Fix HuLa 3-mecanismos para traffic lights de macOS** (`lib.rs:160`):
  1. `WindowEvent::Focused/Resized/ScaleFactorChanged` (`lib.rs:838`)
  2. `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (`lib.rs:331`)
  3. **Polling a 60 fps** (`NSTimer` en `NSRunLoopCommonModes` + `needs_update` `±0.6px`, `lib.rs:865`) — dispara durante `NSEventTrackingRunLoopMode`
  - Targets `Close 22.5 / Mini 44.5 / Zoom 66.5`, `grow 3`, `lower 8`, `shift 16` + `extra_gap`, `setAutoresizingMask(0)`, header `pl-[96px] sm:pl-[108px]`.
- También: assets instalador Windows NSIS/Wix (`nsis-header.bmp`, `wix-banner.bmp`), `LICENSE.rtf`, iconos multi-tamaño `src-tauri/icons/`.
- Verificación: `pnpm build` + `cargo check` en macOS + Linux (docker `webkit2gtk-4.1`).

## 2026-09-02 — Glass y curvas en Linux

### `93657d3` `fix: linux glass veto + curvas ventana + toggle combinado`
- **Glitches amarillos Linux** (`a2.png`) — WebKitGTK 4.1 + DMABUF + NVIDIA/Wayland + `backdrop-blur` → `AcceleratedSurfaceDMABuf was unable to…` + `Error 71` + RAM. Fix: `GlassCardsProvider` retorna `false` si `platform==='linux'`, `GlassEffectToggle` deshabilitado, `globals.css:237` quita `backdrop-filter` → `var(--card)`, `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` antes de `Builder` (`lib.rs:749`). `html.linux .app-shell {border-radius:10px}` corrige ventana plana (`a1.png`). Nuevo `scripts/build-linux.sh`.

## 2026-09-05 — Sombra en Linux

### `9da8602` `fix: sombra de ventana nativa en Linux via GTK CssProvider + fallback webview`
> **Histórico — reemplazado.** Todo lo de abajo se eliminó; ver la sección 2026-09-07 → 2026-09-18.

- `tauri`/`tao` NO soportan `WindowConfig.shadow` en Linux (`"Linux: Unsupported"`). Con `decorations:false transparent:true` el nodo `window.background.csd decoration { box-shadow }` nunca se genera → ventana plana.
  - **Primaria:** `apply_linux_window_shadow` — `gtk_window()` + `CssProvider` (prioridad APPLICATION) fuerza `.csd`, restaura `decoration { box-shadow: 0 16px 48px rgba(0,0,0,.38); margin:12px; border-radius:10px }` + `:backdrop`, añade `html.gtk-shadow` vía `window.eval`.
  - **Fallback:** `html.linux:not(.gtk-shadow) .app-shell` → `margin:12px + box-shadow` — para Sway/Hyprland/X11 donde se ignora CSD. Maximizado/fullscreen → `0`.
- Añade `gtk = "0.18"` (solo linux) + `useWindowStateClasses` para `window-maximized`/`window-fullscreen` vía capability `allow-is-fullscreen`.

## 2026-09-07 → 2026-09-18 — saga de la sombra Linux, revertida

12 commits (`83042a6` … `98966ab`) persiguieron el marco en Linux: sombra híbrida → nativa solo con `StyleContext::add_provider` → CSD forzado con `HeaderBar` oculto → `transparent:false` → visual RGBA forzado + `opaque_region` → `set_opacity(0.99)`.

**Resultado — Linux deja de dibujar su propio marco.** `tauri.linux.conf.json:11` usa `decorations: true` + `transparent: false`, así que GTK / el compositor dibujan la titlebar con minimizar / maximizar / cerrar nativos, sombra y radio de esquinas. Se eliminaron `apply_linux_window_shadow`, las deps linux `gtk` / `gdk` y todas las reglas de marco en `.app-shell` (`border-radius` / `margin` / `box-shadow` / `contain` / scroll interno). Windows también pasó a `decorations: true` aquí, pero se revirtió un día después — ver la entrada del 2026-09-19. El **área de arrastre** personalizada se mantiene (`data-tauri-drag-region` + `useWindowDragRegion`, banda de arrastre de 56px).

Por qué los hacks no podían funcionar: con `transparent:false` tao nunca instala un visual RGBA (lo hace **antes del realize**, solo para ventanas transparentes) y `gtk_widget_set_visual()` después del realize no tiene efecto, así que las esquinas nunca podían mezclarse — las esquinas blancas/opacas de 1px y el buffer cuadrado bajo el `decoration` redondeado eran eso, no un bug de CSS.

Mínimo privilegio: se quitaron `core:window:allow-minimize` / `allow-close` / `allow-is-maximized` / `allow-is-fullscreen` de `capabilities/default.json:6` (solo existían para los caption buttons y `useWindowStateClasses`). Se mantienen `allow-start-dragging`, `allow-internal-toggle-maximize` (script inyectado de Tauri para `data-tauri-drag-region`) y `allow-toggle-maximize` (fallback de doble-clic en `useWindowDragRegion`). `allow-is-fullscreen` sigue sin uso; `allow-minimize` / `allow-close` / `allow-is-maximized` volvieron con los caption buttons de Windows el 2026-09-19.

## 2026-09-19 — Scroll: header fuera del scroller + scrollbars overlay nativas

La ventana usaba la barra de scroll por defecto del OS en las tres plataformas — en Windows eso es la clásica: carril gris, botones de flecha arriba/abajo y una columna propia en el borde. Peor: pertenecía al *shell* (header + contenido), así que además le robaba ~12px al header y empujaba los caption buttons hacia dentro.

- **El scroller se movió al contenido.** `.app-shell` ahora es `height:100dvh; overflow:hidden` (solo recorta) y un nuevo `.app-scroll` (`globals.css:231`) tiene `overflow-y:auto` y envuelve solo `main` + `Footer` (`apps/web/src/App.tsx:52`). El header — que *es* la barra de título — queda fuera, así que una barra de scroll no puede estrecharlo ni pintarse encima del botón de cerrar. La build web no cambia (el div es inerte, scrollea el documento) y conserva `md:sticky`.
- **Las scrollbars overlay vienen de la plataforma, no del CSS.** Windows: `"scrollBarStyle": "fluentOverlay"` (`tauri.windows.conf.json:13`, WebView2 >= 125.0.2535.41) → barra overlay Fluent (pastilla fina, se auto-oculta, flota sobre el contenido). macOS mantiene su overlay auto-oculto nativo; Linux sigue `gtk-overlay-scrolling` en WebKitGTK.
- **Primer intento descartado (no repetir):** una pastilla custom con `::-webkit-scrollbar` (carril de 12px, thumb de 6px, track transparente, sin botones) se veía bien pero fuerza la barra *clásica* no-overlay tanto en WebKit como en Chromium — en macOS mata el auto-ocultado nativo y pelea con `scrollBarStyle`. Añadir `scrollbar-width`/`scrollbar-color` lo empeoró: en Chromium esas propiedades estándar tienen prioridad e **ignoran** los pseudo-elementos webkit, que es como volvieron los botones de flecha. No queda CSS de scrollbar.
- Verificado en Windows 11 build 26200: el header llega a la esquina redondeada sin carril, no hay barra en reposo, aparece una pastilla overlay fina al scrollear, y la rueda y PageDown mueven el contenedor nuevo.

## 2026-09-19 — Windows: titlebar overlay con decorum (estilo Edge)

Windows vuelve a ser frameless (`tauri.windows.conf.json:12` → `decorations: false`, `transparent: true` se mantiene por Mica) y la titlebar la dibuja la app: el plugin de la comunidad [decorum](https://github.com/clearlysid/tauri-plugin-decorum) (deps solo para el target Windows en `Cargo.toml`; `lib.rs:774`) más `create_overlay_titlebar()` en `setup()` (`lib.rs:814`). Es el modelo Edge / VS Code — una sola banda fija de 44px en vez del marco del OS encima del header.

- `apps/web/src/components/layout/window-controls.tsx:61` pinta minimizar / maximizar-restaurar / cerrar (iconos lucide, zona de 46px, hover rojo en cerrar), montado por `header.tsx:224` solo si `platform === 'windows'`.
- Los botones quedan **pegados al borde derecho** (`window-controls.tsx:120`, sin `pr-2`): el botón de cerrar de 46px termina exactamente en el borde del cliente, así que su hover rojo llega a la esquina y DWM lo recorta con el radio de la ventana. Misma geometría que Edge/Chromium (46px de ancho, icono a ~23px del borde).
- Snap Layouts: hover de 620 ms sobre maximizar (`window-controls.tsx:8`) enfoca la ventana e invoca `plugin:decorum|show_snap_overlay` (`window-controls.tsx:104`) — decorum pulsa Win+Z y luego Alt para ocultar los números. Chromium responde `WM_NCHITTEST` con `HTMAXBUTTON` para el flyout real de hover; tao no expone ese hook, así que este es el equivalente más cercano. Verificado en una VM Windows 11 build 26200: minimizar / maximizar / restaurar / cerrar funcionan, arrastrar por el header mueve la ventana, `DwmGetWindowAttribute` devuelve `corner = 2` (`DWMWCP_ROUND`), `WS_THICKFRAME` sigue puesto (redimensionable) y el flyout abre tras el hover — ver `troubleshooting.md` para el gotcha de la ventana negra cuando la app se lanza desde un contexto de servicio.
- `globals.css:230` oculta la titlebar de 32px que inyecta decorum (`[data-tauri-decorum-tb]`), que taparía el header y se tragaría los clics de los botones; la banda de arrastre sigue siendo nuestra (`data-tauri-drag-region` + `useWindowDragRegion`, `header.tsx:68`). El resize sigue funcionando (tao hace hit-test de los cantos en ventanas undecorated redimensionables) y `DWMWCP_ROUND` (`lib.rs:810`) mantiene las esquinas redondeadas.
- Permisos: `allow-minimize` / `allow-close` / `allow-is-maximized` / `allow-set-focus` de vuelta en `capabilities/default.json:6` (el último está en `capabilities/default.json:15`; sin él `setFocus()` se rechaza y el `catch` de `window-controls.tsx` se lo traga, así que el flyout de Snap Layouts nunca abre en silencio), y `decorum:allow-show-snap-overlay` en su propia `capabilities/windows.json:7` con `platforms: ["windows"]` — el plugin es dep `cfg(windows)`, así que tener el permiso en `default.json` hacía fallar cualquier `cargo check` en macOS/Linux con `Permission decorum:allow-show-snap-overlay not found`. Linux mantiene la decoración nativa completa; macOS intacto.

## 2026-09-19 — Titlebar: banda fija de 44px + hover legible en los controles

- `header.tsx:29` — `HEADER_HEIGHT` clava la banda por plataforma (`h-[52px]` macOS, `h-11` = 44px Win/Linux, `h-14` móvil) en vez de un único `h-14`. 44px es lo que el flex-column del shell ya comprimía el header (min-content), o sea la banda que el usuario veía; `shrink-0` + la clase fija sólo evitan que dependa del contenido de la página. Los caption buttons (`h-full`) llenan la banda y los controles de idioma / tema siguen en 32px, así la pastilla no se recorta.
- `native-chrome.ts:12` — la banda de arrastre deja de hardcodear 56px: `headerBandHeight()` mide `.app-header` en runtime (fallbacks 52 macOS / 44 Win-Linux), así banda y zona de arrastre no pueden desincronizarse.
- `header.tsx:18` — los botones de idioma / tema comparten un único token de hover, `hover:bg-black/10 dark:hover:bg-white/15`, aplicado a **las dos** ramas, shadcn y glass. Los valores viejos no se leían sobre la banda: `bg-muted` / `dark:bg-muted/50` desaparecen sobre la barra oscura translúcida, y el `hover:bg-white/10` de glass se invierte a 6 % de negro en tema claro (`globals.css:403`). Los botones glass mantienen `hover:scale-100`, así la pastilla no crece fuera de la titlebar.
- Verificado en la VM Windows 11 build 26200 (VNC + sonda de píxeles): la banda de la titlebar mide 44px (48 px capturados con el escala ~1,09 de la VM = rect de hover de los caption buttons + borde de 1px), el hover de tema / idioma pasa de `(11,11,11)` a `(49,49,49)` en oscuro y de `(254,254,254)` a `(228,228,228)` en claro, el hover rojo de cerrar sigue ocupando los últimos 46px (x=1350..1399, borde del cliente 1400) y arrastrar la banda mueve la ventana exactamente lo mismo que el puntero.

## 2026-09-20 — Dos switches de cristal independientes

- El `GlassEffectToggle` combinado desaparece. `GlassControls` (`apps/web/src/components/layout/glass-controls.tsx`) monta dos switches en paralelo: `VibrancyToggle` (`vibrancy-toggle.tsx`, el material nativo de la ventana) y `GlassCardsToggle` (`glass-cards-toggle.tsx`, los componentes `glass-*` web).
- Cualquier combinación es válida: vibrancy + tarjetas sólidas, tarjetas glass en ventana opaca, o ambos. Los dos providers ya eran independientes (`localStorage: vibrancy` vs `glass-cards`) — solo el switch único los ataba.
- `GlassCardsProvider` ahora expone `supported` (`platform !== 'linux'`) y colapsa `enabled` a `false` ahí, así en Linux el switch se renderiza **deshabilitado** con el tooltip de "no compatible en esta plataforma" en vez de mover un switch que no hace nada. `useGlassCards()` ya no reimplementa el veto de Linux; la clase `html.glass-cards` sigue el valor efectivo.
- i18n: `vibrancy.label` pasa a "Efecto cristal" / "Crystal effect" (ya no controla las tarjetas) y ambos switches exponen su `hint` como tooltip.
- Se borra `glass-effect-toggle.tsx`. Checks en verde: `pnpm typecheck`, `pnpm lint`, `pnpm test`.

## 2026-09-19 — Traffic lights de macOS: 2px más a la izquierda

- `TRAFFIC_LIGHTS_X` (`lib.rs:160`) pasa a `17.5 / 39.5 / 61.5` (antes `19.5 / 41.5 / 63.5`): 2px más cerca del borde izquierdo, con el centrado vertical y `grow 3` / `shift_right 16` + `extra_gap` intactos.
- Verificado con captura de pantalla: dots a `17.5–75px` del borde izquierdo y centro a `26px` del superior (mitad del header de 52px).

## 2026-09-19 — Traffic lights de macOS centrados en la banda de 52px del header

- `traffic_lights_target_y` (`lib.rs:185`) ahora deriva la `y` del **superview** del botón (`isFlipped()` + altura del contenedor) en vez de asumir que la `y` del frame es la distancia desde el borde superior. En macOS 26 ese contenedor de la titlebar **no está flipped**, así que el antiguo `y` absoluto `26 - size/2` empujaba los dots ~9px *hacia arriba*: medidos desde el borde superior pasaban de `9–23px` (nativos) a `0–13px`.
- Resultado: los centros de los dots quedan en `MACOS_HEADER_BAND / 2` (`lib.rs:166` = 26px) — la mitad del header de macOS (`header.tsx:29`, `h-[52px]`). Verificado con captura de pantalla: centro nativo `15.8px` → `25.8px`.
- `adjust_macos_traffic_lights` (`lib.rs:205`) elimina los empujones a ciegas `lower 8` / `−3px`: el objetivo absoluto hace la escritura idempotente, así que el detector de drift de 60 fps (`needs_traffic_lights_update`, `lib.rs:300`) deja de re-aplicar el frame en cada tick.

## 2026-09-19 — Traffic lights de macOS: 3px a la izquierda

- `lib.rs:160` — los tres dots hacen snap en `19.5 / 41.5 / 63.5` (antes `22.5 / 44.5 / 66.5`): 3px más cerca del borde izquierdo de la ventana, con `grow 3` / `lower 8` / `shift 16` + `extra_gap` intactos.
- La X objetivo ahora vive en `TRAFFIC_LIGHTS_X` (`lib.rs:160`), compartida por `adjust_macos_traffic_lights` (`lib.rs:205`) y el detector de drift `needs_traffic_lights_update` (`lib.rs:300`). Tener dos copias a mano era lo que hacía que el observer de 60 fps re-aplicara el frame en cada tick; los punteros `lib.rs:160` de los docs se actualizaron con el cambio.

## 2026-09-18 — cross-compile de Windows funcionando

`scripts/build-windows.sh` ahora cross-compila el bundle Windows x64 desde macOS/Linux con `cargo-xwin` (antes invocaba un `cargo-tauri` de terceros con branding y caía en `--bundles msi`, que no puede correr fuera de Windows). Resuelve las rutas keg-only de LLVM/lld, valida `cargo-xwin` / el target MSVC / `makensis`, y usa el CLI stock: `pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles nsis`. Genera `tauri-react-template.exe` + el `.exe` instalador NSIS. Docs: `docs/es/scripts.md` § Cross-compile Windows.

---

## 2026-09-22 — La titlebar de Linux sigue al tema de la app (`GtkHeaderBar` / CSD) → superseded

- **El marco nativo no puede seguir al tema de la app.** mutter resuelve la variante de la SSD desde la propiedad X11 `_GTK_THEME_VARIANT` **una sola vez, al gestionar la ventana** (`LOAD_INIT` en `mutter/src/x11/window-props.c`). Comprobado en GNOME 46 que `window.setTheme()` (que solo llega a `gtk-application-prefer-dark-theme`), escribir la propiedad con `xprop` y un unmap/remap real dejan la barra en la variante del sistema — una app oscura en un escritorio claro mantenía la titlebar blanca, y al revés.
- `install_linux_titlebar` (eliminada en la entrada del 2026-09-23) instala un `GtkHeaderBar` (CSD) de verdad en `setup()`: GTK lo pinta en proceso, así que se repinta en cuanto cambia `gtk-application-prefer-dark-theme`. `useNativeTheme` (`native-chrome.ts:131`, enganchado en `title-bar.tsx:21`) llama a `window.setTheme()` con el tema resuelto, **solo en Linux** (en macOS cambiaría la apariencia de `NSApp` y en Windows el modo oscuro de toda la app).
- `tauri.linux.conf.json:11` mantiene `decorations: true` y gana `visible: false` (`:12`): la ventana nace oculta para que el headerbar entre **antes** de que GTK la realice — sin `Gtk-WARNING: gtk_window_set_titlebar() called on a realized window` y sin parpadeo del marco del sistema. `setup()` la muestra al final pase lo que pase.
- `gtk = "0.18"` vuelve como dependencia solo-Linux (`Cargo.toml:69`, la misma versión que usan tao/wry). Los botones nativos, la sombra y las esquinas redondeadas vienen del CSD de GTK; sigue sin haber marco CSS en `.app-shell`.
- Permiso nuevo `core:window:allow-set-theme` (`capabilities/default.json:16`): sin él `setTheme()` se rechaza en silencio y la barra se queda con la variante del sistema.

## 2026-09-23 — Linux: titlebar propia sobre un marco CSD "latched" (superseded)

- Dos bugs del diseño del 2026-09-22, ambos comprobados en GNOME 46: (1) las esquinas de **abajo** salían cuadradas — el CSD de GTK redondea el fondo de la ventana, pero el webview lo tapa (las de arriba solo se veían bien porque las cubría la headerbar de GTK); (2) la `GtkHeaderBar` **no era arrastrable** — tao crea la ventana en modo SSD, así que GTK nunca cablea el arrastre de CSD (el arrastre del header de la app **sí** funcionaba).
- El arreglo sigue el patrón "custom frame" de Edge / VS Code / Chromium, o sea el mismo modelo que Windows: la **titlebar la dibuja la app** (banda de 44px de `header.tsx` + `WindowControls` para Win/Linux, `header.tsx:222`) e `install_linux_frame` (`lib.rs:672`) engancha CSD con una `GtkHeaderBar` vacía y oculta más el fondo de ventana de GTK transparente, así que GTK aporta solo su **sombra nativa**.
- `set_no_show_all(true)` es crítico: tao muestra la ventana con `window.show_all()` (`vendor/tao-0.35.3/src/platform_impl/linux/event_loop.rs:308`), que re-mostraba la barra oculta y se comía 43px arriba.
- `globals.css:245` → `html.linux .app-shell { border-radius: 10px }`: con el marco transparente la forma la define el shell.
- **`transparent: true`** (`tauri.linux.conf.json:13`) es lo que hace que las esquinas *se vean* curvas. Con `transparent: false` el radio se aplicaba y las esquinas eran transparentes en el DOM, pero el **fondo del propio webview** seguía opaco (el *base* de Adwaita, `#1e1e1e`) y rellenaba el área fuera del radio, así que se leían como cuadradas. tao instala el visual RGBA **antes del realize** y solo para ventanas transparentes, y wry solo limpia el fondo del webview si la ventana es transparente — la pieza que al viejo `apply_linux_window_shadow` le faltaba. Verificado con un barrido de píxeles por fila en la esquina: con `transparent: false` el borde del contenido es una recta (`inset=0` en todas las filas); con `transparent: true` sigue el arco (`inset 8 → 4 → 2 → 1 → 0`) y los píxeles de la esquina son el escritorio.
- Verificado en la caja Ubuntu ARM: arrastre (`80,80 → 179,180`), minimizar (`_NET_WM_STATE_HIDDEN`), maximizar (`MAXIMIZED_HORZ/VERT` + icono de restaurar), doble click para restaurar, las 4 esquinas redondeadas con sombra, en claro y oscuro.

## 2026-09-24 — Esquinas en Linux: sombra redondeada + clip del webview → superseded

- Las esquinas *sí* estaban redondeadas (el radio CSS se aplicaba y los píxeles eran transparentes) pero seguían leyéndose como cuadradas, porque el Adwaita de GTK3 solo redondea las esquinas de **arriba**: `decoration { border-radius: $window_radius $window_radius 0 0 }` (`$window_radius = 8px`), así que su sombra es cuadrada abajo. El mismo bug que Firefox arregló tras `gtk.rounded-bottom-corners` (bugzilla 1964149). Arreglo: reescribir el radio del marco desde un `GtkCssProvider` (`window.background` + `decoration { border-radius: 10px }`), el enfoque que recomienda la comunidad GTK.
- Segundo artefacto: con el renderer software que Linux necesita (`WEBKIT_DISABLE_DMABUF_RENDERER=1`) la **superficie del webview es opaca** — el `set_background_color(transparent)` de wry no basta — y asomaba un "hombro" cuadrado justo fuera de las esquinas redondeadas (bug de Firefox 1509931). Arreglo: the experimental X11 webview shape clip da forma a la `GdkWindow` del webview con el mismo rectángulo redondeado vía `gdk_window_shape_combine_region` (X11; no-op en Wayland, donde la superficie ya es transparente). Se re-aplica en `size-allocate` y `realize`.
- `transparent: false` no puede funcionar: sin alfa no hay nada que mezclar en las esquinas, así que las rellena el fondo del propio webview (el *base* de Adwaita, `#1e1e1e`). Verificado con barrido de píxeles: con `false` el borde del contenido es una recta, con `true` sigue el arco (inset 8 → 4 → 2 → 1 → 0).
- Residual conocido: un arco ~1px más claro en la esquina (GTK dibuja la sombra alrededor de la caja del `decoration`, dejando una banda muerta fina dentro). Quitar el radio de `.app-shell` y dejar que el clip defina la forma lo elimina a cambio de una esquina sin antialias.
- Verificado en la caja Ubuntu ARM: arco medido en las 4 esquinas, arrastre (`200,150 → 260,210`), minimizar (`_NET_WM_STATE_HIDDEN`), maximizar (`MAXIMIZED_HORZ/VERT`) + restaurar, sin errores de WebKit.

---

## 2026-09-24 — Linux: decoración CSD nativa, sin overrides (superseded)

- Simplifica el marco después de medir las alternativas. `transparent: true` + un override del radio del `decoration` + un clip de forma X11 sobre el webview sí redondeaban las 4 esquinas, pero el clip se pierde cada vez que WebKit recrea su ventana de render (una recarga de página), y con `transparent: false` la superficie del webview sigue opaca, así que el clip era lo único que daba forma a las esquinas.
- Diseño final: GTK conserva su decoración **nativa** intacta. `install_linux_frame` (`lib.rs:672`) solo engancha CSD con una `GtkHeaderBar` vacía y oculta; `transparent: false`; `.app-shell` lleva `border-top-left/right-radius: 8px` (el `$window_radius` de Adwaita) para que el contenido no tape el redondeo de arriba de GTK. GTK3 solo redondea arriba (`decoration { border-radius: r r 0 0 }`), así que las esquinas de abajo son rectas — GTK3 nativo.
- La titlebar sigue siendo de la app (header de 44px + `WindowControls`), que es el objetivo: la SSD de mutter no puede seguir al tema de la app (`_GTK_THEME_VARIANT` se lee una vez, `LOAD_INIT`) y su titlebar no es arrastrable con tao.
- Medido con barrido de píxeles en la esquina superior-izquierda: el arco de 8px está, relleno con el fondo del webview (`#1e1e1e` oscuro / blanco claro) — con tema oscuro se lee como un borde redondeado algo más claro, el color del marco nativo. Arrastre, minimizar, maximizar y restaurar verificados.

---

## 2026-09-24 — Linux: clase GTK del marco + CSD nativo redondeado + agarre resize

- **Clase de marco GTK (patrón de integración de temas Chromium):** `install_linux_frame` asigna `tauri-app` al nodo `window.background` de GtkWindow (`APP_FRAME_CLASS`, `lib.rs:385`); el provider de la app selecciona `window.background.tauri-app decoration`. Verificado en runtime: la clase aparece junto a `background` y `csd`, y un borde GTK temporal limitado a la clase estila el nodo real del marco. Se quitó el estilo de prueba; los temas/hojas GTK del usuario pueden usar el mismo selector.
- **CSD nativo redondeado:** Adwaita GTK3 redondea arriba por defecto. El provider de la app fija explícitamente `border-radius: 16px` en el nodo `decoration` (`lib.rs:697`), y `.app-shell` coincide (`globals.css:245`), así GTK dibuja sombra/marco con las cuatro esquinas curvas y la ventana sigue con `transparent: false`.
- **Resize desde el margen de sombra CSD:** GTK documenta la sombra `.csd` como agarre de resize normal, pero tao no entregaba esos eventos de borde de forma fiable. `install_linux_resize_grip` (`lib.rs:537`) incluye el margen en la región de entrada GTK (los 8px exteriores quedan click-through), pone el cursor direccional y llama a `gtk_window_begin_resize_drag`. La región se reaplica en realize/map/size-allocate. `useWindowResizeEdges` / `start_window_resize` (`lib.rs:88`) manejan el borde interior de 6px del webview. Verificado en los ocho bordes/esquinas; arrastres repetidos a la derecha 1100 → 1220px.
- **Comparación con Chromium:** el `BrowserFrameViewLinux` actual dibuja un marco Views propio con sombra/hit-testing y usa radios solo arriba. Esta app mantiene deliberadamente la decoración y sombra CSD nativas de GTK; toma de Chromium la clase GTK con nombre propio para integrar temas.
- Verificado en Ubuntu ARM GTK3: clase de tema, decoración GTK de 16px en las cuatro esquinas, resize en margen y borde interior, arrastre, minimizar/maximizar/restaurar, con `transparent: true`.

---

## 2026-09-25 — Linux: `transparent: true` vuelve las esquinas reales

- El radio de 16px en `decoration` y la clase `tauri-app` estaban bien aplicados (probado con un borde magenta temporal), pero las capturas ampliadas seguían mostrando esquinas cuadradas. Causa raíz, confirmada con evidencia: con `transparent: false` la ventana X11 no tiene canal alfa, así que el compositor no puede mezclar nada — cada píxel del rectángulo sigue opaco y el radio CSS solo redondea lo dibujado dentro.
- Arreglo: `tauri.linux.conf.json:13` → `transparent: true`. Tao instala el visual RGBA antes del realize, el compositor suaviza el arco y el escritorio se ve en las esquinas. Verificado con capturas ampliadas en temas claro y oscuro, resize de margen/contenido (1100 → 1220px), arrastre del header, minimizar/maximizar/restaurar y ventana maximizada sin huecos — sin errores de WebKit.
- Se conserva a propósito: latch CSD, clase `tauri-app`, override del radio en `decoration`, ambas vías de resize, `WEBKIT_DISABLE_DMABUF_RENDERER=1`.

---

## 2026-09-25 — Linux: radio en ambos nodos GTK + sombra única arregla las puntas

- Las capturas ampliadas aún mostraban un pequeño cuadrado opaco en la punta extrema de cada esquina, más allá del arco redondeado del contenido. Probado con un verde temporal: era el nodo `window.background` pintando en cuadrado — el radio solo estaba en el hijo `decoration`. Arreglo: `window.background.tauri-app { border-radius: 16px }` más `window.background.tauri-app decoration { border-radius: 16px; box-shadow: 0 3px 12px rgba(0, 0, 0, 0.5) }` (`lib.rs:697`).
- La sombra única importa: una revisión anterior estilaba la sombra en ambos nodos y las sombras superpuestas dejaban un parche denso en las puntas.
- Verificado a 6x en las cuatro esquinas: arcos limpios con antialiasing, sombra suave, sin nubs — con `transparent: true`.

---

---

## 27-09-2026 — Linux: frameless + opaco, esquinas cuadradas aceptadas (sustituye al arco CSD de arriba)

- Las esquinas CSD redondeadas funcionaban, pero las puntas transparentes seguían viéndose en los extremos y la maquinaria nunca compensó: provider CSS de GTK (clase `tauri-app`, radio de 16px en ambos nodos), agarre con input shape (`apply_grip_input_shape`, `install_linux_resize_grip`, `find_webview`), dos rutas de resize, `allow-set-theme` + `useNativeTheme`. Decisión deliberada: `tauri.linux.conf.json` → `decorations: false` + `transparent: false`, esquinas cuadradas del sistema como parte de la plataforma.
- Eliminado: `install_linux_frame`, `install_linux_resize_grip`, `apply_grip_input_shape`, `find_webview`, `edge_from_position`/`edge_cursor_name` (+ sus tests en `lib.rs`), `useNativeTheme`, el permiso `core:window:allow-set-theme` y la sonda de input shape (`scripts/probe-input-shape.sh`, que había medido `GDK_REGION_SET` = replace). Conservado: `start_window_resize` (una frameless no recibe agarres del WM — el borde interior de 6px sigue lanzando `begin_resize_drag`), `WEBKIT_DISABLE_DMABUF_RENDERER=1`, el veto de glass.
- `setup()` centra la ventana y llama a `window.show()`: nace oculta (`visible: false`) y se muestra ya centrada. Verificado: `cargo check` + `cargo fmt` + `pnpm typecheck` + `lint` + `test` en verde.

## 2026-09-29 — Public-ready: skills, iconos móviles, dispositivos físicos

- **Skill `linux-build`** (`.claude/skills/linux-build/`) absorbe `scripts/build-linux.sh` (+ `.cmd`): builds Linux solo por SSH en la caja Ubuntu-arm-docker (Cinnamon/X11), rsync sin `.git` (nunca clona), `--debug` = `--no-bundle` rápido, `--verify` = `assistant windows+shot+ocr`; auto-arranca Vite para runs debug (devUrl `:1420`). Makefile: `build-linux` → loop rápido, nuevo `linux-release`, `build-windows` (cargo-xwin).
- **Iconos móviles arreglados de raíz**: `branding/icon-1024.png` es el máster (`icons.master` en `branding.json`); `scripts/mobile/mobile-icons-regen.sh` (post-init en `apple-xcode.sh`/`android-autogen.sh`) corre `tauri icon` y compone el trío de marketing iOS 1024 (light/dark/tinted) que esta versión del CLI nunca genera. Los templates móviles vendoreados llevan placeholders neutros — un `gen/` fresco no puede arrastrar arte ajeno nunca más. De paso: el generador `xcodegen` desaparece de los docs (el init del CLI vendoreado es el único).
- **Branding**: `make rebrand` ahora propaga también `authors` + `description` (Cargo.toml, package.json) y avisa el seguimiento de la caja Linux (la skill deriva el binario de Cargo.toml).
- **Flota iOS**: `.env` carga automático en make (include+export) y `apple-xcode.sh` lo sourcea; `APPLE_DEVELOPMENT_TEAM` traducido desde `DEVELOPMENT_TEAM` con fallback `scripts/.team-id`; cada receta de make resuelve `cargo`/`rustc` vía rustup (el cargo Homebrew no tiene el std cross → E0463). Verificado de punta a punta en un iPhone 15 Pro Max físico (Personal Team, provisioning gratuito de 7 días) y en un dispositivo Android físico ARM32 (APK armv7, `INSTALL_FAILED_NO_MATCHING_ABIS` → `--target armv7`).
- **`install-skills.sh --verify` es content-aware** (hash de cada fichero; MISSING/STALE/EXTRA + exit code; md5 portable).
- **Status bar Android, dos bugs graves arreglados**: (1) el flash inicial era el fondo lavanda/morado por defecto de Material3 — el template Android ahora fija `tauri_window_bg` (tokens del frontend: `#FFFFFF` / zinc-950 `#18181B`) en `values{-night}/themes.xml` + splash `values-v31`; (2) al salir a segundo plano y volver, los handlers de resume/focus re-aplicaban el estado NOCHE del SISTEMA, así que app clara + sistema oscuro (o al revés) dejaba iconos invisibles — `MainActivity` ahora persiste el estilo resuelto por el FRONTEND (`lastJsNight`/`resolvedNight`) y re-aplica ese. Verificado en el dispositivo físico armv7 con sondas de píxeles (frame inicial = `#18181B`, sin morado; iconos visibles tras volver: 10.3% de píxeles oscuros en la franja) y logcat (viejo: resumes con night=true tras la llamada JS; nuevo: estilo conservado).
- **Puente de tema Linux + chrome E2E** (caja Cinnamon, `decorations:false` se mantiene tras 4 experimentos — `decorations:true` siempre trae la titlebar nativa de muffin; GTK3 no tiene overlay): nuevo comando Rust `set_linux_theme` empuja el tema RESUELTO de la app a GTK (`gtk-application-prefer-dark-theme`), invocado por el theme provider igual que `set_status_bar_style`, así los scrollbars/controles nativos de WebKitGTK dejan de seguir al sistema cuando app y sistema difieren (verificado por log `prefer-dark=false/true/false` al togglear). Banda de agarre de resize 6px→8px (`RESIZE_BAND`; los marcos nativos se sienten mejor porque su agarre es más generoso). E2E con xdotool en la caja: delta de drag exacto (+120,+60), resize oeste exacto (−100/+100), doble-clic maximiza (1920×1040) y restaura (1300×800). Fila Linux de AGENTS §4 actualizada.
- **Barrido pre-publicación**: eliminados los restos de supabase del proyecto anterior — CSP `connect-src https://*.supabase.co` (conf base + macOS) y los `build.rs` EMBED_KEYS / `validate_supabase_url` (que hacían PANIC de un build release cuyo backend no fuera *.supabase.co). Añadido `.gitattributes` (LF para scripts/configs, marcadores binarios — los clones Windows siguen funcionando) y un `CONTRIBUTING.md` raíz. Corregido el warning de CSS de Tailwind: `env()` en valores arbitrarios se emite como `env(...)` inválido por Tailwind v4/lightningcss (la clase del header `pt-[env(safe-area-inset-top)]` nunca se aplicaba y el calc `h-[calc(3.5rem+env(...))]` rompía el optimizador) — el padding safe-area y la altura móvil del header ahora viven como CSS plano en `.app-header` (`html.ios/.android`), build sin warnings. Titular del LICENSE fijado a Yanx Studio; `make doctor` reporta cargo-tauri vía la invocación real `cargo tauri`. Metadatos del repo en GitHub (descripción + topics).
- **CI semanal por schedule** (decisión pensando en la cuenta gratuita): `.github/workflows/ci.yml` corre solo lunes 18:00 UTC + `workflow_dispatch` (nada de push/PR). Los jobs solo llaman targets del Makefile — `make ci-frontend` y `make ci-rust` (ubuntu-latest, `permissions: contents: read`); móvil y bundles nativos siguen fuera (pipeline manual de 5 OS). Deps de sistema de Tauri instaladas para clippy/fmt/test; `.nvmrc`/engines y rust-cache reutilizados. Documentación EN/ES del "sin CI" corregida (README, testing, AGENTS, scripts) y changelog EN+ES (buena parte con especificación externa).
- **Rust pulido a cero avisos pedantic+nursery**: revisión manual completa de `lib.rs` (750L) + stubs de platform + `main.rs` + `build.rs`. clippy `-D warnings -W pedantic -W nursery` reporta 0 lints en el host Y en la caja Linux (valida las rutas `cfg(linux)`): constantes extraídas, `ptr.cast`, brazos `Self::`, puntos-y-coma, backticks de doc + `# Panics`, `eprintln!` → `log::info!`, `#[allow]` puntuales con razón donde el contrato de comandos de Tauri exige args owned/`Result` (window_effects_set, set_status_bar_style, set_linux_theme). `make ci-rust` se queda en clippy estándar según el spec del CI.
- **Guardas de mantenibilidad** (locales, fuera del spec del CI a propósito): `make check-docs` corre `scripts/check-docs-parity.sh` (lista de ficheros + conteo de headings por nivel + proxy de orden — la traducción cambia legítimamente las palabras de los títulos, así que se compara la estructura, no los títulos — más la cobertura del router docs/README) y `scripts/check-agents-anchors.sh` (anclas `file:line` de AGENTS + docs frescos resueltas con el mapa de nombres; los changelogs quedan fuera porque la historia cita líneas viejas a propósito). Ambas cazan los dos modos de deriva que sufrimos de verdad (paridad, anclas ~100 líneas desfasadas).
- **Recomendaciones de mantenibilidad aplicadas**: (1) política de versiones escrita en contributing.md (EN+ES) — cuándo subir TEMPLATE_VERSION/tag, mapeo semver, rebrand+regen+verify en las subidas; (2) `make check-docs` conectado a `.husky/pre-commit` (paridad + anclas ahora bloquean commits); (3) mantenimiento del CI semanal documentado en testing.md (EN+ES) — dispatch manual, qué significa un lunes en rojo, "no silencies el job"; (4) riesgo del registro einui documentado en contributing.md (EN+ES) — los componentes commiteados son autocontenidos; el registro solo hace falta para los NUEVOS.
- **Barrido de cumplimiento i18n (frontend)**: el footer armaba su frase con strings hardcodeados ('Built with'/'Hecho con', ' and '/' y ') y un "© Yanx Studio" fijo — violando la regla de claves de AGENTS §5 y bloqueando el rebrand de los adoptantes. El footer ahora renderiza la clave existente `footer.builtWith` y una clave nueva `footer.copyright` (`© {{year}} Yanx Studio`, editable — los adoptantes rebrandean sin tocar JSX). El demo greet dejó de reemplazar la respuesta del backend con string-replace (fijada a idioma y frágil) — el texto visible sale de la clave nueva `status.greeted` con interpolación, y la llamada IPC queda como demo del path de error. Los sets de claves en/es siguen idénticos (verificado). Todas las cadenas de usuario del frontend pasan por `t()`.
- **Capabilities reforzadas**: `opener:allow-open-url` ahora explícito en default.json (el interceptor de links externos de main.tsx depende de él — el set de `opener:default` podría cambiar entre versiones del plugin; el grant explícito convierte el comportamiento navegador-sistema en contrato garantizado, no en accidente del set por defecto). Verificado con cargo check (capabilities validadas contra el schema).
- **Identidad web**: la capa web era la última superficie sin branding — `apps/web/public` no existía, así que el enlace del favicon apuntaba a un `/vite.svg` inexistente (ícono en blanco en navegadores/webviews), y el `<title>`/`og:title` de `index.html` quedaba con la marca del template tras un rebrand. `branding-update.sh` ahora fija title/og:title (nombre en Title Case vía python3 — portable, sin sed GNU) y genera `public/favicon.png` (128px) del máster de iconos; index.html ahora referencia `/favicon.png`. El `package.json` raíz ganó los metadatos npm que faltaban: `license: MIT`, `repository`, `homepage` (completitud de cara al adoptante).
- **Bug de greet i18n cazado por la guarda de interpolación nueva**: la clave `status.greeted` usaba un solo brace `{name}` pero i18next interpola `{{name}}` — el saludo renderizaba literal "Hello, {name}!". Corregido en ambos locales. `.husky/pre-commit` no tenía `set -euo pipefail`: un `lint-staged` fallido podía quedar enmascarado si el `make check-docs` final pasaba (el commit se colaba). Guarda añadida. `check-docs-parity.sh` ganó un 4º check: detección de interpolación de brace único, anclado `(?<!\{)\{…\}(?!\})` — el primer regex naíf hacía backtracking dentro de `{{year}}` (falsos positivos en cada `{{…}}`), cazado y sustituido por la versión anclada (verificado con muestras: 0 falsos positivos, singles reales detectados).
- **Fixes del audit frontend (agente A, batch 1)**: H1 header móvil — `html.ios`/`html.android` nunca se añadían (title-bar lo limitaba a desktop), la regla de altura safe-area era código muerto; ahora cada plataforma conocida recibe su clase (strings desconocidos se ignoran — nunca revienta classList) + tests de regresión. H2 el typecheck de `apps/web` era un no-op (tsconfig solution-style + `tsc --noEmit`); ahora `tsc -p tsconfig.app.json && tsconfig.node.json` (26 ficheros de src comprobados, antes 0). H3 el toggle de tema desde `system`+oscuro escribía "dark" (primer clic no-op) — el provider ahora expone `resolvedTheme` y el toggle parte de él (+ tests). M1 el glass ya no se aplica antes de resolverse la plataforma en el shell Tauri (flash de boot en Linux). M4 la banda de resize ya no roba clics a los controles del top 8px y evita el doble IPC del drag (un IPC por pulsación). M5 focus ring visible en claro+glass; tap-highlight de iOS suprimido. M7 el texto del greet traduce en render (sin congelarse al cambiar idioma). Skip link y label de nav keyed; claves i18n muertas fuera; hero hint ya no imprime "D" dos veces. +9 tests de regresión (17 en web).
- Nits: schema de `biome.json` 2.5.14, `turbo.json` test `outputs: []`, `authors` del template, `IOS_DEVICE` → `iPhone 18 Pro` en todos lados, refs `file:line` de la tabla §4 de `AGENTS.md` re-ancladas al código actual.

### Barrido de auditoría 2 — pase de verdad backend/configs/tooling
- **Bugs reales corregidos**: PATH de LLVM en Linux en `scripts/build-windows.sh` (`/usr/lib/llvm-*/bin` iba entrecomillado → un `*` literal que nunca expande, así que cargo-xwin no encontraba `llvm-rc`/`lld-link`; ahora un loop con glob); `scripts/branding-update.sh` usaba `sed -i ''` solo-BSD (aborta GNU sed bajo `set -e` → rebrand roto en Linux/Git Bash; ahora python3 portable); `env_logger` estaba declarado pero nunca se inicializaba (cada `log::*` del crate era un no-op silencioso — ahora `Builder::from_env` al inicio de `run()`); el test del CLI vendoreado contradecía MOD-1 (`fetch_options` cae al fallback en vez de fallar — aserción corregida; `cargo test --lib mobile::` en verde); el grep de identidad de `detect-project.sh` no veía el crate con T mayúscula (ahora case-insensitive).
- **CSP unificada**: `https://*.supabase.co` fuera de `tauri.windows.conf.json` + `tauri.android.conf.json` — los cuatro targets envían ya la CSP idéntica (base + macOS ya estaban limpios), así que la afirmación "una sola política estricta en todos los targets" de `tauri.md` es cierta. Las menciones de validación `SUPABASE_*` en `tauri.md`/`getting-started.md`/`.env.example` desaparecen (el código nunca las tuvo).
- **Peso muerto eliminado**: la ruta actool → `TAURI_ASSETS_CAR` de `build.rs` (nadie consumía la env var; tauri-bundler solo lee entries `.car`/`.icon` de `bundle.icon`, así que el "AppIcon con temas" nunca se envió — `icon.icns` fue siempre el icono real) + `CFBundleIconName` de `Info.plist`; `src-tauri/vendor/tao-0.35.3` + `swift-rs` (sin referencias, 1.6 MB); la recomendación de Prettier en VS Code (el repo es solo-Biome); los `tokio` sin uso (dep de target macOS + dev-dep, cero usos); la fila fantasma `TAURI_CLI` (nadie la lee).
- **Robustez de rebrand**: la phase de Xcode hardcodeaba el nombre de la lib fuente (`libtauri_react_template_lib.a`, minúscula — funcionaba solo por APFS case-insensitive y rompería para cada adoptante rebrandeado) → ahora un glob `lib*.a` (el nombre del crate cambia con el branding; el nombre enlazado `libapp.a` no). Validado con un `apple-xcode.sh --build` completo en macOS.
- **Info.plist**: fuera `NSAllowsArbitraryLoads` (se mantiene `NSAllowsLocalNetworking` — el devUrl es local), `NSLocalNetworkUsageDescription` bilingüe.
- **Pase de verdad en docs**: `hotreload` retirado de todos los sitios donde seguía documentado como config viva (scripts/README, mobile, troubleshooting, mods.md, xcode-dev.command, README — EN+ES): el rebase a 2.12 hizo de `debug` el flujo dev/HMR, y la prosa del probe JSON-RPC de la era 2.11 desaparece. La afirmación del sentinel `__TAURI_DEVELOPMENT_TEAM__` se sustituye por la realidad (`APPLE_DEVELOPMENT_TEAM` exportada por `apple-xcode.sh`, consumida en `ios init`). `pnpm dev:web` → el real `make dev:web`. Banda de resize 6px → 8px en todo lo vigente (README, testing, tauri, native-feel, troubleshooting). `TPL`/`TAURI_CLI` → `TMPL_DIR`/`CARGO_TAURI` en la skill de rebase. Nombres del binario Windows (`Tauri-react-template.exe`). Inventario de scripts/README completado (branding-update, check-*, mobile/*.swift). Metadatos de `Cargo.toml`: `license` + `repository`.
- **Anclas re-fijadas**: cada `lib.rs:NNN` de AGENTS + docs re-resuelta contra el fichero actual (la inserción de env_logger desplazó ~+7 líneas; entradas antiguas citaban tres eras distintas), más las refs de `header.tsx`, `window-controls.tsx`, `globals.css`, `App.tsx`, `Cargo.toml` y `capabilities/default.json`. Se probó un auto-fixer ingenuo y se revirtió (corrompió 9 ficheros y resolvió símbolos a menciones en comentarios) — el pase final usó pares de líneas explícitos y verificados.

## Lecciones para futuros cambios

- Si ves `// HuLa fix`, esa línea sobrevivió a múltiples bugs de plataforma. Lee el commit antes de tocarla.
- `backdrop-blur` en Linux está vetado por motivo — cualquier re-activación debe manejar DMABUF + NVIDIA + Wayland y mantener RAM plana al redimensionar.
- Traffic lights: nunca elimines uno de los tres mecanismos — cada uno cubre un timing distinto (general, macOS 26, live-drag).
- Titlebar de Linux: la ventana es frameless + opaca (`decorations: false`, `transparent: false`), esquinas cuadradas del sistema por diseño — el arco CSD (`GtkHeaderBar` enganchada, clase `tauri-app`, input shape) se eliminó deliberadamente el 27-09-2026. La app sigue dibujando su titlebar (`header.tsx` + `WindowControls`) y el borde interior de 8px sigue lanzando `begin_resize_drag` (`start_window_resize`). Nunca re-añadas radio CSS ni un provider GTK para redondear las esquinas.
- `src-tauri/gen/` siempre es desechable — la fuente real de Xcode es `vendor/tauri-cli-*/templates/mobile/ios/` (ahora rebase del 2.12.0 stock + retoques; el `[patch]` de mobile2 sobra desde que 0.22.5 trajo el fix de Xcode 27).

Siguiente: [Contribuir →](./contributing.md) · [Sensación nativa →](./native-feel.md)
