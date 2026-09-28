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
| `make dev:ios` | `pnpm tauri ios dev "iPhone 17"` (sim, usa `IOS_DEVICE`) |
| `make dev-ios-physical` | `cargo tauri ios dev "iPhone 17" --host $(IOS_DEV_HOST)` (necesita `make install-tauri-cli`) |
| `make dev-android-emulator` | arranca `$ANDROID_AVD` + `tauri android dev --target $ANDROID_TARGET` |
| `make gen-apple` | `scripts/Xcode/apple-xcode.sh` (xcodegen → `gen/apple`) |
| `make build-linux` | `scripts/build-linux.sh --remote --debug --fetch` en `ubuntu-arm` (`LINUX_REMOTE`/`LINUX_DIR` lo cambian) |
| `make dev-linux` | `scripts/build-linux.sh --remote --dev` (hot reload en la caja) |
| `make linux-logs` / `make linux-stop` | sigue / mata el dev server o la app en remoto |
| `make box-shot` | `scripts/box-shot.sh` (captura VNC de la caja) |
| `make install-tauri-cli` | Compila `src-tauri/vendor/tauri-cli-2.12.0` (2.12.0 stock + 3 retoques: fallback standalone, target `_Apple`) → `~/.cargo/bin/cargo-tauri` |
| `make install-skills` | Instala todas las agent skills del proyecto (macOS/Linux; en Windows corre `scripts\install-skills.cmd`) |
| `make lint` / `make build` | alias |
| `make help` / `make doctor` | lista comandos / revisa toolchain |

Shells por OS: `scripts/build-linux.sh` (+ `build-linux.cmd` en Windows), `scripts/build-windows.sh`, `scripts/Xcode/apple-xcode.sh`.

## Build Linux (`scripts/build-linux.sh`)

Construye los bundles de Linux y puede compilar **y lanzar** la app en una caja Linux por
SSH. Dos backends: `--remote [HOST]` (empuja por SSH y compila allí) y `--native` (compila en
un host Linux). Sin flag de modo: nativo en Linux, remoto si la caja responde — y si la caja
no está accesible el script para con instrucciones en vez de compilar en otro sitio.

| Flag | Efecto |
|------|--------|
| `--remote [HOST]` | rsync → caja SSH (por defecto `$LINUX_BUILD_REMOTE` o `ubuntu-arm`) |
| `--native` | compila en este host (debe ser Linux) |
| `--release` / `--debug` | perfil de compilación (release por defecto; debug es mucho más rápido) |
| `--dev` | `tauri dev` (Vite + app, hot reload) en vez de un bundle; implica `--debug` |
| `--run` | tras compilar, lanza la app en el display indicado |
| `--bundles LIST` | `deb` (por defecto) \| `appimage` \| `rpm` \| `all` |
| `--target ARCH` | `aarch64` \| `x86_64` \| un triple de rust (debe coincidir con la caja) |
| `--display :N` | display X para `--dev`/`--run` (por defecto `:1`) |
| `--fetch` | copia los bundles de vuelta a `./dist-linux` |
| `--sync-only` / `--no-sync` | solo empuja las fuentes / reutiliza lo que ya hay en remoto |
| `--logs` / `--stop` | sigue / mata el dev server o la app en remoto (solo remoto) |

```bash
./scripts/build-linux.sh --remote --dev                  # compila + lanza en la caja
./scripts/build-linux.sh --remote --debug --run          # build rápido y lanza
./scripts/build-linux.sh --remote --release --bundles all --fetch
./scripts/build-linux.sh                                 # auto: remoto, o nativo en Linux
./scripts/build-linux.sh --native                        # fuerza un build local en Linux
```

**Plataformas:** el build de Linux siempre ocurre en la caja Ubuntu-arm-docker por SSH —
macOS y Windows no pueden correr `webkit2gtk` + los bundlers de Linux en local. En
**macOS** ejecuta el `.sh` directo; en **Windows** corre `scripts\build-linux.cmd`
(localiza Git Bash; necesita cliente OpenSSH, rsync opcional). El flag `--native`
solo funciona en un host Linux y aborta en el resto.

El backend remoto usa `pnpm tauri` (la CLI fijada en `devDependencies`, así que no hay paso
`cargo install tauri-cli`) y espera que la caja tenga Rust, Node 24 y las cabeceras de
desarrollo de WebKitGTK/GTK. Cubre todo el ciclo por SSH: build (release o debug), `--dev`,
`--run`, `--logs` y `--stop`. El sync usa `rsync` si ambos extremos lo tienen y cae a `tar`
si no.

Como la caja mantiene `node_modules` y `target/` en disco, los rebuilds son incrementales
(segundos) y `--dev` da Vite + hot reload; se descartó un backend de contenedor por build
porque nunca podría ejecutar la app para probarla.

## La caja Linux

La caja actual es **[Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker)** (repo aparte): escritorio Ubuntu 26.04 + GNOME 50 (Wayland) en Docker para arm64, con noVNC, VNC nativo, SSH y toolchain Tauri v2 lista. Ahí es donde se compila y se mira la app ahora.

| | |
|---|---|
| Repo | [YanxReal/Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker) (`make install`) |
| noVNC / VNC / SSH | `http://localhost:6080/vnc.html` · `localhost:5902` · `ssh ubuntu-arm` (alias en `~/.ssh/config`, usuario `admin`, clave) |
| Ruta del proyecto | `/workspace/Tauri-react-template` (bind `./workspace`) |
| Lanzar apps GUI | wrapper `dev <cmd>` (inyecta `WAYLAND_DISPLAY` + bus de sesión) |

Apúntala con el script de este repo (sync + build). Ojo: `--run`/`--dev` asumen un `DISPLAY` X11, así que en esta caja Wayland lanza vía `dev`:

```bash
./scripts/build-linux.sh --remote ubuntu-arm --debug
# luego en la caja (sin GPU — render por software):
WEBKIT_DISABLE_COMPOSITING_MODE=1 LIBGL_ALWAYS_SOFTWARE=1 dev ./src-tauri/target/debug/tauri-react-template
```

Los defaults ya son `ubuntu-arm` + `/workspace/Tauri-react-template` (T mayúscula:
el checkout del repo; el binario sigue en minúsculas `tauri-react-template`), así
que `make build-linux` / `make dev-linux` no necesitan env. Cambia con
`LINUX_BUILD_REMOTE=<host>` / `LINUX_BUILD_DIR=<dir>` si hace falta.
La caja puede traer un pnpm más nuevo que el fijado `pnpm@10.34.5` — sin problema:
cada install corre con `--frozen-lockfile`, así el lockfile sigue mandando.

### Caja retirada del repo (`docker/linux-gnome` + `scripts/linux-box.sh`)

Eliminada: la caja X11/Xvfb `ubuntu-vnc` vivía en este repo pero se borró en
favor de Ubuntu-arm-docker (rebuilds más rápidos, sesión Wayland real, sin
imagen que mantener aquí). Si aún ves `ubuntu-vnc` en un viejo `~/.ssh/config`,
borra esos dos bloques `Host` — el único alias en uso es `ubuntu-arm`.

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
