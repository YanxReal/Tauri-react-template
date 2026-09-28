# Tauri React Template — multi-platform development
# iOS CLI is the official tauri-cli 2.12.0 (ships cargo-mobile2 0.22.5 with
# the Xcode 27 fix). The vendor keeps only the customized templates +
# 3 local tweaks (standalone fallback + _Apple target); see
# src-tauri/vendor/tauri-cli-2.12.0/templates/mobile/ios/project.yml.

TAURI := pnpm tauri
CARGO_TAURI := cargo tauri

# Stable macOS signing identity (optional, avoids Keychain prompts)
MACOS_SIGNING_IDENTITY := $(shell cat src-tauri/keys/macos-signing-identity.txt 2>/dev/null)
ifneq ($(strip $(MACOS_SIGNING_IDENTITY)),)
    EXPORT_APPLE_SIGNING_IDENTITY := APPLE_SIGNING_IDENTITY="$(MACOS_SIGNING_IDENTITY)"
endif

# iOS — Mac link-local IP on the USB network (what the iPhone can reach)
IOS_DEVICE ?= iPhone 17
IOS_DEV_HOST ?= $(shell ip=$$(ifconfig en9 2>/dev/null | awk '/inet / && $$2 ~ /^169\.254\./ {print $$2; exit}'); if [ -z "$$ip" ]; then ip=$$(ifconfig 2>/dev/null | awk '/^[a-z0-9]+:/{i=$$1} /inet 169\.254\./{print $$2; exit}'); fi; echo $$ip)
ANDROID_AVD ?= Resizable_Experimental
ANDROID_TARGET ?= aarch64
ANDROID_HOME ?= $(HOME)/Library/Android/sdk
export PATH := $(ANDROID_HOME)/emulator:$(ANDROID_HOME)/platform-tools:$(PATH)

.DEFAULT_GOAL := help

.PHONY: help doctor dev dev\:web dev\:ios dev-ios-physical dev-android-emulator gen-apple install-tauri-cli lint build

help: ## Show available commands
	@awk -F'##' '/^[a-zA-Z0-9_\\:.-]+:[ \t]*##/ { t=$$1; sub(/:[ \t]*$$/, "", t); gsub(/\\/, "", t); printf "  \033[36m%-22s\033[0m %s\n", t, $$2 }' $(MAKEFILE_LIST)
	@echo ""

doctor: ## Check toolchain (versions or MISSING + scope)
	@command -v node >/dev/null && echo "node:                 $$(node --version)" || echo "node:                 MISSING (required)"
	@command -v pnpm >/dev/null && echo "pnpm:                 $$(pnpm --version)" || echo "pnpm:                 MISSING (required)"
	@command -v cargo >/dev/null && echo "cargo:                $$(cargo --version)" || echo "cargo:                MISSING (required for desktop/mobile builds)"
	@command -v rustc >/dev/null && echo "rustc:               $$(rustc --version | cut -d' ' -f2)" || echo "rustc:                MISSING"
	@XB=$$(xcodebuild -version 2>/dev/null | head -1); [ -n "$$XB" ] && echo "xcodebuild:           $$XB" || echo "xcodebuild:           MISSING (iOS/macOS builds only)"
	@command -v xcodegen >/dev/null && echo "xcodegen:             present" || echo "xcodegen:             MISSING (Xcode regen only)"
	@command -v cargo-tauri >/dev/null && echo "cargo-tauri:          $$(cargo-tauri --version 2>/dev/null)" || { test -x ~/.cargo/bin/cargo-tauri && echo "cargo-tauri:          $$(~/.cargo/bin/cargo-tauri --version 2>/dev/null) (not on PATH)" || echo "cargo-tauri:          MISSING (iOS flows: make install-tauri-cli)"; }
	@test -x "$(ANDROID_HOME)/emulator/emulator" && echo "android emulator:    present" || echo "android emulator:    MISSING (Android only)"
	@command -v makensis >/dev/null && echo "makensis:             present" || echo "makensis:             MISSING (Windows NSIS only)"
	@command -v docker >/dev/null && echo "docker:               $$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo unreachable)" || echo "docker:               MISSING (Linux box only)"

dev: ## Tauri dev (desktop)
	$(EXPORT_APPLE_SIGNING_IDENTITY) $(TAURI) dev

dev\:web: ## Vite dev only (:1420)
	pnpm --filter web dev

# iOS simulator — correct target (aarch64-apple-ios-sim) + simctl.
# The selector tells simulator vs physical apart via cargo-mobile2 0.22.5
# (visibility_class filter). Simulators build with -sdk iphonesimulator +
# simctl install/launch; physical devices with -sdk iphoneos + devicectl.
dev\:ios: ## iOS simulator dev
	pnpm tauri ios dev "$(IOS_DEVICE)"

# Physical iOS — needs the local cargo-tauri (make install-tauri-cli, with the
# vendor tweaks) and the iPhone on USB. devUrl is advertised on link-local IP.
dev-ios-physical: ## iOS device dev (USB iPhone)
	@test -n "$(IOS_DEV_HOST)" || { echo "No 169.254.x.x link-local IP — iPhone on USB?"; exit 1; }
	$(CARGO_TAURI) ios dev "$(IOS_DEVICE)" --host $(IOS_DEV_HOST)

# Android emulator — boots the AVD and runs `tauri android dev` against it.
# Needs Android SDK (cmdline-tools + emulator + an arm64 system image).
dev-android-emulator: ## Boot AVD + android dev
	@$(ANDROID_HOME)/emulator/emulator -list-avds 2>/dev/null | grep -qx "$(ANDROID_AVD)" || { echo "No AVD '$(ANDROID_AVD)' — create it in Android Studio → Device Manager"; exit 1; }
	$(ANDROID_HOME)/emulator/emulator -avd "$(ANDROID_AVD)" -no-snapshot -no-boot-anim >/tmp/android-emulator.log 2>&1 &
	$(ANDROID_HOME)/platform-tools/adb wait-for-device
	pnpm tauri android dev --target "$(ANDROID_TARGET)"

# Xcode — regenerate src-tauri/gen/apple from the template (xcodegen).
gen-apple: ## Regen Xcode project
	scripts/Xcode/apple-xcode.sh

install-tauri-cli: ## Build vendor CLI → ~/.cargo/bin/cargo-tauri
	@echo "Building cargo-tauri 2.12.0 + local tweaks (standalone fallback, _Apple target) ..."
	cd src-tauri/vendor/tauri-cli-2.12.0 && CARGO_TARGET_DIR=$(CURDIR)/src-tauri/target/tauri-cli cargo build --release
	mkdir -p ~/.cargo/bin
	install -m 755 src-tauri/target/tauri-cli/release/cargo-tauri ~/.cargo/bin/cargo-tauri
	@echo "Installed ~/.cargo/bin/cargo-tauri — use 'cargo tauri ios dev' for physical iOS"

lint: ## Biome check
	pnpm lint

build: ## Turbo build
	pnpm build
