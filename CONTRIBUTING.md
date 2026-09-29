# Contributing

Contributions are welcome — this is a community **template**, and the fastest
way to improve it is a clear PR or a reproducible bug report.

- **Full guide:** [`docs/en/contributing.md`](docs/en/contributing.md) /
  [`docs/es/contributing.md`](docs/es/contributing.md) (bilingual, parity kept).
- **Issue templates:** use the [bug report](.github/ISSUE_TEMPLATE) /
  feature request forms — include the OS, the Tauri version and a repro.
- **PRs:** follow the [pull request template](.github/pull_request_template.md).
  Keep the EN/ES docs mirrored and the gates green (`pnpm lint/test/build`,
  `cargo fmt/clippy` — see `AGENTS.md` §5).
- The repo has **no CI**: gates run locally by design (see `docs/en/testing.md`).

TL;DR: fork → branch → change (remember: edit the vendored **templates**, never
`src-tauri/gen/`) → run the gates → PR.