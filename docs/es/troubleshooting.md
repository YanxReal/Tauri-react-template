# Solución de problemas

## Terminal rota: `35;22;36M` / `?1000h`

**Causa:** `pnpm dev` (= `turbo dev`) activa el modo ratón TUI de Turbo. `tauri dev` lo mata con `SIGTERM` dejando la terminal en ese modo.

**Fix:** `tauri.conf.json:build.beforeDevCommand` ya es `pnpm --filter web dev` (Vite directo, sin Turbo). Usa `make dev` / `pnpm tauri:dev` para desktop. Solo ejecuta `pnpm dev` standalone (solo web).

Resetea una terminal rota: `reset` o `tput rmcup`.

## Traffic lights de macOS saltan al redimensionar

Asegúrate de que `lib.rs:116` `adjust_macos_traffic_lights` + `ensure_traffic_lights_observer` + polling 60 fps existan. Contrarrestan que AppKit los resetee a `12px` en cada layout. Verifica `titleBarStyle: Overlay` + `hiddenTitle` en `tauri.macos.conf.json`. Comprueba targets `22.5/44.5/66.5`.

## Ventana plana en Linux / sin sombra / esquinas cuadradas

Por diseño la app **no** dibuja su propio marco: `tauri.linux.conf.json:11` usa `decorations: true`, así que GTK (CSD) o el compositor (SSD) dibujan la titlebar, la sombra y el radio de esquinas. Si no ves nada de eso, el problema es la sesión/tema, no la app — revisa `echo $XDG_SESSION_TYPE` y que haya un tema GTK. Nunca vuelvas a añadir `box-shadow` / `border-radius` / `margin` sobre `.app-shell` en Linux: el shell es el área cliente dentro del marco nativo y esas reglas se ven como esquinas cortadas bajo la titlebar.

## Windows: no aparecen los caption buttons / no hay Snap Layouts

Windows es frameless (`tauri.windows.conf.json:12` → `decorations: false`) y la titlebar es de la app: `header.tsx:191` renderiza `window-controls.tsx` y `lib.rs:361` llama a `create_overlay_titlebar()`. Si los botones no salen, comprueba que `platform === 'windows'` resolvió (comando Rust `platform_info`) y que `capabilities/default.json:6` sigue listando `allow-minimize` / `allow-close` / `allow-is-maximized` / `allow-set-focus` (`capabilities/default.json:15`), más `capabilities/windows.json:7` para `decorum:allow-show-snap-overlay` (capability solo-Windows; déjala fuera de `default.json` o `cargo check` falla en macOS/Linux). Los Snap Layouts solo se abren con el hover de 620 ms sobre maximizar (`window-controls.tsx:8` → `show_snap_overlay`), que es el equivalente Win+Z de decorum — tao no puede responder `WM_NCHITTEST` con `HTMAXBUTTON`, así que no hay flyout nativo real de hover. Si alguna vez aparece la barra de 32px que inyecta el plugin encima del header, es que se quitó la regla `[data-tauri-decorum-tb]` (`globals.css:247`).

## Scrollbar con flechas / el header no llega al borde derecho

**Síntoma:** la build de Windows muestra la barra de scroll clásica (carril gris + botones de flecha arriba/abajo) en el borde de la ventana, y el header se queda ~12px antes del borde derecho, empujando los caption buttons hacia dentro.

**Causa:** `.app-shell` era el contenedor de scroll, así que la barra pertenecía al *shell* (header + contenido) en vez de al contenido, y WebView2 dibujaba la barra por defecto (no overlay).

**Arreglo (dos partes, ambas necesarias):**
1. `tauri.windows.conf.json:13` → `scrollBarStyle: "fluentOverlay"` para que WebView2 dibuje la scrollbar **overlay** Fluent (fina, se auto-oculta, flota sobre el contenido). Necesita WebView2 Runtime >= 125.0.2535.41.
2. `.app-scroll` (`globals.css:231`, `apps/web/src/App.tsx:52`) es el único scroller y envuelve solo `main` + `Footer`, así el header queda fuera.

**No** lo "arregles" con CSS: las reglas `::-webkit-scrollbar` anulan el overlay nativo y devuelven la barra clásica con carril reservado y flechas (y añadir `scrollbar-width`/`scrollbar-color` hace que Chromium ignore por completo los pseudo-elementos webkit, que es justo como se cuelan las flechas). En Linux el overlay viene del ajuste GTK `gtk-overlay-scrolling`; en macOS es nativo y se auto-oculta.

