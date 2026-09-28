# tauri-react-template

**Starter multi-plataforma Tauri v2 + React 19** — un solo código, ventanas nativas en macOS, Windows, Linux, iOS y Android, con docs bilingües (EN/ES) y contrato para agentes.

[![Tauri 2](https://img.shields.io/badge/tauri-2-FFC131?logo=tauri&logoColor=white)](https://tauri.app)
[![React 19](https://img.shields.io/badge/react-19-61DAFB?logo=react&logoColor=white)](https://react.dev)
[![Node 24](https://img.shields.io/badge/node-%3E%3D24-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![pnpm 10](https://img.shields.io/badge/pnpm-%3E%3D10-F69220?logo=pnpm&logoColor=white)](https://pnpm.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> 🌐 **Idioma:** **Español** | [English](README.md)

[Resumen](#-resumen) • [Características](#-características) • [Requisitos](#-requisitos) • [Inicio rápido](#-inicio-rápido) • [Modelo de ventana](#-modelo-de-ventana) • [Configuración](#-configuración) • [Targets Make](#-targets-make) • [Verificación](#-verificación) • [Seguridad](#-seguridad) • [Solución de problemas](#-solución-de-problemas) • [Roadmap](#-roadmap) • [Documentación](#-documentación) • [Docs](docs/es/README.md)

---

## Tabla de contenidos

1. [Resumen](#-resumen)
2. [Características](#-características)
3. [Requisitos](#-requisitos)
4. [Inicio rápido](#-inicio-rápido)
5. [Estructura del proyecto](#-estructura-del-proyecto)
6. [Modelo de ventana](#-modelo-de-ventana)
7. [Configuración](#-configuración)
8. [Targets Make](#-targets-make)
9. [Flujo de desarrollo](#-flujo-de-desarrollo)
10. [Verificación](#-verificación)
11. [Datos y persistencia](#-datos-y-persistencia)
12. [Seguridad](#-seguridad)
13. [Solución de problemas](#-solución-de-problemas)
14. [Roadmap](#-roadmap)
15. [Documentación](#-documentación)
16. [Contribuir](#-contribuir)
17. [Licencia](#-licencia)
18. [Agradecimientos](#-agradecimientos)
19. [Enlaces](#-enlaces)

---

## 🔭 Resumen

Plantilla privada para publicar una **app desktop + móvil con sensación nativa** desde un solo código React. Cada ventana se dibuja por SO (traffic lights Overlay en macOS, frameless + Snap Layouts en Windows, frameless en Linux, target Xcode unificado iOS/macOS, emulador Android), con la matriz completa cubierta por docs, checks y scripts.

| | |
|---|---|
| 🖥️ **Cinco targets** | macOS, Windows, Linux, iOS, Android desde un solo código |
| 📐 **Chrome nativo** | Titlebar de 44px dibujada por la app en Win/Linux, lights Overlay en macOS |
| 🌐 **Bilingüe** | UI (i18next EN/ES) + `docs/en` + `docs/es` espejados + regla de paridad |
| 🤖 **Lista para agentes** | Contrato `AGENTS.md`: invariantes, checklist de paridad, gates de verificación |
| 🧰 **Con herramientas** | Dev con Make, caja Linux por SSH, script de regen de Xcode, CI en 3 SO |

---

## ✨ Características

- **React 19.2 + Vite 8.2 + TypeScript 5.9 (estricto)**, Tailwind v4.3, Biome 2.5, Vitest 4 + Testing Library, monorepo Turborepo 2.10 (`apps/*`, `packages/*`).
- **Design system** (`packages/ui`): 45 componentes shadcn + liquid-glass einui (`glass-*`), tokens OKLCH, Inter Variable.
- **i18n**: `i18next` + detector de navegador + caché `localStorage`, `en.json`/`es.json`, el toggle del header sincroniza `document.documentElement.lang`.
- **Semántica HTML5**: landmarks, skip link, nav etiquetada — con tests (`App.test.tsx`).
- **Backend Tauri v2**: comandos `greet` / `platform_info` / `start_window_resize` / `window_effects_set`, `plugin-opener`, `prevent-default` (`Flags::debug()`).
- **Efecto cristal**: toggle de translucidez nativa (vibrancy en macOS, Mica en Windows), independiente de las glass cards; forzado a OFF en Linux.
- **Target Xcode unificado iOS + macOS** (`tauri-react-template_Apple`): configs debug / hotreload / release, auto-inyección de `DEVELOPMENT_TEAM`, CLI 2.12.0 vendoreada + retoques documentados (`MODS.md`).

---

## 📦 Requisitos

| Dependencia | Versión | Instalación | Requerida |
|---|---|---|---|
| **Node.js** | ≥ 24 | `nvm use` / nodejs.org | ✅ |
| **pnpm** | ≥ 10 | `corepack enable && corepack prepare pnpm@latest --activate` | ✅ |
| **Rust** | estable 1.85+ | `rustup` (o `rust` de Homebrew) | ✅ |
| **targets rustup** | triples iOS/Android | `rustup show` (`rust-toolchain.toml`) | ◻️ solo móvil |
| **Xcode** | 26+ | App Store | ◻️ builds iOS/macOS |
| **xcodegen** | latest | `brew install xcodegen` | ◻️ regen de Xcode |
| **Android SDK** | cmdline-tools + emulator + imagen arm64 | Android Studio | ◻️ solo Android |
| **cargo-xwin + LLVM** | latest | `cargo install cargo-xwin --locked`, `brew install llvm lld` | ◻️ cross-compile Windows |
| **Docker** | Desktop 4.x | — | ◻️ solo caja Linux |
| **cargo-tauri 2.12.0** | vendoreado + retoques | `make install-tauri-cli` | ◻️ flujos iOS |

> Nota solo-Windows: el bundler MSI/WiX y la firma del instalador necesitan un host Windows; desde macOS/Linux usa `--bundles nsis`.

---

## 🚀 Inicio rápido

```bash
# 0. Toolchain
node --version   # v24.x
pnpm --version   # 10.x
rustc --version  # 1.85+

# 1. Clonar + instalar
git clone https://github.com/YanxReal/tauri-react-template.git
cd tauri-react-template
pnpm install
# Done en ~1m (581 paquetes) + hook `husky` de prepare

# 2. Solo web (Vite :1420 + HMR :1421)
pnpm dev:web     # o: pnpm --filter web dev

# 3. App desktop (necesita Rust)
make dev          # o: pnpm tauri:dev

# 4. Checks (todos tienen que pasar)
pnpm typecheck && pnpm lint && pnpm test && pnpm build
```

Los flujos iOS / Android / caja Linux están en [Modelo de ventana](#-modelo-de-ventana), [Targets Make](#-targets-make) y [`docs/es/scripts.md`](docs/es/scripts.md).

---

## 📁 Estructura del proyecto

```
.
├── apps/web                 # App Vite React (HTML semántico, i18n)
│   ├── index.html           # meta, OG, theme-color
│   └── src/
│       ├── App.tsx          # header/main/section/footer + i18n
│       ├── i18n/            # en.json / es.json
│       ├── components/layout/{header,hero,features,footer}.tsx
│       └── test/setup.ts
├── packages/ui              # design system (shadcn + glass-*)
│   └── src/{components,lib,styles/globals.css}
├── src-tauri/               # Backend Tauri v2 (Rust)
│   ├── src/lib.rs           # comandos + setup por SO
│   ├── capabilities/        # default.json + windows.json
│   ├── tauri.conf.json      # base (se fusiona con tauri.{os}.conf.json)
│   ├── vendor/              # tauri-cli 2.12.0 + templates (ver MODS.md)
│   └── Info.plist           # plantilla para macOS + iOS
├── scripts/                 # build-linux.sh, box-shot.sh, Xcode/, ...
├── docs/en + docs/es        # docs espejadas (regla de paridad)
├── MODS.md                  # modificaciones del CLI vendoreado (raíz)
├── AGENTS.md                # contrato para agentes
├── biome.json               # formateador + linter (sin ESLint)
└── turbo.json               # pipeline
```

`src-tauri/gen/` es autogen (gitignored) — no lo edites nunca; edita la plantilla.

---

## 🪟 Modelo de ventana

Una única titlebar de 44px dibujada por la app (banda de arrastre + caption buttons) en Win/Linux; chrome nativo en el resto:

| SO | Marco | Esquinas | Resize | Notas |
|---|---|---|---|---|
| **macOS** | `titleBarStyle: Overlay`, `hiddenTitle` | nativas | nativo + fix HuLa de 3 mecanismos para traffic lights | banda de 52px, dots en `17.5/39.5/61.5` |
| **Windows** | frameless + `tauri-plugin-decorum` | `DWMWCP_ROUND` | nativo (`WM_NCHITTEST`) | Snap Layouts al hover de maximizar (620 ms) |
| **Linux** | frameless, opaco | **cuadradas por diseño** | borde de 6px de la app → `begin_resize_drag` | glass OFF (veto WebKitGTK) |
| **iOS** | target unificado `_Apple` | — | — | sim con `cargo tauri`, físico con `--host` |
| **Android** | emulador AVD | — | — | `make dev-android-emulator` |

Detalle: [`docs/es/native-feel.md`](docs/es/native-feel.md) · [`docs/es/mobile.md`](docs/es/mobile.md) · [`docs/es/tauri.md`](docs/es/tauri.md)

---

## ⚙️ Configuración

Todo vive en env / vars de `Makefile` / ficheros estilo `.env` (nada hardcodeado):

| Variable | Default | Descripción |
|---|---|---|
| `DEVELOPMENT_TEAM` / `scripts/.team-id` | — (manual en Xcode) | team de firma iOS, inyectado al regenerar |
| `TAURI_CLI` | `@tauri-apps/cli@2.12.0` | CLI para los flujos `--build` de regen |
| `XCODEGEN` | `xcodegen` | binario generador del proyecto Xcode |
| `IOS_DEVICE` | `iPhone 17` | selector de simulador/dispositivo |
| `IOS_DEV_HOST` | autodetección link-local | host dev para iPhone físico (USB) |
| `ANDROID_AVD` / `ANDROID_TARGET` | `Resizable_Experimental` / `aarch64` | emulador + arquitectura |
| `ANDROID_HOME` | `~/Library/Android/sdk` | ubicación del SDK |
| `LINUX_BUILD_REMOTE` / `LINUX_BUILD_DIR` | `ubuntu-arm` / `/workspace/tauri-react-template` | caja Linux de build por SSH ([Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker)) |
| `APPLE_SIGNING_IDENTITY` / `src-tauri/keys/macos-signing-identity.txt` | — (opcional) | identidad estable de firma macOS |

> Tras editar, los flujos son por target (`make restart`, scripts de regen); en runtime solo se leen claves `localStorage` de tema/i18n.

---

## 🛠️ Targets Make

```bash
make dev                  # tauri dev (desktop)
make dev:web              # pnpm --filter web dev
make dev:ios              # pnpm tauri ios dev "iPhone 17" (simulador)
make dev-ios-physical     # cargo tauri ios dev + --host (iPhone USB)
make dev-android-emulator # arranca AVD + pnpm tauri android dev
make gen-apple            # regenera src-tauri/gen/apple (xcodegen)
make install-tauri-cli    # compila vendor/tauri-cli → ~/.cargo/bin/cargo-tauri
make lint / make build    # alias
```

---

## 🔧 Flujo de desarrollo

```tsx
// i18n — nunca hardcodees strings visibles
const { t, i18n } = useTranslation()
t("hero.title") // EN/ES auto
await i18n.changeLanguage("es")
```

```bash
# shadcn (caen en packages/ui/src/components)
pnpm dlx shadcn@latest add button -c apps/web
```

```tsx
import { Button } from "@workspace/ui/components/button"
```

```bash
# Plugin Tauri: paquete JS + dep Cargo + capability
pnpm --filter web add @tauri-apps/plugin-xxx
# luego: tauri-plugin-xxx = "2" en Cargo.toml + JSON de capabilities
```

---

## ✅ Verificación

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
```

Y testear **scroll + click + no-zoom** en un bundle real por SO (`pnpm tauri:build`, `scripts/build-linux.sh`, `scripts/build-windows.sh`) — matriz completa: [`docs/es/testing.md`](docs/es/testing.md). Los gates corren en local (sin CI) — ver Verificación arriba.

---

## 💾 Datos y persistencia

| Ruta | Tipo | Propósito |
|---|---|---|
| `src-tauri/gen/` | autogen (gitignored) | proyectos Xcode/Android — regenerable, no editar |
| `src-tauri/target/` | build (gitignored) | salida de cargo (incl. `target/tauri-cli/`) |
| `node_modules/`, `dist/` | build (gitignored) | deps + bundles |
| `dist-linux/` | traído (gitignored) | bundles copiados de vuelta desde la caja Linux |
| `scripts/.team-id` | local (gitignored) | Team ID persistente de Apple |
| volúmenes Docker `tauri-*` | volúmenes con nombre | cachés cargo/pnpm de la caja Linux mínima |
| [Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker) | repo aparte | caja Linux actual (Ubuntu 26.04 + GNOME 50, toolchain Tauri) — proyecto en `/workspace/tauri-react-template` |

Los volúmenes de la caja viven en el compose de Ubuntu-arm-docker (`admin-home`, `ssh-host-keys`); este repo no tiene target destroy.

---

## 🔐 Seguridad

> Pensada como **plantilla privada** — los defaults favorecen la velocidad local.

- **CSP**: políticas estrictas `default-src 'self'` en las configs Windows/macOS; base + móvil usan `csp: null` — endurecer antes de cualquier release pública.
- **`prevent-default`**: `Flags::debug()` conserva menú contextual/devtools/reload en **debug** y bloquea todo (Ctrl+P/S, zoom, menú nativo) en **release**. Verifica testear el perfil release.
- **Puertos**: los dev servers escuchan en todas las interfaces (`host: true`, necesario para el reload iOS por LAN) — `1420` (Vite) + `1421` (HMR). No los expongas más allá de tu LAN.
- **Firma**: Team ID e identidad macOS viven en ficheros gitignored, nunca en el repo.
- **Cajas dev**: passwords VNC/SSH por defecto (`dev`/`admin`) son conveniencias locales tras `127.0.0.1` — cámbialos + usa claves SSH para lo que salga de localhost.

---

## 🆘 Solución de problemas

| Síntoma | Arreglo |
|---|---|
| Terminal garbled (`35;22;36M`) | Usa `make dev` (Vite directo, sin TUI de Turbo); `reset` para recuperar |
| Traffic lights saltan en resize | Revisa el trío HuLa (`lib.rs:205/331` + poll 60 fps) + config Overlay |
| Sin caption buttons / Snap Layouts (Win) | Revisa resolve de `platform` + permisos `default.json` + permiso decorum en `windows.json` |
| Glitches amarillos / RAM en Linux | El glass sigue en OFF (veto); mantén `WEBKIT_DISABLE_DMABUF_RENDERER=1` |
| Puerto 1420 ocupado | Mata el Vite suelto antes del scheme `hotreload` |
| Falla `pnpm install` | Node ≥ 24 + pnpm ≥ 10 (`package.json:engines`) |
| iOS `EBADARCH` / mismatch de arch | `make install-tauri-cli` y luego `cargo tauri` (no `pnpm tauri`) |

Tabla completa: [`docs/es/troubleshooting.md`](docs/es/troubleshooting.md)

---

## 🗺️ Roadmap

- [ ] Resize del borde derecho en Wayland: confirmar serial-vs-detección, luego fix + verificar los 8 bordes
- [ ] Verificar frameless Linux en hardware real (sesiones NVIDIA/Wayland + X11)
- [ ] Pipeline de iPhone físico end-to-end (Team ID + iPhone USB)
- [ ] Bundle release Android + ruta de metadatos de tienda
- [ ] Plan A de glass degradado en Linux (especificado en native-feel, no implementado)

---

## 📚 Documentación

Las guías completas están en [`docs/es/`](docs/es/README.md) (espejo: [`docs/en/`](docs/en/README.md)) — mismas páginas, mismo orden, ambos idiomas:

| Doc | Audiencia | Contenido |
|---|---|---|
| [Primeros pasos](docs/es/getting-started.md) | Todos | Requisitos, instalación, primera ejecución, builds |
| [Arquitectura](docs/es/architecture.md) | Nuevos contribuidores | Mapa del monorepo, entry points, capas de config |
| [Frontend](docs/es/frontend.md) | Devs web | App shell, providers, shadcn, convenciones |
| [Backend Tauri](docs/es/tauri.md) | Devs Rust | Comandos, setup por SO, plugins |
| [Estilos](docs/es/styling.md) | Devs web | Tokens, modo oscuro, shell, sistema glass |
| [i18n](docs/es/i18n.md) | Devs web | Locales, toggle, añadir idiomas |
| [Móvil](docs/es/mobile.md) | Devs iOS/Android | Target Xcode, configs, emulador |
| [Sensación nativa](docs/es/native-feel.md) | Trabajo de ventana | Chrome por SO, guards, vibrancy, scrollbars |
| [Scripts](docs/es/scripts.md) | Todos | `package.json`, Makefile, scripts de build, CI |
| [Testing](docs/es/testing.md) | Todos | Unitarios, Rust, matriz manual por SO |
| [Solución de problemas](docs/es/troubleshooting.md) | ¿Atascado? | Tablas síntoma → arreglo |
| [Contribuir](docs/es/contributing.md) | Contribuidores | Convenciones, paridad, gates |
| [Changelog](docs/es/changelog.md) | Curiosos | Evolución completa, commit a commit |

Regla de paridad: cada página `es/` tiene su espejo `en/` idéntico en estructura (`AGENTS.md` §3).

---

## 🤝 Contribuir

```bash
git checkout -b feat/mi-cambio
# código + docs/en + docs/es espejadas (regla de paridad — ver AGENTS.md §3)
pnpm typecheck && pnpm lint && pnpm test && pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
# abre PR con el checklist de paridad
```

Reglas que importan: **paridad bilingüe de docs** (cada cambio `en/` necesita su espejo `es/`), **no editar `src-tauri/gen/`**, **invariantes multiplataforma** (`AGENTS.md` §4.3). Los gates corren en local.

---

## 📄 Licencia

MIT © tauri-react-template — ver [LICENSE](LICENSE). Plantilla privada para uso personal:

```bash
gh repo create tauri-react-template --private --source=. --push
```

---

## 🙏 Agradecimientos

- [Tauri](https://tauri.app/) + [wry](https://github.com/tauri-apps/wry)/[tao](https://github.com/tauri-apps/tao) por el runtime del webview
- [shadcn/ui](https://ui.shadcn.com) + [einui](https://ui.eindev.ir) por el design system
- [decorum](https://github.com/clearlysid/tauri-plugin-decorum) por la titlebar overlay de Windows
- [noVNC](https://github.com/novnc/noVNC) por testear por navegador

---

## 🔗 Enlaces

- **Repo:** https://github.com/YanxReal/tauri-react-template
- **Docs:** [`docs/en/README.md`](docs/en/README.md) · [`docs/es/README.md`](docs/es/README.md) · [router](docs/README.md)
- **Tauri v2:** https://tauri.app · **Vite:** https://vite.dev · **Tailwind:** https://tailwindcss.com · **Biome:** https://biomejs.dev
