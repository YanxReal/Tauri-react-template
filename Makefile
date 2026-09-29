# Tauri React Template — multi-platform development
# iOS CLI is the official tauri-cli 2.12.0 (ships cargo-mobile2 0.22.5 with
# the Xcode 27 fix). The vendor keeps only the customized templates +
# 3 local tweaks (standalone fallback + _Apple target); see
# src-tauri/vendor/tauri-cli-2.12.0/templates/mobile/ios/project.yml.

# Personal env (.env is gitignored): DEVELOPMENT_TEAM (iOS signing),
# ANDROID_HOME/NDK_HOME (if custom), app vars. Loaded into make AND
# exported to recipe shells, so `make dev-ios-physical` etc. see them
# automatically. Never commit .env.
ifneq (,$(wildcard .env))
include .env
export
endif

# The vendored CLI reads APPLE_DEVELOPMENT_TEAM; .env carries DEVELOPMENT_TEAM
# (our canonical name). Fallback when .env is absent: scripts/.team-id
# (gitignored, one Team ID per line). Translate automatically for every target.
APPLE_DEVELOPMENT_TEAM ?= $(if $(strip $(DEVELOPMENT_TEAM)),$(strip $(DEVELOPMENT_TEAM)),$(shell cat scripts/.team-id 2>/dev/null))
export APPLE_DEVELOPMENT_TEAM

TAURI := pnpm tauri
CARGO_TAURI := cargo tauri

# rustup's cargo/rustc are REQUIRED for iOS/Android cross builds (Homebrew's
# cargo lacks the target std, and rust-toolchain.toml is only honoured by
# rustup). Prepend the rustup bin dir so every recipe's bare `cargo`/`rustc`
# resolve through rustup; the phase scripts add the same guard internally.
RUSTUP_BIN := $(if $(wildcard $(HOME)/.cargo/bin/cargo),$(HOME)/.cargo/bin,$(if $(wildcard /opt/homebrew/opt/rustup/bin/cargo),/opt/homebrew/opt/rustup/bin,))
ifneq ($(strip $(RUSTUP_BIN)),)
export PATH := $(RUSTUP_BIN):$(PATH)
endif

# Stable macOS signing identity (optional, avoids Keychain prompts)
MACOS_SIGNING_IDENTITY := $(shell cat src-tauri/keys/macos-signing-identity.txt 2>/dev/null)
ifneq ($(strip $(MACOS_SIGNING_IDENTITY)),)
    EXPORT_APPLE_SIGNING_IDENTITY := APPLE_SIGNING_IDENTITY="$(MACOS_SIGNING_IDENTITY)"
endif

# iOS — Mac link-local IP on the USB network (what the iPhone can reach)
IOS_DEVICE ?= iPhone 18 Pro
IOS_DEV_HOST ?= $(shell ip=$$(ifconfig en9 2>/dev/null | awk '/inet / && $$2 ~ /^169\.254\./ {print $$2; exit}'); if [ -z "$$ip" ]; then ip=$$(ifconfig 2>/dev/null | awk '/^[a-z0-9]+:/{i=$$1} /inet 169\.254\./{print $$2; exit}'); fi; echo $$ip)
ANDROID_AVD ?= Resizable_Experimental
ANDROID_TARGET ?= aarch64
ANDROID_HOME ?= $(HOME)/Library/Android/sdk
export PATH := $(ANDROID_HOME)/emulator:$(ANDROID_HOME)/platform-tools:$(PATH)

# Linux — Ubuntu-arm-docker box (separate repo, Cinnamon/X11), via the
# linux-build skill's script (SSH-only; see .claude/skills/linux-build).
# Checkout dir uses capital T; the binary follows Cargo.toml [package] name.
LINUX_REMOTE ?= ubuntu-arm
LINUX_DIR ?= /workspace/Tauri-react-template
SKILL_LINUX ?= .claude/skills/linux-build/scripts/linux-build.sh

.DEFAULT_GOAL := help

.PHONY: help doctor dev dev\:web dev\:ios dev-ios-physical dev-android-emulator build-linux linux-release build-windows dev-linux linux-logs linux-stop gen-apple gen-android install-tauri-cli install-skills rebrand lint build ci-frontend ci-rust check-docs

help: ## Show available commands
	@awk -F'##' '/^[a-zA-Z0-9_\\:.-]+:[ \t]*##/ { t=$$1; sub(/:[ \t]*$$/, "", t); gsub(/\\/, "", t); printf "  \033[36m%-22s\033[0m %s\n", t, $$2 }' $(MAKEFILE_LIST)
	@echo ""