## Glitches amarillos glass / RAM disparada en Linux

## Windows: ventana negra / "no se pudo crear el directorio de datos" (WebView2)

**Síntoma:** la app abre y el área de cliente se queda negra/oscura, o un diálogo de WebView2 dice que Microsoft Edge no puede leer ni escribir `…\EBWebView`.

**Causa:** WebView2 nunca creó su carpeta de datos — esto **no** es un problema de render, GPU ni Mica, así que no persigas `transparent` / `window_effects_set`. Aparece cuando el proceso se lanza desde un **contexto de servicio**: una sesión SSH, `PsExec -i 1`, una tarea programada como SYSTEM o WinRM. Esos tokens corren sin el perfil interactivo cargado, así que `%LOCALAPPDATA%\com.tauri-react-template.app\EBWebView` no es escribible para esa identidad.

**Solución:** lanza la app de la forma normal, como el usuario del escritorio que tiene sesión iniciada (acceso directo / `pnpm tauri:dev`). Para fijar la carpeta explícitamente, define `WEBVIEW2_USER_DATA_FOLDER=C:\alguna\carpeta\escribible` antes de arrancar (ojo con el gotcha de cmd: `set VAR=valor && app.exe` se queda con el espacio final, así que entrecomilla: `set "VAR=valor" && app.exe`). Truco de depuración: `scripts/build-windows.sh` + `PsExec64 -i 1 -s` reproduce el fallo, así que no sirve para revisar la UI — copia el exe a una sesión real y haz doble clic.

Desactiva glass — Linux fuerza `glass OFF` por diseño (`glass-cards-provider.tsx` + `globals.css:247`). Mantén `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` en `lib.rs:315`. Ver Plan A degradado en `native-feel.md`.

## `pnpm install` falla / mismatch Node

Requiere **Node >=24** y **pnpm >=10** (`package.json:engines`). Usa `nvm use` / `pnpm env use --global 10`.

## `cargo check` falla en target iOS

```bash
cargo check --target aarch64-apple-ios --manifest-path src-tauri/Cargo.toml
```

Requiere targets de `rust-toolchain.toml` instalados (`rustup show`). Sin Xcode, el `cargo check` de desktop sigue pasando.

## `tauri ios dev` EBADARCH / MIInstallerErrorDomain 15

Xcode 26 lista simuladores vía `devicectl` — `cargo-mobile2 0.22.4` sin parche instala con `-sdk iphoneos` → mismatch de arch.

```bash
make install-tauri-cli
cargo tauri ios dev "iPhone 17"   # no pnpm tauri
```

Para device físico usa `make dev-ios-physical` (necesita `--host 169.254.x.x`).

## Puerto 1420 ya en uso / hotreload `beforeDevCommand terminated`

Otro Vite está corriendo. Mátalo (`lsof -i :1420`, `pkill -f vite`) antes de lanzar el scheme `hotreload` — crea un segundo Vite vía el parent `tauri ios dev`.

## `DEVELOPMENT_TEAM` no inyectado / falla de firma

```bash
echo TU_TEAM_ID > scripts/.team-id
scripts/Xcode/apple-xcode.sh
xcodebuild -project src-tauri/gen/apple/tauri-react-template.xcodeproj \
  -scheme tauri-react-template_Apple -configuration Debug \
  -showBuildSettings | grep DEVELOPMENT_TEAM
```

La selección manual en Xcode se pierde al regenerar — usa `.team-id`.

## Scroll con tirones / rubber-band roto

Nunca añadas `overscroll-behavior:none` u overrides `overflow:hidden` más allá de `globals.css`. La app depende de `touch-action: pan-x pan-y` para scroll nativo. El plugin Rust (`prevent-default` con `Flags::debug()`) no toca el scroll — si añades CSS custom, verifica scroll 0↔max con JS.

## Traducciones faltantes / fallback a inglés inesperado

Asegúrate de que la key exista en **ambos** `en.json` y `es.json`. `fallbackLng: "en"` oculta keys `es` faltantes. Comprueba que `supportedLngs` incluya tu locale en `i18n/config.ts:20`.

Siguiente: [Contribuir →](./contributing.md)
