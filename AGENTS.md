# AGENTS.md — Instructions for AI Agents (LLMs)

> **READ THIS FILE FIRST. It is the binding contract between you (the model) and this repository.**
> If you skip it, you will break parity, cross-platform invariants, or the build. Every task — code, docs, refactor — must satisfy the rules below.

---

## 0. Who you are and what we expect from you

You are an **autonomous coding agent** (Muse Spark, Claude, Codex, Cursor, Copilot, etc.) operating inside this Tauri template. You will be asked to add features, fix bugs, write docs, or refactor. Regardless of the model family:

- **Follow instructions literally.** Do not "improvise" new conventions. This repo is opinionated (Tauri v2 + React 19 + Vite 8 + Tailwind v4 + Biome + Rust 1.85). Match the existing style.
- **Be evidence-driven.** Before editing, `read` / `grep` / `glob` the files you touch. Never guess URLs, APIs, or file paths. Cite `file_path:line_number` when you reference code in docs or PR descriptions.
- **Be bilingual-aware.** Half the repository is English, half is Spanish. You must produce **both** every time (see §3). A monolingual change is an incomplete change.
- **Be cross-platform aware.** This is not a macOS-only app. Every UI, CSS, or Rust change must work on **macOS, Windows, Linux, iOS, Android** (see §4.3). Test or reason about all targets.
- **Explain your reasoning concisely.** Keep comments short, keep PR descriptions factual, don't add praise or emojis unless asked.

If a user instruction conflicts with §3 or §4, **explain the conflict and propose a compliant alternative** instead of silently violating the invariants.

---

## 1. Project snapshot

| Layer | Detail |
|-------|--------|
| **Stack** | Tauri v2.11 + React 19.2 + Vite 8.2 + Tailwind v4.3 (`@tailwindcss/vite`) + TypeScript 5.9 strict + Turborepo 2.10 + Biome 2.5 + Vitest 4 + i18next (EN/ES). Rust stable 1.85+, `window-vibrancy 0.8`, `tauri-plugin-prevent-default`, `plugin-opener`. |
| **Monorepo** | `apps/web` (Vite app, port `1420`, alias `@` → `src`) + `packages/ui` (shadcn design system, exports `@workspace/ui/*`) + `src-tauri` (Rust backend, per-OS Tauri configs). |
| **Docs** | `docs/en/` and `docs/es/` — **mirrored, must stay in parity** (see §3). `docs/README.md` is the bilingual router. |
| **Quality** | `biome.json` (formatter + linter, 2 spaces / 80 cols / `asNeeded`), Husky + lint-staged, `cargo fmt` + `clippy` (`await_holding_lock: deny`), CI `frontend.yml` + `rust.yml`. |
| **Reference** | The original evolution is recorded in `git log` — 20 commits from `455897d` (initial) to `9da8602` (Linux shadow). Read it before large refactors. |

### Why git history matters (read it)

The `git log` is the **design rationale** for every non-obvious line of code. Before you touch native-feel, vibrancy, or mobile, skim it:

```bash
git log --oneline --reverse   # chronological story
git show <hash> --stat        # what a commit touched
```

Key milestones you must know (chronological):

