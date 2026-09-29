# Scripts y tooling

> **Audiencia:** todos — qué correr y cuándo.

## Scripts raíz

`package.json:11`:

| Comando | Ejecuta |
|---------|---------|
| `pnpm dev` | `turbo dev` (web, TUI) |
| `pnpm build` | `turbo build` |
| `pnpm lint` | `biome check .` |
| `pnpm lint:fix` | `biome check --write .` |
| `pnpm format` / `pnpm format:check` | igual que lint (Biome también formatea) |
| `pnpm typecheck` | `turbo typecheck` |
| `pnpm test` | `turbo test` (vitest) |
| `pnpm tauri` | `tauri` (passthrough CLI) |
| `pnpm tauri:dev` / `pnpm tauri:build` | `tauri dev` / `tauri build` |

`Makefile`:

| Target | Efecto |
|--------|--------|
| `make dev` | `tauri dev` (desktop), respeta `APPLE_SIGNING_IDENTITY` |
| `make dev:web` | `pnpm --filter web dev` |
| `make dev:ios` | `pnpm tauri ios dev "iPhone 18 Pro"` (sim, usa `IOS_DEVICE`) |
| `make dev-ios-physical` | `cargo tauri ios dev "iPhone 18 Pro" --host $(IOS_DEV_HOST)` (necesita `make install-tauri-cli`) |
| `make dev-android-emulator` | arranca `$ANDROID_AVD` + `tauri android dev --target $ANDROID_TARGET` |
| `make gen-apple` | `scripts/Xcode/apple-xcode.sh` — regen `gen/apple` (init del CLI vendoreado, branding-aware) |
| `make gen-android` | `scripts/Android/android-autogen.sh` — regen `gen/android` (init del CLI vendoreado, branding-aware, Linux/Win/macOS) |
| `make build-linux` | **skill linux-build**: sync (rsync, sin `.git`) + build debug rápido + run + verificación `assistant` en `ubuntu-arm` (`LINUX_REMOTE`/`LINUX_DIR` lo cambian) |
| `make linux-release` | ídem, bundle release (deb) + fetch a `./dist-linux` (`LINUX_BUNDLES` cambia la lista) |
| `make build-windows` | `scripts/build-windows.sh --debug` (cargo-xwin; `WINDOWS_BUNDLES`/`WINDOWS_EXTRA` lo cambian) |
| `make dev-linux` | skill linux-build `--remote --dev` (hot reload en la caja) |
| `make linux-logs` / `make linux-stop` | sigue / mata el dev server o la app en remoto |
| `make install-tauri-cli` | Compila `src-tauri/vendor/tauri-cli-2.12.0` (2.12.0 stock + 3 retoques: fallback standalone, target `_Apple`) → `~/.cargo/bin/cargo-tauri` |
| `make install-skills` | Instala todas las agent skills del proyecto (macOS/Linux; en Windows corre `scripts\install-skills.cmd`) |
| `make rebrand` | Propaga la identidad de `branding.json` (nombre, versión, identifier, iconos) a todos los consumidores de escritorio; avisa de regenerar `gen/` para iOS/Android |
| `make lint` / `make build` | alias |
| `make help` / `make doctor` | lista comandos / revisa toolchain |

Shells por OS: **Linux → la skill `linux-build`** (`.claude/skills/linux-build/scripts/linux-build.sh`, solo SSH, ver abajo), `scripts/build-windows.sh`, `scripts/Xcode/apple-xcode.sh`, `scripts/Android/android-autogen.sh`.

## Build Linux (skill `linux-build`)

El build de Linux ocurre **solo por SSH**, en la caja Ubuntu-arm-docker (Docker en
macOS/Windows; Linux no es nativo allí, así que `webkit2gtk` + los bundlers de Linux no
pueden correr en local). El flujo viaja como una **skill de agente** (`.claude/skills/linux-build/`),
que sustituye al viejo `scripts/build-linux.sh` del repo — se instala en todos lados con `make
install-skills`. La skill nunca clona el repo en la caja ni gestiona el contenedor:
sincroniza las fuentes por SSH con `rsync` (**sin `.git`** — la caja es un target de build,
no un repo), mientras `node_modules/` y `target/` quedan cacheados en la caja, así los
rebuilds son incrementales (segundos).

