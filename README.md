# tauri-react-template

Bilingual Tauri v2 + React 19 + Vite 8 + Tailwind v4 starter — ready for your private use.
Plantilla bilingüe Tauri v2 + React 19 + Vite 8 + Tailwind v4 — lista para uso privado.

> **Documentation / Documentación**
> - 🇬🇧 English: [`docs/en/README.md`](docs/en/README.md) — [Getting Started](docs/en/getting-started.md) · [Architecture](docs/en/architecture.md) · [Frontend](docs/en/frontend.md) · [Tauri](docs/en/tauri.md) · [Styling](docs/en/styling.md) · [i18n](docs/en/i18n.md) · [Mobile](docs/en/mobile.md) · [Native Feel](docs/en/native-feel.md) · [Scripts](docs/en/scripts.md) · [Troubleshooting](docs/en/troubleshooting.md) · [Changelog](docs/en/changelog.md)
> - 🇪🇸 Español: [`docs/es/README.md`](docs/es/README.md) — [Primeros pasos](docs/es/getting-started.md) · [Arquitectura](docs/es/architecture.md) · [Frontend](docs/es/frontend.md) · [Tauri](docs/es/tauri.md) · [Estilos](docs/es/styling.md) · [i18n](docs/es/i18n.md) · [Móvil](docs/es/mobile.md) · [Sensación nativa](docs/es/native-feel.md) · [Scripts](docs/es/scripts.md) · [Solución de problemas](docs/es/troubleshooting.md) · [Changelog](docs/es/changelog.md)
> - Bilingual router: [`docs/README.md`](docs/README.md) · Agent contract: [`AGENTS.md`](AGENTS.md) (parity rule EN ↔ ES)

## Stack

- **Runtime:** Node >=24, pnpm >=10, Rust stable (1.85+, edition 2021)
- **Frontend:** React 19.2, Vite 8.2, TypeScript 5.9 (strict), Tailwind 4.3 (`@tailwindcss/vite`), Biome 2.5, Vitest 4 + Testing Library, i18next (EN/ES)
- **Desktop:** Tauri 2.11 (`@tauri-apps/api` + `plugin-opener`), Cargo edition 2021
- **Monorepo:** Turborepo 2.10, workspaces `apps/*` + `packages/*`, path alias `@` → `apps/web/src`, `@workspace/ui/*`
- **UI:** shadcn + Base UI (`@base-ui/react`), `globals.css` with OKLCH, `Inter Variable`

## Quick start / Inicio rápido

```bash
# requirements: node 24, pnpm 10, rust
pnpm install
pnpm dev          # turbo dev (web on http://localhost:1420)
pnpm tauri:dev    # tauri dev (needs Rust)
pnpm build        # turbo build
pnpm typecheck
pnpm lint         # biome check
pnpm test         # vitest
```

## Project structure / Estructura

```
.
├── apps/web                 # Vite React app (HTML5 semantic, i18n)
│   ├── index.html           # semantic meta, OG, theme-color
│   └── src/
│       ├── App.tsx          # header/main/section/footer + i18n
│       ├── i18n/            # en.json / es.json
│       ├── components/layout/{header,hero,features,footer}.tsx
│       └── test/setup.ts
├── packages/ui              # design system (shadcn)
│   └── src/{components,lib,styles/globals.css}
├── src-tauri/               # Tauri v2 backend (Rust)
│   └── tauri.conf.json      # frontendDist: ../apps/web/dist
├── biome.json               # formatter + linter (replaces ESLint+Prettier)
├── turbo.json
└── pnpm-workspace.yaml
```

## i18n — Bilingual / Bilingüe

- `apps/web/src/i18n/config.ts` — `i18next` + `browser-languagedetector` + `localStorage` cache
- Locales: `en.json` / `es.json` typed (`defaultNS: translation`)
- Language toggle in `Header` updates `document.documentElement.lang` and persists
- Add a locale: copy `en.json` → `xx.json`, add to `supportedLngs` in `config.ts`

```tsx
const { t, i18n } = useTranslation()
t("hero.title") // EN/ES auto
await i18n.changeLanguage("es")
```

## HTML5 Semantic

- `index.html` has `lang`, `description`, `og:*`, `theme-color`, `noscript`
- `App.tsx` uses `<header><nav><main><section><footer>` + skip-link + landmarks + `kbd` hint
- `Header` has `aria-label="Main navigation"`, `Footer` has `contentinfo`

## Adding shadcn components

