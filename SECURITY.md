# Security Policy

This is a **private template** — defaults favor local development speed. If you
publish an app built from it, harden it first (see checklist below).

## Supported versions

| Version | Supported |
|---|---|
| `master` (working tree) | ✅ |
| Anything older | ❌ (rebase onto `master`) |

There is no LTS: the template moves fast and fixes land on `master`.

## Reporting a vulnerability

Open a **GitHub issue** with `[security]` in the title and include:

- What you ran (OS, profile: `dev` / `debug` / `release` bundle)
- The exact command and the full log
- What you expected vs what happened

No bug bounties. Sensitive reports (signing identities, tokens): rotate the
secret first, then file the issue without pasting it.

## Hardening checklist (before any public release)

- [ ] `csp: null` in the base + mobile configs → set a strict `default-src 'self'` policy like the desktop ones.
- [ ] Test the **release** profile: `prevent-default` (`Flags::debug()`) only blocks webview defaults (context menu, devtools, reload) in release.
- [ ] Dev servers listen on all interfaces (`host: true` in `vite.config.ts`) — never expose `1420`/`1421` beyond your LAN.
- [ ] Rotate anything that touched the repo: `scripts/.team-id`, `src-tauri/keys/*`, `.env` files (all gitignored — verify with `git status`).
- [ ] Dev-box defaults (`dev`/`admin` VNC/SSH passwords on `127.0.0.1`) are local-only conveniences — change them + use SSH keys past localhost.
