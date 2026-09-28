#!/usr/bin/env bash
# Regenerates src-tauri/gen/apple (unified iOS+macOS Xcode project) from the
# durable template at src-tauri/vendor/tauri-cli-2.12.0/templates/mobile/ios/.
# gen/ is gitignored — the template is the source of truth: ALWAYS edit
# the template, NEVER the generated .xcodeproj (it does not persist).
#
# Usage:
#   scripts/Xcode/apple-xcode.sh            # regenerate gen/apple with xcodegen
#   scripts/Xcode/apple-xcode.sh --build    # also builds iOS simulator (via CLI, the
#                                   # xcode-script's parent) and macOS host
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TPL="$ROOT/src-tauri/vendor/tauri-cli-2.12.0/templates/mobile/ios"
GEN="$ROOT/src-tauri/gen/apple"
XCODEGEN="${XCODEGEN:-xcodegen}"
TAURI_CLI="${TAURI_CLI:-@tauri-apps/cli@2.12.0}"

if [ ! -d "$TPL" ]; then
  echo "Template not found: $TPL" >&2
  exit 1
fi

rm -rf "$GEN"
mkdir -p "$GEN"
cp -R "$TPL/." "$GEN/"

# DEVELOPMENT_TEAM auto-injection (never hardcoded in the template).
# Priority: DEVELOPMENT_TEAM env → scripts/.team-id → drop the line
# (pick the team by hand in Xcode → Signing & Capabilities).
TEAM="${DEVELOPMENT_TEAM:-}"
if [ -z "$TEAM" ] && [ -f "$ROOT/scripts/.team-id" ]; then
  TEAM="$(tr -d '[:space:]' < "$ROOT/scripts/.team-id")"
fi
if [ -n "$TEAM" ]; then
  sed -i '' "s/__TAURI_DEVELOPMENT_TEAM__/$TEAM/g" "$GEN/project.yml"
  echo "→ DEVELOPMENT_TEAM=$TEAM (injected)"
else
  sed -i '' '/__TAURI_DEVELOPMENT_TEAM__/d' "$GEN/project.yml"
  echo "→ no DEVELOPMENT_TEAM (pick it in Xcode → Signing & Capabilities)"
fi

(cd "$GEN" && "$XCODEGEN" generate)

# Shim para el CLI stock (`tauri ios dev|build`): cargo-mobile2 lee
# gen/apple/<app>_iOS/Info.plist. Copia del plist generado por XcodeGen para
# el target `_Apple` (misma info: propiedades del bloque `info` de project.yml).
mkdir -p "$GEN/tauri-react-template_iOS"
cp -f "$GEN/tauri-react-template_Apple/Info.plist" \
  "$GEN/tauri-react-template_iOS/Info.plist"

echo "✓ Xcode project regenerated (iOS + macOS):"
echo "  $GEN/tauri-react-template.xcodeproj"

if [ "${1:-}" = "--build" ]; then
  echo "→ building iOS simulator (via tauri CLI — xcode-script needs its parent)..."
  (cd "$ROOT/src-tauri" && pnpm dlx "$TAURI_CLI" ios build --target aarch64-sim --debug) || exit 1
  echo "✓ iOS simulator OK:"
  echo "  $GEN/build/arm64-sim/tauri-react-template.app"
  echo "→ building macOS (My Mac)..."
  xcodebuild -project "$GEN/tauri-react-template.xcodeproj" \
    -scheme tauri-react-template_Apple \
    -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -quiet build || exit 1
  echo "✓ macOS host OK"
fi