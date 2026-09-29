---
name: Linux Build
description: Build, launch and verify the Tauri app for Linux over SSH to the Ubuntu-arm-docker dev box (a Dockerised Ubuntu 26.04 + Cinnamon/X11 desktop with the full Tauri v2 toolchain) — the ONLY way to produce Linux bundles from macOS/Windows hosts, where Linux is not native. Use when the user says "build for Linux", "linux bundle/deb", "test on Linux", "run the app in the Linux box", or when AGENTS.md verification requires Linux (cfg(linux) code, frameless checks, scroll/click/no-zoom in a real bundle). SSH-only workflow: rsync sync (never clones), fast debug or release builds, launch in the GUI session, verify with real screenshots/OCR/input.
metadata:
  opencode/autoinvoke: false
---

# Linux Build

Build the **Linux bundles** of this Tauri app — and optionally **run and verify it** — on the
`Ubuntu-arm-docker` dev box, reached exclusively over SSH. On macOS and Windows, Linux is not
native: `webkit2gtk` + the Linux bundlers only exist inside the box, which runs under Docker on
the host. **This skill never manages the container and never clones the repo into it.** It
synchronises the sources over SSH with `rsync` (incremental, **without `.git`**), keeping
`node_modules/` and `target/` cached on the box so rebuilds take seconds instead of the
was-clone-every-time tedium.

Everything below is scripted and wired into the repo's Makefile — read §3 for the recipe, and
prefer the script/make targets over ad-hoc SSH commands.

---

## 1. World model (the box, as of 2026-09)

