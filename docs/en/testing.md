# Testing

> **Audience:** everyone — automated checks first, then the manual per-OS matrix. Nothing ships without both.

## Unit tests (Vitest)

```bash
pnpm --filter web test          # single run
pnpm --filter web test:watch    # watch mode
pnpm test                       # turbo (all workspaces)
```

- Config in `vite.config.ts` (`jsdom`, `setupFiles`); coverage to `coverage/**`.
- `App.test.tsx` renders inside `AppProviders` (same Theme → Vibrancy → GlassCards stack as the webview boot — rendering `App` bare throws).
- `native-chrome.test.ts` covers `resizeEdgeAt` (which edge a pointer position maps to). Pure function, runs on any OS.

## Rust tests

```bash
cargo test --manifest-path src-tauri/Cargo.toml
```

No CI exists, so run it yourself — on this host AND in the Linux box (`make build-linux` — the `linux-build` skill syncs, builds and verifies with the box's rustup env). Linux-only logic stays testable as pure functions: `ResizeEdge::from_str` (`lib.rs`) parses the 8 GDK edge names with zero GTK calls, so it runs everywhere; the `cfg(linux)` body that maps it to `gtk::gdk::WindowEdge` only compiles in the box.

## Static gates (run all, in order)

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
cargo test --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
```

No CI exists — run them yourself before every push. A failing gate blocks the PR — no exceptions. (`cfg(linux)` bodies only compile in the Linux box: re-run `cargo check`/`cargo test` over SSH there when Rust changes.)

## Manual matrix (per real bundle)

Automation cannot see pixels. After the gates, verify on a **real bundle per OS** (`pnpm tauri:build`, `make build-linux` / `make linux-release` — Linux via the `linux-build` skill —, `scripts/build-windows.sh`):

| Check | macOS | Windows | Linux |
|---|---|---|---|
| Launch, no errors | ✓ | ✓ | ✓ |
| Drag by header band | ✓ | ✓ | ✓ |
| Resize all edges/corners | ✓ (+live traffic lights) | ✓ | ✓ (6px app edge) |
| Caption buttons (min/max/close) | traffic lights | ✓ + Snap hover | ✓ |
| Scroll 0↔max, no jank | ✓ | ✓ (overlay bar) | ✓ |
| No zoom (double-tap, Ctrl+wheel, pinch) | ✓ | ✓ | ✓ |
| Theme toggle follows everywhere | ✓ | ✓ | ✓ (no native frame to follow) |

Always test the **release** profile too: `prevent-default` (`Flags::debug()`) only blocks webview defaults there.

## Screenshots as evidence

Pixel scans beat eyeballing for frames and corners (`standard_deviation` per row: a frozen screen reads `0` everywhere). Tools: on the Linux box (X11, real) use the `linux-build` skill's flow — `assistant shot` (capture), `assistant ocr` (text), `assistant click/type` (real input) — and `scrot`/`xwd`/`compare` on X11 hardware; on Wayland-with-a-real-GPU use `gnome-screenshot` where it works. Paste the numbers, not adjectives.

Next: [Troubleshooting →](./troubleshooting.md)
