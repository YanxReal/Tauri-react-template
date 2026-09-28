---
name: Template Update
description: Update a downstream app built on the Tauri-react-template to the latest template version WITHOUT breaking the user's own code, renames, or customizations. Follows a strict, reversible, consent-gated safety protocol (snapshot → classify → apply per class → verify invariants/identifiers → gates green before bump). Use when the user says "update my template", "bring my app to parity with the template", "upgrade to the latest template release", or similar.
metadata:
  opencode/autoinvoke: false
---

# Template Update

Bring a **downstream app** (built on `tauri-react-template`, possibly **renamed and customized**) to parity with the latest template **release**, WITHOUT breaking the user's work. This skill exists because plain `git merge template/vX` and naive copy scripts break on renamed identifiers and customized files — the AI's job is to do the *semantic* update instead, mapping identifiers and never touching user-owned code.

> **Prime directive:** the user's app code, their renames, and their local customizations come FIRST. The template is the *upstream* — it must never clobber the app. When in doubt about a file's ownership, you STOP rather than risk it.

---

## 0. Preflight & abort conditions

Before anything else, read the repo state. **STOP and ask** (never proceed autonomously) if:

- **You cannot identify the template baseline.** There is no readable `TEMPLATE_VERSION` file at the repo root → ask the user whether this repo is a downstream app or the template source itself.
- **The working tree is dirty** (`git status --porcelain` is non-empty). The update MUST run from a clean tree so snapshots and reverts are exact. Tell the user to commit or stash first; do NOT auto-commit their work.
- **No git repo / no remote.** Confirm there is a git remote from which to fetch template releases, or obtain the template `vX.Y.Z` tarball/URL from the user.
- **No git identity** (`git config user.name` / `user.email` empty). The update creates commits; ask the user to set an identity first so commit authorship is correct.
- **This repo IS the template source** (origin or HEAD history is the template's own changelog with no per-user app layer) → there is no downstream work to protect; just verify you are on the latest tag (or tell the user you are the source, not a consumer).

If none of the above triggers, continue.

---

## 1. Snapshot (irreversible-safety net) — REQUIRED, never skip

Your baseline for "did we break anything" is a pre-update snapshot. Do ALL of these before writing a single file:

1. `git status --porcelain` → must be empty (see §0). If not, stop.
2. Record the commit hash: `git rev-parse HEAD` (save it as `$BASE`).
3. Create a restore point tag (lightweight, non-annotated local only):
   ```bash
   git tag "template-update/pre/$OLD" "$(git rev-parse HEAD)"
   ```
   The user can always `git reset --hard template-update/pre/$OLD` to undo the whole update.
4. Snapshot the **template-owned file set** so you can prove after the update that user-owned files are byte-identical:
   ```bash
   mkdir -p .tmp/template-update
   git ls-files > .tmp/template-update/tracked-before.txt
   ```
   (The ownership map in `references/ownership.md` defines which paths are user-owned vs template-owned.)
5. Store the detected identifiers (from §2) in `.tmp/template-update/ids.json` for later comparison.

**Invariant:** after the update you will re-verify that every **user-owned** path is unchanged vs this snapshot, EXCEPT the handful you consciously touch with explicit per-file consent.

---

## 2. Identify baseline, target, and the user's identifiers

### 2a. Baseline and target
- `OLD` = contents of `TEMPLATE_VERSION` (the version the user is on).
- Ensure the template remote exists. Prefer a remote named `template`; if absent, add it **without touching `origin`**:
  ```bash
  git remote get-url template || git remote add template https://github.com/YanxReal/Tauri-react-template.git
  ```
- `git fetch template --tags --force`
- `NEW` = the highest `vX.Y.Z` tag reachable on the template (list + sort: `git tag --list "v*" --sort=-v:refname`), OR the tag the user explicitly requested.
- If `OLD == NEW` → report "already up to date" and STOP (idempotency basis, see §9).
- Fetch the exact target: `git fetch template tag "$NEW"` so you have the precise ref.

### 2b. Detect the user's identifiers
Run the helper:
```bash
scripts/detect-identifiers.sh
```
It prints JSON with the **user's** current identifiers (e.g. `crate`, `libName`, `productName`, `identifier`, `windowTitle`, and derived `binary`, `appleScheme`, `androidPackage`). Save it to `.tmp/template-update/ids.json`.

Compare against the template's own ids. The rule: **the update must never re-introduce the template's identifiers (`tauri-react-template`, `com.tauri-react-template.app`, etc.) into user-owned paths, and must not silently rebrand the user back to the template's name.** When a template file references its own identifiers, translate them to the user's detected set before writing.

If `detect-identifiers.sh` cannot run or the output looks wrong, STOP and manually confirm the identifiers with the user.

---

## 3. Classify the delta — produce a plan table (CONSENT GATE)

Compute exactly what changed between the user's current template version and the target:

```bash
git diff template/$OLD template/$NEW --name-status   # list, or --stat for summary
```

For **every** changed path, classify into one bucket using `references/ownership.md`. You MUST produce a written plan (a table) covering every path before writing anything. Buckets:

| Bucket | Example paths | Default action | Risk |
|--------|---------------|----------------|------|
| `A-safe` (template-owned) | `scripts/`, `Makefile`, `src-tauri/vendor/`, tooling (MODS content now lives in the tauri-cli-rebase skill) | Semantic apply with identifier translation | Low — but CHECK these aren't user-customized (see §4.1) |
| `A-component` (vendored UI) | `packages/ui/src/components/**` | Prefer re-vendoring from the registry; else diff | Low if pure vendored; **Medium if user customized** (see §4.4) |
| `A-config` (per-OS configs) | `tauri.conf.json`, `tauri.*.conf.json` | **JSON merge, never overwrite**: apply new/missing keys, preserve the user's app id, `productName`, `title`, and any value they intentionally set | Medium |
| `B-user-owned` | `apps/web/src/**`, `src-tauri/src/**`, `.env*`, `capabilities/`, user pages | **READ-ONLY**. Mechanical/backward-safe edits only, and only with per-file user consent | High |
| `B-adjacent-interface` | files that define the *interface* B consumes (e.g. `native-chrome.ts`, i18n `en/es.json` keys, a Rust command B calls) | Apply only safe mechanical parts; surface breaking changes as a migration TODO; do NOT rewrite B's callers | High |

Show the plan to the user. Explicitly call out anything that touches `B-user-owned` or changes an interface B uses. **Do not write a single file until the user approves the plan.**

---

## 4. Apply — transactional, logical commits, consent-gated

Apply **only** what the plan approved. Work in small, logically grouped commits so each is independently revertible. Never batch "everything" into one blob.

### 4.1 Verify A-files aren't user-customized
Before overwriting any `A-safe` file, check whether the user diverged from the template for that path:
```bash
git diff template/$OLD -- <path>
```
If the user diverged, STOP that file and present the case: overwrite (lose their tweak), manual merge, or leave it behind and note it. Their choice.

### 4.2 Semantic apply with identifier translation
For each approved `A-safe` file: take the diff `template/$OLD..template/$NEW`, apply the **change** to the user's current file (3-way, not replace-from-scratch unless the file is pure vendored). Translate any *identifier* literal (see §2b) to the user's. Commit:
```bash
git add <path> && git commit -m "chore(template-update): apply $NEW — <area>"
```

### 4.3 JSON merge for configs (`A-config`)
Use a real JSON merge (not a blind copy): union the template's new keys with the user's file, and **keep the user's** `app.windows[].title`, `productName`, `identifier`, and any key they set. Never restore the template's app identity. If a merge would conflict on a semantic key, STOP and ask.

### 4.4 Components (`A-component`)
- If the file is **byte-identical** to the upstream registry source, you may re-vendor it (see `references/ownership.md` for the registry + `sync` mechanism).
- If the user **customized** it (diff vs registry source is non-empty), do NOT overwrite. Report it as "customized component — left as-is; here is the upstream delta if you want to migrate it."

### 4.5 B-owned / B-adjacent
- `B-user-owned`: **no writes without explicit per-file user consent.** Do not "fix" or reformat user code during an update.
- `B-adjacent-interface`: apply only the backward-safe mechanical changes. Any breaking interface change becomes a **migration TODO** logged to the user (and appended to the update report), not something you silently rewrite across the app.

### 4.6 Never leak identifiers
After each commit, verify the file doesn't reference the template's identifiers where the user's belong. Do not introduce `tauri-react-template` into any committed file except where it's an invariant/loader default that must match the crate (rare). When in doubt, ask.

---

## 5. Invariant re-verification — the "nothing broke" net (REQUIRED)

After applying, re-check the cross-platform invariants hold **in the updated repo** (see `references/ownership.md` for the full checklist). Non-exhaustive, most load-bearing:

- `dragDropEnabled:false` + `zoomHotkeysEnabled:false` still present in **every** desktop `tauri.*.conf.json` windows array.
- `index.html` still carries `user-scalable=no, maximum-scale=1.0`; CSS still has `user-select:none` and `touch-action: pan-x pan-y`.
- `window_effects_set` is still **sync** (main thread).
- Linux env vars (`WEBKIT_DISABLE_DMABUF_RENDERER=1`, `__NV_DISABLE_EXPLICIT_SYNC=1`) still set before `Builder`.
- Windows frameless + decorum + `DWMWCP_ROUND` intact.

Also verify:
- **Identifiers unchanged**: `.tmp/template-update/ids.json` still matches `detect-identifiers.sh` output after the update (no drift).
- **User-owned files intact**: `git diff template-update/pre/$OLD -- <every B path>` is empty (or only the consented files differ), and no `tauri-react-template` literal leaked into B paths.
- **No dead files left**: files removed by the template release are removed in the user's tree too (that's intended), but never a B path.

