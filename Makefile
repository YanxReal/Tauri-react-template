# Tauri React Template — desarrollo multi-plataforma
# La CLI parcheada para iOS vive en src-tauri/vendor/tauri-cli-2.11.4
# y usa el cargo-mobile2 vendoreado con el fix de Xcode 26 (reality != simulated).
# Ver src-tauri/vendor/tauri-cli-2.11.4/Cargo.toml [patch.crates-io].

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

.PHONY: dev dev\:web dev\:ios dev-ios-physical dev-android-emulator install-tauri-cli lint build

dev:
	$(EXPORT_APPLE_SIGNING_IDENTITY) $(TAURI) dev

dev\:web:
	pnpm --filter web dev

# iOS simulador — usa el target correcto (aarch64-apple-ios-sim) y simctl.
# Sin hardcodear UDID: el selector ahora distingue simulador vs físico
# gracias al parche cargo-mobile2 (reality != simulated). Si eliges un
# simulador, el build es -sdk iphonesimulator + simctl install/launch;
# si eliges un físico, es -sdk iphoneos + devicectl.
dev\:ios:
	pnpm tauri ios dev "$(IOS_DEVICE)"

# iOS físico — requiere la CLI parcheada (make install-tauri-cli) y que el
# iPhone esté conectado por USB. El devUrl se anuncia en la IP link-local.
dev-ios-physical:
	@test -n "$(IOS_DEV_HOST)" || { echo "No hay IP link-local 169.254.x.x — ¿iPhone conectado por USB?"; exit 1; }
	$(CARGO_TAURI) ios dev "$(IOS_DEVICE)" --host $(IOS_DEV_HOST)

install-tauri-cli:
	@echo "Construyendo cargo-tauri parcheado (Xcode 26 fix) ..."
	cd src-tauri/vendor/tauri-cli-2.11.4 && CARGO_TARGET_DIR=$(CURDIR)/src-tauri/target/tauri-cli cargo build --release
	install -m 755 src-tauri/target/tauri-cli/release/cargo-tauri ~/.cargo/bin/cargo-tauri
	@echo "Instalado ~/.cargo/bin/cargo-tauri — usa 'cargo tauri ios dev' para iOS físico"

lint:
	pnpm lint

build:
	pnpm build
