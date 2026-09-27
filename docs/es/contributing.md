# Contribuir

> **Audiencia:** contribuidores — convenciones, paridad, gates. Para bugs usa las [plantillas de issue](../../.github/ISSUE_TEMPLATE/bug_report.md).

## Convenciones

- **JS/TS:** Biome formatea + lintea (`biome.json:1`). Sin ESLint/Prettier. Pasa `pnpm lint:fix` antes de commitear; Husky + lint-staged lo exigen.
- **Rust:** `cargo fmt` + `clippy` (`await_holding_lock: deny`).
- **Commits:** enfocados, sin secretos, nunca saltes hooks salvo petición expresa.
- **i18n:** nunca hardcodees strings visibles — `t("key")`, `en.json`/`es.json` sincronizados.
- **Estilos:** tokens en `globals.css:1`; componentes en `@workspace/ui`.

## Paridad bilingüe de docs (obligatoria)

Docs espejadas: `docs/en/` ↔ `docs/es/` (ver [`AGENTS.md`](../../AGENTS.md)):

1. Cada cambio de docs cae en **ambos** idiomas, mismo commit/PR.
2. Mismo árbol (`en/X.md` ↔ `es/X.md`) y mismo orden de secciones — traducción, no reescritura.
3. Mismos punteros `file:line`; cross-links dentro del árbol (`en/`→`en/`, `es/`→`es/`).
4. `README.md` + `README.es.md` raíz con estructura idéntica; `docs/README.md` sigue siendo el router bilingüe.
5. Los PR de un solo lado se rechazan — la paridad es el primer gate de review.

## Quality gates antes de push

Matriz completa: [Testing](./testing.md).

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
```

Más un bundle real por SO (scroll + click + no-zoom) — ver la matriz manual en [Testing](./testing.md).

## Añadir una página a docs

1. Crea `docs/en/<page>.md` + `docs/es/<page>.md` juntas.
2. Fila en los índices `docs/en/README.md` + `docs/es/README.md`.
3. Fila en `docs/README.md` (ambas columnas).
4. Punteros `file_path:line_number` para referencias a código.

## Componentes shadcn

```bash
pnpm dlx shadcn@latest add <component> -c apps/web
# cae en packages/ui/src/components
```

Documenta los componentes nuevos en ambos árboles.

## Reportar issues

Usa las plantillas (`.github/ISSUE_TEMPLATE/`): SO, versiones Node/pnpm/Rust, y si reproduce en **navegador** (`pnpm dev`) vs **Tauri** (`pnpm tauri:dev`) vs **móvil**. Logs completos, no capturas.

Volver al [Índice de docs →](./README.md)
