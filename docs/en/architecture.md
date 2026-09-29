# Architecture

> **Audience:** new contributors — where everything lives and how it connects.

```
┌────────────────────────────── Host ──────────────────────────────┐
│  apps/web (React 19 + Vite :1420)                                │
│    │ invoke("greet" | "platform_info" │ "start_window_resize"     │
│    │         │ "window_effects_set")                             │
│    ▼                                                             │
│  src-tauri (Rust: lib.rs commands + per-OS setup)                │
│    ├── tauri.conf.json (base) + tauri.{macos,windows,linux}.     │
│    │       conf.json (per-OS window overlays)                    │
│    ├── capabilities/ (default.json + windows.json)               │
│    └── Info.plist template → macOS + iOS                         │
│                                                                  │
│  packages/ui (shadcn + glass-*) ← imported as @workspace/ui      │
└──────────────────────────────────────────────────────────────────┘
```

## Monorepo layout

```
.
├── apps/web                 # Vite React app (port 1420)
│   ├── index.html           # SEO, OG, theme-color, viewport-fit
│   ├── vite.config.ts       # @ alias, host:true, hmr, vitest
│   └── src/
│       ├── App.tsx          # header/main/section/footer + i18n + greet
│       ├── main.tsx         # providers + native-feel guards
│       ├── i18n/            # config.ts + locales/en.json, es.json
│       ├── components/layout/  # header, hero, features, footer, title-bar
│       ├── *-{provider}.tsx # theme, vibrancy, glass-cards providers
│       ├── hooks/ && test/
├── packages/ui              # design system (shadcn)
│   └── src/{components,lib,styles/globals.css}
├── src-tauri/               # Tauri v2 backend (Rust)
│   ├── Cargo.toml           # window-vibrancy, prevent-default, gtk (linux)
│   ├── build.rs             # tauri_build + actool + env embedding
│   ├── tauri.conf.json      # base (devUrl, frontendDist, windows)
│   ├── tauri.{macos,windows,linux,ios,android}.conf.json
│   ├── capabilities/        # Tauri v2 permissions
│   ├── src/{lib.rs,main.rs,platform/}
│   ├── Info.plist           # template (macOS + iOS source of truth)
│   └── vendor/              # tauri-cli 2.12.0 + templates (see .claude/skills/tauri-cli-rebase/references/mods.md)
├── scripts/                 # build-*.sh, Xcode/
└── biome.json · turbo.json · pnpm-workspace.yaml · Makefile · AGENTS.md
```

## Workspace & build

- `pnpm-workspace.yaml:1` — `packages: ["apps/*", "packages/*"]`.
- `turbo.json:1` — tasks `build`, `lint`, `format`, `typecheck`, `test`, `dev` (`cache:false`, `persistent:true`).
- Aliases: `@` → `apps/web/src`, `@workspace/ui/*` → `packages/ui/src/*`.

## Frontend → Backend boundary

- Frontend calls Rust via `invoke` (`App.tsx:37`).
- Commands registered in `lib.rs:635`: `greet`, `platform_info`, `start_window_resize`, `window_effects_set`, `set_status_bar_style`, `set_linux_theme`.
- Plugins: `tauri_plugin_opener`, `tauri_plugin_prevent_default` (`Flags::debug()` — see [Native Feel](./native-feel.md)).

## Config layering (Tauri)

Base `tauri.conf.json:1` holds `build`, common windows, bundle. Per-OS overlays merge at build time — see table in [Tauri Backend](./tauri.md#configuration). All desktop configs keep `dragDropEnabled:false` / `zoomHotkeysEnabled:false` in sync.

## Entry points

| Platform | Entry |
|---|---|
| Desktop | `main.rs` → `run()` in `lib.rs` |
| macOS (Xcode) | `main.mm` → `start_app()` (FFI, `#[no_mangle]`) |
| Mobile | `#[cfg_attr(mobile, tauri::mobile_entry_point)]` on `run()` |

## Quality gates

- **JS/TS:** Biome — 2 spaces, 80 cols, `asNeeded` semis, `useImportType:error`. No ESLint/Prettier.
- **Rust:** `cargo fmt` + `clippy` (`await_holding_lock: deny`, `Cargo.toml:84`).
- **Tests:** Vitest + Testing Library — see [Testing](./testing.md).
- **Git:** Husky + lint-staged (`biome check --write` on code files).
- **Gates (local, no CI):** `pnpm typecheck/lint/test/build` + `cargo check/fmt/clippy/test` — see [Testing](./testing.md).

Next: [Frontend →](./frontend.md)
