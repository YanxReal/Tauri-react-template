# Ownership map & safety references for the Template Update skill

This file is the source of truth the skill (`SKILL.md`) uses to classify every path
into template-owned (safe to update) vs user-owned (must not break). Keep it in step
with the repo structure and the invariants in `AGENTS.md`.

---

## 1. Path ownership map

Paths are classified at update time. A path the user has **diverged from the template**
is treated as user-customized (see below) even if it "belongs" to a template-owned bucket.

### Template-owned (`A`) — the template may replace/migrate these
`A-safe` (tooling, configs-agnostic, docs, vendored CLI):
- `scripts/`, `Makefile`, `.github/`, `.claude/`, `.vscode/`, `.husky/`, `src-tauri/vendor/`
- `docs/` (both `en/` + `es/` trees; keep parity), root `README*.md`, `CHANGELOG.md`
- `src-tauri/vendor/` (rebased template CLI), `src-tauri/Info.plist`, `Assets.xcassets`
- `rust-toolchain.toml`, `biome.json`, `.editorconfig`, `.npmrc`, `pnpm-workspace.yaml`,
  `turbo.json`, `tsconfig*.json`, `package.json` (careful: build scripts only)

`A-component` (vendored UI, registry-backed):
- `packages/ui/src/components/**` — vendored from the einui registry
  (`https://ui.eindev.ir/r/{name}.json`) and shadcn. Prefer re-vendoring over hand-diff.
  A component the user customized must NOT be silently overwritten.

`A-config` (per-OS configs) — **JSON-merge, never replace**:
- `src-tauri/tauri.conf.json`, `tauri.macos.conf.json`, `tauri.windows.conf.json`,
  `tauri.linux.conf.json`, `tauri.ios.conf.json`, `tauri.android.conf.json`
- `src-tauri/capabilities/*.json`

### User-owned (`B`) — read-only unless explicitly consented per file
- `apps/web/src/**` (App.tsx, layout/, pages, hooks/, components the user added)
- `src-tauri/src/**` (lib.rs, platform.rs — the user's commands and native logic)
- `.env`, `.env.local`, `.env.*`, `scripts/.team-id`, `scripts/.env*`
- `branding.json` + `branding/` (identity: name, version, authors, `icons.master` —
  the user's brand; the template only ever reads these, never writes them)
- Any file/path the user created that is not in the template's `git ls-files`

### B-adjacent (interface the user's code consumes) — high care
Paths that define APIs/contracts the user's `B` code calls. Updating them can break the
app even though they're "template files". Handle as `B` risk:
- `apps/web/src/components/layout/native-chrome.ts` (drag/resize API)
- `apps/web/src/components/layout/*.tsx` that the user imports
- `apps/web/src/i18n/locales/en.json` + `es.json` (key contract)
- `apps/web/src/main.tsx` (guards the user may have extended)
- `apps/web/src/components/glass-cards-provider.tsx`, `vibrancy-provider.tsx`
- Rust `#[tauri::command]` signatures the frontend invokes

---

## 2. How to know if a path is user-customized

For a path `P` that exists in the template at `$OLD`:

```bash
git diff template/$OLD -- <P>          # non-empty ⇒ user diverged
```

If `P` does NOT exist in the template at `$OLD`, it is user-created → treat as `B`.

For a vendored component, compare against its registry source; a non-empty diff means
"customized".

---

## 3. JSON merge rules for `A-config`

1. Load the user's current JSON and the template's target JSON.
2. Keep the user's **identity** fields verbatim: `app.windows[].title`, `productName`,
   `identifier`, bundle ids.
3. Add new keys the template introduced; do NOT delete keys the user set.
4. For overlapping keys the template changed, apply the template's new value ONLY when
   the user's current value equals the old template value (i.e. the user never changed
   it). If the user diverged, keep theirs and report the semantic diff.
5. Never expand the user's `bundle.targets`/icon set unless they approve.

---

## 4. Component registry & sync

- Registry: einui `https://ui.eindev.ir/r/{name}.json`, shadcn registry equivalents.
- A component is re-vendorable only if the user's copy is byte-identical to the upstream
  registry source. Otherwise it is "customized" — leave it and report the delta.
- Dedicated `pnpm sync:ui` may not exist yet; prefer targeted re-vendor per changed
  component over a blanket overwrite.

---

## 5. Cross-platform invariant checklist (must all hold after update)

From `AGENTS.md` §4. Re-verify in the **updated** repo:

- [ ] `dragDropEnabled:false` + `zoomHotkeysEnabled:false` in **every** desktop
      `tauri.*.conf.json` `windows[]` (base, macos, windows, linux).
- [ ] `index.html`: viewport `user-scalable=no, maximum-scale=1.0`; `globals.css`:
      `user-select:none`, `touch-action: pan-x pan-y`.
- [ ] `window_effects_set` stays **sync** (main thread) — async reintroduces the
      window-vibrancy panic.
- [ ] Linux env (`WEBKIT_DISABLE_DMABUF_RENDERER=1`, `__NV_DISABLE_EXPLICIT_SYNC=1`)
      set before `Builder`.
- [ ] `titleBarStyle: Overlay` + `hiddenTitle` + the 3-mechanism live-resize fix intact
      on macOS.
- [ ] Linux = frameless + opaque (square corners by design); app header = the titlebar.
- [ ] Windows = frameless + decorum + `DWMWCP_ROUND`; `[data-tauri-decorum-tb]` hidden.
- [ ] Scroll container = content only; overlay scrollbars from the OS, never CSS.
- [ ] `prevent-default` with `Flags::debug()`; `host: true` in Vite config.

If any box is left unticked, the update is NOT safe to ship — fix it before §7.

## 5b. Desktop native-feel — no regen layer (protected like mobile, differently)

Desktop windows behavior does NOT come from `gen/` (that is mobile + Xcode
skeleton only). It lives in **plain repo source** that the template update must
merge, never "regenerate" or overwrite:

- `src-tauri/src/lib.rs` (traffic lights/snap/X consts, vibrancy, Linux resize +
  frameless, Windows decorum, `prevent-default` flags)
- `src-tauri/tauri.{macos,windows,linux}.conf.json` guard keys
- `apps/web/src/components/layout/{header,window-controls,native-chrome}.tsx`
- `src-tauri/Assets.xcassets` + `src-tauri/build.rs`

There is no `mods.md` for these: they are the user's runtime (merge rules §3/
`B` apply). Protection rule: after ANY step of an update, `git diff` on those
paths must show only intentional template merges — never a silent replace, and
never a move into a "generated" bucket.

---

## 6. Identifier fields the skill must protect

Never let the template overwrite these with the template's own values:
`crate`, `libName`, `productName`, `identifier`, `windowTitle`, `binary`, `appleScheme`,
`androidPackage`, plus `branding.json` (name, version, authors, `icons.master`) and
`branding/icon-1024.png`. Use `scripts/detect-identifiers.sh` before and after to confirm no drift.