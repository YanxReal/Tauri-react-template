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
make check-docs                       # EN/ES parity + AGENTS/docs anchors
```

`make check-docs` is also wired into the pre-commit hook — it fails before `git
commit` on a broken mirror or a drifted `file:line`anchor.

Plus a real bundle per OS (scroll + click + no-zoom) — see the manual matrix in [Testing](./testing.md).

## Versioning policy

The repo version lives in `TEMPLATE_VERSION` + the `vX.Y.Z` tag (both must
stay in sync). The changelog (EN+ES) records every change.

- **Bump `TEMPLATE_VERSION` + tag on any change a downstream app must know
  about**: new Makefile/script/skill hooks, changed command signatures,
  config schema changes, invariant changes (AGENTS §4), icon/identity flow
  changes, dependency pins that alter behavior.
- **Patch (x.y.Z)**: doc-only, tooling-only or non-behavioral fixes — bump
  only if a downstream needs the fix (they can also pin to a commit).
- **Minor (x.Y.0)**: new capability that does not break adopters.
- **Major (X.0.0)**: breaking changes for adopters (renames, removed targets,
  changed file layout). When bumping: run `make rebrand`, regenerate the
  mobile `gen/` trees, gates + `make check-docs`, and re-verify one real
  bundle per OS.
- Tag with a message: `git tag -a vX.Y.Z -m "..."` and push tags
  (`git push --tags`).

### Upstream advisories (Dependabot)

Dependabot flags `glib < 0.20` (medium, `glib::VariantStrIter` unsoundness) on
the default branch. It is **upstream-bound**: glib arrives through the whole
GTK 0.18 stack that `tauri 2.12` pulls on Linux (`gtk 0.18.2` ←
`tao`/`wry`/`muda`/`webkit2gtk`). Bumping glib alone breaks the gtk-rs minor
alignment and the Linux build — do NOT run
`cargo update -p glib --precise 0.20`. It resolves when tauri/tao bump their
GTK stack; re-check after each tauri upgrade
(`cargo tree -i glib --target x86_64-unknown-linux-gnu`).

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

> **Long-term dependency note:** `packages/ui/components.json` references the
> external einui registry (`ui.eindev.ir`) — it is only needed to add NEW
> components. Everything already committed is self-contained; if the registry
> ever dies, keep using the committed set and hand-write any new components in
> the same style (or mirror the registry locally).

## Reporting issues

Use the templates (`.github/ISSUE_TEMPLATE/`): OS, Node/pnpm/Rust versions, and whether it reproduces in **browser** (`pnpm dev`) vs **Tauri** (`pnpm tauri:dev`) vs **mobile**. Full logs, not screenshots.

Back to [Docs index →](./README.md)
