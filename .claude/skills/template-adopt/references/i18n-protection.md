# i18n language-protection rule (HARD — for the template-adopt skill)

> The user's languages are user-owned. Adopting the template must NEVER touch, add, rename, empty,
> or rewrite a language the user has beyond the template's own `en`/`es`. This is a **must-not
> violate** — not a best effort.

---

## 1. What "the user's languages" means

- The template's own locales are `en` and `es` (see `apps/web/src/i18n/locales/`).
- ANY locale besides those two — `fr`, `de`, `ja`, `pt`, and so on, added by the user — is a
  **user-owned language**.
- Even the template's `en`/`es` can be user-modified; their translated strings are user content.

---

## 2. The rule

1. Before adoption, enumerate all locales: `scripts/detect-locales.sh` →
   `{ "locales": ["en","es","fr","de","ja"], "userOwned": ["fr","de","ja"] }`.
2. **Never** add, rename, empty, or edit a `userOwned` locale.
3. The template's key contract is only added to the template's own `en`/`es`.
4. If the user customized `en`/`es`, preserve their translations; only add missing template keys if
   the user approves (never rewrite/delete their strings).
5. Never create a translation in a `userOwned` locale on the user's behalf.
6. If a key-contract change cannot be applied cleanly to `en`/`es` without risking a `userOwned`
   locale, STOP and ask — do not leave a silent partial edit.

## 3. Why (so the adopting agent understands, not just obeys)

A user who took the trouble to support 7–8 languages made a real investment. An adoption that
silently drops, rewrites, or un-syncs any of those is data loss from the user's perspective — the
single most likely thing to make them say "you broke my project". Enforcing this rule is what keeps
adoption safe.

## 4. Verification after adoption

- `scripts/detect-locales.sh` post-run: the `userOwned` set is IDENTICAL (and its files
  byte-identical) to the pre-adoption snapshot.
- The template's `en`/`es` differ only by user-approved additions.
- No template locale was ever created for a language the user didn't already have.