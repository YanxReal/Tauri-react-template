# AGENTS.md — Operating Contract for AI Agents

> **READ THIS FIRST.** You (the model) break this repo by skipping it: parity drift, broken cross-platform invariants, or red builds. Every task — code, docs, refactor — follows the protocol below. No exceptions, regardless of model family.

---

## 0. Task protocol (the loop — follow it every time)

1. **Understand.** Restate the task in one line. If it conflicts with §3 (parity) or §4 (invariants), stop and propose a compliant alternative — never silently violate them (§6).
2. **Locate.** `read` / `grep` / `glob` before editing. Never guess paths, APIs, or URLs. The repo has no `tailwind.config.*` (config is in CSS) and no ESLint (only Biome).
3. **Check constraints.** Which rows of §4 does your change touch? Which platforms (§4.3 checklist)? Which docs pages need the EN+ES mirror (§3)?
4. **Edit minimally.** Touch only the lines the task requires. Match Biome (2 spaces, 80 cols, `asNeeded`, double quotes) and Rust (`cargo fmt`, no `.await` under lock) styles.
5. **Verify.** Run the checks in §5. Re-check every `file_path:line_number` you moved. Confirm parity with the §3.3 checklist.
6. **Report concisely.** Facts only, no praise, no emojis. Cite `file_path:line_number`.

---

## 1. Project snapshot

| Layer | Detail |
|-------|--------|
| **Stack** | Tauri v2 (runtime 2.12, CLI 2.12) + React 19.3 + Vite 8.3 + Tailwind v4.3 (`@tailwindcss/vite`) + TypeScript 7.0 strict + Turborepo 2.11 + Biome 2.5 + Vitest 5 + i18next (EN/ES). Rust stable 1.85+, `window-vibrancy 0.8`, `tauri-plugin-prevent-default`, `plugin-opener`. |
| **Monorepo** | `apps/web` (Vite `:1420`, `@` → `src`) + `packages/ui` (shadcn, `@workspace/ui/*`) + `src-tauri` (Rust, per-OS configs). |
| **Docs** | `docs/en/` + `docs/es/` mirrored, parity enforced (§3). `docs/README.md` is the router; root has `README.md` (EN) + `README.es.md` (ES). |
| **Quality** | Biome, Husky + lint-staged, `cargo fmt` + `clippy` (`await_holding_lock: deny`, `Cargo.toml:76`). No CI — gates run locally ([Testing](docs/en/testing.md)). |
| **History** | `git log` from `455897d` is the design rationale. Skim it (`--oneline --reverse`) before touching native-feel, vibrancy, or mobile. Milestones below. |

Key milestones (chronological — why non-obvious code exists):

| Hash | Commit | Why it exists |
|------|--------|---------------|
| `e08ca4a` | `feat: modernize template` | Baseline: pnpm, Node 24, Biome, bilingual i18n, HTML5 semantics. |
| `653bebc` | `feat: shadcn full + einui liquid glass` | 45 shadcn + glass-* in `packages/ui`. |
| `10a74e4` | `feat: unified iOS+macOS Xcode template` | One target `tauri-react-template_Apple`, 3 configs, JSON-RPC probe, `DEVELOPMENT_TEAM` sentinel. |
| `c9ae1a4` | `feat: native-app feel` | **Foundational:** `dragDropEnabled:false` + `zoomHotkeysEnabled:false` (all configs), viewport lock, `user-select:none` + `touch-action`, `prevent-default` with `Flags::debug()`. |
| `f997723` | `feat: efecto cristal` | `window-vibrancy 0.8` + **sync** `window_effects_set`, `VibrancyProvider`. |
| `5fb6077` | `feat: ventana nativa` | DWM `DWMWCP_ROUND`, `native-chrome.ts`, theme-following glass. |
| `aa83704` | `fix: arrastre macOS fiable (banda 20px)` | Reliable drag: `useMacDragRegion`, 20px band, sticky header offset. |
| `9177b88` | `fix: ventana arrastrable en las 3 plataformas` | `allow-start-dragging`, `app-shell` scroll container. |
| `938f89a` | `fix: traffic lights live-resize sin flicker` | **HuLa 3-mechanism** fix (WindowEvent + NSNotificationCenter + 60fps NSTimer). |
| `93657d3` | `fix: linux glass veto` | Glass OFF (DMABUF glitches + RAM), `WEBKIT_DISABLE_DMABUF_RENDERER`. |
| `9da8602` | `fix: sombra nativa Linux` | GTK shadow work → superseded → **removed** (frameless Linux, 2026-09-27). Windows went frameless earlier (`tauri-plugin-decorum`). |

