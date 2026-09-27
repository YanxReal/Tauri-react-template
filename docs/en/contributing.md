# Contributing

> **Audience:** contributors — conventions, parity, gates. For bug reports use the [issue templates](../../.github/ISSUE_TEMPLATE/bug_report.md).

## Conventions

- **JS/TS:** Biome formats + lints (`biome.json:1`). No ESLint/Prettier. Run `pnpm lint:fix` before committing; Husky + lint-staged enforces it.
- **Rust:** `cargo fmt` + `clippy` (`await_holding_lock: deny`).
- **Commits:** focused, no secrets, never skip hooks unless asked.
- **i18n:** never hardcode user-facing strings — `t("key")`, `en.json`/`es.json` in sync.
- **Styling:** tokens in `globals.css:1`; components in `@workspace/ui`.

## Bilingual docs parity (mandatory)

Mirrored docs: `docs/en/` ↔ `docs/es/` (see [`AGENTS.md`](../../AGENTS.md)):

1. Every docs change lands in **both** languages, same commit/PR.
2. Same file tree (`en/X.md` ↔ `es/X.md`) and same section order — translation, not rewrite.
3. Same `file:line` pointers; cross-links stay in-tree (`en/`→`en/`, `es/`→`es/`).
4. Root `README.md` + `README.es.md` keep identical structure; `docs/README.md` stays the bilingual router.
5. One-sided PRs get rejected — parity is the first review gate.

## Quality gates before push

Full matrix: [Testing](./testing.md).

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
```

Plus a real bundle per OS (scroll + click + no-zoom) — see the manual matrix in [Testing](./testing.md).

## Adding a page to docs

1. Create `docs/en/<page>.md` + `docs/es/<page>.md` together.
2. Row in `docs/en/README.md` + `docs/es/README.md` indexes.
3. Row in `docs/README.md` (both columns).
4. `file_path:line_number` pointers for code references.

## Shadcn components

```bash
pnpm dlx shadcn@latest add <component> -c apps/web
# lands in packages/ui/src/components
```

Document new components in both trees.

## Reporting issues

Use the templates (`.github/ISSUE_TEMPLATE/`): OS, Node/pnpm/Rust versions, and whether it reproduces in **browser** (`pnpm dev`) vs **Tauri** (`pnpm tauri:dev`) vs **mobile**. Full logs, not screenshots.

Back to [Docs index →](./README.md)