| Hash | Commit | Why it exists |
|------|--------|---------------|
| `e08ca4a` | `feat: modernize template — pnpm + node24, biome, i18n bilingüe, tailwind v4, tauri v2` | Baseline: pnpm workspaces, Node 24, Biome, bilingual i18n, HTML5 semantics. |
| `653bebc` | `feat: shadcn full + einui liquid glass — dual registry` | 45 shadcn components + einui glass-* vendored into `packages/ui`. Dual registry `@einui`. |
| `10a74e4` | `feat: unified iOS+macOS Xcode template — debug/hotreload/release pipelines` | Single target `tauri-react-template_Apple`, 3 configs, JSON-RPC probe, `DEVELOPMENT_TEAM` sentinel. |
| `c9ae1a4` | `feat: native-app feel — prevent-default plugin, dragDrop/zoomHotkeys off, CSS+JS multi-OS` | The **foundational native-feel** commit: `dragDropEnabled:false` + `zoomHotkeysEnabled:false` (all 4 configs), viewport lock, CSS `user-select:none` + `touch-action`, Rust `prevent-default` with `Flags::debug()`. |
| `f997723` | `feat: efecto cristal — toggle de translucidez nativa (window-vibrancy)` | `window-vibrancy 0.8` + **sync** `window_effects_set` (main thread), `VibrancyProvider`. |
| `5fb6077` | `feat: ventana nativa - esquinas redondeadas, arrastre y cristal por tema` | DWM `DWMWCP_ROUND`, `native-chrome.ts`, glass that follows theme, `pan-x pan-y` scroll. |
| `aa83704` | `fix: arrastre macOS fiable (patron Prestly, banda 20px)` | Reliable drag: `useMacDragRegion`, 20px band (`--native-titlebar-height`), header sticky offset. |
| `9177b88` | `fix: ventana arrastrable y esquinas redondeadas en las 3 plataformas` | Permissions `core:window:allow-start-dragging`, `app-shell` as scroll container with `border-radius`. |
| `938f89a` | `fix: traffic lights live-resize sin flicker + header alineado + windows NSIS/Wix` | **HuLa 3-mecanismo** for macOS traffic lights (WindowEvent + NSNotificationCenter + 60fps NSTimer), positions `22.5/44.5/66.5`. |
| `93657d3` | `fix: linux glass veto + curvas ventana + toggle combinado` | Linux glass OFF (yellow DMABUF glitches + RAM), `WEBKIT_DISABLE_DMABUF_RENDERER`, combined toggle, `build-linux.sh`. |
| `9da8602` | `fix: sombra de ventana nativa en Linux via GTK CssProvider + fallback webview` | GTK `CssProvider` restores `decoration { box-shadow }`, fallback `app-shell` shadow, `gtk-shadow` class. → superseded by Wayland-safe `StyleContext::add_provider` (native only, no fallback). |

> **Rule of thumb:** if you see `// Prestly pattern` or `// HuLa fix` in comments, that line is load-bearing. Don't remove it without re-reading the commit that added it. See `docs/en/native-feel.md` and `docs/en/mobile.md` for the long-form explanations.

---

## 2. Where things live

```
apps/web/src/App.tsx            App shell (semantic landmarks, i18n, greet) — see App.tsx:19
apps/web/src/main.tsx           Providers + native guards (drag, zoom, opener) — see main.tsx:17
apps/web/src/i18n/config.ts     i18next init (en/es, localStorage cache) — see config.ts:14
apps/web/vite.config.ts         Vite + Tailwind + alias + host:true + vitest — see vite.config.ts:8
packages/ui/src/styles/globals.css  Single source of truth for theme/tokens/shell — see globals.css:11
src-tauri/src/lib.rs            Commands + vibrancy + macOS traffic lights + Linux shadow — see lib.rs:78, lib.rs:107, lib.rs:315
src-tauri/tauri.conf.json       Base Tauri config (merged with tauri.{os}.conf.json)
src-tauri/Info.plist            Template source for macOS+iOS Info.plist (gen/ is autogen)
scripts/Xcode/apple-xcode.sh    Regeneration of src-tauri/gen/apple (xcodegen) — never edit gen/
Makefile                        Desktop/iOS/Android shortcuts + install-tauri-cli
docs/                           Bilingual docs (en/ + es/) — see docs/README.md
AGENTS.md                       This file — agent contract (you are here)
```

### File ownership

| You want to change… | Edit… | Never edit… |
|---------------------|-------|-------------|
| Xcode project | `src-tauri/vendor/tauri-cli-*/templates/mobile/ios/` + `apple.xcconfig` | `src-tauri/gen/` (regenerated) |
| App icons | `src-tauri/icons/` + `Assets.xcassets` | `src-tauri/gen/apple/Assets.*` |
| iOS Info.plist | `src-tauri/Info.plist` (template, feeds both macOS+iOS) | `src-tauri/gen/apple/**/Info.plist` |
| macOS traffic lights | `src-tauri/src/lib.rs:107` | AppKit internals elsewhere |
| Linux shadow | `src-tauri/src/lib.rs:315` + `globals.css:241` | `src-tauri/gen/` |

