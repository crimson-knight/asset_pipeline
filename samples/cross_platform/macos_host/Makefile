# Makefile for the HIG macOS visual-validation host.
#
# Pattern copied from happy_coach/Makefile; stripped of crystal-audio
# extensions and app-specific bridges. Renders one UI::View per slug
# and opens it in a native AppKit window for AXTest to screenshot.
#
# Usage:
#   make showcase SLUG=buttons
#   make clean

# PROJECT_DIR resolves to this Makefile's directory.
PROJECT_DIR := $(shell pwd)

# asset_pipeline shard root (three levels up from samples/cross_platform/macos_host).
SHARD_ROOT  := $(abspath $(PROJECT_DIR)/../../..)

CRYSTAL     := crystal-alpha
BIN         := bin/hig_showcase
SRC         := hig_showcase.cr

# Asset Pipeline ObjC bridge (ARM64-safe objc_msgSend wrappers).
# IMPORTANT: -fno-objc-arc is REQUIRED -- the bridge manages its own memory.
AP_BRIDGE     := $(SHARD_ROOT)/src/ui/native/objc_bridge.o
AP_BRIDGE_SRC := $(SHARD_ROOT)/src/ui/native/objc_bridge.m

# HIG host window helper (NSApplication + NSWindow init).
WIN_HELPER     := $(PROJECT_DIR)/window_helper.o
WIN_HELPER_SRC := $(PROJECT_DIR)/window_helper.m

# Framework flags for macOS.
# AppKit + Foundation + lobjc = renderer essentials.
# ApplicationServices + CoreFoundation = AXTest screenshot harness.
# CoreGraphics + ImageIO = CGWindowListCreateImage capture path (Phase 0.1).
MACOS_FRAMEWORKS := -framework AppKit -framework Foundation \
	-framework ApplicationServices -framework CoreFoundation \
	-framework CoreGraphics -framework ImageIO -framework QuartzCore \
	-lobjc

MACOS_LINK_FLAGS := $(AP_BRIDGE) $(WIN_HELPER) $(MACOS_FRAMEWORKS)

SLUG ?= buttons

.PHONY: showcase build ext-ap ext-win clean

# --- Build + run ---

showcase: build
	@echo "[hig_showcase] SLUG=$(SLUG) -> $(BIN)"
	@if [ -z "$$HIG_SCREENSHOT_PATH" ]; then \
		echo "[hig_showcase] build complete. NOT running the binary because HIG_SCREENSHOT_PATH is unset."; \
		echo "[hig_showcase] To capture: HIG_SCREENSHOT_PATH=/tmp/out.png HIG_SLUG=$(SLUG) ./$(BIN)"; \
		echo "[hig_showcase] Automated pipelines should use spec/ui/hig_validation/macos_visual_spec.cr which sets the env vars."; \
	else \
		HIG_SLUG=$(SLUG) ./$(BIN); \
	fi

build: ext-ap ext-win $(BIN)

$(BIN): $(SRC) ext-ap ext-win
	@mkdir -p bin
	$(CRYSTAL) build $(SRC) -o $(BIN) -Dmacos \
		--link-flags="$(MACOS_LINK_FLAGS)"

# --- ObjC bridge ---
# IMPORTANT: -fno-objc-arc is REQUIRED.

ext-ap: $(AP_BRIDGE)
$(AP_BRIDGE): $(AP_BRIDGE_SRC)
	clang -c $(AP_BRIDGE_SRC) -o $(AP_BRIDGE) -fno-objc-arc

ext-win: $(WIN_HELPER)
$(WIN_HELPER): $(WIN_HELPER_SRC)
	clang -c $(WIN_HELPER_SRC) -o $(WIN_HELPER) -fno-objc-arc

# --- Clean ---

clean:
	rm -f $(BIN) $(AP_BRIDGE) $(WIN_HELPER)
	rm -rf bin
