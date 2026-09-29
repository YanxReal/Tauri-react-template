# Adoption layer map & safety references (for the template-adopt skill)

This is the source of truth the skill uses to classify every path during an ADOPTION. Keep it in
step with the repo structure and the invariants in `AGENTS.md`. Mirrors the spirit of the
`template-update` ownership map but from the *adoption* direction (bringing capes onto an existing
project).

---

## 1. Template capes by layer

These are what the template CAN offer. During adoption each cape lands in one of the buckets
(additive / merge / skip-user).

| Layer | Template-owned paths/features |
|-------|-------------------------------|
| **UI / components** | `packages/ui/src/components/**` (shadcn + glass-*), `packages/ui/src/lib/utils.ts`, `packages/ui/src/styles/globals.css` (as the theme startup), `packages/ui/vitest.config.ts`, `apps/web/vite.config.ts` alias |
| **Native feel** | `src-tauri/tauri.conf.json` + `tauri.{macos,windows,linux,ios,android}.conf.json` (guards), `src-tauri/src/lib.rs` native commands/setup, `capabilities/`, `index.html` viewport/meta, `globals.css` guards |
| **i18n** | `apps/web/src/i18n/config.ts`, `locales/en.json` + `locales/es.json` (template's own two), the i18n key contract the template uses |
| **Tooling / skills / docs** | `scripts/**` (incl. `scripts/mobile/**` icon pipeline), `Makefile`, `.claude/skills/**`, `docs/{en,es}/**`, root `README*.md`, `CHANGELOG.md`, `.github/**`, `rust-toolchain.toml`, `biome.json`, `pnpm-workspace.yaml`, `turbo.json`, `tsconfig*` |
| **Identity** (user-owned, never replaced) | `branding.json` (name, version, authors, `icons.master`) + `branding/icon-1024.png` (the icon master that `scripts/mobile/mobile-icons-regen.sh` feeds on) |

---

## 2. Bucket classification matrix

For any target path `P`:

| If… | Bucket |
|-----|--------|
| `P` is template-owned and does NOT exist in the user project | `additive` (copy in) |
| `P` exists in BOTH template and user project, but the user's version is template-aligned or config-like (no heavy custom code) | `merge` (fuse conservatively) |
| `P` exists and carries user code/decisions (pages, components they wrote, their commands, `.env*`, their capabilities, their extra locales) | `skip/user` (do not touch) |

Detection: use `git diff`/`git status` and `scripts/detect-project.sh`. When unsure, default to
`skip/user` and ask.

---

## 3. Merge rules for shared paths

1. **Configs** (`tauri*.conf.json`): union the template's new keys with the user's; KEEP the user's
   `productName`, `identifier`, `app.windows[].title`, `bundle.targets`/icons, and any value they
   intentionally set. Never restore the template's identity.
2. **Rust sources** (`lib.rs`, `platform.rs`): never overwrite. Add any missing template command
   ONLY if it doesn't collide with the user's. On any collision → stop and ask.
3. **Frontend roots** (`main.tsx`, `App.tsx`, `globals.css`, `index.html`): add the template's
   guards/layers without removing the user's. If the user already has the same guard with different
   values, keep the user's and report the delta.
4. **i18n**: add only the template's key contract to the template's own `en`/`es`; never touch the
   user's other locales; never disambiguate their translations.

---

## 4. i18n language-protection (HARD)

- Enumerate every locale (see `scripts/detect-locales.sh`).
- Any locale other than the template's own `en`/`es` is **user-owned**: never added, renamed,
  emptied, or edited.
- Even the template's `en`/`es`: if the user customized them, preserve their translations and only
  add missing template keys if user-approved; never rewrite/remove their strings.
- Follow `references/i18n-protection.md` for the exact rule.

---

## 5. Cross-platform invariants (must all hold after adoption)

From `AGENTS.md` §4. Re-verify in the ADOPTED repo:

- [ ] `dragDropEnabled:false` + `zoomHotkeysEnabled:false` in every desktop `tauri.*.conf.json` window.
- [ ] `index.html`: `user-scalable=no, maximum-scale=1.0`; `globals.css`: `user-select:none`,
      `touch-action: pan-x pan-y`.
- [ ] `window_effects_set` is SYNC (main thread).
- [ ] Linux env vars before `Builder`; Windows decorum + `DWMWCP_ROUND`; macOS Overlay traffic lights.
- [ ] Scroll container = content only; overlay scrollbars from the OS.
- [ ] `prevent-default` with `Flags::debug()`; `host: true` in Vite.

If any box is left unticked after adoption, do not ship — fix it before §7.

### 5b. Desktop native-feel — adopted as source, never "regenerated"

The mobile layers are generated from vendored templates (`gen/`, `MOD`s,
`tauri-cli-rebase`). The DESKTOP native feel is NOT generated: `lib.rs`
(traffic lights/vibrancy/Linux resize+decorum/`prevent-default`),
`tauri.{macos,windows,linux}.conf.json` guards,
`apps/web/src/components/layout/*`, `Assets.xcassets` + `build.rs` are adopted
as plain source (buckets `merge`/`skip/user`, §2–§3). Adoption must NEVER move
them into a generated bucket or gate them behind a regen flow; the user's
values win on any collision and the invariant checks above are the shipping
gate (same rule as `template-update` §5b).

---

## 6. Identifier fields that must be preserved

`crate`, `libName`, `productName`, `identifier`, `windowTitle`, `binary`, `appleScheme`,
`androidPackage`, plus `branding.json` (name, version, authors, `icons.master`) and
`branding/icon-1024.png`. Use `scripts/detect-identifiers.sh` (from the `template-update`/`tauri-cli-rebase`
skill dirs, or reproduce it) before and after to confirm no drift. The user's project is NEVER
rebranded to `tauri-react-template`. After adoption, verify the icon master is the USER's image
and run the mobile icon regeneration (`scripts/mobile/mobile-icons-regen.sh`) so `gen/` assets
carry their brand, not the template placeholders.