> **Rule of thumb:** `// HuLa fix` in a comment means load-bearing — re-read the adding commit before touching it. Full story: `docs/en/native-feel.md`, `docs/en/mobile.md`, `docs/en/changelog.md`.

---

## 2. Where things live

```
apps/web/src/App.tsx            App shell (landmarks, i18n, greet) — App.tsx:19
apps/web/src/main.tsx           Providers + native guards (drag, zoom, opener) — main.tsx:21
apps/web/src/i18n/config.ts     i18next init (en/es, localStorage) — config.ts:14
apps/web/vite.config.ts         Vite + Tailwind + alias + host:true + vitest — vite.config.ts:8
packages/ui/src/styles/globals.css  Theme/tokens/shell source of truth — globals.css:11
src-tauri/src/lib.rs            Commands + vibrancy + traffic lights + decorum — lib.rs:125, lib.rs:185, lib.rs:461
src-tauri/tauri.conf.json       Base config (merged with tauri.{os}.conf.json)
src-tauri/Info.plist            Template source for macOS+iOS Info.plist (gen/ is autogen)
scripts/Xcode/apple-xcode.sh    Regen of src-tauri/gen/apple (xcodegen) — never edit gen/
scripts/patch-tauri-cli.sh      Re-applies the 3 CLI tweaks (refuses unknown versions)
MODS.md                         CLI vendor modifications + rebase checklist (root)
Makefile                        Desktop/iOS/Android shortcuts + install-tauri-cli
docs/                           Bilingual docs — docs/README.md
AGENTS.md                       This file
```

### Linux box (test bed for `cfg(linux)` code)

`cfg(target_os = "linux")` in `lib.rs` **never compiles on macOS** — `cargo check` here cannot catch its type errors. Current box: [Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker) (`ssh ubuntu-arm`, project at `/workspace/Tauri-react-template`, GUI via `dev`). It already caught a real bug once (a `type_().name()` misuse only visible on Linux). Session recipe with measured symptoms: `docs/en/scripts.md`.

### File ownership (edit left, never right)

| Change… | Edit… | Never edit… |
|---------|-------|-------------|
| Xcode project | `src-tauri/vendor/tauri-cli-*/templates/mobile/ios/` + `apple.xcconfig` | `src-tauri/gen/` (regenerated) |
| App icons | `src-tauri/icons/` + `Assets.xcassets` | `src-tauri/gen/apple/Assets.*` |
| iOS Info.plist | `src-tauri/Info.plist` (feeds macOS+iOS) | `src-tauri/gen/apple/**/Info.plist` |
| macOS traffic lights | `lib.rs:185` (`traffic_lights_target_y`) / `lib.rs:205` (snap) — X `17.5/39.5/61.5` (`lib.rs:160`) | AppKit internals elsewhere |
| Linux titlebar (app-drawn, frameless) | `header.tsx` + `window-controls.tsx`; `window.show()` after `center()` in `setup()` | `src-tauri/gen/` |
| Windows overlay (decorum) | `tauri.windows.conf.json:12` + `lib.rs:461`/`lib.rs:457` + `window-controls.tsx` | `src-tauri/gen/` |
| CLI behavior | `src-tauri/vendor/tauri-cli-*/src/mobile/` (then rebuild) | crates.io copy (use `patch-tauri-cli.sh` flow) |