| Flag | Efecto |
|------|--------|
| `--remote [HOST]` | caja SSH (por defecto `$LINUX_BUILD_REMOTE` o `ubuntu-arm`) |
| `--release` / `--debug` | release (por defecto, con bundle) o debug rápido (debug = `--no-bundle` salvo que des `--bundles`) |
| `--dev` | `tauri dev` (Vite + app, hot reload) en vez de un bundle; implica `--debug` |
| `--run` | tras compilar, lanza la app en la sesión GUI de la caja (vía su wrapper `dev` de sesión; los runs debug auto-arrancan Vite — el binario debug carga `devUrl :1420`) |
| `--verify` | tras `--run`: `assistant windows` + `assistant shot` + `assistant ocr` en la caja, y trae el PNG a `./dist-linux/linux-verify.png` |
| `--bundles LIST` | `deb` (por defecto) \| `appimage` \| `rpm` \| `all` |
| `--target ARCH` | `aarch64` \| `x86_64` \| un triple de rust (debe coincidir con la caja) |
| `--fetch` | copia los bundles de vuelta a `./dist-linux` |
| `--sync-only` / `--no-sync` | solo empuja las fuentes / reutiliza lo que ya hay en remoto |
| `--logs` / `--stop` | sigue / mata el dev server o la app en remoto |

```bash
make build-linux                      # sync + build debug rápido + run + verify
make linux-release                    # bundle release .deb + fetch
make linux-release LINUX_BUNDLES=appimage
make dev-linux                        # hot reload en la caja
make linux-logs / make linux-stop     # sigue / mata la app o el dev server remoto
```

El script usa `pnpm tauri` (la CLI fijada en `devDependencies` — no hay paso `cargo install
tauri-cli`) y espera que la caja tenga Rust, Node 24 y las cabeceras de desarrollo de
WebKitGTK/GTK. El sync usa `rsync` si ambos extremos lo tienen y cae a `tar` si no.

## La caja Linux

La caja actual es **[Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker)** (repo aparte): Ubuntu 26.04 + **Cinnamon 6.4 en X11** (Xvfb `:1`) en Docker para arm64, con noVNC, VNC nativo (multi-cliente `x11vnc`), SSH y toolchain Tauri v2 lista. Ahí es donde se compila y se mira la app ahora.

| | |
|---|---|
| Repo | [YanxReal/Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker) (`make install`) |
| noVNC / VNC / SSH | `http://localhost:6080/vnc.html` · `localhost:5902` · `ssh ubuntu-arm` (alias en `~/.ssh/config`, usuario `admin`, clave) |
| Ruta del proyecto | `/workspace/Tauri-react-template` (bind `./workspace`) |
| Lanzar apps GUI | wrapper `dev <cmd>` (inyecta `DISPLAY=:1` + `XAUTHORITY` + `DBUS_SESSION_BUS_ADDRESS`) |
| Control para IA | CLI `assistant` — `shot`/`region` (captura X11 real), `ocr`, `click`/`type`/`key` (input `xdotool` real), `windows`/`winmove`, `record`, `wd` (GTK aislado) |

`make build-linux` cubre todo el ciclo: sync + build debug rápido + lanzamiento en la sesión
GUI + verificación `assistant` (lista de ventanas, captura, OCR). Más fondo: la skill
`linux-build` (`SKILL.md` + `references/box.md`).

Los defaults ya son `ubuntu-arm` + `/workspace/Tauri-react-template` (el checkout
del repo; el nombre del binario sigue el `[package] name` de `src-tauri/Cargo.toml`),
así que los targets make no necesitan env. Cambia con `LINUX_REMOTE=<host>` /
`LINUX_BUILD_DIR=<dir>` si hace falta. La caja puede traer un pnpm más nuevo que el
fijado `pnpm@10.34.5` — sin problema: cada install corre con `--frozen-lockfile`,
así el lockfile sigue mandando.