| Fact | Value |
|---|---|
| Box repo | [YanxReal/Ubuntu-arm-docker](https://github.com/YanxReal/Ubuntu-arm-docker) — Ubuntu 26.04 LTS, **Cinnamon 6.4 on X11 (Xvfb `:1`)**, arm64 |
| Access | SSH `ubuntu-arm` alias (`~/.ssh/config`, port 2222, user `admin`; password auth or your key via `ssh-copy-id`); noVNC `localhost:6080`, native VNC `localhost:5902` (password `admin`) |
| Toolchain | `CARGO_HOME=/usr/local/cargo`, `RUSTUP_HOME=/usr/local/rustup` (stable + rustfmt + clippy), Node 24 + pnpm + `@tauri-apps/cli` global in `/usr/local/bin` |
| Project on box | `/workspace/Tauri-react-template` (default `LINUX_BUILD_DIR`; the box's `./workspace` is bind-mounted from the host) |
| GUI launching | `dev <cmd>` wrapper — injects `DISPLAY=:1`, `XAUTHORITY`, `DBUS_SESSION_BUS_ADDRESS` from `/run/user/1000/desktop-env` |
| AI control | `assistant` CLI: `status`, `shot` (real X11 capture), `region`, `ocr` (tesseract spa+eng), `open`/`run`, `type`/`key`/`click`/`rclick`/`move`/`drag` (real `xdotool` input), `windows`/`winmove`, `record` (video), `files`/`here`, `wd` (isolated GTK session) |
| Artifacts home | `/workspace/ai/` — write screenshots there; fetch them with `scp -P 2222 admin@localhost:/workspace/ai/<file> .` |
| Session log | `/run/user/1000/session.log` (Xvfb/Cinnamon/x11vnc watchdog restarts them) |

Full reference: [`references/box.md`](./references/box.md).

## 2. Preflight (always)

1. `ssh ubuntu-arm true` — if the alias is unknown, use `ssh -p 2222 admin@localhost` (password `admin`) and offer to `ssh-copy-id`.
2. **Host key changed** (container recreated): `ssh` will refuse with *REMOTE HOST IDENTIFICATION HAS CHANGED*. The box is the user's own, on localhost → safe to run `ssh-keygen -R "[127.0.0.1]:2222"` (or the port in their alias) and retry. Ask first if the box is remote.
3. **Box not reachable**: do NOT start Docker or containers yourself. The box repo has its own flow (`make install` / `make up` in its checkout). Tell the user it is down and what to run; the script's error message says the same.
4. Read `src-tauri/Cargo.toml` `[package] name` — the binary name on the box follows it (the script derives it, you don't).

## 3. The recipe (the advanced method — no clones, fast debug & release)

Use the script — `make` targets at repo root wrap it (see §5):

```bash
# Fast daily loop: rsync sources (+ debug build w/o bundle) + run + verify
make build-linux
#   ≡ LINUX_BUILD_REMOTE="$(LINUX_REMOTE)" ... .claude/skills/linux-build/scripts/linux-build.sh --remote --debug --run --verify

# Release bundle (deb by default): build + fetch to ./dist-linux
make linux-release                 # or LINUX_BUNDLES=appimage make linux-release

# Hot reload (Vite + app) in the box
make dev-linux

# Follow / kill the remote app or dev server
make linux-logs   /   make linux-stop
```

Reading the script output: `pnpm install --frozen-lockfile` is idempotent (seconds when nothing changed); the first cargo build after a Rust change is minutes, later ones incremental. The box keeps its cargo cache, so consecutive builds are fast — that is why the sync excludes `target/` and `node_modules/`.

## 4. What to do when the flow asks for more

- **Launch only** (already built): `linux-build.sh --remote --debug --run` (no rebuild if `--no-sync`; run always uses the `dev` wrapper when present). **Debug runs auto-start Vite** on the box before launching — the debug binary loads `devUrl :1420`; a launch without Vite yields an empty window list. Release binaries embed the frontend (no Vite).
- **Dev server quirks**: `--dev` starts Vite `:1420` + the app in the box. If port `:1420` is taken remotely, `tauri dev` may fail — check `linux-logs`.
- **The app does not appear**: verify the GUI session first — `ssh ubuntu-arm 'assistant status'` (X session OK?), then `assistant windows`. If only `assistant windows` is missing, the app may have crashed: read `/tmp/<binary>.log` on the box.
- **Software rendering caveats**: the box renders with llvmpipe (no GPU). Do NOT set `WEBKIT_DISABLE_COMPOSITING_MODE=1` — the box enables its compositor on purpose (live window drag); disabling it regresses the desktop. The app's own `WEBKIT_DISABLE_DMABUF_RENDERER=1` guard (in `lib.rs`) is about NVIDIA/Wayland real hardware, unrelated here.
- **Verification shows a blank/frozen window**: take the shot again after a few seconds (`assistant shot /workspace/ai/x.png`), OCR it. If still empty, check `/tmp/<binary>.log` remotely; a debug build without Vite (devUrl) is expected when the release binary was run alone.

## 5. Script & make reference

`make` targets (repo root `Makefile`):

| Target | Runs | Use |
|---|---|---|
| `build-linux` | `linux-build.sh --remote --debug --run --verify` | daily loop: sync + fast debug + launch + assistant verify |
| `linux-release` | `linux-build.sh --remote --release [--bundles $LINUX_BUNDLES] --fetch` | .deb (or appimage/rpm/all) + fetch to `./dist-linux` |
| `dev-linux` | `linux-build.sh --remote --dev` | hot reload on the box |
| `linux-logs` / `linux-stop` | `linux-build.sh --remote --logs` / `--stop` | follow / kill remote app or dev server |

Overrides: `LINUX_REMOTE=<host>` / `LINUX_DIR=<dir>` / `LINUX_BUNDLES=<list>` / `LINUX_BUILD_DISPLAY=:N`.

Script flags (`.claude/skills/linux-build/scripts/linux-build.sh --help`): `--remote [HOST]`, `--release|--debug` (debug = `--no-bundle` unless `--bundles` given), `--dev`, `--run`, `--verify` (implies run; `assistant windows+shot+ocr` then fetches the PNG to `./dist-linux/linux-verify.png`), `--bundles deb|appimage|rpm|all`, `--target aarch64|x86_64|<triple>`, `--fetch`, `--sync-only`, `--no-sync`, `--logs`, `--stop`. Defaults: host `ubuntu-arm`, dir `/workspace/Tauri-react-template`, release profile, bundles `deb`.

## 6. Windows & macOS specifics

- **macOS**: run the make targets or the `.sh` directly (bash ships with macOS).
- **Windows**: run from a **Git Bash** terminal (Git for Windows ships OpenSSH + bash). `rsync` is optional — the sync falls back to `tar` (no stale-file cleanup, otherwise identical). Docker Desktop runs the box; nothing here needs WSL.
- The skill installs everywhere with the repo's `scripts/install-skills.sh --global` (copy of this folder to `~/.claude/skills` + `~/.config/opencode/skills`), so downstream apps get the same flow.

## 7. Traps (from the box's own AGENTS.md — read before improvising)

- Coordinates for `assistant click/move` are **pixels of the 1920×1080 capture**.
- `assistant drag` selects; it does NOT move windows (use `assistant winmove X Y`).
- On Xvfb+llvmpipe the compositor state may regress to outline-only drag — report it, don't "fix" it.
- `assistant wd` runs GTK apps in an isolated Mutter session (real PNG + AT-SPI) when the live desktop is not what you need.
- Anything failing on the box side: `make logs-x11vnc` exists in the BOX repo; from here, `ssh ubuntu-arm 'tail -n 60 /run/user/1000/session.log'`.

## 8. Deliverable

A Linux verification is complete when: the chosen profile built on the box (debug binary or release bundle), the app launched (visible in `assistant windows`), a PNG landed in `dist-linux/linux-verify.png` (or `/workspace/ai/`), and no new failures were introduced. Report paths + OCR/status lines, not adjectives — per AGENTS.md §5, "paste the numbers".