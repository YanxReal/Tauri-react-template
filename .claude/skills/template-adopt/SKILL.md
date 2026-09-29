---
name: Template Adopt
description: Adopt the Tauri-react-template architecture into an ALREADY-BUILT project (either an old template-based app needing renewal, or an independent Tauri app) WITHOUT breaking the user's code, renames, languages, or customizations. Full-scope adoption (UI, native-feel, i18n, tooling/skills/docs) with a strict, reversible, consent-gated protocol. Use when the user says "adopt the template into my project", "bring my existing app up to the template", "use the template in my already-made project", "migrate my app to this template", or similar.
metadata:
  opencode/autoinvoke: false
---

# Template Adopt

Adopt the **Tauri-react-template** architecture into an **existing project** that was built
independently — bringing the template's layers ON TOP of the user's work **without breaking
anything**. This is different from `template-update` (which syncs a project ALREADY on the
template to a newer template version, sharing git history). Here there is usually **no shared
baseline**: we must inventory the user's project, lay the template's capes on top, and never
damage the user's code, identifiers, languages, or customizations.

> **Prime directive:** the user's existing project is sovereign. The template is the *upstream
> capes* placed around it — never a replacement. If you cannot prove a file is template-owned
> additive, treat it as user-owned and STOP to ask.

---

## 0. Detect the case (up-in-place vs greenfield) — REQUIRED first

Read the target repo and decide which adoption strategy applies. Do NOT guess.

- Is there a `.claude/skills/` directory, a `TEMPLATE_VERSION` file, `packages/ui/`, or template
  identifiers (`tauri-react-template`, `com.tauri-react-template.app`, `tauri_react_template_lib`)?
  - **YES → up-in-place**: the project was built from this template (or a fork) and fell out of
    date. It shares structure; adoption = **renew to the current architecture**, preserving the
    user's divergences. Runs much like `template-update` but as an adoption/renewal (no template
    remote merge — we align to the current tree present in this repo).
  - **NO → greenfield adoption**: an independently-built Tauri app. The template capes are layered
    on top. Every coexisting path must be merged conservatively.

Run `scripts/detect-project.sh` (or manually inspect) to classify. State the detected case to the
user before proceeding.

---

## 1. Preflight & abort conditions

**STOP and ask** (never proceed autonomously) if:

- You cannot determine whether the project is up-in-place or greenfield (§0).
- The working tree is dirty (`git status --porcelain` non-empty). Adoption must start from a clean
  tree so snapshots and reverts are exact.
- You cannot find the project's identity (crate, `productName`, `identifier`, bundle names) — you
  must know what to preserve before adding anything.
- This repo IS the template source itself (no downstream user work exists to protect) → nothing to
  adopt; tell the user this is the source, not a consumer.

If all clear, continue.

---

## 2. Snapshot (irreversibility net) — REQUIRED

1. `git status --porcelain` → empty (else stop).
2. `$BASE="$(git rev-parse HEAD)"`
3. Lightweight restore tag:
   ```bash
   git tag "template-adopt/pre" "$BASE"
   ```
   Undo anytime with `git reset --hard template-adopt/pre`.
4. Record the tracked file set + the user's identifiers + all locales:
   ```bash
   mkdir -p .tmp/template-adopt
   git ls-files > .tmp/template-adopt/tracked-before.txt
   scripts/detect-identifiers.sh > .tmp/template-adopt/ids.json   # from the tauri-cli/template-update skill set if present
   scripts/detect-locales.sh > .tmp/template-adopt/locales.json
   ```

---

## 3. Inventory the user's work — "what must NOT be touched"

### 3a. **Languages (protect ALL of them)** — this is a hard rule
List **every** i18n locale the user has. Any locale beyond the template's own (`en`, `es`) —
e.g. `fr`, `de`, `ja`… the user's added languages — is **user-owned and never touched, added,
renamed, or emptied**. Also protect any locale they customized even for `en`/`es`.

Use `references/i18n-protection.md` and `scripts/detect-locales.sh`. Principle: the template only
**adds/aligns the key contract** it introduces; it never deletes a key, never rewrites a user
translation, never adds its own locale, and never drops a language the user has.

### 3b. **Identity**
Preserve and NEVER re-brand: `productName`, `identifier`, `crate`/`lib_name`, bundle IDs, window
titles, and `branding.json` (name, version, authors, `icons.master`) with its
`branding/icon-1024.png` master. The template adds its architecture under the user's identity —
it never gets renamed to `tauri-react-template`.
After the adoption apply, regenerate the mobile icons from the USER's master:
`scripts/mobile/mobile-icons-regen.sh` (post-init step that `apple-xcode.sh`/`android-autogen.sh`
already run; `tauri icon <master>` + the iOS 1024 trio composite). If the user has no 1024 master,
ask for one before touching `gen/`.

