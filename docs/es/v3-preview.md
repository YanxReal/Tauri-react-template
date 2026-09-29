# Vista previa de Tauri v3 (rama `v3-preview`)

> Estado: **solo vista previa** — nunca se fusiona a `main` hasta que Tauri v3 sea estable.

## Propósito

`v3-preview` es la línea de la Fase A del roadmap: persigue las alphas/betas
de Tauri v3 para que la migración se ejercite **de forma continua** en lugar
de ser un salto de golpe. `main` se queda en Tauri v2 estable — esta rama no
debe romper esa promesa.

## Tauri v3 — hechos actuales (investigado el 2026-09-29)

| Hecho | Valor |
|---|---|
| Último release | `3.0.0-alpha.3` (2026-09-26); alphas ~semanales |
| Gran cambio Linux | **GTK4 + WebKitGTK 6.0** (GTK3 no tiene mantenimiento upstream) |
| Runtimes | runtimes de webview intercambiables: `tauri-runtime-wry` (webview del sistema) o `tauri-runtime-cef` (Chromium) |
| MSRV | 1.95 (esta plantilla está en 1.85) |
| Otros | edition 2024, ACL compacta (overrides implícitos allow/deny), updater moderno (sin `v1Compatible`), hot-reload de recursos en dev, devtools por runtime |

Esta es también la línea donde muere el aviso documentado `glib < 0.20`: v3
sustituye todo el stack GTK-0.18.

## Reglas de la rama

- Sincroniza `main` → `v3-preview` con regularidad (rebasear mantiene el diff pequeño).
- Los gates también quedan verdes aquí: `pnpm typecheck/lint/test/build`, `cargo
  fmt/clippy`, `make check-docs`.
- **Nunca fusiones `v3-preview` → `main`**: cuando v3 sea estable, la migración
  llega a `main` como un único cambio coherente (Fase B del roadmap).

## Pasos de adopción gradual (en orden)

1. **Rebase del CLI vendoreado** a `tauri-cli 3.0.0-alpha.x` (el flujo de la
   skill `tauri-cli-rebase`, re-aplicando la semántica de MOD-1..5; la
   detección de runtime ahora viene del manifest, no de features).
2. **Refactor de runtime crates**: añadir `tauri-runtime-wry`, elegirlo vía
   `tauri::Builder::default().runtime(...)`, mover el código específico de
   runtime (traffic lights, vibrancy) a los extension traits de wry.
3. **MSRV 1.95 + edition 2024** (`rust-toolchain.toml`, `Cargo.toml`).
4. **Rework Linux GTK4** (frameless, banda de resize, `set_linux_theme`,
   guard DMABUF, planes de glass) — verificado en el contenedor + sesiones
   Wayland reales.
5. **Modernización de ACL + updater + devtools**; más tarde el perfil CEF
   opcional (`make init --runtime cef`).
6. Re-verificar la matriz 5-SO en bundles reales.

## Estado actual

A la creación de la rama: idéntica a `main` más este documento — los pasos de
migración arrancan cuando la línea alpha sea lo bastante estable para
compilar todo el repo (todo lo anterior ocurre en commits pequeños con gates
verdes).