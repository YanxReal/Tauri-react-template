#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# mobile-icons-regen.sh — regenerate EVERY app icon from the branding master.
#
# Post-init step for apple-xcode.sh and android-autogen.sh (never edit
# gen/ by hand). It runs the vendored CLI `tauri icon` with the master that
# branding.json icons.master points to, which writes:
#   - src-tauri/icons/*        (desktop: png/icns/ico — canonical, committed)
#   - gen/apple/Assets.xcassets/AppIcon.appiconset  (iOS, up to 512@2x)
#   - gen/android/app/src/main/res/*                (launcher mipmaps)
# then composes the iOS 1024 marketing trio (AppIcon-1024*{, -dark, -tinted})
# which THIS CLI version does not generate — those stay template placeholders
# otherwise. The vendored mobile templates ship neutral color placeholders so
# a fresh init never carries a wrong brand.
#
# macOS-only (swift compositor). Requires the vendored cargo-tauri
# ($CARGO_TAURI or ~/.cargo/bin/cargo-tauri) and a 1024×1024 master.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MASTER="$(python3 -c "import json;print(json.load(open('$ROOT/branding.json'))['icons']['master'])")"
MASTER="$ROOT/$MASTER"
[ -f "$MASTER" ] || { echo "error: icon master missing: $MASTER (branding.json icons.master)" >&2; exit 1; }

CARGO_TAURI="${CARGO_TAURI:-$HOME/.cargo/bin/cargo-tauri}"
[ -x "$CARGO_TAURI" ] || { echo "error: vendored CLI not built — run: make install-tauri-cli" >&2; exit 1; }

# rustup's cargo for any CLI subcommand that touches cargo; harmless here.
RUSTUP_CARGO_BIN=""
if [ -x "$HOME/.cargo/bin/cargo" ]; then
  RUSTUP_CARGO_BIN="$HOME/.cargo/bin"
elif [ -x "/opt/homebrew/opt/rustup/bin/cargo" ]; then
  RUSTUP_CARGO_BIN="/opt/homebrew/opt/rustup/bin"
fi

echo "==> regenerating icons from master: $MASTER"
PATH="$RUSTUP_CARGO_BIN:$HOME/.cargo/bin:$PATH" "$CARGO_TAURI" icon "$MASTER"

# iOS AppIcon-1024 trio: the vendored CLI only generates up to AppIcon-512@2x.
IOSET="$ROOT/src-tauri/gen/apple/Assets.xcassets/AppIcon.appiconset"
if [ -d "$IOSET" ]; then
  echo "==> composing iOS 1024 marketing icons (light/dark/tinted)"
  swift "$ROOT/scripts/mobile/icon-composite.swift" "$MASTER" "$IOSET/AppIcon-1024.png" bg FFFFFF
  swift "$ROOT/scripts/mobile/icon-composite.swift" "$MASTER" "$IOSET/AppIcon-1024-dark.png" bg 1C1C1E
  swift "$ROOT/scripts/mobile/icon-composite.swift" "$MASTER" "$IOSET/AppIcon-1024-tinted.png" silhouette
fi
echo "✓ icons regenerated (desktop + mobile)"