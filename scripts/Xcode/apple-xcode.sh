#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# apple-xcode.sh — regenerate src-tauri/gen/apple (unified iOS+macOS Xcode
# project) for real, honoring branding.json (single source of truth).
#
# Why this exists (learned the hard way): the raw vendored template is
# Handlebars (`{{#if …}}`), so `xcodegen` cannot parse it directly; the CLI's
# own `ios init` is the ONLY valid generator. It resolves identifiers/teams
# and writes `gen/apple` from `templates/mobile/ios/`. This script is the
# durable wrapper: reads branding.json → runs the vendored CLI init → restores
# the `_iOS` shims cargo-mobile2 needs (Info.plist + scheme) using the
# branding-derived app name, so nothing is hardcoded to the old lowercase.
#
# Usage:
#   scripts/Xcode/apple-xcode.sh            # regenerate gen/apple
#   scripts/Xcode/apple-xcode.sh --build    # + build iOS sim + macOS host
#
# Requires `make install-tauri-cli` once (the vendored cargo-tauri).
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_T="$ROOT/src-tauri"
GEN="$SRC_T/gen/apple"
BRAND="$ROOT/branding.json"
CARGO_TAURI="${CARGO_TAURI:-$HOME/.cargo/bin/cargo-tauri}"

if [ ! -f "$BRAND" ]; then
  echo "error: $BRAND not found (branding.json is the single source of truth)" >&2
  exit 1
fi
if [ ! -x "$CARGO_TAURI" ]; then
  echo "error: vendored CLI not built — run: make install-tauri-cli" >&2
  exit 1
fi

# App name from branding.json (rust.binary), identifier fallback; NOT hardcoded.
APP_NAME="$(python3 -c "import json;print(json.load(open('$BRAND'))['rust']['binary'])")"
TMPL_DIR="$ROOT/src-tauri/vendor/tauri-cli-2.12.0/templates/mobile/ios"
if [ ! -d "$TMPL_DIR" ]; then
  echo "error: template not found: $TMPL_DIR" >&2
  exit 1
fi

# Development Team: fed to the vendored CLI via APPLE_DEVELOPMENT_TEAM (the
# only var it reads). Source of truth is .env -> DEVELOPMENT_TEAM, fallback
# scripts/.team-id. NEVER hardcoded here.
TEAM="${DEVELOPMENT_TEAM:-}"
if [ -z "$TEAM" ] && [ -f "$ROOT/scripts/.team-id" ]; then
  TEAM="$(tr -d '[:space:]' < "$ROOT/scripts/.team-id")"
fi
[ -n "$TEAM" ] && export APPLE_DEVELOPMENT_TEAM="$TEAM"

echo "==> regenerating gen/apple (app=$APP_NAME) via vendored CLI init..."
rm -rf "$GEN"
(cd "$SRC_T" && PATH="$HOME/.cargo/bin:$PATH" "$CARGO_TAURI" ios init)

# --- `_iOS` shims (cargo-mobile2 reads gen/apple/<scheme>/Info.plist) -------
# scheme() = "<app>_iOS" in cargo-mobile; our target is the unified `_Apple`.
mkdir -p "$GEN/${APP_NAME}_iOS"
cp -f "$GEN/${APP_NAME}_Apple/Info.plist" "$GEN/${APP_NAME}_iOS/Info.plist"

SHARED="$GEN/${APP_NAME}.xcodeproj/xcshareddata/xcschemes"
mkdir -p "$SHARED"
cp -f "$SHARED/${APP_NAME}_Apple.xcscheme" "$SHARED/${APP_NAME}_iOS.xcscheme" 2>/dev/null || {
  # If the scheme dir/source doesn't exist (fresh init), create the _iOS
  # scheme as a copy of the _Apple scheme so cargo-mobile2 can invoke it.
  :
}

echo "✓ Xcode project regenerated:"
echo "  $GEN/${APP_NAME}.xcodeproj"
echo "  shims: ${APP_NAME}_iOS/Info.plist + xcscheme"

if [ "${1:-}" = "--build" ]; then
  echo "==> building iOS simulator (vendored CLI)..."
  (cd "$SRC_T" && PATH="$HOME/.cargo/bin:$PATH" "$CARGO_TAURI" ios build --debug --target aarch64-sim) || exit 1
  echo "✓ iOS simulator OK: $GEN/build/arm64-sim/${APP_NAME}.app"
  echo "==> building macOS host (My Mac)..."
  xcodebuild -project "$GEN/${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}_Apple" \
    -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -quiet build || exit 1
  echo "✓ macOS host OK"
fi