### Caja retirada del repo (`docker/linux-gnome` + `scripts/linux-box.sh`)

Eliminada: la caja X11/Xvfb `ubuntu-vnc` vivía en este repo pero se borró en
favor de Ubuntu-arm-docker (rebuilds más rápidos, sesión X11 real con captura e
input reales para la IA vía `assistant`, sin imagen que mantener aquí). Si aún
ves `ubuntu-vnc` en un viejo `~/.ssh/config`, borra esos dos bloques `Host` — el
único alias en uso es `ubuntu-arm`.

## Cross-compile Windows (`cargo-xwin`)

`scripts/build-windows.sh [--bundles nsis] [args de tauri build]` construye el bundle Windows x64 desde macOS **o** Linux — resuelve el toolchain LLVM/lld de la plataforma y el Rust gestionado por rustup, y luego llama a `pnpm tauri build --target x86_64-pc-windows-msvc --runner cargo-xwin --bundles nsis`.

Setup una sola vez: `brew install llvm lld makensis` en macOS o `sudo apt install llvm lld nsis` en Linux (`makensis`/`nsis` solo hace falta para el bundle NSIS), `cargo install cargo-xwin --locked` y `rustup target add x86_64-pc-windows-msvc`. Salidas: `src-tauri/target/x86_64-pc-windows-msvc/release/tauri-react-template.exe` (app) y `.../bundle/nsis/tauri-react-template_0.1.0_x64-setup.exe` (instalador; ~200 MB porque `webviewInstallMode: offlineInstaller` embebe WebView2).

Notas: el bundler MSI/WiX solo corre en un host Windows (`--bundles nsis` es el default en macOS/Linux); firmar el instalador también requiere Windows salvo que definas `bundle > windows > signCommand`. `cargo xwin check --target x86_64-pc-windows-msvc` es la vía rápida para type-checkear el código Windows.

## Helper Xcode

`scripts/Xcode/apple-xcode.sh` (ver `scripts/README.es.md:46` — sección Xcode unificado):

- Resuelve el sentinel `DEVELOPMENT_TEAM` → ID real (env `DEVELOPMENT_TEAM` > `scripts/.team-id` > omitido).
- Corre `xcodegen` → `src-tauri/gen/apple`.
- Con `--build` también compila iOS sim + macOS host.

Ver `docs/es/mobile.md` para configs y el parche `cargo-mobile2` de Xcode 26.

## Lint y format (Biome)

`biome.json:1`:

- `formatter: indentStyle space, indentWidth 2, lineWidth 80, lineEnding lf`
- `linter.rules: preset recommended` + `noUnusedVariables:warn`, `noExplicitAny:warn`, `useImportType:error`
- `javascript.formatter: quoteStyle double, semicolons asNeeded, trailingCommas es5`
- `overrides`: desactiva linter/formatter dentro de `src-tauri/**` y `packages/ui/src/components/**` + `apps/web/src/components/*.tsx`

```bash
pnpm lint
pnpm lint:fix
pnpm format:check
biome check --write .   # directo
```

## Git hooks

`package.json:23` `prepare: husky`:

- `.husky/pre-commit` → `lint-staged`
- `lint-staged:25` — `*.{ts,tsx,js,jsx,json,jsonc,css}` → `biome check --write --no-errors-on-unmatched`

## CI (eliminado)

Sin workflows de CI — solo consumían recursos de GitHub. Los mismos gates corren en local (ver [Testing](./testing.md)); Husky + lint-staged vigilan cada commit.

## Pines Node / pnpm

- `.nvmrc` + `.node-version` — Node 24
- `.npmrc` — ajustes pnpm
- `pnpm-lock.yaml` frozen al instalar (`--frozen-lockfile`)

Siguiente: [Solución de problemas →](./troubleshooting.md)
