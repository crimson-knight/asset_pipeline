#!/usr/bin/env bash
# build_crystal_lib.sh
#
# Build the CrystalHIGHost Crystal bridge as a static library for iOS.
#
# Output: samples/cross_platform/ios_host/build/libhighost.a
#
# Prerequisites
# -------------
#   - crystal-alpha installed
#   - Xcode with iOS SDK: xcode-select --install
#
# Usage
# -----
#   cd asset_pipeline && ./samples/cross_platform/ios_host/build_crystal_lib.sh [simulator|device]
#
# Key learnings from happy_coach:
#   - MUST use ld -r -unexported_symbol _main on Crystal .o to avoid _main clash with Swift @main
#   - BoehmGC (libgc.a) must be compiled targeting the iOS simulator SDK (caller's responsibility)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CRYSTAL=${CRYSTAL:-crystal-alpha}
BUILD_TARGET="${1:-simulator}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shard root = samples/cross_platform/ios_host/.. /.. /..
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_LIB="$BUILD_DIR/libhighost.a"
BRIDGE_SRC="$SCRIPT_DIR/hig_bridge.cr"
BRIDGE_BASE="$BUILD_DIR/bridge"

MIN_IOS_VER="16.0"

case "$BUILD_TARGET" in
    simulator)
        LLVM_TARGET="arm64-apple-ios-simulator"
        SDK_NAME="iphonesimulator"
        ;;
    device)
        LLVM_TARGET="arm64-apple-ios"
        SDK_NAME="iphoneos"
        ;;
    *)
        echo "Usage: $0 [simulator|device]"
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { printf '\033[0;34m[build]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[ok]\033[0m    %s\n' "$*"; }
fail()  { printf '\033[0;31m[fail]\033[0m  %s\n' "$*" >&2; exit 1; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

require_cmd "$CRYSTAL"
require_cmd xcrun
require_cmd xcodebuild

[[ ! -f "$BRIDGE_SRC" ]] && fail "Bridge source not found: $BRIDGE_SRC"

SDK_PATH="$(xcrun --sdk $SDK_NAME --show-sdk-path)"
CLANG="$(xcrun --sdk $SDK_NAME --find clang)"

info "Target         : $LLVM_TARGET"
info "SDK            : $SDK_PATH"
info "Bridge source  : $BRIDGE_SRC"

mkdir -p "$BUILD_DIR"

# ---------------------------------------------------------------------------
# Step 1: Compile asset_pipeline ObjC bridge for iOS
# ---------------------------------------------------------------------------
# IMPORTANT: -fno-objc-arc REQUIRED -- asset_pipeline bridge manages its own memory.

AP_BRIDGE_SRC="$PROJECT_ROOT/src/ui/native/objc_bridge.m"
AP_BRIDGE_OBJ="$BUILD_DIR/objc_bridge_ios.o"

if [[ -f "$AP_BRIDGE_SRC" ]]; then
    info "Compiling asset_pipeline ObjC bridge for $BUILD_TARGET..."
    "$CLANG" -c "$AP_BRIDGE_SRC" -o "$AP_BRIDGE_OBJ" \
        -target "$LLVM_TARGET" \
        -isysroot "$SDK_PATH" \
        -mios-version-min=$MIN_IOS_VER \
        -fno-objc-arc
    ok "ObjC bridge compiled"
else
    info "No asset_pipeline ObjC bridge found at $AP_BRIDGE_SRC, skipping"
fi

# ---------------------------------------------------------------------------
# Step 1b: Compile AssetPipelineSwiftKit C trampolines and static library
# ---------------------------------------------------------------------------
# Phase 3a routes UI::Button through AssetPipelineSwiftKit. The C
# trampolines in `swiftkit_bridge.m` resolve `apsk_make_button(...)` etc.
# via objc_msgSend onto the Swift facade classes. The Swift facade is
# packaged as a static archive that the consuming Xcode project (or
# `ar`-merged libhighost.a below) links against alongside SwiftUI /
# Combine system frameworks. iOS Swift runtime ships at
# /usr/lib/swift inside the SDK; the Xcode project must add a runtime
# search path to load it.

SWIFTKIT_BRIDGE_SRC="$PROJECT_ROOT/src/ui/native/swiftkit_bridge.m"
SWIFTKIT_BRIDGE_OBJ="$BUILD_DIR/swiftkit_bridge_ios.o"
SWIFTKIT_PACKAGE_DIR="$PROJECT_ROOT/swift/AssetPipelineSwiftKit"
SWIFTKIT_BUILD_TARGET="$BUILD_DIR/swiftkit_${BUILD_TARGET}.a"

if [[ -f "$SWIFTKIT_BRIDGE_SRC" ]]; then
    info "Compiling AssetPipelineSwiftKit C trampolines for $BUILD_TARGET..."
    "$CLANG" -c "$SWIFTKIT_BRIDGE_SRC" -o "$SWIFTKIT_BRIDGE_OBJ" \
        -target "$LLVM_TARGET" \
        -isysroot "$SDK_PATH" \
        -mios-version-min=$MIN_IOS_VER \
        -fno-objc-arc
    ok "SwiftKit C trampolines compiled"
fi

info "Compiling AssetPipelineSwiftKit Swift facade for $BUILD_TARGET..."
# Its own scratch path: a build into the package's default .build repoints
# .build/release at the iOS objects, and the macOS host and `make test-macos`
# then link iOS Simulator objects into a macOS binary (ld64.lld refuses).
SWIFTKIT_SCRATCH="$SWIFTKIT_PACKAGE_DIR/.build/ios-$BUILD_TARGET"
swift build -c release \
    --package-path "$SWIFTKIT_PACKAGE_DIR" \
    --scratch-path "$SWIFTKIT_SCRATCH" \
    --triple "$LLVM_TARGET" \
    --sdk "$SDK_PATH"

# Ask SwiftPM where it put the products: the location has moved between Swift
# versions (Xcode 27 resolved the dependencies under the scratch path and built
# elsewhere), so the same flags with --show-bin-path are the only stable answer.
# A search of the package's build trees is the fallback; without the archive
# the Xcode project's link of build/swiftkit_<target>.a fails later, so stop here.
SWIFTKIT_BIN_PATH="$(swift build -c release \
    --package-path "$SWIFTKIT_PACKAGE_DIR" \
    --scratch-path "$SWIFTKIT_SCRATCH" \
    --triple "$LLVM_TARGET" \
    --sdk "$SDK_PATH" \
    --show-bin-path 2>/dev/null || true)"
SWIFTKIT_SRC_LIB="$SWIFTKIT_BIN_PATH/libAssetPipelineSwiftKit.a"
if [[ ! -f "$SWIFTKIT_SRC_LIB" ]]; then
    SWIFTKIT_SRC_LIB="$(find "$SWIFTKIT_SCRATCH" "$SWIFTKIT_PACKAGE_DIR/.build" -type f -name libAssetPipelineSwiftKit.a -path "*$LLVM_TARGET*" 2>/dev/null | head -n 1)"
fi
if [[ -n "$SWIFTKIT_SRC_LIB" && -f "$SWIFTKIT_SRC_LIB" ]]; then
    cp "$SWIFTKIT_SRC_LIB" "$SWIFTKIT_BUILD_TARGET"
    ok "SwiftKit static library staged at $SWIFTKIT_BUILD_TARGET (from $SWIFTKIT_SRC_LIB)"
else
    info "SwiftPM bin path: ${SWIFTKIT_BIN_PATH:-(none)}"
    find "$SWIFTKIT_PACKAGE_DIR/.build" -maxdepth 3 -type d 2>/dev/null | sed 's/^/  /' >&2
    find "$SWIFTKIT_PACKAGE_DIR/.build" -type f -name 'libAssetPipelineSwiftKit.a' 2>/dev/null | sed 's/^  archive: /  /' >&2
    fail "Swift archive libAssetPipelineSwiftKit.a not found for $LLVM_TARGET"
fi

# ---------------------------------------------------------------------------
# Step 2: Cross-compile Crystal bridge
# ---------------------------------------------------------------------------

info "Cross-compiling Crystal bridge..."

"$CRYSTAL" build "$BRIDGE_SRC" \
    --cross-compile \
    --target="$LLVM_TARGET" \
    -Dios \
    -o "$BRIDGE_BASE"

ok "Crystal cross-compilation complete"

# ---------------------------------------------------------------------------
# Step 3: Fix _main symbol conflict
# ---------------------------------------------------------------------------
# CRITICAL: Crystal emits a _main symbol that conflicts with Swift's @main.
# We must hide it using ld -r -unexported_symbol _main.

info "Fixing _main symbol conflict..."

if [[ -f "$BRIDGE_BASE.o" ]]; then
    ld -r -unexported_symbol _main "$BRIDGE_BASE.o" -o "$BUILD_DIR/bridge_fixed.o"
    mv "$BUILD_DIR/bridge_fixed.o" "$BRIDGE_BASE.o"
    ok "_main symbol hidden"
fi

# ---------------------------------------------------------------------------
# Step 4: Pack into static library
# ---------------------------------------------------------------------------

info "Creating static library..."

OBJ_FILES="$BRIDGE_BASE.o"
[[ -f "$AP_BRIDGE_OBJ" ]] && OBJ_FILES="$OBJ_FILES $AP_BRIDGE_OBJ"
[[ -f "$SWIFTKIT_BRIDGE_OBJ" ]] && OBJ_FILES="$OBJ_FILES $SWIFTKIT_BRIDGE_OBJ"

ar rcs "$OUTPUT_LIB" $OBJ_FILES
ok "Static library created: $OUTPUT_LIB"

info "Done! Link with: -L$BUILD_DIR -lhighost"
info "Also link: $SWIFTKIT_BUILD_TARGET (AssetPipelineSwiftKit Swift facade)"
info "Frameworks: -framework SwiftUI -framework Combine -framework Foundation -framework UIKit"
info "Swift runtime rpath: add /usr/lib/swift to the consuming target's runpath search paths"
