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

Runs in CI on `ubuntu-latest` (the only place `#[cfg(target_os = "linux")]` code compiles). Keep Linux-only logic testable as pure functions so it stays covered.

## Static gates (run all, in order)

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
```

CI mirrors this: `frontend.yml` (Node 24 + pnpm 10) and `rust.yml` (matrix ubuntu / windows / macos). A red CI blocks the PR — no exceptions.

## Manual matrix (per real bundle)

Automation cannot see pixels. After the gates, verify on a **real bundle per OS** (`pnpm tauri:build`, `scripts/build-linux.sh`, `scripts/build-windows.sh`):

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

Pixel scans beat eyeballing for frames and corners (`standard_deviation` per row: a frozen screen reads `0` everywhere). Tools: `scrot`/`xwd`/`compare` on X11, VNC capture + `box-shot.sh` on Wayland boxes, `gnome-screenshot` where it works. Paste the numbers, not adjectives.

Next: [Troubleshooting →](./troubleshooting.md)
