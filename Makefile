# Tauri React Template — desarrollo multi-plataforma
# La CLI para iOS es la oficial tauri-cli 2.12.0 (trae cargo-mobile2 0.22.5 con
# el fix de Xcode 27). El vendor solo conserva los templates customizados +
# 3 retoques locales (fallback standalone + target _Apple); ver
# src-tauri/vendor/tauri-cli-2.12.0/templates/mobile/ios/project.yml.

TAURI := pnpm tauri
CARGO_TAURI := cargo tauri

# Identidad de firma macOS estable (opcional, evita prompts de Keychain)
MACOS_SIGNING_IDENTITY := $(shell cat src-tauri/keys/macos-signing-identity.txt 2>/dev/null)
ifneq ($(strip $(MACOS_SIGNING_IDENTITY)),)
    EXPORT_APPLE_SIGNING_IDENTITY := APPLE_SIGNING_IDENTITY="$(MACOS_SIGNING_IDENTITY)"
endif

# iOS — IP link-local del Mac en la red USB (lo que el iPhone puede alcanzar)
IOS_DEVICE ?= iPhone 17
IOS_DEV_HOST ?= $(shell ip=$$(ifconfig en9 2>/dev/null | awk '/inet / && $$2 ~ /^169\.254\./ {print $$2; exit}'); if [ -z "$$ip" ]; then ip=$$(ifconfig 2>/dev/null | awk '/^[a-z0-9]+:/{i=$$1} /inet 169\.254\./{print $$2; exit}'); fi; echo $$ip)
ANDROID_AVD ?= Resizable_Experimental
ANDROID_TARGET ?= aarch64
ANDROID_HOME ?= $(HOME)/Library/Android/sdk
export PATH := $(ANDROID_HOME)/emulator:$(ANDROID_HOME)/platform-tools:$(PATH)

.PHONY: dev dev\:web dev\:ios dev-ios-physical dev-android-emulator gen-apple install-tauri-cli lint build

dev:
	$(EXPORT_APPLE_SIGNING_IDENTITY) $(TAURI) dev

dev\:web:
	pnpm --filter web dev

# iOS simulador — usa el target correcto (aarch64-apple-ios-sim) y simctl.
# El selector distingue simulador vs físico gracias a cargo-mobile2 0.22.5
# (filtro visibility_class). Si eliges un simulador, el build es
# -sdk iphonesimulator + simctl install/launch; si eliges un físico, es
# -sdk iphoneos + devicectl.
dev\:ios:
	pnpm tauri ios dev "$(IOS_DEVICE)"

# iOS físico — requiere el cargo-tauri local (make install-tauri-cli, con los
# retoques del vendor) y que el iPhone esté conectado por USB. El devUrl se
# anuncia en la IP link-local.
dev-ios-physical:
	@test -n "$(IOS_DEV_HOST)" || { echo "No hay IP link-local 169.254.x.x — ¿iPhone conectado por USB?"; exit 1; }
	$(CARGO_TAURI) ios dev "$(IOS_DEVICE)" --host $(IOS_DEV_HOST)

# Android emulator — arranca el AVD y corre `tauri android dev` contra él.
# Requiere Android SDK (cmdline-tools + emulator + una system-image arm64).
dev-android-emulator:
	@$(ANDROID_HOME)/emulator/emulator -list-avds 2>/dev/null | grep -qx "$(ANDROID_AVD)" || { echo "No existe el AVD '$(ANDROID_AVD)' — créalo en Android Studio → Device Manager"; exit 1; }
	$(ANDROID_HOME)/emulator/emulator -avd "$(ANDROID_AVD)" -no-snapshot -no-boot-anim >/tmp/android-emulator.log 2>&1 &
	$(ANDROID_HOME)/platform-tools/adb wait-for-device
	pnpm tauri android dev --target "$(ANDROID_TARGET)"

# Xcode — regenera src-tauri/gen/apple desde el template (xcodegen).
gen-apple:
	scripts/Xcode/apple-xcode.sh

install-tauri-cli:
	@echo "Construyendo cargo-tauri 2.12.0 + retoques locales (fallback standalone, target _Apple) ..."
	cd src-tauri/vendor/tauri-cli-2.12.0 && CARGO_TARGET_DIR=$(CURDIR)/src-tauri/target/tauri-cli cargo build --release
	mkdir -p ~/.cargo/bin
	install -m 755 src-tauri/target/tauri-cli/release/cargo-tauri ~/.cargo/bin/cargo-tauri
	@echo "Instalado ~/.cargo/bin/cargo-tauri — usa 'cargo tauri ios dev' para iOS físico"

lint:
	pnpm lint

build:
	pnpm build
