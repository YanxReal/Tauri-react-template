# Primeros pasos

> **Audiencia:** del primer clon a la primera app corriendo. Tiempo: ~10 min (más los builds de Rust).

## Requisitos

| Herramienta | Versión | Instalación | Necesaria para |
|---|---|---|---|
| **Node.js** | ≥ 24 | `nvm use` | todo |
| **pnpm** | ≥ 10 | `corepack enable && corepack prepare pnpm@latest --activate` | todo |
| **Rust** | estable 1.85+ | `rustup` (o `rust` de Homebrew) | builds desktop / móvil |
| **targets rustup** | iOS + Android | `rustup show` (lee `rust-toolchain.toml`) | solo móvil |
| **Xcode** | 26+ | App Store | iOS / macOS |
| **xcodegen** | latest | `brew install xcodegen` | regen de Xcode |
| **Android SDK** | cmdline-tools + emulator + imagen arm64 | Android Studio | solo Android |
| **Docker** | Desktop 4.x | — | solo caja Linux |
| **cargo-tauri 2.12.0** | vendoreado + retoques | `make install-tauri-cli` | flujos iOS |

`package.json:engines` fija Node + pnpm.

## Matriz de compilación por SO

Qué targets de escritorio/móvil puede producir **cada SO de desarrollo**. Tauri compila
el backend contra el webview y los bundlers nativos del host, así que los límites los
marca el SO, no el template:

| Compilas en → produces | macOS | Windows | Linux | **iOS** | **Android** |
|---|---|---|---|---|---|
| **macOS** (Apple Silicon) | ✅ nativo | ⚠️ cross (`cargo-xwin`) | ❌ necesita caja Linux | ✅ **único lugar donde es posible** (Xcode) | ✅ |
| **Windows** | ❌ | ✅ nativo | ❌ | ❌ **imposible** (sin Xcode) | ✅ |
| **Linux** | ❌ | ⚠️ cross (`cargo-xwin`) | ✅ nativo | ❌ **imposible** (sin Xcode) | ✅ |

Reglas clave (fuente: [`Requisitos de Tauri`](https://v2.tauri.app/start/prerequisites/)):

- **iOS requiere Xcode → solo un host macOS puede compilarlo.** "El desarrollo de iOS
  requiere Xcode y solo está disponible en macOS." Windows y Linux no pueden producir
  un build de iOS.
- **macOS desktop → solo en macOS** (AppKit + Xcode no existen en otros SO).
- **Linux desktop → solo en Linux** (necesita `webkit2gtk`; los bundlers deb/rpm/AppImage
  solo corren en Linux). Este es el único target que un desarrollador en macOS no puede
  compilar en local → va a la caja Linux (`scripts/build-linux.sh --remote ubuntu-arm`).
- **Android → compilable en los tres SO** (Android Studio/SDK/NDK/JDK existen en
  macOS, Windows y Linux).
- **Windows desktop → nativo en Windows; cross-compile desde macOS/Linux vía
  `cargo-xwin`** (`scripts/build-windows.sh`). El firmado del instalador y el MSI siguen
  necesitando un host Windows.

## Instalación

```bash
git clone <tu-repo> Tauri-react-template
cd Tauri-react-template
pnpm install
# Done en ~1m · 581 paquetes · hook `husky` de prepare
```

Verifica la instalación (todo en verde antes de seguir):

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
```

## Desarrollo

### Solo web (lo más rápido)

```bash
pnpm dev:web
# Vite en http://localhost:1420, HMR en :1421 (sin TUI de Turbo)
```

`pnpm dev` (= `turbo dev`) también vale pero activa el modo ratón de la TUI
(`?1000h`) — `tauri dev` lo mata con `SIGTERM` y deja la terminal garbled
(`35;22;36M`). `tauri.conf.json:build` ya usa la forma directa:

```json
{
  "beforeDevCommand": "pnpm --filter web dev",
  "devUrl": "http://localhost:1420",
  "beforeBuildCommand": "pnpm build",
  "frontendDist": "../apps/web/dist"
}
```

### Desktop (Tauri)

```bash
make dev          # tauri dev + centrado de ventana + signing identity
# o: pnpm tauri:dev
```

### Móvil y caja Linux

Simulador / dispositivo iOS, emulador Android y la caja Linux por SSH tienen
flujo propio — ver [Móvil](./mobile.md) y [Scripts](./scripts.md):

```bash
make dev:ios                # simulador iPhone
make dev-android-emulator   # arranca AVD + android dev
# Caja Linux (repo aparte):
#   cd ../Ubuntu-arm-docker && make install   # escritorio Ubuntu 26.04 + GNOME 50
#   ssh ubuntu-arm                             # admin, clave
```

### Variables de entorno

Las vars públicas se incrustan al compilar vía `src-tauri/build.rs`
(`EMBED_KEYS`): `VITE_API_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`. Ponlas en `src-tauri/.env`
(gitignored) o como env del proceso. En **release**, `SUPABASE_URL` debe ser
`https://*.supabase.co` o el build hace panic (`build.rs:135`).

## Build

```bash
pnpm build            # turbo build → apps/web/dist
pnpm tauri:build      # bundle Tauri (todos los targets de bundle.targets)
```

Shells por SO: `./scripts/build-linux.sh` (bundles + opcional `--run` en la
caja Linux) y `./scripts/build-windows.sh` (cross-compile `cargo-xwin`, NSIS;
MSI/WiX necesita host Windows). Detalle: [Scripts](./scripts.md).

## IDE

VS Code + `tauri-vscode` + `rust-analyzer` + `biome` + `tailwindcss`
(ver `.vscode/extensions.json`). Settings recomendados (`formatOnSave` +
`source.fixAll.biome`) en `.vscode/settings.json`.

## Publicar a un repo remoto

```bash
gh repo create Tauri-react-template --public --source=. --push
# o (público, o créalo privado en GitHub primero y usa SSH):
git remote add origin git@github.com:TU_USUARIO/Tauri-react-template.git
git push -u origin master
```

Siguiente: [Arquitectura →](./architecture.md)