---

## 3. Bilingual docs parity (most violated rule — read twice)

Two mirrored trees: `docs/en/` + `docs/es/`. `docs/README.md` routes both. Root entry points are split: `README.md` (EN) + `README.es.md` (ES), identical structure. `CHANGELOG.md` (root) is a bilingual router.

### Rules (no exceptions)

1. **Both trees, same commit.** Editing `docs/en/foo.md` without `docs/es/foo.md` (or vice-versa) = incomplete PR, request changes.
2. **Same tree, same order.** Identical filenames, identical heading order. Translation, not rewrite. New page → create both files + register in both indexes + `docs/README.md` (both columns).
3. **Same pointers, same tree.** `file_path:line_number` identical across languages (they point at code). `en/` links only `en/` peers, `es/` only `es/` peers.
4. **No stubs.** No `TODO: translate`, no empty sections, no untranslated paragraphs. You are Spanish-capable — produce the real translation.
5. **Self-heal.** Divergence on sight (missing mirror, stale section, wrong-tree link) → fix in the same PR.
6. **Review gate.** Parity is the FIRST review check.

### Parity checklist (paste into PR, all boxes before done)

- [ ] `diff <(ls docs/en) <(ls docs/es)` is empty
- [ ] Identical filenames + heading order per file
- [ ] `docs/README.md` covers all pages in both columns
- [ ] Cross-links in-tree; `file:line` pointers identical
- [ ] No `TODO`, no stubs, no untranslated prose

Why it matters: Spanish readers get the SAME information as English readers. Breaking parity creates two user tiers and dumps work on the next agent.

---

## 4. Cross-platform invariants (subtle bugs live here)

Earned through painful commits (§1). Removing any row reintroduces its platform bug:

| Invariant | Where | From | Breaks if removed |
|-----------|-------|------|-------------------|
| `dragDropEnabled:false` + `zoomHotkeysEnabled:false` in **every** desktop `windows[]` | `tauri.conf.json:21`, `tauri.macos.conf.json:16`, `tauri.windows.conf.json:15`, `tauri.linux.conf.json:14` | `c9ae1a4` | File drag-drop / pinch-keyboard zoom back |
| `viewport user-scalable=no, maximum-scale=1.0` + `touch-action: pan-x pan-y` + `user-select:none` | `index.html:5`, `globals.css:137`, `globals.css:148` | `c9ae1a4` | Double-tap zoom, select-everywhere, scroll jank (mobile first) |
| `window_effects_set` stays **sync** (main thread) | `lib.rs:125` | `f997723` | `window-vibrancy` off-thread panic |
| `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` before `Builder` | `lib.rs:394` | `93657d3` | Yellow blur glitches + RAM blow-up (NVIDIA/Wayland) |
| `titleBarStyle: Overlay` + `hiddenTitle` + 3-mechanism live-resize fix | `tauri.macos.conf.json`, `lib.rs:205` | `938f89a` | Traffic-light flicker/jump on resize |
| Traffic-light `y` from button **superview** (`isFlipped()` + height), target `MACOS_HEADER_BAND / 2` = 26px | `lib.rs:185`, `lib.rs:166` | measured macOS 26 | Dots land ~9px off |
| Linux = frameless + opaque, square corners **by design**; app header IS the 44px titlebar; inner 6px edge drives `begin_resize_drag` | `tauri.linux.conf.json:11-13`, `header.tsx:222`, `lib.rs:88` | 2026-09-27 decision | No content-edge resize (WM gives none); re-adding radius reopens the removed CSD arc |
| Windows = frameless + decorum + caption buttons + `DWMWCP_ROUND`; `[data-tauri-decorum-tb]` hidden | `lib.rs:461`/`lib.rs:457`, `window-controls.tsx` | decorum overlay | Missing controls or a 32px overlay bar |
| Scroll container = content only (`.app-shell` clips, `.app-scroll` scrolls `main` + `Footer`); overlay scrollbars from the OS, never CSS | `globals.css:215`/`globals.css:231`, `App.tsx:52` | scrollbar overlay work | Classic bar back, header width stolen, caption buttons covered |
| `prevent-default` with `Flags::debug()` | `lib.rs:403` | `c9ae1a4` | Menus/devtools leak into release (or lost in debug) |
| `host: true` in Vite config | `vite.config.ts:25` | `10a74e4` | `tauri ios dev` LAN health-check fails |

