#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# android-autogen.sh — regenerate src-tauri/gen/android (Android Studio project
# + MainActivity) honoring branding.json. Mirror of scripts/Xcode/apple-xcode.sh
# for the Apple target.
#
# Why: gen/android is autogen (gitignored) — the CLI's `android init` is the
# ONLY valid generator (it resolves identifiers/teams and writes the project
# from the vendored template, including the MOD-4 status-bar MainActivity and
# the 16 KB page-alignment). This wrapper reads branding.json, locates the
# Android toolchain on ANY host (macOS / Linux / Windows-Git-Bash), runs the
# vendored CLI init, and verifies the result.
#
# Usage:
#   scripts/Android/android-autogen.sh            # regenerate gen/android
#   scripts/Android/android-autogen.sh --build    # + build debug APK (aarch64)
#
# Requires `make install-tauri-cli` once (the vendored cargo-tauri) + Android
# SDK/NDK/JDK (see .env.example and docs). Windows: run via Git Bash.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_T="$ROOT/src-tauri"
GEN="$SRC_T/gen/android"
BRAND="$ROOT/branding.json"
CARGO_TAURI="${CARGO_TAURI:-$HOME/.cargo/bin/cargo-tauri}"
BUILD=0
[[ "${1:-}" == "--build" ]] && BUILD=1

if [ ! -f "$BRAND" ]; then
  echo "error: $BRAND not found (branding.json is the single source of truth)" >&2
  exit 1
fi
if [ ! -x "$CARGO_TAURI" ]; then
  echo "error: vendored CLI not built — run: make install-tauri-cli" >&2
  exit 1
fi

APP_NAME="$(python3 -c "import json;print(json.load(open('$BRAND'))['rust']['binary'])")"
PKG_NAME="$(python3 -c "import json;print(json.load(open('$BRAND'))['tauri']['identifier'])")"

# --- OS detection (Git Bash on Windows reports MINGW*/MSYS*) -----------------
OST="$(uname -s 2>/dev/null || echo unknown)"
case "$OST" in
  Linux)      HOST_OS="linux" ;;
  Darwin)     HOST_OS="macos" ;;
  MINGW*|MSYS*|CYGWIN*) HOST_OS="windows" ;;
  *) HOST_OS="unknown" ;;
esac

# --- Java: JAVA_HOME > Android Studio JBR (common paths per OS) --------------
if [ -z "${JAVA_HOME:-}" ]; then
  case "$HOST_OS" in
    macos)   [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ] \
               && export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ;;
    linux)   for j in /usr/lib/jvm/java-21-openjdk-arm64 /usr/lib/jvm/java-17-openjdk-amd64 /usr/lib/jvm/java-17-openjdk-arm64; do
               [ -d "$j" ] && { export JAVA_HOME="$j"; break; }
             done ;;
    windows) [ -d "/c/Program Files/Android/Android Studio/jbr" ] \
               && export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr" ;;
  esac
fi
if [ -z "${JAVA_HOME:-}" ] || [ ! -x "$JAVA_HOME/bin/java" ]; then
  echo "error: no JDK found — set JAVA_HOME (see .env.example) or install Android Studio" >&2
  exit 1
fi

# --- Android SDK: ANDROID_HOME > per-OS defaults ------------------------------
if [ -z "${ANDROID_HOME:-}" ]; then
  case "$HOST_OS" in
    macos)   [ -d "$HOME/Library/Android/sdk" ] && export ANDROID_HOME="$HOME/Library/Android/sdk" ;;
    linux)   [ -d "$HOME/Android/Sdk" ] && export ANDROID_HOME="$HOME/Android/Sdk" ;;
    windows) [ -d "/c/Users/$USER/AppData/Local/Android/Sdk" ] \
               && export ANDROID_HOME="/c/Users/$USER/AppData/Local/Android/Sdk" ;;
  esac
fi
if [ -z "${ANDROID_HOME:-}" ] || [ ! -d "$ANDROID_HOME" ]; then
  echo "error: no Android SDK — set ANDROID_HOME (see .env.example)" >&2
  exit 1
fi

# --- NDK (must exist; any side-by-side version works) -------------------------
if [ -z "${NDK_HOME:-}" ]; then
  NDKS="$(ls -1 "$ANDROID_HOME"/ndk 2>/dev/null | head -1 || true)"
  [ -n "$NDKS" ] && export NDK_HOME="$ANDROID_HOME/ndk/$NDKS"
fi
if [ -z "${NDK_HOME:-}" ] || [ ! -d "$NDK_HOME" ]; then
  echo "error: no NDK under $ANDROID_HOME/ndk — install via sdkmanager (see docs)" >&2
  exit 1
fi

echo "==> android autogen: app=$APP_NAME pkg=$PKG_NAME host=$HOST_OS"
echo "    JAVA_HOME=$JAVA_HOME"
echo "    ANDROID_HOME=$ANDROID_HOME"
echo "    NDK_HOME=$NDK_HOME"

echo "==> regenerating gen/android via vendored CLI init..."
rm -rf "$GEN"
(cd "$SRC_T" && PATH="$HOME/.cargo/bin:$PATH" "$CARGO_TAURI" android init)

# --- Verify MOD-4 (status-bar MainActivity) survived the init ----------------
# Package dir = identifier with hyphens -> underscores (Android norm).
MAIN_PATH="$(echo "$PKG_NAME" | tr '-' '_' | sed 's/\./\//g')"
MAIN_ACT="$GEN/app/src/main/java/$MAIN_PATH/MainActivity.kt"
if [ -f "$MAIN_ACT" ] && grep -q "setStatusBarDark" "$MAIN_ACT"; then
  echo "✓ MOD-4 status-bar MainActivity present"
else
  echo "warn: MainActivity missing or without the status-bar fix — check the vendored template" >&2
fi

echo "✓ Android project regenerated:"
echo "  $GEN"

if [ "$BUILD" = "1" ]; then
  echo "==> building debug APK (aarch64)..."
  (cd "$SRC_T" && PATH="$HOME/.cargo/bin:$PATH" "$CARGO_TAURI" android build --debug --target aarch64) || exit 1
  echo "✓ APK: $GEN/app/build/outputs/apk/universal/debug/app-universal-debug.apk"
fi