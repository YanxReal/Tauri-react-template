# tauri-react-template — generic multi-platform workflow
# Adaptado de Prestly (Tauri v2 + Rust) simplificado para template.
# - Desktop: pnpm dev / tauri dev (sin Xcode ok)
# - macOS con Xcode: Assets.xcassets se compila vía actool en build.rs
# - iOS/Android: requieren Xcode / Android SDK, pero el template compila
#   en desktop sin ellos (build.rs salta actool con warning).
#
# CLI: SIEMPRE el stock vía pnpm dlx (el `cargo tauri` instalado es un build
# modificado de Prestly y genera proyectos Prestly-branded).

TAURI := pnpm dlx @tauri-apps/cli@2.11.4
PNPM := pnpm

# iOS physical: dispositivo y host USB link-local (169.254.x.x como en Prestly)
IOS_DEVICE ?= iPhone
IOS_DEV_HOST ?= $(shell ip=$$(ifconfig en9 2>/dev/null | awk '/inet / && $$2 ~ /^169\.254\./ {print $$2; exit}'); if [ -z "$$ip" ]; then ip=$$(ifconfig 2>/dev/null | awk '/^[a-z0-9]+:/{i=$$1} /inet 169\.254\./{print $$2; exit}'); fi; echo $$ip)

# Android emulator (Gradle 8.14 no corre en JDK 25)
ANDROID_HOME ?= $(shell [ -n "$$ANDROID_HOME" ] && echo "$$ANDROID_HOME" || echo "$(HOME)/Library/Android/sdk")
ANDROID_ADB := $(ANDROID_HOME)/platform-tools/adb
ANDROID_EMULATOR := $(ANDROID_HOME)/emulator/emulator
ANDROID_AVD ?= Resizable_Experimental
ANDROID_TARGET ?= aarch64
ANDROID_APK := src-tauri/gen/android/app/build/outputs/apk/universal/debug/app-universal-debug.apk
JAVA_HOME_ANDROID ?= $(shell \
  d="$(HOME)/Library/Java/JavaVirtualMachines/jbr-21.0.11/Contents/Home"; [ -d "$$d" ] && echo "$$d" && exit 0; \
  for d in "$(HOME)"/Library/Java/JavaVirtualMachines/*21*/Contents/Home "$(HOME)"/Library/Java/JavaVirtualMachines/*17*/Contents/Home; do [ -d "$$d" ] && echo "$$d" && exit 0; done; \
  h=$$(/usr/libexec/java_home -v 21 2>/dev/null); [ -n "$$h" ] && echo "$$h" && exit 0; \
  h=$$(/usr/libexec/java_home -v 17 2>/dev/null); [ -n "$$h" ] && echo "$$h" && exit 0; \
  echo "" )

.PHONY: dev dev\:web dev\:tauri gen-apple dev-ios dev-ios-physical dev-android dev-android-emulator android-emulator-boot android-apk build build-android build-ios lint fmt check icons help

## dev — app completa (vite + tauri, hot reload) — funciona sin Xcode
dev:
	$(TAURI) dev

## dev:web — solo vite en navegador (iteración UI más rápida)
dev\:web:
	$(PNPM) dev

## dev:tauri — binario tauri compilado contra vite dev server
dev\:tauri:
	cd src-tauri && cargo run

Android: regenera gen/apple (iOS+macOS) desde src-tauri/vendor/tauri-cli-2.11.4/templates/mobile/ios/
gen-apple:
	scripts/ios-xcode.sh

## dev-ios — iOS simulator (requiere Xcode; usa el target unificado via scheme `_iOS`)
dev-ios:
	$(TAURI) ios dev

## dev-ios-physical — iPhone físico vía USB (requiere Xcode)
dev-ios-physical:
	@test -n "$(IOS_DEV_HOST)" || { echo "No se encontró IP link-local 169.254.x.x — ¿iPhone conectado por USB?"; exit 1; }
	$(TAURI) ios dev "$(IOS_DEVICE)" --host $(IOS_DEV_HOST)

## dev-android — Android dev (requiere Android Studio + SDK)
dev-android:
	$(TAURI) android dev

## dev-android-emulator — compila APK debug, instala y lanza en emulador
dev-android-emulator: android-emulator-boot android-apk
	@echo "Instalando $(ANDROID_APK) ..."
	$(ANDROID_ADB) install -r $(ANDROID_APK)
	$(ANDROID_ADB) shell am start -n com.tauri-react-template.app/.MainActivity
	@echo "Lanzado en $(ANDROID_AVD)."

android-emulator-boot:
	@test -x $(ANDROID_EMULATOR) || { echo "Emulador no encontrado en $(ANDROID_EMULATOR) — define ANDROID_HOME."; exit 1; }
	@$(ANDROID_EMULATOR) -list-avds | grep -qx '$(ANDROID_AVD)' || { echo "AVD '$(ANDROID_AVD)' no encontrado. Disponibles:"; $(ANDROID_EMULATOR) -list-avds; exit 1; }
	@if $(ANDROID_ADB) devices | awk 'NR>1 && $$2=="device"' | grep -q .; then \
	  echo "Dispositivo Android ya conectado — skip boot."; \
	else \
	  echo "Booteando emulador '$(ANDROID_AVD)' ..."; \
	  nohup $(ANDROID_EMULATOR) -avd $(ANDROID_AVD) -no-boot-anim -no-snapshot-save > /tmp/tauri-android.log 2>&1 & \
	  $(ANDROID_ADB) wait-for-device; \
	  i=0; until [ "$$($(ANDROID_ADB) shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do \
	    i=$$((i+1)); [ $$i -gt 120 ] && { echo "Timeout boot — ver /tmp/tauri-android.log"; exit 1; }; sleep 2; \
	  done; \
	  echo "Emulador booted."; \
	fi

android-apk:
	@test -n "$(JAVA_HOME_ANDROID)" || { echo "JDK 17/21 no encontrado (Gradle no corre en JDK 25). Define JAVA_HOME_ANDROID."; exit 1; }
	cd src-tauri && JAVA_HOME="$(JAVA_HOME_ANDROID)" $(TAURI) android build --debug --target $(ANDROID_TARGET)

## build — bundle producción (vite + tauri) — sin Xcode usa icon.icns, con Xcode usa Assets.xcassets
build:
	$(TAURI) build

build-android:
	cd src-tauri && $(TAURI) android build

build-ios:
	$(TAURI) ios build --target aarch64-sim --debug

## lint — typecheck + clippy
lint:
	$(PNPM) typecheck
	$(PNPM) lint
	cd src-tauri && cargo clippy --all-targets -- -D warnings

## fmt — formato Rust
fmt:
	cd src-tauri && cargo fmt

## check — check rápido Rust
check:
	cd src-tauri && cargo check

## icons — regenera icons desde app-icon.png
icons:
	$(TAURI) icon

help:
	@echo "Targets: dev dev:web dev:tauri gen-apple dev-ios dev-ios-physical dev-android dev-android-emulator build build-android build-ios lint fmt check icons"
