# Phase 6.10 — Voyager demo Makefile.
#
# Three targets:
#   make web   -> output/voyager-demo/*.html (single-page + per-screen)
#   make macos -> macos/bin/voyager (NavigationCoordinator-driven host)
#   make ios   -> Voyager.app for iPhone 17 Simulator
#
# Web is the primary deliverable for the state-propagation litmus;
# macOS + iOS hosts mirror the Cascade demo's structure for the
# native NSWindow setContentView + UIKit SwiftUI @State trampoline
# patterns.

PROJECT_DIR := $(shell pwd)
SHARD_ROOT  := $(abspath $(PROJECT_DIR)/../..)

CRYSTAL_VANILLA := crystal
CRYSTAL_NATIVE  := crystal-alpha

.PHONY: all web macos ios clean

all: web

# ---------------------------------------------------------------------------
# Web target — pure Crystal, no native toolchain required.
# ---------------------------------------------------------------------------

web:
	@echo "[voyager web] building single-page navigable demo -> output/voyager-demo/"
	$(CRYSTAL_VANILLA) run $(PROJECT_DIR)/web/static_site.cr

# ---------------------------------------------------------------------------
# macOS + iOS targets (placeholders — D2 macOS/iOS host implementations
# follow the Cascade pattern; see the brief's Phase 6.10 D2 commits).
# ---------------------------------------------------------------------------

macos:
	@echo "[voyager macos] target requires the SwiftKit bridge + objc_bridge.o + window_helper.o; mirror samples/initiative-cross-platform-ui-demo/Makefile macos block."
	@exit 1

ios:
	@echo "[voyager ios] target requires ios/build_crystal_lib.sh + xcodegen; mirror samples/initiative-cross-platform-ui-demo/Makefile ios block."
	@exit 1

clean:
	rm -rf $(SHARD_ROOT)/output/voyager-demo