**Pre-push checklist (UI/Rust):** all affected targets reasoned about · guards still `false` everywhere · viewport/touch/select intact · `window_effects_set` sync · Linux env vars set · Windows frameless+decorum intact · header outside scroller, no scrollbar CSS added.

---

## 5. Style, i18n, generated code, verification

- **JS/TS:** Biome (2 spaces, 80 cols, `asNeeded`, double quotes, `useImportType: error`). `pnpm lint:fix` before commit. No drive-by reformats.
- **Rust:** `cargo fmt` + `clippy` (`await_holding_lock: deny`, `Cargo.toml:76`). Never `.await` under a `MutexGuard`.
- **i18n:** user strings via `t()` only; keep `en.json`/`es.json` key-synced; `Header` toggle syncs `document.documentElement.lang` (`App.tsx:29`); new locale = copy `en.json`, register in `i18n/config.ts:20`.
- **Never edit `src-tauri/gen/`** (autogen, gitignored). Xcode changes go in the **template**, then `scripts/Xcode/apple-xcode.sh`.
- **Verify** (run what your change touches):
  ```bash
  pnpm typecheck && pnpm lint && pnpm test && pnpm build
  cargo check --manifest-path src-tauri/Cargo.toml
  cargo test --manifest-path src-tauri/Cargo.toml
  cargo fmt --manifest-path src-tauri/Cargo.toml --check
  cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
  # Rust logic changed: also check + test over SSH in the Linux box
  # (`cfg(linux)` never compiles here), plus target-check ios + windows-msvc
  # (see docs/en/testing.md), then scroll/click/no-zoom in a REAL bundle per OS.
  ```
  Red gate = fix before done. No batching completions.

---

## 6. Ask vs act, and what "good" looks like

- **Ask (explain + propose):** request conflicts with §3/§4 (e.g. "English docs only", "make `window_effects_set` async", "round the Linux corners"). Cite the commit and the bug, offer a compliant alternative.
- **Act (self-heal):** divergence on sight → fix in the same PR.
- **Flag:** English-only upstream paste → still translate to ES, flag `ES: translated from EN` in the PR.

Good PR: clear title (`fix:`/`feat:`/`docs:`) + both language trees with identical structure + accurate `file:line` + all gates green + parity checklist pasted and checked + no `gen/` edits + no dropped guards.

---

## 7. Quick links

| Doc | EN | ES |
|-----|----|----|
| Index / Getting Started / Architecture / Frontend | `docs/en/README.md`, `getting-started.md`, `architecture.md`, `frontend.md` | `docs/es/README.md`, `getting-started.md`, `architecture.md`, `frontend.md` |
| Tauri / Styling / i18n / Mobile | `docs/en/tauri.md`, `styling.md`, `i18n.md`, `mobile.md` | `docs/es/tauri.md`, `styling.md`, `i18n.md`, `mobile.md` |
| Native Feel / Scripts / Testing | `docs/en/native-feel.md`, `scripts.md`, `testing.md` | `docs/es/native-feel.md`, `scripts.md`, `testing.md` |
| Troubleshooting / Contributing / Changelog | `docs/en/troubleshooting.md`, `contributing.md`, `changelog.md` | `docs/es/troubleshooting.md`, `contributing.md`, `changelog.md` |
| Router | `docs/README.md` (both) | — |

---

*English by design (agent lingua franca). If `docs/` structure changes, update this file — and mirror new sections into the relevant doc pages.*
