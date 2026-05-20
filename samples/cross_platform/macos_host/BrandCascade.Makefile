# Makefile for the Phase 1 brand cascade demo (macOS / AppKit).
#
# Builds `brand_cascade_demo.cr` into a signed binary that renders a
# UI::VStack + UI::Button using `Tokens.default.with_brand(SentinelBrand.new)`
# and captures a PNG of the rendered window. The validator flips the
# `BRAND_PRIMARY_HEX` constant in `brand_cascade_demo.cr` and re-runs to
# confirm the sentinel color cascades to the rendered pixel.
#
# Usage (from this directory):
#   make -f BrandCascade.Makefile build
#   HIG_SCREENSHOT_PATH=/tmp/brand_cascade_macos.png ./bin/brand_cascade_demo

PROJECT_DIR := $(shell pwd)
SHARD_ROOT  := $(abspath $(PROJECT_DIR)/../../..)

CRYSTAL     := crystal-alpha
BIN         := bin/brand_cascade_demo
SRC         := brand_cascade_demo.cr

CODESIGN_IDENTITY ?= -

AP_BRIDGE     := $(SHARD_ROOT)/src/ui/native/objc_bridge.o
AP_BRIDGE_SRC := $(SHARD_ROOT)/src/ui/native/objc_bridge.m

WIN_HELPER     := $(PROJECT_DIR)/window_helper.o
WIN_HELPER_SRC := $(PROJECT_DIR)/window_helper.m

MACOS_FRAMEWORKS := -framework AppKit -framework Foundation \
	-framework ApplicationServices -framework CoreFoundation \
	-framework CoreGraphics -framework ImageIO -framework QuartzCore \
	-framework UserNotifications \
	-framework WebKit -framework MapKit -framework CoreLocation -framework AVKit -framework AVFoundation \
	-lobjc

MACOS_LINK_FLAGS := $(AP_BRIDGE) $(WIN_HELPER) $(MACOS_FRAMEWORKS)

.PHONY: build run ext-ap ext-win clean

build: ext-ap ext-win $(BIN)

$(BIN): $(SRC) ext-ap ext-win
	@mkdir -p bin
	$(CRYSTAL) build $(SRC) -o $(BIN) -Dmacos \
		--link-flags="$(MACOS_LINK_FLAGS)"
	@if [ "$(CODESIGN_IDENTITY)" != "-" ]; then \
		codesign --force --sign "$(CODESIGN_IDENTITY)" --timestamp=none $(BIN); \
	fi

run: build
	@HIG_SCREENSHOT_PATH=$${HIG_SCREENSHOT_PATH:-/tmp/brand_cascade_macos.png} ./$(BIN)

ext-ap: $(AP_BRIDGE)
$(AP_BRIDGE): $(AP_BRIDGE_SRC)
	clang -c $(AP_BRIDGE_SRC) -o $(AP_BRIDGE) -fno-objc-arc

ext-win: $(WIN_HELPER)
$(WIN_HELPER): $(WIN_HELPER_SRC)
	clang -c $(WIN_HELPER_SRC) -o $(WIN_HELPER) -fno-objc-arc

clean:
	rm -f $(BIN)
	rm -rf bin
