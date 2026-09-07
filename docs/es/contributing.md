# Contribuir

## Convenciones

- **JS/TS:** Biome es formatter y linter (`biome.json:1`). Sin ESLint/Prettier. Ejecuta `pnpm lint:fix` antes de commit. `husky` + `lint-staged` lo impone.
- **Rust:** `cargo fmt` + `clippy` (`await_holding_lock: deny`). Ejecuta `cargo check --manifest-path src-tauri/Cargo.toml` y `cargo fmt --check`.
- **Commits:** mantenlos enfocados; sin secretos; nunca saltes hooks salvo petición explícita.
- **i18n:** nunca hardcodees strings visibles — usa `t("key")` y mantén `en.json` / `es.json` sincronizados.
- **Estilos:** tokens en `packages/ui/src/styles/globals.css:1`; componentes en `@workspace/ui`.

## Paridad bilingüe de docs (obligatoria)

Este repo tiene **docs espejados**: `docs/en/` ↔ `docs/es/`. Ver [`/AGENTS.md`](../../AGENTS.md:1).

Reglas:

1. Cada cambio visible en docs debe aplicarse en **ambos** idiomas.
2. Mismo árbol: `en/X.md` ↔ `es/X.md` (nombres idénticos).
3. Misma estructura y orden de secciones — traducción, no reescritura.
4. Mantén los cross-links consistentes (`en/` enlaza a pares `en/`, `es/` a pares `es/`).
5. `docs/README.md` y el `README.md` raíz permanecen bilingües.

Las PRs que toquen solo un lado deben rechazarse. El check de paridad en `AGENTS.md` exige actualizar ambos lados.

## Puertas de calidad antes de push

```bash
pnpm typecheck
pnpm lint
pnpm test
pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
```

Para lógica Tauri también testea:

```bash
cargo check --target aarch64-apple-ios --manifest-path src-tauri/Cargo.toml
```

Y verifica manualmente **scroll + click + no-zoom** en un bundle real por OS (`pnpm tauri:build` o `scripts/build-*.sh`) — ver `docs/es/native-feel.md`.

## Añadir una página a docs

1. Crea `docs/en/<page>.md` y `docs/es/<page>.md` juntos.
2. Añade la fila a los índices `docs/en/README.md` y `docs/es/README.md`.
3. Añade la fila de links a `docs/README.md` (ambas columnas).
4. Si el contenido referencia código, incluye punteros `file_path:line_number`.

## Componentes shadcn

```bash
pnpm dlx shadcn@latest add <component> -c apps/web
# cae en packages/ui/src/components
```

No hay divergencia de docs EN/ES aquí — documenta cualquier componente nuevo en ambos árboles.

## Reportar issues

Incluye OS, versiones Node/pnpm/Rust y si el bug reproduce en **navegador** (`pnpm dev`) vs **Tauri** (`pnpm tauri:dev`) vs **móvil**.

Volver a [Índice docs →](./README.md)