---

## 3. BILINGUAL DOCS PARITY — MANDATORY (the most violated rule)

This repository has **two mirrored documentation trees**:

- `docs/en/` — English
- `docs/es/` — Spanish

`docs/README.md` is the **bilingual router** (both languages side-by-side).

### 3.1 Rules (enforce strictly, no exceptions)

1. **Every docs change touches BOTH trees.** If you edit `docs/en/foo.md`, you **MUST** edit `docs/es/foo.md` in the **same commit/PR**, and vice-versa. A PR that touches only one side is incomplete and must be rejected or fixed.
2. **Same file tree.** `docs/en/X.md` ↔ `docs/es/X.md` — **identical filenames**, identical section order. Translation, not rewrite. If you add `docs/en/changelog.md`, you must add `docs/es/changelog.md`.
3. **Same structure.** Headings (`#`, `##`, `###`), tables, code blocks, admonitions, and cross-links must **mirror 1:1**. `en/` pages link only to `en/` peers, `es/` pages only to `es/` peers.
4. **Bilingual routers stay bilingual.** `docs/README.md` and root `README.md` have two columns (EN | ES). Keep them that way.
5. **Self-heal on sight.** If you detect a divergence (missing file, outdated section, untranslated addition, link pointing to the wrong tree), **fix it immediately** — do not leave the trees out of sync for the next agent.
6. **Review gate.** In code review, the first check is parity. If parity is broken, request changes before reviewing content.

### 3.2 How to apply (step-by-step for models)

**Adding a new page:**

```bash
# 1. Create BOTH files together
touch docs/en/my-feature.md docs/es/my-feature.md
# 2. Write the English version first (source of truth), then translate fully to Spanish
#    — keep headings identical in order, translate the body faithfully
# 3. Register in BOTH indexes
#    - docs/en/README.md  → add row for my-feature
#    - docs/es/README.md  → add row for my-feature (same position)
#    - docs/README.md     → add row with BOTH links (EN | ES columns)
```

**Updating an existing page (even a single line):**

1. Apply the change to `docs/en/foo.md`.
2. Immediately translate and apply the equivalent change to `docs/es/foo.md` — keep the diff symmetric.
3. Keep `file_path:line_number` pointers **identical** across languages (they point to source code, not to language).
4. Do **not** leave `TODO: translate` or empty sections. Produce a real translation. You are Spanish-capable; assume the same for any reviewer.

**What NOT to do (anti-patterns):**

- ❌ `docs/en/foo.md` updated, `docs/es/foo.md` untouched ("will translate later").
- ❌ `docs/en/foo.md` has 5 sections, `docs/es/foo.md` has 3 ("shorter is fine").
- ❌ `docs/en/foo.md` links to `../es/bar.md` (cross-tree link).
- ❌ Machine-translation stub that loses meaning or drops code blocks.
- ✅ `docs/en/foo.md` and `docs/es/foo.md` have same headings in same order, same tables, same `file_path:line_number`, translated prose.

### 3.3 Parity checklist (run mentally BEFORE finishing — copy it into your PR description)

- [ ] `ls docs/en` count == `ls docs/es` count (`diff <(ls docs/en) <(ls docs/es)` is empty)
- [ ] Every `en/` file has an `es/` counterpart with **identical name** and **identical heading order**
- [ ] `docs/README.md` link table covers **all** pages in **both** columns
- [ ] Cross-links point to the correct language tree (`en/` → `en/`, `es/` → `es/`)
- [ ] `file_path:line_number` pointers are identical across languages
- [ ] No `TODO`, no empty stub, no English paragraph left untranslated in `es/`

### 3.4 Why this matters

A user who reads Spanish must get the **same** information as a user who reads English. The docs are a product surface, not an afterthought. Breaking parity creates a two-tier user experience and forces the next agent to do your work.

---

## 4. Workflow for agents (how to ship safely)

### 4.1 Read before edit

```bash
# Good: inspect the files you will touch
read apps/web/src/App.tsx
grep "window_effects_set" src-tauri/src/lib.rs
glob "docs/en/*.md"
```

