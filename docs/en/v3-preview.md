# Tauri v3 Preview (`v3-preview` branch)

> Status: **preview only** — never merged to `main` until Tauri v3 is stable.

## Purpose

`v3-preview` is the roadmap's Phase A line: it tracks the Tauri v3
alphas/betas so the migration is exercised **continuously** instead of being
a big-bang jump. `main` stays on stable Tauri v2 — this branch must not break
that promise.

## Tauri v3 — current facts (researched 2026-09-29)

| Fact | Value |
|---|---|
| Latest release | `3.0.0-alpha.3` (2026-09-26); alphas roughly weekly |
| Big Linux change | **GTK4 + WebKitGTK 6.0** (GTK3 is unmaintained upstream) |
| Runtimes | swappable webview runtimes: `tauri-runtime-wry` (system webview) or `tauri-runtime-cef` (Chromium) |
| MSRV | 1.95 (this template is at 1.85) |
| Other | edition 2024, compact ACL (implicit allow/deny overrides), modern updater (no `v1Compatible`), resource hot-reload in dev, per-runtime devtools |

This is also the line where the documented `glib < 0.20` advisory dies: v3
replaces the whole GTK-0.18 stack.

## Branch rules

- Sync `main` → `v3-preview` regularly (rebasing keeps the diff small).
- Gates stay green here too: `pnpm typecheck/lint/test/build`, `cargo
  fmt/clippy`, `make check-docs`.
- **Never merge `v3-preview` → `main`**: when v3 goes stable, the migration
  lands on `main` as one coherent change (roadmap Phase B).

## Gradual adoption steps (in order)

1. **Vendored CLI rebase** to `tauri-cli 3.0.0-alpha.x` (the
   `tauri-cli-rebase` skill flow, re-applying MOD-1..5 semantics; the runtime
   detection now comes from the manifest, not features).
2. **Runtime crates refactor**: add `tauri-runtime-wry`, select it via
   `tauri::Builder::default().runtime(...)`, move the runtime-specific code
   (traffic lights, vibrancy) to the wry extension traits.
3. **MSRV 1.95 + edition 2024** (`rust-toolchain.toml`, `Cargo.toml`).
4. **Linux GTK4 rework** (frameless, resize band, `set_linux_theme`, DMABUF
   guard, glass plans) — verified in the container + real Wayland sessions.
5. **ACL + updater + devtools modernization**; later the optional CEF
   profile (`make init --runtime cef`).
6. Re-verify the 5-OS matrix on real bundles.

## Current state

As of the branch creation: identical to `main` plus this document — the
migration steps start when the alpha line is stable enough to compile the
whole repo (everything above happens in small, gate-green commits).