```bash
pnpm dlx shadcn@latest add button -c apps/web
pnpm dlx shadcn@latest add dialog -c apps/web
# components land in packages/ui/src/components
```

```tsx
import { Button } from "@workspace/ui/components/button"
```

## Tauri

- `src-tauri/tauri.conf.json:build` → `beforeDevCommand: "pnpm dev"`, `frontendDist: "../apps/web/dist"`
- Rust: `cargo check --manifest-path src-tauri/Cargo.toml`
- Add Tauri plugin: `pnpm --filter web add @tauri-apps/plugin-xxx` + `Cargo.toml` + `capabilities`

## Native app feel — multiplataforma / cross-platform

Esta es una **app multiplataforma** (desktop: **macOS, Windows, Linux**; mobile: **iOS, Android**) —
no pienses solo en macOS o iOS. Cualquier cambio debe funcionar y testearse en todos los
sistemas. Configuración actual de "sensación nativa", derivada del commit `c9ae1a4`:

### macOS traffic lights — live-resize sin flicker (wry#1747, tauri#13044)

`titleBarStyle: Overlay` + `hiddenTitle` deja el webview bajo los traffic lights. AppKit los
resetea a `12px` nativos en cada pase de layout (`setContentView:`, webview load, `NSWindowDidResize`,
`NSViewFrameDidChange`), y `drawRect:` de `WryWebViewParent` no basta (wry#1747). En macOS 26 el race es peor.

**Fix HuLa (3 mecanismos en `src-tauri/src/lib.rs`):**
- `WindowEvent::Focused/Resized/ScaleFactorChanged` (`init.rs` hook) — fallback general.
- `NSNotificationCenter` `NSWindowDidResizeNotification` + `DidMove` (macOS 26+ más fiable que `WindowEvent`).
- Polling live-resize a `60fps` (`NSTimer` en `NSRunLoopCommonModes` + `needs_update` `±0.6px`) mientras `inLiveResize` — dispara durante `NSEventTrackingRunLoopMode`, no solo al soltar.

Posición final: `Close 22.5 / Mini 44.5 / Zoom 66.5` (22px centros, `15px` con `grow 3`, `lower 8`, `shift_right 16` + `extra_gap 0/2/4`, `pl-[96px] sm:pl-[108px]` en header). `setAutoresizingMask(0)` evita que AppKit los vuelva a autoresize entre frames. Ver `lib.rs:adjust_macos_traffic_lights` + `ensure_traffic_lights_observer`.

- `dragDropEnabled: false` + `zoomHotkeysEnabled: false` en TODAS las ventanas (`tauri.conf.json`
  + `tauri.{macos,windows,linux}.conf.json` — las 4 configs, no solo macOS).
- Viewport `user-scalable=no`, `maximum-scale=1.0` (desactiva el zoom del webview).
- `globals.css`: `user-select:none` / `-webkit-user-drag:none` (excepto inputs/textarea/contenteditable),
  `touch-action: manipulation` en `html,body` (scroll nativo conservado y fluido en WebKit).
- `main.tsx`: bloqueo de `dragstart`, de zoom con rueda Ctrl/⌘, y links externos → `plugin-opener`.
- `tauri-plugin-prevent-default` registrado con `Flags::debug()`: en **release** bloquea los
  defaults del webview (context menu, devtools, reload); en **debug** lo conserva. El plugin
  NO toca el scroll; el scroll del documento se validó sano (0↔max) por JS.
- Mobile se apoya en las mismas reglas CSS/JS (`touch-action` desactiva el double-tap zoom en iOS).

### Efecto cristal / glass (window-vibrancy) — toggle

Patrón de **Prestly**: toggle nativo de translucidez de la ventana.

- **Rust**: `window-vibrancy = "0.8"` (crate, no plugin). Comando sync `window_effects_set {enabled, dark?}` en `src-tauri/src/lib.rs` — vibrancy (`NSVisualEffectView`) en macOS, Mica en Windows 11; Linux/mobile responden `unsupported` (no-op). Patrón de Prestly: el comando debe ser **sync** (corre en el main thread; `window-vibrancy` exige el main thread).
- **Frontend**: `VibrancyProvider` + `useVibrancy()` (`apps/web/src/components/vibrancy-provider.tsx`). Persistencia en `localStorage` (`vibrancy`), ON por defecto donde hay soporte nativo. Al activarse añade `html.vibrancy` → `globals.css` pone `body { background: transparent }` para que el material del OS se vea. `dark` sigue al tema (tint de Mica en Windows).
- **Toggle nativo**: `<VibrancyToggle />` (`apps/web/src/components/layout/vibrancy-toggle.tsx`) — usa el `Switch` de shadcn/Base UI y desaparece si `!supported` (Linux/mobile/browser).
- **Dos switches independientes**: `GlassControls` (`apps/web/src/components/layout/glass-controls.tsx`) monta `VibrancyToggle` (material nativo) + `GlassCardsToggle` (componentes `glass-*`), cada uno con su `localStorage` (`vibrancy` / `glass-cards`), por defecto **OFF** (`VibrancyProvider` ya no hace `|| stored===null`). Antes eran un solo toggle combinado. En Linux el switch de tarjetas queda deshabilitado; el nativo se oculta.

To verify: `pnpm typecheck && pnpm lint && pnpm build`, y testear scroll + click + no-zoom en una
build real de cada plataforma.

### Windows — titlebar overlay (estilo Edge / VS Code)

`tauri.windows.conf.json` → `decorations: false`, `transparent: true` (para que Mica siga viéndose). La titlebar la dibuja la app con el plugin de la comunidad `tauri-plugin-decorum` (`create_overlay_titlebar()` en `src-tauri/src/lib.rs`), más los caption buttons React de `apps/web/src/components/layout/window-controls.tsx` (minimizar/maximizar-restaurar/cerrar), montados por `header.tsx` **solo** en Windows. El hover de 620 ms sobre maximizar abre **Snap Layouts** (`plugin:decorum|show_snap_overlay`); decorum inyecta una barra de 32px que ocultamos por CSS (`[data-tauri-decorum-tb]`), así que la franja de arrastre sigue siendo el header de siempre (`data-tauri-drag-region` + `useWindowDragRegion`) y DWM conserva las esquinas redondeadas (`DWMWCP_ROUND`).

**Scroll:** `scrollBarStyle: "fluentOverlay"` (WebView2 ≥ 125.0.2535.41) para que la barra sea la **overlay** de Fluent — fina, auto-oculta y por dentro del contenido, sin carril ni flechas. El único scroller es `.app-scroll` (envuelve `main` + `Footer`), así que el header — que es la barra de título — queda fuera y siempre llega al borde derecho. No añadir CSS de scrollbar (`::-webkit-scrollbar` / `scrollbar-width`): anula el overlay y devuelve la barra clásica con flechas.

### Linux — limitaciones conocidas / Known issues

**0. Marco de ventana (titlebar propia + CSD "latched", patrón Chromium/VS Code/Edge):** `tauri.linux.conf.json` → `decorations: true`, **`transparent: true`** y `visible: false`. `install_linux_frame` (`src-tauri/src/lib.rs`) engancha CSD con una `GtkHeaderBar` **vacía y oculta** (`set_no_show_all(true)` — tao muestra la ventana con `show_all()`) y pinta transparente el fondo de GTK, así que GTK aporta **solo su sombra nativa**. La titlebar la dibuja la app: la banda fija de 44px del header (`data-tauri-drag-region` + `useWindowDragRegion`) con los **caption buttons** de `WindowControls` (minimizar / maximizar-restaurar / cerrar) — el mismo modelo que Windows y que Edge/VS Code/Chrome en Linux. `globals.css` da `border-radius: 10px` a `.app-shell` para que las 4 esquinas queden redondeadas. **`transparent: true` es lo que hace que se vean curvas de verdad:** con `transparent: false` el fondo del propio webview se queda opaco (el *base colour* de Adwaita, `#1e1e1e` en oscuro) y rellena el área fuera del radio, así que las esquinas se redondean pero revelan casi-negro en vez del escritorio y se leen como cuadradas (tao solo instala el visual RGBA antes del realize y solo para ventanas transparentes). **Por qué no la titlebar nativa:** mutter lee la variante clara/oscura (`_GTK_THEME_VARIANT`) una sola vez, al gestionar la ventana (`LOAD_INIT` en `mutter/src/x11/window-props.c`), así que la SSD no puede seguir al tema de la app (ni con `setTheme`, ni con `xprop`, ni remapeando: los tres comprobados) — una app oscura en un escritorio claro dejaba la barra blanca; y con tao creando la ventana en modo SSD, GTK no cablea el arrastre de CSD, así que una `GtkHeaderBar` no se podía arrastrar (el arrastre del header sí funciona). `useNativeTheme` (`apps/web/src/components/layout/native-chrome.ts`, enganchado en `title-bar.tsx`) refleja el tema en la variante de GTK; necesita el permiso `core:window:allow-set-theme`. Los viejos hacks de `apply_linux_window_shadow` (visual RGBA forzado + `opacity 0.99`) siguen eliminados.

**1. Glass cards + WebKitGTK → glitches amarillos y RAM desbocada (`a2.png`):** `backdrop-blur` + `DMABUF` en WebKitGTK 4.1 (sobre todo NVIDIA/Wayland) dispara `AcceleratedSurfaceDMABuf was unable to construct a complete framebuffer` y `Error 71` + RAM al redimensionar (Tauri `linux-graphics` docs, `wry#1747`). **Solución actual (veto):** en Linux se fuerza `glass OFF` — `glass-cards-provider.tsx` `useGlassCards()` devuelve `enabled:false` + `supported:false` si `platform==='linux'`, `GlassCardsToggle` deshabilitado con tooltip, y `globals.css` `html.linux .glass-card/backdrop-blur { backdrop-filter:none; background:var(--card) }`. Además `src-tauri/src/lib.rs` fija `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` antes de `Builder` y `html.linux { backdrop-filter:none }` para header/shell.

**Plan A — Glass degradado sin blur (no implementado, recomendado):** en Linux renderizar `GlassCard` sin `backdrop-blur`, solo `bg-white/[0.06] + border` translúcido + `box-shadow` sutil. Mantiene estética translúcida sin DMABUF, compatible 100% y sin amarillos. Requiere `glass-card.tsx` variante `if (platform==='linux') return <div className="rounded-xl border bg-white/[0.06]">` y `globals.css` `html.linux .glass-card { background:rgba(255,255,255,0.06) }`.

**Plan B — Detección GPU (no implementado):** habilitar `backdrop-blur` solo en `Mesa/Intel/AMD` (donde `WEBKIT_DISABLE_DMABUF_RENDERER` no es necesario) y mantener veto en `NVIDIA`. Necesita `navigator.gpu` / `WEBGL_debug_renderer_info` (WebKit enmascara `Apple GPU`) + `localStorage` flag `glass-linux-force`. Más frágil.

Se deja el **veto** como está; si quieres vidrio en Linux, implementamos el Plan A.

## Mobile — iOS/macOS (Xcode) y Android

- `src-tauri/gen/` está gitignored (autogen). La fuente de verdad del proyecto Xcode es el
  template `src-tauri/vendor/tauri-cli-2.11.4/templates/mobile/ios/` (target único
  `tauri-react-template_Apple`, destinos **iOS + macOS** vía `apple.xcconfig` y la phase
  "Build Rust Code"). Regenera y compila con:

  ```bash
  scripts/Xcode/apple-xcode.sh            # xcodegen → src-tauri/gen/apple
  scripts/Xcode/apple-xcode.sh --build    # + iOS simulator (CLI) y macOS host
  make gen-apple                  # alias de scripts/Xcode/apple-xcode.sh
  ```

- Usa SIEMPRE el CLI stock (el `cargo tauri` instalado puede ser un build modificado):

  ```bash
  pnpm dlx @tauri-apps/cli@2.11.4 ios build --target aarch64-sim --debug
  pnpm dlx @tauri-apps/cli@2.11.4 android build --debug --target aarch64
  make dev:ios            # iOS simulator (cargo tauri parcheado + simctl, sin EBADARCH)
  make dev-ios-physical   # iPhone físico (cargo tauri parcheado + --host 169.254.x.x)
  make dev-android-emulator   # APK debug → emulador
  ```

- `make dev` (desktop) no requiere Xcode; basta Rust. `start_app()` + `platform/` en
  `src-tauri/src/` adaptan la entrada por plataforma.

### Parche Xcode 26 — `cargo-mobile2` y `cargo-tauri` vendoreados

Xcode 26 hace que `xcrun devicectl list devices --json-output` liste también los **simuladores** (`reality: "simulated"`). El `cargo-mobile2` del registry (0.22.4) no los filtraba y `tauri ios dev` los trataba como físico → `aarch64-apple-ios`/`-sdk iphoneos`/`devicectl install` sobre un simulador → `MIInstallerErrorDomain 15 / EBADARCH [iOS,arm64] vs [iOS-simulator]`.

**Fix en plantilla (no en `gen`, nunca tocar `gen`):**
- `src-tauri/vendor/cargo-mobile2-0.22.4/src/apple/device/devicectl/device_list.rs` añade `reality: Option<String>` y filtro `reality != "simulated"` (ver `Prestly`).
- `src-tauri/vendor/tauri-cli-2.11.4/Cargo.toml` parchea `[patch.crates-io] cargo-mobile2 = { path = "../cargo-mobile2-0.22.4" }`.

Instálalo una vez por clon:
```bash
make install-tauri-cli # compila vendor/tauri-cli y lo instala en ~/.cargo/bin/cargo-tauri
cargo tauri ios dev "iPhone 17" # usa el binario parcheado → Starting simulator ... -sdk iphonesimulator → simctl
```
`pnpm tauri ios dev` (Node CLI) sigue usando el `cargo-mobile2` del registry sin parche — para iOS usa `cargo tauri`.

> **Al actualizar `cargo-mobile2`:** el fix ya está en `cargo-mobile2` `0.22.5` (dev, commit `ee65fb1` — *Fixed iOS simulators being listed as connected physical devices on Xcode 27*) pero aún no está publicado en crates.io (último publicado `0.22.4` del 29 Apr 2025). **Esperamos al release oficial** y dejamos el vendor parcheado tal cual. Cuando `0.22.5` salga y `tauri-cli` lo pida, se borrará el vendor y el `[patch]`. Si actualizas manualmente antes, re-vendorea la nueva versión y reaplica el filtro `reality`, o el bug vuelve.

### Info.plist — plantilla vs autogen

Solo se edita la **plantilla**:
- `src-tauri/Info.plist` — fuente para **macOS** (`tauri.macos.conf.json: bundle.macOS.infoPlist`) y para **iOS** (`tauri.ios.conf.json: bundle.iOS.infoPlist`). Ahí van `NSAppTransportSecurity` (`NSAllowsLocalNetworking` + `NSAllowsArbitraryLoads` para `http://192.0.0.2:1420`/`ws://` de HMR), `NSLocalNetworkUsageDescription` y `NSBonjourServices`.
- `src-tauri/gen/apple/.../Info.plist` y `src-tauri/gen/android/.../AndroidManifest.xml` son **autogen** — se regeneran desde la plantilla + defaults de Tauri. No los edites; todo lo que pongas ahí se pierde en `tauri ios init` / `apple-xcode.sh`.

Sí: si necesitas tocar Info.plist, edita **esos 2** (en la práctica 1 archivo `Info.plist` compartido vía `tauri.*.conf.json`) y **todos** los demás (`gen`) consumen de ahí.

### Dev sin TUI de Turbo

`pnpm dev` = `turbo dev` (TUI `?1000h`). `tauri dev` lo mata con `SIGTERM` y dejaba la TTY en modo mouse → `zsh: command not found: 35;22;36M` sin haber clicado. `tauri.conf.json: build.beforeDevCommand` ahora es `pnpm --filter web dev` (vite directo, sin turbo), así `tauri ios dev` no habilita `?1000h` y no deja la terminal garbled. `pnpm dev` web sigue con TUI si lo lanzas directo.

### DEVELOPMENT_TEAM (firma iOS)

El template NO hardcodea tu Team ID: `scripts/Xcode/apple-xcode.sh` lo inyecta al
regenerar con esta prioridad — **env `DEVELOPMENT_TEAM` → `scripts/.team-id` (gitignored)
→ si no hay ninguno se omite y lo eliges a mano en Xcode → Signing & Capabilities**
(necesario solo para el pipeline `tauri ios dev|build`; sim directo y macOS firman ad-hoc).
Ejemplo persistente:

```bash
echo YOUR_TEAM_ID > scripts/.team-id   # una vez
scripts/Xcode/apple-xcode.sh           # cada regeneración lo inyecta
```

Más detalle: [scripts/README.md](scripts/README.md#firma--development_team-auto-inyección).

## Scripts

| Script | Description |
|---|---|
| `pnpm dev` | `turbo dev` (web) |
| `pnpm build` | `turbo build` |
| `pnpm lint` / `lint:fix` | `biome check` |
| `pnpm typecheck` | `turbo typecheck` |
| `pnpm test` | `turbo test` (vitest) |
| `pnpm tauri:dev` | `tauri dev` |
| `pnpm tauri:build` | `tauri build` |

## Recommended IDE

VS Code + `tauri-vscode` + `rust-analyzer` + `biome` + `tailwindcss` (see `.vscode/extensions.json`).
Settings: `editor.formatOnSave` + `source.fixAll.biome` enabled.

## Git private

This repo is intended as your **private** template.

```bash
gh repo create tauri-react-template --private --source=. --push
# or
git remote add origin git@github.com:YOUR_USER/tauri-react-template.git
git push -u origin master
```

## License

MIT — private template for personal use.
