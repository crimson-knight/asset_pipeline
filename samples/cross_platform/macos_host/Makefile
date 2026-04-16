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

# Code-signing identity. TCC permissions (Screen Recording, Accessibility, etc.)
# persist across rebuilds ONLY if the binary is signed with a stable identity.
# Ad-hoc signatures change hash on every rebuild — TCC grants get invalidated.
# Override with `make CODESIGN_IDENTITY="..."` or set to `-` to disable signing.
CODESIGN_IDENTITY ?= Developer ID Application: AgentC Consulting LLC (PXDF92M2T4)

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
	-framework WebKit -framework MapKit -framework CoreLocation -framework AVKit -framework AVFoundation \
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
	@$(MAKE) --no-print-directory sign

# --- Code signing ---
# Sign with a stable identity so TCC permissions (Screen Recording, etc.)
# persist across rebuilds. The Developer ID identity hash is derived from
# the signing certificate's team ID, which is stable forever — so granting
# Screen Recording to this binary once makes it work for every rebuild.

.PHONY: sign
sign:
	@if [ "$(CODESIGN_IDENTITY)" = "-" ]; then \
		echo "[codesign] Skipping (CODESIGN_IDENTITY=-)"; \
	else \
		echo "[codesign] Signing $(BIN) with: $(CODESIGN_IDENTITY)"; \
		codesign --force --sign "$(CODESIGN_IDENTITY)" \
			--timestamp=none \
			$(BIN); \
		codesign --verify --verbose=1 $(BIN); \
	fi
	# Note: hardened runtime (--options runtime) is intentionally NOT enabled.
	# The binary loads homebrew dylibs (libssl, libcrypto) signed by their own
	# teams; hardened runtime would reject them as "different Team IDs."
	# Hardened runtime is required for notarized distribution, not dev tools.

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
