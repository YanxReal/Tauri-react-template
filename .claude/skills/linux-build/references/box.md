# The Ubuntu-arm-docker box — full reference

> Facts verified against the box repo at `101cd9a` (2026-09). The box repo is a
> **separate project**; this file only documents what an agent needs to drive
> builds from here. Nothing here manages the container (that is the box repo's
> own Makefile: `make install` / `make up` / `make status` / `make logs`).

## Access

| Path | Value |
|---|---|
| SSH | `ssh ubuntu-arm` (`~/.ssh/config` alias: HostName `127.0.0.1`, Port `2222`, User `admin`) or `ssh -p 2222 admin@localhost` |
| Password | `admin` (VNC and noVNC share it) |
| Key auth | `sshpass -p admin ssh-copy-id ubuntu-arm` (or `ssh-copy-id -p 2222 admin@localhost`) |
| noVNC | http://localhost:6080/vnc.html |
| Native VNC | `localhost:5902` (host port → container 5900), x11vnc `-forever -shared` (multi-client: the agent captures while a human watches) |
| Desktop | **Cinnamon 6.4 on X11**: Xvfb `:1` (1920×1080×24), session bus at `/run/user/1000/bus` |
| Container | `ubuntu-desktop-cinnamon:26.04`, service `ubuntu-desktop`, arm64 native on Apple Silicon (QEMU-emulated elsewhere) |

## Toolchain (where things live in the box)

- **Rust**: rustup at `/usr/local/rustup`, cargo at `/usr/local/cargo` (stable, `rustfmt`+`clippy` added). Non-interactive SSH shells do NOT source the profile → prefix every cargo/tauri call with:
  `export CARGO_HOME=/usr/local/cargo RUSTUP_HOME=/usr/local/rustup PATH=/usr/local/cargo/bin:$PATH`
- **Node 24 LTS** + **pnpm** + **yarn** + **`@tauri-apps/cli`** (global, latest) + `create-tauri-app` in `/usr/local/bin`.
- **WebKitGTK 4.1 / GTK3** dev headers, OpenSSL, libsoup-3, librsvg, libayatana-appindicator, libxdo — the full Tauri v2 Linux dependency set.
- Host is `aarch64` → builds are `aarch64-unknown-linux-gnu` by default (no `--target` needed).

## Session environment

`dev <cmd>` (in `/usr/local/bin/dev`) is the GUI launcher: it sources
`/run/user/1000/desktop-env` which exports `XDG_RUNTIME_DIR`,
`DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`, `DISPLAY=:1`,
`XAUTHORITY`, `XDG_SESSION_TYPE=x11`, `XDG_CURRENT_DESKTOP=Cinnamon`,
`RESOLUTION`, `VNC_PORT`, `VNC_PASSWORD`. **Everything graphical must go
through it** — a bare `DISPLAY=:1` launch from a non-session shell lacks
`XAUTHORITY`/DBUS and shows nothing.

Examples:

```bash
ssh ubuntu-arm 'dev /workspace/<app>/src-tauri/target/debug/<binary>'   # run app
ssh ubuntu-arm 'cd /workspace/<app> && dev pnpm tauri dev'              # hot reload
```

## `assistant` CLI (AI control — real X11 capture + real input)

| Subcommand | What it does |
|---|---|
| `assistant status` | X session + tools status, DISPLAY, captura/ocr/input availability |
| `assistant shot [out.png]` | Real screenshot (ImageMagick `import` on X11) — default `/workspace/ai/screen.png` |
| `assistant region X Y W H [out]` | Region capture |
| `assistant ocr [png]` | tesseract OCR (spa+eng) of a capture |
| `assistant open <app>` / `run <cmd...>` | Launch an app / run a command inside the GUI session (`dev`) |
| `assistant type "text"` | Type text (xdotool) |
| `assistant key ctrl+c\|super\|...` | Key combo: `ctrl+c/v/a/s/w`, `alt+tab`, `super`, `enter|return`, `tab`, `space`, `esc|escape` |
| `assistant click X Y` / `rclick X Y` | Left/right click at pixel (X,Y) of the 1920×1080 capture |
| `assistant move X Y` / `drag DX DY` | Move pointer / drag (selection, not window-moving) |
| `assistant windows` | List windows (active marked `*`) — id, name, position, size |
| `assistant winmove X Y [wid]` | Move a window reliably via the WM |
| `assistant record [secs] [out.webm]` | Record desktop video (ffmpeg x11grab) |
| `assistant files [subdir]` | List `/workspace` (shared host↔box bind mount) |
| `assistant here <path> [name]` | Copy a box file to `/workspace/ai/` for the host |
| `assistant wd run --app <cmd> --shot out.png ...` | **WayDriver**: isolated Mutter session, real PNG, AT-SPI (`--click`, `--click-text`, `--read` xpath, `--set-text`, `--press`, `--xml`, `--sleep`) |

Invocation from here: `ssh ubuntu-arm 'assistant shot /workspace/ai/s.png'`. The box repo also
exposes `make assistant ARGS="shot"` etc. from its own checkout. Screenshots written under
`/workspace/ai/` appear immediately on the host via the bind mount (and are fetchable with
`scp -P 2222 admin@localhost:/workspace/ai/<file> .`).

**MCP server (optional)**: the box repo ships `scripts/mcp-assistant.py` (stdlib MCP over
stdio, 2024-11-05) exposing every `assistant` subcommand as a tool. Register on the host with
`"mcpServers": {"assistant": {"command": "ssh", "args": ["-p", "2222", "admin@localhost",
"/usr/local/bin/mcp-assistant.py"]}}`.

## Build facts

- The project on the box is a **build target, not a repo**: sources are rsynced (no `.git`),
  `node_modules/` + `target/` persist. `.deb` landing zone: `src-tauri/target/<profile>/bundle/deb/`.
- `pnpm install --frozen-lockfile` is authoritative and idempotent.
- Why the `dev` wrapper is required for launching: non-session shells lack the session env.
- The box watchdog (`session.sh`) restarts Xvfb/Cinnamon/x11vnc up to 20 times and logs to
  `/run/user/1000/session.log` (`make logs-x11vnc` in the box repo tails it).

## Troubleshooting quick map

| Symptom | Move |
|---|---|
| SSH "REMOTE HOST IDENTIFICATION HAS CHANGED" | Container recreated → local box: `ssh-keygen -R "[127.0.0.1]:2222"`, retry (box is the user's own; confirm if remote) |
| SSH "Permission denied" | Key revoked (volume reset) → `sshpass -p admin ssh-copy-id ubuntu-arm` (or password auth) |
| Box down | `make install` / `make up` in the box repo — never start Docker from this repo |
| App launched but invisible | `assistant status` → X session OK? → `assistant windows` → `/tmp/<binary>.log` |
| `assistant shot` empty | Wait 2–4 s, re-shoot; llvmpipe paints lazily. OCR twice before concluding |
| Port `:1420` busy for `--dev` | Kill the remote Vite via `make linux-stop`, or use the standalone binary instead |