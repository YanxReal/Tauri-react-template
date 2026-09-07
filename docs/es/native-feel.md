# Sensación nativa — multiplataforma

> **Esta es una app multiplataforma** (desktop: **macOS, Windows, Linux**; móvil: **iOS, Android**) — cualquier cambio debe funcionar y testearse en todos los sistemas. Nunca asumas solo macOS/iOS.

## Guards compartidos (todas las ventanas / todos los OS)

Derivados del commit `c9ae1a4`:

- `tauri*.conf.json` (los 4 configs): `dragDropEnabled: false` + `zoomHotkeysEnabled: false` en cada entrada `windows[]` — no solo macOS.
- `apps/web/index.html:5` — viewport `user-scalable=no, maximum-scale=1.0, viewport-fit=cover`
- `packages/ui/src/styles/globals.css:136` — `* { user-select:none; -webkit-user-drag:none; touch-action: pan-x pan-y }` (inputs/textarea/contenteditable reactivan selección). Sin `overscroll-behavior:none`.
- `apps/web/src/main.tsx:17` — bloqueo `dragstart`, bloqueo de zoom por rueda (`ctrl/meta + wheel`), links externos → `openUrl` vía `plugin-opener`.
- `src-tauri/src/lib.rs:390` — `tauri-plugin-prevent-default` con `Flags::debug()`: en **release** bloquea defaults del webview (menú contextual, devtools, reload); en **debug** los conserva. Nunca toca el scroll del documento.

Móvil (menú long-press iOS, Android) usa las mismas reglas CSS/JS (`touch-action: manipulation` mata el double-tap zoom en iOS).

## macOS — traffic lights (live-resize sin flicker)

Referencia: `wry#1747`, `tauri#13044`. `titleBarStyle: Overlay` + `hiddenTitle` deja el webview **debajo** de los traffic lights. AppKit los resetea a `12px` nativos en cada pase de layout (`setContentView:`, carga del webview, `NSWindowDidResize`, `NSViewFrameDidChange`), y `drawRect:` en `WryWebViewParent` no basta. En macOS 26 el race es peor.

**Fix HuLa (3 mecanismos en `src-tauri/src/lib.rs:107`)**

