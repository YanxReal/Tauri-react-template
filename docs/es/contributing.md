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
make check-docs                       # paridad EN/ES + anclas AGENTS/docs
```

`make check-docs` también está en el hook de pre-commit — falla antes del
`git commit` si un espejo se rompe o una ancla `file:line` deriva.

Más un bundle real por SO (scroll + click + no-zoom) — ver la matriz manual en [Testing](./testing.md).

## Política de versiones

La versión del repo vive en `TEMPLATE_VERSION` + el tag `vX.Y.Z` (ambos deben
ir en sincronía). El changelog (EN+ES) registra cada cambio.

- **Suba `TEMPLATE_VERSION` + tag ante cualquier cambio que una app
  downstream deba saber**: ganchos nuevos de Makefile/scripts/skills, firmas
  de comandos cambiadas, cambios de esquema de config, cambios de
  invariantes (AGENTS §4), cambios de iconos/identidad, pines de dependencias
  que alteren comportamiento.
- **Patch (x.y.Z)**: fixes solo de docs, tooling o no de comportamiento —
  sube solo si un downstream lo necesita (también pueden fijarse a un commit).
- **Minor (x.Y.0)**: capacidad nueva que no rompe a los adoptantes.
- **Major (X.0.0)**: cambios que rompen a los adoptantes (renames, targets
  eliminados, layout de ficheros cambiado). Al subir: corre `make rebrand`,
  regenera los árboles móviles `gen/`, gates + `make check-docs`, y vuelve a
  verificar un bundle real por SO.
- Tag con mensaje: `git tag -a vX.Y.Z -m "..."` y sube los tags
  (`git push --tags`).

### Avisos upstream (Dependabot)

Dependabot marca `glib < 0.20` (medium, unsoundness en `glib::VariantStrIter`)
en la rama por defecto. Es **de frontera upstream**: glib llega por todo el
stack GTK 0.18 que `tauri 2.12` arrastra en Linux (`gtk 0.18.2` ←
`tao`/`wry`/`muda`/`webkit2gtk`). Subir glib por su cuenta rompe la alineación
de minors de gtk-rs y el build Linux — NO ejecutes
`cargo update -p glib --precise 0.20`. Se resuelve cuando tauri/tao suban su
stack GTK; re-revisa tras cada subida de tauri
(`cargo tree -i glib --target x86_64-unknown-linux-gnu`).

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

> **Nota de dependencia a largo plazo:** `packages/ui/components.json`
> referencia el registro externo einui (`ui.eindev.ir`) — solo hace falta para
> AÑADIR componentes nuevos. Todo lo ya commiteado es autocontenido; si el
> registro muriera, sigue usando el set commiteado y escribe los componentes
> nuevos a mano con el mismo estilo (o espeja el registro en local).

## Reportar issues

Usa las plantillas (`.github/ISSUE_TEMPLATE/`): SO, versiones Node/pnpm/Rust, y si reproduce en **navegador** (`pnpm dev`) vs **Tauri** (`pnpm tauri:dev`) vs **móvil**. Logs completos, no capturas.

Volver al [Índice de docs →](./README.md)