### 3c. **User code**
Pages, hooks, React components the user wrote, their `#[tauri::command]`s, their Rust logic in
`lib.rs`/`platform.rs`, their `.env*`, their `capabilities/` — all read-only unless explicitly
consented per file.

---

## 4. Classify every path into a bucket (PLAN + CONSENT GATE)

Using `references/ownership.md`, classify the template's capes that we intend to add:

| Bucket | What | Default action |
|--------|------|----------------|
| `additive` | New template-owned layers (e.g. `packages/ui` components, docs, skills, scripts, Makefile targets, `.claude/`) that don't exist in the user project | Copy in untouched |
| `merge` | Paths that exist in BOTH the user project and the template (configs `tauri*.conf.json`, `Cargo.toml`, `index.html`, `globals.css`, `main.tsx`, i18n config, `App.tsx`) | Conservatively merge **preserving user identity/code**, add template keys/capes, ask on any collision |
| `skip/user` | User-owned, or a template cape whose host the user owns | Do not touch |

Produce a written plan table (path | bucket | action | risk) covering every intended change, and
show it to the user. **Do not write a single file until the user approves the plan.**

---

## 5. Apply — transactional, small logical batches, consent-gated

- Apply **only** what the plan approved, in small grouped commits so each is independently
  revertible.
- For `merge` paths: open the user's file and the template's version, fuse them, **keeping the
  user's identity and their commands/keys/settings**. Where the two collide (e.g. a user `lib.rs`
  that already defines `greet`, or a config key the user intentionally set), STOP and ask —
  do not overwrite.
- For `additive` paths: copy the template's layer in. Translate any template identifier literal to
  the user's identity (§3b) so nothing gets rebranded.
- **Languages**: for i18n `en/es` the template adds any new key contract it introduces to those two
  only; the user's OTHER locales are never modified. If a key contract change is non-trivial, only
  apply it to the template's own languages and leave the user's other locales with a clear note
  (never a silent partial edit).
- Never reformat, "fix", or restructure user code during adoption.

---

## 6. Invariant re-verification — the "nothing broke" net (REQUIRED)

After applying, re-check in the ADOPTED repo (full list in `references/ownership.md`):

- Native-feel invariants hold: `dragDropEnabled:false` + `zoomHotkeysEnabled:false` in every
  desktop `tauri.*.conf.json`; viewport/touch/select guards; `window_effects_set` sync; Linux env
  vars; Windows decorum; scroll container.
- **User identity unchanged**: `scripts/detect-identifiers.sh` post-run matches the pre snapshot.
- **All user locales still present and untouched**: `scripts/detect-locales.sh` post-run shows the
  same set (and unchanged content except the template's own `en`/`es` key alignment if user-approved).
- **User files intact**: diff against the snapshot shows only the approved `additive`/`merge` paths.
- **No template identifier leaked** into user-owned paths.

---

## 7. Gates — green before "done" (REQUIRED)

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
cargo test --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
```
If Rust changed, also check in the Linux box. A red gate blocks "done" — no exceptions.

---

## 8. Finalize & report

1. Bump `TEMPLATE_VERSION` (create it if the project had none) to the current template version.
2. Optionally add `.claude/skills` + run `make install-skills` so the project owns the update skills.
3. Keep `template-adopt/pre` (the undo handle).
4. Report: **case detected** (up-in-place/greenfield) · **adopted** (additive layers) · **merged**
   (paths + how identity was preserved) · **untouched** (user code + all languages) · **gates** ·
   **rollback** (`git reset --hard template-adopt/pre`).

---

## 9. Idempotency & edge cases

- **Already adopted** (has `.claude/skills/template-update`, `TEMPLATE_VERSION`, current package)
  → report already current; stop (this is `template-update`'s job instead).
- **Partial/interrupted** → rely on per-batch commits + `template-adopt/pre` tag; never continue a
  half-applied state blindly.
- **More than en/es** → are protected unconditionally; adopt only the template's own languages.
- **Identity collision** → when the user's identifiers match the template's, that's a real adoption
  obstacle; surface it and confirm before proceeding (may be an up-in-place case).

---

## References

- `references/ownership.md` — layer map, merge rules, invariant checklist.
- `references/i18n-protection.md` — the language-protection rule (hard).
- `scripts/detect-project.sh` — classify up-in-place vs greenfield.
- `scripts/detect-locales.sh` — enumerate all user locales.
- The `template-update` and `tauri-cli-rebase` skills (same `.claude/skills/` tree) for version/sync
  concerns.