# Testing

> **Audiencia:** todos — primero checks automatizados, luego la matriz manual por SO. Nada sale sin ambas.

## Unitarios (Vitest)

```bash
pnpm --filter web test          # una pasada
pnpm --filter web test:watch    # modo watch
pnpm test                       # turbo (todos los workspaces)
```

- Config en `vite.config.ts` (`jsdom`, `setupFiles`); coverage a `coverage/**`.
- `App.test.tsx` renderiza dentro de `AppProviders` (mismo stack Theme → Vibrancy → GlassCards que el arranque del webview — renderizar `App` a pelo lanza excepción).
- `native-chrome.test.ts` cubre `resizeEdgeAt` (qué borde corresponde a cada posición). Función pura, corre en cualquier SO.

## Tests Rust

```bash
cargo test --manifest-path src-tauri/Cargo.toml
```

Un CI semanal programado (`.github/workflows/ci.yml`, lunes 18:00 UTC + dispatch manual) corre los gates JS+Rust vía `make ci-frontend`/`make ci-rust` en ubuntu-latest (solo targets desktop; móvil y bundles nativos quedan fuera del CI). Córrelos también tú — en este host Y en la caja Linux (`make build-linux` — la skill `linux-build` sincroniza, compila y verifica con el env de rustup de la caja). La lógica Linux-only se mantiene testeable como funciones puras: `ResizeEdge::from_str` (`lib.rs`) parsea los 8 nombres de borde GDK sin llamadas GTK, así corre en todas partes; el cuerpo `cfg(linux)` que lo mapea a `gtk::gdk::WindowEdge` solo compila en la caja.

## Gates estáticos (todos, en orden)

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
cargo test --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
```

No hay CI — pásalos tú antes de cada push. Un gate en rojo bloquea el PR — sin excepciones. (Los cuerpos `cfg(linux)` solo compilan en la caja Linux: repite `cargo check`/`cargo test` por SSH allí cuando toques Rust.)

## Matriz manual (por bundle real)

La automatización no ve píxeles. Tras los gates, verifica en un **bundle real por SO** (`pnpm tauri:build`, `make build-linux` / `make linux-release` — Linux vía la skill `linux-build` —, `scripts/build-windows.sh`):

| Check | macOS | Windows | Linux |
|---|---|---|---|
| Arranca, sin errores | ✓ | ✓ | ✓ |
| Arrastre por la banda del header | ✓ | ✓ | ✓ |
| Resize de bordes/esquinas | ✓ (+ traffic lights en vivo) | ✓ | ✓ (borde de 6px de la app) |
| Caption buttons (min/max/cerrar) | traffic lights | ✓ + hover Snap | ✓ |
| Scroll 0↔max, sin jank | ✓ | ✓ (barra overlay) | ✓ |
| Sin zoom (doble-tap, Ctrl+rueda, pinch) | ✓ | ✓ | ✓ |
| El toggle de tema sigue en todo | ✓ | ✓ | ✓ (sin marco nativo que seguir) |

Testea siempre también el perfil **release**: `prevent-default` (`Flags::debug()`) solo bloquea los defaults del webview ahí.

## Capturas como evidencia

Los barridos de píxeles ganan al ojo para marcos y esquinas (`standard_deviation` por fila: una pantalla congelada da `0` en todas). Herramientas: en la caja Linux (X11, real) usa el flujo de la skill `linux-build` — `assistant shot` (captura), `assistant ocr` (texto), `assistant click/type` (input real) — y `scrot`/`xwd`/`compare` en hardware X11; en Wayland con GPU real usa `gnome-screenshot` donde funcione. Pega números, no adjetivos.

Siguiente: [Solución de problemas →](./troubleshooting.md)
