# Arquitectura

> **Audiencia:** nuevos contribuidores — dónde vive cada cosa y cómo se conecta.

```
┌────────────────────────────── Host ──────────────────────────────┐
│  apps/web (React 19 + Vite :1420)                                │
│    │ invoke("greet" | "platform_info" │ "start_window_resize"     │
│    │         │ "window_effects_set")                             │
│    ▼                                                             │
│  src-tauri (Rust: comandos + setup por SO)                       │
│    ├── tauri.conf.json (base) + tauri.{macos,windows,linux}.     │
│    │       conf.json (overlays de ventana por SO)                │
│    ├── capabilities/ (default.json + windows.json)               │
│    └── plantilla Info.plist → macOS + iOS                        │
│                                                                  │
│  packages/ui (shadcn + glass-*) ← importado como @workspace/ui   │
└──────────────────────────────────────────────────────────────────┘
```

## Layout del monorepo

```
.
├── apps/web                 # App Vite React (puerto 1420)
│   ├── index.html           # SEO, OG, theme-color, viewport-fit
│   ├── vite.config.ts       # alias @, host:true, hmr, vitest
│   └── src/
│       ├── App.tsx          # header/main/section/footer + i18n + greet
│       ├── main.tsx         # providers + guards native-feel
│       ├── i18n/            # config.ts + locales/en.json, es.json
│       ├── components/layout/  # header, hero, features, footer, title-bar
│       ├── *-{provider}.tsx # providers theme, vibrancy, glass-cards
│       ├── hooks/ && test/
├── packages/ui              # design system (shadcn)
│   └── src/{components,lib,styles/globals.css}
├── src-tauri/               # Backend Tauri v2 (Rust)
│   ├── Cargo.toml           # window-vibrancy, prevent-default, gtk (linux)
│   ├── build.rs             # tauri_build + actool + env embedding
│   ├── tauri.conf.json      # base (devUrl, frontendDist, windows)
│   ├── tauri.{macos,windows,linux,ios,android}.conf.json
│   ├── capabilities/        # permisos Tauri v2
│   ├── src/{lib.rs,main.rs,platform/}
│   ├── Info.plist           # plantilla (fuente macOS + iOS)
│   └── vendor/              # tauri-cli 2.12.0 + templates (ver MODS.md)
├── scripts/                 # build-*.sh, box-shot.sh, Xcode/
└── biome.json · turbo.json · pnpm-workspace.yaml · Makefile · AGENTS.md
```

## Workspace y build

- `pnpm-workspace.yaml:1` — `packages: ["apps/*", "packages/*"]`.
- `turbo.json:1` — tareas `build`, `lint`, `format`, `typecheck`, `test`, `dev` (`cache:false`, `persistent:true`).
- Alias: `@` → `apps/web/src`, `@workspace/ui/*` → `packages/ui/src/*`.

## Frontera Frontend → Backend

- El frontend llama a Rust vía `invoke` (`App.tsx:35`).
- Comandos registrados en `lib.rs:422`: `greet`, `platform_info`, `start_window_resize`, `window_effects_set`.
- Plugins: `tauri_plugin_opener`, `tauri_plugin_prevent_default` (`Flags::debug()` — ver [Sensación nativa](./native-feel.md)).

## Capas de config (Tauri)

La base `tauri.conf.json:1` tiene `build`, ventanas comunes y bundle. Los overlays por SO se fusionan al compilar — ver tabla en [Backend Tauri](./tauri.md#configuración). Todas las configs desktop mantienen `dragDropEnabled:false` / `zoomHotkeysEnabled:false` sincronizados.

## Entry points

| Plataforma | Entrada |
|---|---|
| Desktop | `main.rs` → `run()` en `lib.rs` |
| macOS (Xcode) | `main.mm` → `start_app()` (FFI, `#[no_mangle]`) |
| Móvil | `#[cfg_attr(mobile, tauri::mobile_entry_point)]` sobre `run()` |

## Quality gates

- **JS/TS:** Biome — 2 espacios, 80 cols, semis `asNeeded`, `useImportType:error`. Sin ESLint/Prettier.
- **Rust:** `cargo fmt` + `clippy` (`await_holding_lock: deny`, `Cargo.toml:76`).
- **Tests:** Vitest + Testing Library — ver [Testing](./testing.md).
- **Git:** Husky + lint-staged (`biome check --write` en ficheros de código).
- **Gates (local, sin CI):** `pnpm typecheck/lint/test/build` + `cargo check/fmt/clippy/test` — ver [Testing](./testing.md).

Siguiente: [Frontend →](./frontend.md)
