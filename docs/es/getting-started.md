# Primeros pasos

## Requisitos

| Herramienta | Versión | Notas |
|-------------|---------|-------|
| Node.js | `>=24` | Exigido por `package.json:engines` |
| pnpm | `>=10` | `packageManager: pnpm@10.34.5` |
| Rust | `stable 1.85+` | `edition 2021`, ver `rust-toolchain.toml` |
| Xcode | `26+` | Solo para targets iOS/macOS |
| Android SDK/NDK | última | Solo para targets Android |

Instala los targets de Rust una vez:

```bash
rustup show   # instala desde rust-toolchain.toml (targets iOS + Android)
```

## Instalación

```bash
git clone <tu-repo> tauri-react-template
cd tauri-react-template
pnpm install
```

Verifica:

```bash
pnpm typecheck
pnpm lint
pnpm test
pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
```

## Desarrollo

### Solo web (más rápido)

```bash
pnpm dev              # turbo dev → Vite en http://localhost:1420
# o sin la TUI de Turbo (útil cuando tauri dev mata la TUI):
pnpm --filter web dev
make dev:web
```

### Desktop (Tauri)

```bash
pnpm tauri:dev        # Tauri v2 dev (beforeDevCommand = pnpm --filter web dev)
make dev              # alias — también centra la ventana y gestiona la identidad de firma
```

Config `src-tauri/tauri.conf.json:build`:

```json
{
  "beforeDevCommand": "pnpm --filter web dev",
  "devUrl": "http://localhost:1420",
  "beforeBuildCommand": "pnpm build",
  "frontendDist": "../apps/web/dist"
}
```

¿Por qué `pnpm --filter web dev` y no `turbo dev`? Turbo activa su TUI (`?1000h` mouse mode). Cuando `tauri dev` lo mata con `SIGTERM` la terminal queda en ese modo y escribe `35;22;36M`. Vite directo evita eso — ver `docs/es/native-feel.md` y `src-tauri/src/lib.rs:330`.

### Variables de entorno

Las vars públicas se incrustan en compilación por `src-tauri/build.rs` (`EMBED_KEYS`):

- `VITE_API_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`

Provéelas vía:

- `src-tauri/.env` (gitignored, se lee en build), o
- Env del proceso (`cargo:rerun-if-env-changed`).

En **release**, `SUPABASE_URL` debe ser `https://` y host `*.supabase.co` o el build hace panic (ver `build.rs:135`).

## Build

```bash
pnpm build            # turbo build → apps/web/dist
pnpm tauri:build      # bundle Tauri (todos los targets en bundle.targets)
cargo check --manifest-path src-tauri/Cargo.toml
```

Shells por OS disponibles:

```bash
./scripts/build-linux.sh
./scripts/build-windows.sh
```

`scripts/build-windows.sh` cross-compila el bundle Windows x64 desde macOS/Linux con `cargo-xwin` (instalador NSIS; MSI/WiX necesita un host Windows). Setup una sola vez: `brew install llvm lld makensis`, `cargo install cargo-xwin --locked`, `rustup target add x86_64-pc-windows-msvc` — detalle completo en `docs/es/scripts.md`.

## Referencia de scripts (root)

| Comando | Efecto |
|---------|--------|
| `pnpm dev` | `turbo dev` (web) |
| `pnpm build` | `turbo build` |
| `pnpm lint` / `pnpm lint:fix` | `biome check` / `biome check --write` |
| `pnpm format` / `pnpm format:check` | `biome check --write` / `biome check` |
| `pnpm typecheck` | `turbo typecheck` |
| `pnpm test` | `turbo test` (vitest) |
| `pnpm tauri:dev` / `pnpm tauri:build` | `tauri dev` / `tauri build` |
| `make dev` / `make dev:ios` / `make dev-ios-physical` | Desktop / iOS sim / iOS device |
| `make install-tauri-cli` | Compila el `cargo-tauri` vendoreado con el parche de Xcode 26 |

## IDE

VS Code es el editor recomendado — ver `.vscode/settings.json:1` y `.vscode/extensions.json`:

- `tauri-vscode`, `rust-analyzer`, `biome`, `tailwindcss`
- `editor.formatOnSave` + `source.fixAll.biome` + `source.organizeImports.biome`

## Repo privado

```bash
gh repo create tauri-react-template --private --source=. --push
# o
git remote add origin git@github.com:TU_USUARIO/tauri-react-template.git
git push -u origin master
```

Siguiente: [Arquitectura →](./architecture.md)