Do not guess URLs or APIs. The repo has no `tailwind.config.*` — config is in CSS. No ESLint — only Biome. Check the file before you assume.

### 4.2 Keep changes minimal and consistent

- **JS/TS:** Biome style — 2 spaces, line width 80, `asNeeded` semicolons, `double` quotes, `es5` trailing commas, `useImportType: error`. Run `pnpm lint:fix` before committing.
- **Rust:** `cargo fmt` + `clippy`. The crate enforces `await_holding_lock: deny` (`Cargo.toml:73`). Do not `.await` while holding a `MutexGuard`.
- **No drive-by reformats.** Touch only the lines your task requires.

### 4.3 Never break cross-platform invariants (the subtle bugs live here)

These invariants were earned through painful commits (see §1 table). Removing any of them reintroduces a platform-specific bug:

| Invariant | Where | Why (commit) | What breaks if you remove it |
|-----------|-------|--------------|------------------------------|
| `dragDropEnabled:false` + `zoomHotkeysEnabled:false` in **all** `tauri.*.conf.json` windows (desktop **and** mobile layers) | `src-tauri/tauri.conf.json:20`, `tauri.macos/windows/linux/ios.conf.json` | `c9ae1a4` | Drag-and-drop of files into the webview, pinch/keyboard zoom re-enabled. |
| `viewport user-scalable=no, maximum-scale=1.0` + `touch-action: pan-x pan-y` + `user-select:none` | `apps/web/index.html:5`, `globals.css:136`, `globals.css:144` | `c9ae1a4`, `ae5be97` | Zoom on double-tap, text selection everywhere, scroll jank. Mobile breaks first. |
| `window_effects_set` stays **sync** (main thread) | `src-tauri/src/lib.rs:78` | `f997723` | `window-vibrancy` panics/off-thread failure. The command MUST NOT become `async`. |
| `WEBKIT_DISABLE_DMABUF_RENDERER=1` + `__NV_DISABLE_EXPLICIT_SYNC=1` before `Builder` | `src-tauri/src/lib.rs:371` | `93657d3`, `9da8602` | Yellow `backdrop-blur` glitches + RAM blow-up on Linux/NVIDIA/Wayland. |
| `titleBarStyle: Overlay` + `hiddenTitle` + live-resize fix (3 mechanisms) | `tauri.macos.conf.json`, `lib.rs:107` | `938f89a` | macOS traffic lights flicker/jump during resize (wry#1747, tauri#13044). |
| GTK `CssProvider` (native A: `StyleContext::add_provider` Wayland-safe + `app-shell` `border-radius:10px; contain:paint` + `#main-content` scroll for 4 native corners; B: fallback `html.linux:not(.gtk-shadow)` + compositor shader `mutter-rounded`/`niri` as safety) | `lib.rs:315`, `globals.css:241` | `9da8602` (+ fix `screen==None`, bottom via `contain:paint` + `HeaderBar` dummy) | Linux frameless window has no shadow / bottom corners squared (header/footer fake vs system). |
| `prevent-default` with `Flags::debug()` (blocks in release, keeps in debug) | `lib.rs:390` | `c9ae1a4`, `f23a894` | Context menu / Reload leaks into release builds, or devtools lost in debug. |
| `host: true` in `vite.config.ts` | `apps/web/vite.config.ts:25` | `10a74e4` | `tauri ios dev` health-check on LAN IP fails, hot-reload never connects. |

**Checklist before pushing any UI/Rust change:**

- [ ] Tested or reasoned about **all** targets (macOS, Windows, Linux, iOS, Android — or at least the ones your change affects)
- [ ] `dragDropEnabled` / `zoomHotkeysEnabled` still `false` everywhere?
- [ ] Viewport / `touch-action` / `user-select` still intact?
- [ ] `window_effects_set` still `sync`?
- [ ] Linux env vars still set before `Builder`?

### 4.4 Never edit `src-tauri/gen/`

`src-tauri/gen/apple/` and `src-tauri/gen/android/` are **autogen** (gitignored). They are regenerated from:
- `src-tauri/vendor/tauri-cli-*/templates/mobile/ios/` (project.yml, xcconfig)
- `src-tauri/Info.plist` (template for both macOS+iOS)

If you need to change the Xcode project, edit the **template**, then run `scripts/Xcode/apple-xcode.sh`. Any manual edit inside `gen/` is lost on the next regen and will be rejected in review.

### 4.5 i18n

- User-facing strings go through `t("key")` — never hardcode.
- Keep **both** `apps/web/src/i18n/locales/en.json` and `es.json` in sync (same keys, translated values). The `Header` toggle calls `i18n.changeLanguage()` and syncs `document.documentElement.lang` (`App.tsx:28`).
- Adding a locale: copy `en.json` → `xx.json`, register in `i18n/config.ts:20` (`supportedLngs` + `resources`).

### 4.6 Verify (run the checks that match your change)

```bash
pnpm typecheck
pnpm lint
pnpm test
pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
# If Tauri/Rust logic changed:
cargo check --target aarch64-apple-ios --manifest-path src-tauri/Cargo.toml
cargo check --target aarch64-unknown-linux-gnu --manifest-path src-tauri/Cargo.toml
# And when feasible, test scroll/click/no-zoom in a REAL bundle per OS:
pnpm tauri:build
scripts/build-linux.sh
```

If any check fails, fix it before marking the task done. Do not batch completions.

---

## 5. When to ask vs. when to act

- **Ask (or explain and propose):** the user request conflicts with §3 or §4 (e.g. "remove the Linux shadow", "make `window_effects_set` async", "only update English docs"). Explain **why** the invariant exists (cite the commit and the bug it fixed) and propose a compliant alternative that preserves both the request and the invariant.
- **Act (and self-heal):** you notice a divergence (parity drift, missing `es/` counterpart, dead link, outdated section). Fix it in the same PR — do not leave it for the next agent.
- **Flag:** if a docs change is English-only by explicit upstream instruction (e.g. pasting an English-only spec), still produce the Spanish counterpart and flag it in the PR description as `ES: translated from EN — please review wording`.

---

## 6. Quick links to docs

| Doc | EN | ES |
|-----|----|----|
| Index | `docs/en/README.md` | `docs/es/README.md` |
| Getting Started | `docs/en/getting-started.md` | `docs/es/getting-started.md` |
| Architecture | `docs/en/architecture.md` | `docs/es/architecture.md` |
| Frontend | `docs/en/frontend.md` | `docs/es/frontend.md` |
| Tauri Backend | `docs/en/tauri.md` | `docs/es/tauri.md` |
| Styling | `docs/en/styling.md` | `docs/es/styling.md` |
| i18n | `docs/en/i18n.md` | `docs/es/i18n.md` |
| Mobile | `docs/en/mobile.md` | `docs/es/mobile.md` |
| Native Feel | `docs/en/native-feel.md` | `docs/es/native-feel.md` |
| Scripts | `docs/en/scripts.md` | `docs/es/scripts.md` |
| Troubleshooting | `docs/en/troubleshooting.md` | `docs/es/troubleshooting.md` |
| Contributing | `docs/en/contributing.md` | `docs/es/contributing.md` |
| Changelog | `docs/en/changelog.md` | `docs/es/changelog.md` |
| Bilingual router | `docs/README.md` (both) |

---

## 7. For the next agent: what "good" looks like

A good PR in this repo:

1. Has a **clear title** (`fix:`, `feat:`, `docs:`) and references the commit or issue it builds on.
2. Touches **both** `en/` and `es/` docs when docs are involved — with identical structure.
3. Keeps `file_path:line_number` citations accurate (re-check after moving code).
4. Passes `pnpm typecheck && pnpm lint && pnpm build && cargo check` locally.
5. Includes a **parity checklist** (see §3.3) in the PR description and is marked done only after all boxes are checked.
6. Does not edit `src-tauri/gen/`, does not make `window_effects_set` async, does not drop cross-platform guards.

If your work meets all six, you are done. If not, keep iterating.

---

*This file is intentionally in English (agent lingua franca) but the parity rule it defines is bilingual and applies to every agent, regardless of model family. Keep this file updated if `docs/` structure changes — and mirror any new section you add here into the relevant doc pages.*
