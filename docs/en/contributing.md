# Contributing

## Conventions

- **JS/TS:** Biome is the formatter & linter (`biome.json:1`). No ESLint/Prettier. Run `pnpm lint:fix` before committing. `husky` + `lint-staged` enforces it.
- **Rust:** `cargo fmt` + `clippy` (`await_holding_lock: deny`). Run `cargo check --manifest-path src-tauri/Cargo.toml` and `cargo fmt --check`.
- **Commits:** keep them focused; no secrets; never skip hooks unless explicitly requested.
- **i18n:** never hardcode user-facing strings — use `t("key")` and keep `en.json` / `es.json` in sync.
- **Styling:** tokens in `packages/ui/src/styles/globals.css:1`; components in `@workspace/ui`.

## Bilingual docs parity (mandatory)

This repo has **mirrored docs**: `docs/en/` ↔ `docs/es/`. See [`/AGENTS.md`](../../AGENTS.md:1).

Rules:

1. Every user-visible docs change must be applied in **both** languages.
2. Same file tree: `en/X.md` ↔ `es/X.md` (identical filenames).
3. Same structure & section order — translation, not rewrite.
4. Keep cross-links consistent (`en/` links to `en/` peers, `es/` to `es/` peers).
5. `docs/README.md` and root `README.md` stay bilingual.

PRs that touch only one side should be rejected. The CI/parity check in `AGENTS.md` expects both sides updated.

## Quality gates before push

```bash
pnpm typecheck
pnpm lint
pnpm test
pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
```

For Tauri logic also test:

```bash
cargo check --target aarch64-apple-ios --manifest-path src-tauri/Cargo.toml
```

And manually verify **scroll + click + no-zoom** in a real bundle per OS (`pnpm tauri:build` or `scripts/build-*.sh`) — see `docs/en/native-feel.md`.

## Adding a page to docs

1. Create `docs/en/<page>.md` and `docs/es/<page>.md` together.
2. Add the row to both `docs/en/README.md` and `docs/es/README.md` indexes.
3. Add the link row to `docs/README.md` (both columns).
4. If the content references code, include `file_path:line_number` pointers.

## Shadcn components

```bash
pnpm dlx shadcn@latest add <component> -c apps/web
# lands in packages/ui/src/components
```

No English/Spanish docs diverge here — document any new component in both trees.

## Reporting issues

Include OS, Node/pnpm/Rust versions, and whether the bug reproduces in **browser** (`pnpm dev`) vs **Tauri** (`pnpm tauri:dev`) vs **mobile**.

Back to [Docs index →](./README.md)
