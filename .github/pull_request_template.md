# PR description — all boxes required / todos obligatorios

## What / Qué

<!-- EN + ES summary / resumen EN + ES -->

## Checks

- [ ] `pnpm typecheck && pnpm lint && pnpm test && pnpm build`
- [ ] `cargo check` (+ `fmt --check`, `clippy -D warnings` if Rust changed / si tocó Rust)

## Parity checklist (docs)

- [ ] `diff <(ls docs/en) <(ls docs/es)` is empty
- [ ] Same headings order + same `file:line` pointers in both trees
- [ ] Cross-links stay in-tree (`en/` → `en/`, `es/` → `es/`)
- [ ] No `TODO`, no untranslated paragraphs in `es/`

## Platforms (mark affected / marca afectadas)

- [ ] macOS · [ ] Windows · [ ] Linux · [ ] iOS · [ ] Android