1. Hook `WindowEvent::Focused/Resized/ScaleFactorChanged` (`lib.rs:437`) — fallback general.
2. `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (`lib.rs:250`) — más fiable que `WindowEvent` en macOS 26.
3. **Polling live-resize a 60 fps** (`NSTimer` en `NSRunLoopCommonModes` + `needs_update` `±0.6px`) mientras `inLiveResize` — dispara durante `NSEventTrackingRunLoopMode`, no solo al soltar (`lib.rs:449`).

Posiciones finales: `Close 22.5 / Mini 44.5 / Zoom 66.5` (centros de 22px, `15px` con `grow 3`, `lower 8`, `shift_right 16` + `extra_gap 0/2/4`, `pl-[96px] sm:pl-[108px]` en header). `setAutoresizingMask(0)` evita que AppKit vuelva a auto-resize entre frames. Ver `lib.rs:adjust_macos_traffic_lights` + `ensure_traffic_lights_observer`.

Verifica: `pnpm typecheck && pnpm lint && pnpm build` + testear scroll / click / no-zoom en un build real por plataforma.

## Efecto cristal / glass (window-vibrancy) — toggle

Patrón de **Prestly**: toggle nativo de translucidez.

- **Rust** (`lib.rs:18`): crate `window-vibrancy = "0.8"`. Comando sync `window_effects_set {enabled, dark?}` (`lib.rs:78`) — vibrancy (`NSVisualEffectView`) en macOS, Mica en Windows 11; Linux/móvil devuelven `unsupported` (no-op). Debe ser **sync** (main thread).
- **Frontend** (`apps/web/src/components/vibrancy-provider.tsx` + `glass-cards-provider.tsx`): `VibrancyProvider` + `useVibrancy()` persistido en `localStorage` (`vibrancy`), `GlassCardsProvider` (`glass-cards`). `html.vibrancy` activa `globals.css:177` body transparente. `dark` sigue al tema (tint de Mica).
- **Toggle**: `VibrancyToggle` / `GlassEffectToggle` (`apps/web/src/components/layout/glass-effect-toggle.tsx`) — `Switch` de shadcn, oculto si `!supported` (Linux/móvil/navegador). El toggle combinado controla `glass-cards` + `vibrancy` juntos, por defecto **OFF** (Linux fuerza OFF).
- **CSS** (`globals.css:177`, `307`): `html.vibrancy .app-shell { background: color-mix(... 32%) }` (42% en claro), header macOS `backdrop-blur(16px)`; Windows aporta material Mica; Linux desactiva blur.

## Linux — issues conocidos

### 0. Sombra de ventana (`shadow` no soportado) — solo nativa

`tauri`/`tao` no soportan `WindowConfig.shadow` en Linux (*"Linux: Unsupported"*). Con `decorations:false transparent:true` el nodo GTK `window.background.csd decoration { box-shadow; margin; border-radius }` no se genera → ventana plana.

**Fix — 100% nativo (A, patrón `yaru.dart`) en `lib.rs:315` + `tauri.linux.conf.json:11` + `globals.css:241`:**

- `tauri.linux.conf.json:11` ahora `decorations:true` (`transparent:true` se mantiene) para latch `client_decorated=true`. `lib.rs:315` `apply_linux_window_shadow` hace `gtk_window.set_decorated(true)` + dummy `HeaderBar` (`set_visible(false); set_no_show_all(true); set_show_close_button(false)`) como `set_titlebar` → `gtk_window_should_use_csd() → true` → `use_client_shadow = true` para que el compositor cree el nodo `decoration` en X11 y Wayland. Sin esto, `GdkWindow` queda undecorated sin frame y el `box-shadow` nunca renderiza.
- `GtkCssProvider` anclado **directo al `StyleContext` de la ventana** vía `add_provider(..., APPLICATION)` — Wayland-safe (antes `add_provider_for_screen` era `None` en Wayland). CSS `window.background.csd decoration { box-shadow: 0 16px 48px rgba(0,0,0,.38); margin:12px; border-radius:10px }` (+ `:backdrop`) + `window.background.csd { border-radius:10px }`. Maximizado/tiled/fullscreen → `none`.
- `gdk_window.set_shadow_width(12,12,12,12)` (`_GTK_FRAME_EXTENTS`, también en `realize`) informa al WM sobre los extents invisibles para que snap/maximize no los cuente.
- `globals.css:241` `html.linux .app-shell { border-radius:10px; overflow:hidden }` recorta el contenido al mismo radio de 10px en las 4 esquinas (arriba **y abajo**). Maximizado/fullscreen → `border-radius:0`. El `margin` + sombra de `decoration` lo compone el compositor **fuera** del webview; el `overflow:hidden` asegura que las inferiores no queden cuadradas.

Requisito build: `gtk = "0.18"` + `gdk = "0.18"` (`Cargo.toml:67`, solo linux, GTK3 `webkit2gtk 4.1`). Path `gtk4` (`webkitgtk 6.0`, `gtk4::CssProvider` + `add_provider_for_display` + `gdk::Toplevel::set_shadow_width`) usa mismo CSS.

### 1. Esquinas sin glass

`decorations:false transparent:true` deja la ventana cuadrada. Fix: `html.linux .app-shell {border-radius:10px}` + header/footer `rounded-none` — el `app-shell` recorta a 10px. Ver `globals.css:224`.

### 2. Glass + WebKitGTK → glitches amarillos y RAM disparada

`backdrop-blur` + `DMABUF` en WebKitGTK 4.1 (sobre todo NVIDIA/Wayland) dispara `AcceleratedSurfaceDMABuf was unable to construct a complete framebuffer` + `Error 71` + RAM al redimensionar (docs `linux-graphics` de Tauri, `wry#1747`).

**Fix actual (veto):** en Linux se fuerza `glass OFF` — `glass-cards-provider.tsx` devuelve `false` si `platform==='linux'`, `GlassEffectToggle` deshabilitado con tooltip, y `globals.css:283` pone `html.linux .glass-card { backdrop-filter:none; background:var(--card) }` + `contain:paint`. `lib.rs:371` fija `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` antes del `Builder`.

**Plan A (glass degradado sin blur — no implementado):** renderizar `GlassCard` sin `backdrop-blur` en Linux — solo `bg-white/[0.06] + border` translúcido + `box-shadow` sutil. Ver `README.md` para el sketch.

## Checklist de verificación

```bash
pnpm typecheck && pnpm lint && pnpm build
```

Luego testea **scroll + click + no-zoom** en un bundle real por OS (`pnpm tauri:build` o `scripts/build-*.sh`).

Siguiente: [Scripts y tooling →](./scripts.md)
