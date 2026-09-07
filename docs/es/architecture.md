# Arquitectura

## Estructura del monorepo

```
.
├── apps/
│   └── web/                  # App Vite React (puerto 1420)
│       ├── index.html        # SEO, OG, theme-color, viewport-fit
│       ├── vite.config.ts    # alias @, host:true, hmr, vitest
│       └── src/
│           ├── App.tsx       # header/main/section/footer + i18n + greet
│           ├── main.tsx      # providers + guards de sensación nativa
│           ├── i18n/         # config.ts + locales/en.json, es.json
│           ├── components/
│           │   ├── layout/   # header, hero, features, footer, title-bar
│           │   ├── glass-cards-provider.tsx
│           │   ├── vibrancy-provider.tsx
│           │   └── theme-provider.tsx
│           ├── hooks/
│           └── test/
├── packages/
│   └── ui/                   # design system (shadcn)
│       ├── src/components/   # button, dialog, glass-card, etc.
│       ├── src/lib/          # utils (cn, etc.)
│       └── src/styles/globals.css  # Tailwind v4 + OKLCH + overrides nativos
├── src-tauri/                # Backend Tauri v2 (Rust)
│   ├── Cargo.toml            # window-vibrancy, tauri-plugin-prevent-default
│   ├── build.rs              # tauri_build + actool + embedding de env
│   ├── tauri.conf.json       # base (devUrl, frontendDist, windows)
│   ├── tauri.{macos,windows,linux,ios,android}.conf.json
│   ├── capabilities/         # permisos Tauri v2
│   ├── src/lib.rs            # comandos, vibrancy, traffic lights, sombra Linux
│   ├── src/main.rs
│   ├── src/platform/         # current_platform()
│   ├── Info.plist            # plantilla (fuente de verdad para macOS+iOS)
│   └── vendor/               # cargo-mobile2 + tauri-cli vendoreados (parche Xcode 26)
├── scripts/
│   ├── Xcode/apple-xcode.sh  # regenera gen/apple (xcodegen)
│   └── README.md
├── biome.json
├── turbo.json
├── pnpm-workspace.yaml
└── Makefile
```

## Workspace y build

- `pnpm-workspace.yaml:1` — `packages: ["apps/*", "packages/*"]`
- `turbo.json:1` — tareas `build`, `lint`, `format`, `typecheck`, `test`, `dev` (`cache:false`, `persistent:true`, `outputs: ["dist/**"]`).
- Alias de paths:
  - `@` → `apps/web/src` (`apps/web/vite.config.ts:11`, `tsconfig.json`)
  - `@workspace/ui/*` → `packages/ui/src/*` (`packages/ui/package.json:73` exports).

## Frontera frontend → backend

- El frontend llama a Rust vía `invoke` (`@tauri-apps/api`) — ver `apps/web/src/App.tsx:32`.
- Comandos registrados en `src-tauri/src/lib.rs:395`:
  `tauri::generate_handler![greet, platform_info, window_effects_set]`
- Plugins: `tauri_plugin_opener`, `tauri_plugin_prevent_default` (con `Flags::debug()` — ver `native-feel.md`).

## Capas de configuración (Tauri)

El base `src-tauri/tauri.conf.json:1` contiene `build`, `app.windows` comunes y `bundle`.
Los overlays por OS lo extienden (Tauri los mezcla en el build):

- `tauri.macos.conf.json` — `titleBarStyle: Overlay`, `hiddenTitle`, `transparent`, `decorations`, `dragDropEnabled:false`.
- `tauri.windows.conf.json` / `tauri.linux.conf.json` — mismos guards de drag/zoom.
- `tauri.ios.conf.json` / `tauri.android.conf.json` — bundling móvil.

Los 4 configs de escritorio deben mantenerse sincronizados en `dragDropEnabled` / `zoomHotkeysEnabled` / guards de viewport.

## CSS y theming

`packages/ui/src/styles/globals.css:1` es la única fuente de verdad para tokens de diseño (OKLCH), `@theme inline` de Tailwind v4, dark mode `.dark`, translucidez vibrancy, shell de ventana frameless (`.app-shell`) y sombras en Linux. Se importa una vez en `apps/web/src/main.tsx:5` vía `@workspace/ui/globals.css`.

## i18n

`apps/web/src/i18n/config.ts:1` + `locales/en.json|es.json` + `LanguageDetector` (localStorage → navigator → htmlTag). El toggle está en `Header` y sincroniza `document.documentElement.lang`.

## Puertas de calidad

- **JS/TS:** Biome (`biome.json:1`) — formatter (2 espacios, 80 cols, semis `asNeeded`) + linter (recommended, `useImportType:error`). Sin ESLint/Prettier.
- **Rust:** `cargo fmt` + `clippy` con `await_holding_lock: deny` (`Cargo.toml:73`).
- **Tests:** Vitest `4` + jsdom + Testing Library — `apps/web/vite.config.ts:37` y `packages/ui`.
- **Git:** Husky + lint-staged (`package.json:25` — `biome check --write` en `*.{ts,tsx,js,jsx,json,jsonc,css}`).
- **CI:** `.github/workflows/frontend.yml` (typecheck+lint+test+build) + `rust.yml` (cargo check + fmt).

Siguiente: [Frontend →](./frontend.md)