---

## 6. Gates — green before bump (REQUIRED)

Run the full gates (or at minimum `--check` equivalents the user approves). A red gate blocks the marker bump AND the "done" report — no exceptions.

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
cargo check --manifest-path src-tauri/Cargo.toml
cargo test --manifest-path src-tauri/Cargo.toml
cargo fmt --manifest-path src-tauri/Cargo.toml --check
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
```

- If Rust changed: also check in the Linux box over SSH (`cfg(linux)` bodies never compile on macOS) and target-check iOS + windows-msvc (see `docs/en/testing.md`).
- If any gate is red, STOP, do NOT bump the marker, and report the failing gate with the trace. The restore point in §1 is the undo.

---

## 7. Finalize

1. Bump `TEMPLATE_VERSION` to `$NEW` and commit:
   ```bash
   git add TEMPLATE_VERSION && git commit -m "chore(template-update): bump template version to $NEW"
   ```
2. Optionally remove the `.tmp/template-update` scratch dir, or keep the snapshot for a while and mention it.
3. Keep the `template-update/pre/$OLD` tag (it is the user's undo handle).

---

## 8. Report (required summary)

Produce a structured report to the user:

- **Baseline → target** (`OLD` → `NEW`).
- **Per bucket**: what was applied, what was intentionally skipped, what needs manual migration (list each `B` / `B-adjacent` TODO).
- **Consent log**: every `B-user-owned` write you made (with the user's approval).
- **Identifiers**: confirmed unchanged (or list intentional changes).
- **Gates**: all green (paste results).
- **Rollback**: how to undo — `git reset --hard template-update/pre/$OLD`.

---

## 9. Idempotency & edge cases

- **Already up to date**: if `OLD == NEW` after the update, re-running is a no-op (report "already current"). Never re-apply windows that are already applied.
- **Marker missing/garbled**: the `TEMPLATE_VERSION` marker might be intact but you can't reconcile it with a tag — ask the user which version they're on rather than guessing.
- **Partial update / interrupted apply**: rely on the per-batch commits + `template-update/pre/$OLD` tag to resume cleanly; never continue a half-applied state blindly.
- **Offline**: if you cannot fetch `$NEW`, STOP and ask — do not guess a target version.
- **Downgrade detected**: if the requested target is BEHIND the current tag, warn and confirm (downgrades are almost never wanted).

---

## References

- `references/ownership.md` — the template-owned vs user-owned map, the JSON-merge rules, the component registry + sync mechanism, and the full cross-platform invariant checklist.
- `scripts/detect-identifiers.sh` — prints the user's current identifiers as JSON.
- Template release discipline (tags `vX.Y.Z` + bilingual migration notes) lives in `docs/en/changelog.md` / `docs/es/changelog.md`.

---

## Tool compatibility

This skill is distributed in Anthropic **Agent Skills** format; the same `SKILL.md`, `references/`, and `scripts/` work in Claude Code, OpenAI Codex, and OpenCode. Helper scripts must stay executable (e.g. `scripts/detect-identifiers.sh`); `make install-skills` installs every skill shipped with the project and keeps helper scripts executable.