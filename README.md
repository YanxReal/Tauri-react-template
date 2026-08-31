# tauri-react-template

Bilingual Tauri v2 + React 19 + Vite 8 + Tailwind v4 starter — ready for your private use.
Plantilla bilingüe Tauri v2 + React 19 + Vite 8 + Tailwind v4 — lista para uso privado.

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
  make dev-ios            # iOS simulator (vía CLI + scheme _iOS)
  make build-ios          # iOS simulator build
  make dev-android-emulator   # APK debug → emulador
  ```

- `make dev` (desktop) no requiere Xcode; basta Rust. `start_app()` + `platform/` en
  `src-tauri/src/` adaptan la entrada por plataforma.

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