doctor: ## Check toolchain (versions or MISSING + scope)
	@command -v node >/dev/null && echo "node:                 $$(node --version)" || echo "node:                 MISSING (required)"
	@command -v pnpm >/dev/null && echo "pnpm:                 $$(pnpm --version)" || echo "pnpm:                 MISSING (required)"
	@command -v cargo >/dev/null && echo "cargo:                $$(cargo --version)" || echo "cargo:                MISSING (required for desktop/mobile builds)"
	@command -v rustc >/dev/null && echo "rustc:               $$(rustc --version | cut -d' ' -f2)" || echo "rustc:                MISSING"
	@XB=$$(xcodebuild -version 2>/dev/null | head -1); [ -n "$$XB" ] && echo "xcodebuild:           $$XB" || echo "xcodebuild:           MISSING (iOS/macOS builds only)"
	@echo "xcodegen:             not needed (gen via vendored CLI init)"
	@if cargo tauri --version >/dev/null 2>&1; then echo "cargo-tauri:          $$(cargo tauri --version 2>/dev/null) (cargo subcommand)"; else echo "cargo-tauri:          MISSING — run: make install-tauri-cli"; fi
	@test -x "$(ANDROID_HOME)/emulator/emulator" && echo "android emulator:    present" || echo "android emulator:    MISSING (Android only)"
	@ssh -o BatchMode=yes -o ConnectTimeout=4 $(LINUX_REMOTE) true 2>/dev/null && echo "linux box ($(LINUX_REMOTE)): reachable" || echo "linux box ($(LINUX_REMOTE)): UNREACHABLE (start Ubuntu-arm-docker)"
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

# Xcode — regenerate src-tauri/gen/apple from the template (vendored CLI init).
gen-apple: ## Regen Xcode project
	scripts/Xcode/apple-xcode.sh

gen-android: ## Regen Android Studio project (android-autogen.sh)
	scripts/Android/android-autogen.sh

# Linux — Ubuntu-arm-docker box over SSH (skill linux-build; SSH-only, never
# clones: rsync without .git, node_modules/target stay cached on the box).
# `build-linux` = fast loop: sync + debug (no bundle) + run + assistant verify.
build-linux: ## Linux fast loop on the box (sync + debug + run + verify)
	LINUX_BUILD_REMOTE="$(LINUX_REMOTE)" LINUX_BUILD_DIR="$(LINUX_DIR)" $(SKILL_LINUX) --remote --debug --run --verify

linux-release: ## Linux release bundle (deb) + fetch to ./dist-linux
	LINUX_BUILD_REMOTE="$(LINUX_REMOTE)" LINUX_BUILD_DIR="$(LINUX_DIR)" $(SKILL_LINUX) --remote --release $(if $(LINUX_BUNDLES),--bundles $(LINUX_BUNDLES),) --fetch

# Windows cross-compile via cargo-xwin (macOS/Linux; native on Windows hosts).
# WINDOWS_BUNDLES overrides --bundles; WINDOWS_EXTRA passes extra tauri args.
build-windows: ## Windows cross-compile (cargo-xwin) — debug
	scripts/build-windows.sh --debug $(if $(WINDOWS_BUNDLES),--bundles $(WINDOWS_BUNDLES),) $(WINDOWS_EXTRA)

dev-linux: ## Linux dev (hot reload on the box)
	LINUX_BUILD_REMOTE="$(LINUX_REMOTE)" LINUX_BUILD_DIR="$(LINUX_DIR)" $(SKILL_LINUX) --remote --dev

linux-logs: ## Follow remote dev/app log
	LINUX_BUILD_REMOTE="$(LINUX_REMOTE)" LINUX_BUILD_DIR="$(LINUX_DIR)" $(SKILL_LINUX) --remote --logs

linux-stop: ## Kill remote dev/app
	LINUX_BUILD_REMOTE="$(LINUX_REMOTE)" LINUX_BUILD_DIR="$(LINUX_DIR)" $(SKILL_LINUX) --remote --stop

install-tauri-cli: ## Build vendor CLI → ~/.cargo/bin/cargo-tauri
	@echo "Building cargo-tauri 2.12.0 + local tweaks (standalone fallback, _Apple target) ..."
	cd src-tauri/vendor/tauri-cli-2.12.0 && CARGO_TARGET_DIR=$(CURDIR)/src-tauri/target/tauri-cli cargo build --release
	mkdir -p ~/.cargo/bin
	install -m 755 src-tauri/target/tauri-cli/release/cargo-tauri ~/.cargo/bin/cargo-tauri
	@echo "Installed ~/.cargo/bin/cargo-tauri — use 'cargo tauri ios dev' for physical iOS"

# Install all Agent Skills shipped with the project (see scripts/install-skills.sh).
install-skills: ## Install all agent skills of the project
	$(if $(SKILLS_GLOBAL),scripts/install-skills.sh --global,scripts/install-skills.sh)

# Rebrand from branding.json (single source of truth) — see that file's _doc.
rebrand: ## Propagate branding.json identity to all consumers
	scripts/branding-update.sh

lint: ## Biome check
	pnpm lint

build: ## Turbo build
	pnpm build

# ---------------------------------------------------------------------------
# CI targets — the ONLY source the weekly workflow calls (see
# .github/workflows/ci.yml). Any new check: add a target here first, then the
# job just invokes it. Mobile + native Tauri builds stay OUT of CI (local/box).
# ---------------------------------------------------------------------------
ci-frontend: ## CI: typecheck + lint + test + build del frontend
	pnpm typecheck && pnpm lint && pnpm test && pnpm build

ci-rust: ## CI: fmt + clippy + tests del backend Rust
	cargo fmt --manifest-path src-tauri/Cargo.toml --check
	cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
	cargo test --manifest-path src-tauri/Cargo.toml

# Maintainability guards (local; kept OUT of the CI spec on purpose).
check-docs: ## Guard: EN/ES parity + AGENTS/docs file:line anchors
	scripts/check-docs-parity.sh
	scripts/check-agents-anchors.sh
