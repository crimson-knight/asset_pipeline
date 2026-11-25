# Native macOS styling showcase — offscreen light and dark renders.
#
#   make -C examples/native_styling run OUT=/tmp/native-styling \
#        MICHROMA=/path/to/Michroma-Regular.ttf
#
# Reuses the repo root Makefile's bridge objects and SwiftKit library
# targets, so a `make test-macos` build is shared.

SHARD_ROOT := $(abspath $(CURDIR)/../..)
ACRYSTAL   ?= acrystal
OUT        ?= $(SHARD_ROOT)/output/native-styling
MICHROMA   ?=
BIN        := $(SHARD_ROOT)/output/bin/native_styling_showcase

AP_BRIDGE_OBJ  := $(SHARD_ROOT)/src/ui/native/objc_bridge.o
SK_BRIDGE_OBJ  := $(SHARD_ROOT)/src/ui/native/swiftkit_bridge.o
COL_BRIDGE_OBJ := $(SHARD_ROOT)/src/ui/native/collection_bridge.o
SWIFTKIT_LIB   := $(SHARD_ROOT)/swift/AssetPipelineSwiftKit/.build/release/libAssetPipelineSwiftKit.a

MACOS_FRAMEWORKS := \
	-framework AppKit -framework Foundation \
	-framework SwiftUI -framework Combine \
	-framework ApplicationServices -framework CoreFoundation \
	-framework CoreGraphics -framework CoreText -framework ImageIO -framework QuartzCore \
	-framework UserNotifications \
	-framework WebKit -framework MapKit -framework CoreLocation \
	-framework AVKit -framework AVFoundation \
	-lobjc

LINK_FLAGS := $(AP_BRIDGE_OBJ) $(SK_BRIDGE_OBJ) $(COL_BRIDGE_OBJ) \
	-Wl,-force_load,$(SWIFTKIT_LIB) \
	$(MACOS_FRAMEWORKS) \
	-Wl,-rpath,/usr/lib/swift

.PHONY: run build deps

run: build
	OUT="$(OUT)" MICHROMA="$(MICHROMA)" $(BIN)

build: deps
	mkdir -p $(dir $(BIN))
	$(ACRYSTAL) build native_styling_showcase.cr -o $(BIN) -Dmacos -Duse_pcre2 \
		--link-flags="$(LINK_FLAGS)"

deps:
	$(MAKE) -C $(SHARD_ROOT) src/ui/native/objc_bridge.o src/ui/native/swiftkit_bridge.o \
		src/ui/native/collection_bridge.o swift/AssetPipelineSwiftKit/.build/release/libAssetPipelineSwiftKit.a
