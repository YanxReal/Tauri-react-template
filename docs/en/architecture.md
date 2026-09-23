# Architecture

## Monorepo layout

```
.
├── apps/
│   └── web/                  # Vite React app (port 1420)
│       ├── index.html        # SEO, OG, theme-color, viewport-fit
│       ├── vite.config.ts    # @ alias, host:true, hmr, vitest
│       └── src/
│           ├── App.tsx       # header/main/section/footer + i18n + greet
│           ├── main.tsx      # providers + native-feel guards
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
│       └── src/styles/globals.css  # Tailwind v4 + OKLCH + native-feel overrides
├── src-tauri/                # Tauri v2 backend (Rust)
│   ├── Cargo.toml            # window-vibrancy, tauri-plugin-prevent-default
│   ├── build.rs              # tauri_build + actool + env embedding
│   ├── tauri.conf.json       # base (devUrl, frontendDist, windows)
│   ├── tauri.{macos,windows,linux,ios,android}.conf.json
│   ├── capabilities/         # Tauri v2 permissions
│   ├── src/lib.rs            # commands, vibrancy, traffic lights, Linux shadow
│   ├── src/main.rs
│   ├── src/platform/         # current_platform()
│   ├── Info.plist            # template (source of truth for macOS+iOS)
│   └── vendor/               # cargo-mobile2 + tauri-cli vendored (Xcode 26 patch)
├── scripts/
│   ├── Xcode/apple-xcode.sh  # regenerates gen/apple (xcodegen)
│   └── README.md
├── biome.json
├── turbo.json
├── pnpm-workspace.yaml
└── Makefile
```

## Workspace & build

- `pnpm-workspace.yaml:1` — `packages: ["apps/*", "packages/*"]`
- `turbo.json:1` — tasks `build`, `lint`, `format`, `typecheck`, `test`, `dev` (`cache:false`, `persistent:true`, `outputs: ["dist/**"]`).
- Path aliases:
  - `@` → `apps/web/src` (`apps/web/vite.config.ts:11`, `tsconfig.json`)
  - `@workspace/ui/*` → `packages/ui/src/*` (`packages/ui/package.json:73` exports).

## Frontend → Backend boundary

- Frontend calls Rust via `invoke` (`@tauri-apps/api`) — see `apps/web/src/App.tsx:32`.
- Commands are registered in `src-tauri/src/lib.rs:421`:
  `tauri::generate_handler![greet, platform_info, window_effects_set]`
- Plugins: `tauri_plugin_opener`, `tauri_plugin_prevent_default` (with `Flags::debug()` — see `native-feel.md`).

## Config layering (Tauri)

Base `src-tauri/tauri.conf.json:1` holds `build`, common `app.windows`, `bundle`.
Per-OS overlays extend it (Tauri merges at build):

- `tauri.macos.conf.json` — `titleBarStyle: Overlay`, `hiddenTitle`, `transparent`, `decorations`, `dragDropEnabled:false`.
- `tauri.windows.conf.json` — same drag/zoom guards + frameless overlay titlebar (`decorations: false`, decorum plugin, app-drawn caption buttons).
- `tauri.linux.conf.json` — same drag/zoom guards + a GTK `GtkHeaderBar` (CSD) installed from Rust so the titlebar follows the app theme (`decorations: true`; the window stays hidden until `setup()` shows it).
- `tauri.ios.conf.json` / `tauri.android.conf.json` — mobile bundling.

All four desktop configs must stay in sync for `dragDropEnabled` / `zoomHotkeysEnabled` / viewport guards.

## CSS & theming

`packages/ui/src/styles/globals.css:1` is the single source of truth for design tokens (OKLCH), Tailwind v4 `@theme inline`, dark mode `.dark`, vibrancy translucency, titlebar/framed window shell (`.app-shell`), and Linux shadows. Imported once in `apps/web/src/main.tsx:5` via `@workspace/ui/globals.css`.

## i18n

`apps/web/src/i18n/config.ts:1` + `locales/en.json|es.json` + `LanguageDetector` (localStorage → navigator → htmlTag). Toggle lives in `Header`, syncs `document.documentElement.lang`.

## Quality gates

- **JS/TS:** Biome (`biome.json:1`) — formatter (2 spaces, 80 cols, `asNeeded` semis) + linter (recommended, `useImportType:error`). No ESLint/Prettier.
- **Rust:** `cargo fmt` + `clippy` with `await_holding_lock: deny` (`Cargo.toml:66`).
- **Tests:** Vitest `4` + jsdom + Testing Library — `apps/web/vite.config.ts:37` and `packages/ui`.
- **Git:** Husky + lint-staged (`package.json:25` — `biome check --write` on `*.{ts,tsx,js,jsx,json,jsonc,css}`).
- **CI:** `.github/workflows/frontend.yml` (typecheck+lint+test+build) + `rust.yml` (cargo check + fmt).

Next: [Frontend →](./frontend.md)
