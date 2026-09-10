# Phase 10C.0 — Root Makefile for the asset_pipeline shard repo.
#
# Targets:
#   test-web       — runs the default web spec lane with plain `crystal`.
#   test-macos     — runs the macOS native spec lane with `acrystal -Dmacos`
#                    + ObjC bridge + AppKit/ApplicationServices framework
#                    link flags. Requires the macOS SwiftKit static lib
#                    (built via `swift build -c release`).
#   test-ios       — cross-compiles the HIG host bridge for the iOS simulator,
#                    generates its Xcode project and runs the behavior UI tests
#                    on one simulator (scripts/test_ios_host.sh). Needs Xcode,
#                    xcodegen and jq; builds the C deps when missing.
#   test-android   — real native build, device tests and isolated failure checks.
#                    Requires an explicit ANDROID_SERIAL; never auto-selects a device.
#                    See docs/android-ci.md for toolchain and evidence requirements.
#   test-all       — runs `test-web` + `test-macos`.
#   lint           — runs Phase 10A.0a's convention-rule runner
#                    (`scripts/lint_conventions.cr`).
#
# Bridge object file lifecycle:
#   `make test-macos` depends on `src/ui/native/objc_bridge.o`
#   (`$(AP_BRIDGE_OBJ)`) and `src/ui/native/swiftkit_bridge.o`
#   (`$(SK_BRIDGE_OBJ)`). Both are compiled with `-fno-objc-arc`
#   (the bridges manage their own memory). The `.o` files are .gitignored
#   build artifacts — never check them in.

CRYSTAL       ?= crystal
ACRYSTAL      ?= acrystal
# These are data, not Make expressions or shell fragments.
override ANDROID_SERIAL := $(value ANDROID_SERIAL)
override ANDROID_TEST_EVIDENCE := $(value ANDROID_TEST_EVIDENCE)
export ANDROID_SERIAL ANDROID_TEST_EVIDENCE

AP_BRIDGE_OBJ := src/ui/native/objc_bridge.o
AP_BRIDGE_SRC := src/ui/native/objc_bridge.m
SK_BRIDGE_OBJ := src/ui/native/swiftkit_bridge.o
SK_BRIDGE_SRC := src/ui/native/swiftkit_bridge.m

COL_BRIDGE_OBJ := src/ui/native/collection_bridge.o
COL_BRIDGE_SRC := src/ui/native/collection_bridge.m

SWIFTKIT_DIR  := swift/AssetPipelineSwiftKit
SWIFTKIT_LIB  := $(SWIFTKIT_DIR)/.build/release/libAssetPipelineSwiftKit.a

MACOS_FRAMEWORKS := \
	-framework AppKit -framework Foundation \
	-framework SwiftUI -framework Combine \
	-framework ApplicationServices -framework CoreFoundation \
	-framework CoreGraphics -framework ImageIO -framework QuartzCore \
	-framework UserNotifications \
	-framework WebKit -framework MapKit -framework CoreLocation \
	-framework AVKit -framework AVFoundation \
	-lobjc

MACOS_LINK_FLAGS := \
	$(abspath $(AP_BRIDGE_OBJ)) $(abspath $(SK_BRIDGE_OBJ)) $(abspath $(COL_BRIDGE_OBJ)) \
	-Wl,-force_load,$(abspath $(SWIFTKIT_LIB)) \
	$(MACOS_FRAMEWORKS) \
	-Wl,-rpath,/usr/lib/swift

.PHONY: test-web test-macos test-ios test-android test-all lint clean-bridges

test-web:
	$(CRYSTAL) spec spec/web/

test-macos: $(AP_BRIDGE_OBJ) $(SK_BRIDGE_OBJ) $(COL_BRIDGE_OBJ) $(SWIFTKIT_LIB)
	$(ACRYSTAL) spec spec/native_macos/ -Dmacos \
		--link-flags="$(MACOS_LINK_FLAGS)"

test-ios:
	@bash scripts/test_ios_host.sh

test-android:
	@bash scripts/test_android_target.sh

test-all: test-web test-macos
	@echo "[test-all] web + macOS lanes complete."
	@echo "[test-all] Android is separate: make test-android ANDROID_SERIAL=<adb-serial>"
	@echo "[test-all] iOS is separate: make test-ios (a simulator, xcodegen)"

lint:
	$(CRYSTAL) run scripts/lint_conventions.cr

$(AP_BRIDGE_OBJ): $(AP_BRIDGE_SRC)
	clang -c $(AP_BRIDGE_SRC) -o $(AP_BRIDGE_OBJ) -fno-objc-arc

$(SK_BRIDGE_OBJ): $(SK_BRIDGE_SRC)
	clang -c $(SK_BRIDGE_SRC) -o $(SK_BRIDGE_OBJ) -fno-objc-arc

$(COL_BRIDGE_OBJ): $(COL_BRIDGE_SRC)
	clang -c $(COL_BRIDGE_SRC) -o $(COL_BRIDGE_OBJ) -fno-objc-arc

$(SWIFTKIT_LIB): $(wildcard $(SWIFTKIT_DIR)/Sources/AssetPipelineSwiftKit/*.swift) \
                 $(wildcard $(SWIFTKIT_DIR)/Sources/AssetPipelineSwiftKit/**/*.swift) \
                 $(SWIFTKIT_DIR)/Package.swift
	swift build -c release --package-path $(SWIFTKIT_DIR)

clean-bridges:
	rm -f $(AP_BRIDGE_OBJ) $(SK_BRIDGE_OBJ) $(COL_BRIDGE_OBJ)
