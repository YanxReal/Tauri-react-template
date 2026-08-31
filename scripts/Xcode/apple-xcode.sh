#!/usr/bin/env bash
# Regenera src-tauri/gen/apple (Xcode project unificado iOS+macOS) desde el
# template durable en src-tauri/vendor/tauri-cli-2.11.4/templates/mobile/ios/.
# gen/ está gitignored — el template es la fuente de verdad: editar SIEMPRE
# el template, NUNCA el .xcodeproj generado (no persiste).
#
# Uso:
#   scripts/Xcode/apple-xcode.sh            # regenera gen/apple con xcodegen
#   scripts/Xcode/apple-xcode.sh --build    # además compila iOS simulator (vía CLI, que
#                                   # es el padre del xcode-script) y macOS host
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TPL="$ROOT/src-tauri/vendor/tauri-cli-2.11.4/templates/mobile/ios"
GEN="$ROOT/src-tauri/gen/apple"
XCODEGEN="${XCODEGEN:-xcodegen}"
TAURI_CLI="${TAURI_CLI:-@tauri-apps/cli@2.11.4}"

if [ ! -d "$TPL" ]; then
  echo "Template no encontrado: $TPL" >&2
  exit 1
fi

rm -rf "$GEN"
mkdir -p "$GEN"
cp -R "$TPL/." "$GEN/"

# Auto-inyección del DEVELOPMENT_TEAM (nunca hardcodeado en el template).
# Prioridad: env DEVELOPMENT_TEAM → scripts/.team-id → omitir la línea
# (el team se elige a mano en Xcode → Signing & Capabilities).
TEAM="${DEVELOPMENT_TEAM:-}"
if [ -z "$TEAM" ] && [ -f "$ROOT/scripts/.team-id" ]; then
  TEAM="$(tr -d '[:space:]' < "$ROOT/scripts/.team-id")"
fi
if [ -n "$TEAM" ]; then
  sed -i '' "s/__TAURI_DEVELOPMENT_TEAM__/$TEAM/g" "$GEN/project.yml"
  echo "→ DEVELOPMENT_TEAM=$TEAM (inyectado)"
else
  sed -i '' '/__TAURI_DEVELOPMENT_TEAM__/d' "$GEN/project.yml"
  echo "→ sin DEVELOPMENT_TEAM (elígelo en Xcode → Signing & Capabilities)"
fi

(cd "$GEN" && "$XCODEGEN" generate)

# Shim para el CLI stock (`tauri ios dev|build`): cargo-mobile2 lee
# gen/apple/<app>_iOS/Info.plist. Copia del plist generado por XcodeGen para
# el target `_Apple` (misma info: propiedades del bloque `info` de project.yml).
mkdir -p "$GEN/tauri-react-template_iOS"
cp -f "$GEN/tauri-react-template_Apple/Info.plist" \
  "$GEN/tauri-react-template_iOS/Info.plist"

echo "✓ Xcode project regenerado (iOS + macOS):"
echo "  $GEN/tauri-react-template.xcodeproj"

if [ "${1:-}" = "--build" ]; then
  echo "→ compilando iOS simulator (vía tauri CLI — el xcode-script necesita al padre)..."
  (cd "$ROOT/src-tauri" && pnpm dlx "$TAURI_CLI" ios build --target aarch64-sim --debug) || exit 1
  echo "✓ iOS simulator OK:"
  echo "  $GEN/build/arm64-sim/tauri-react-template.app"
  echo "→ compilando macOS (My Mac)..."
  xcodebuild -project "$GEN/tauri-react-template.xcodeproj" \
    -scheme tauri-react-template_Apple \
    -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -quiet build || exit 1
  echo "✓ macOS host OK"
fi