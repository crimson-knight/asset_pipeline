#!/usr/bin/env bash
# Voyager watchOS bridge — cross-compile script. Mirrors ios/build_crystal_lib.sh,
# adapted for watchOS-simulator. Produces build/libvoyagerwatch.a (the Crystal bridge
# + ObjC trampolines) and stages the SwiftKit .a/module + a single-threaded libgc.a.
#
# Output: samples/initiative-cross-platform-ui-voyager/watchos/build/libvoyagerwatch.a
# Usage:  ./build_crystal_lib.sh
set -euo pipefail

CRYSTAL=${CRYSTAL:-acrystal}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_LIB="$BUILD_DIR/libvoyagerwatch.a"
BRIDGE_SRC="$SCRIPT_DIR/bridge.cr"
BRIDGE_BASE="$BUILD_DIR/bridge"

LLVM_TARGET="arm64-apple-watchos10.0-simulator"
SDK_NAME="watchsimulator"
MIN_FLAG="-mwatchos-simulator-version-min=10.0"
DEPS_DIR="/tmp/crystal-cross-deps/watchos-simulator/lib"

info() { printf '\033[0;34m[voyager-watch-build]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[ok]\033[0m %s\n' "$*"; }
fail() { printf '\033[0;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

command -v "$CRYSTAL" >/dev/null 2>&1 || fail "Required: $CRYSTAL"
[[ -f "$BRIDGE_SRC" ]] || fail "Bridge source not found: $BRIDGE_SRC"

SDK_PATH="$(xcrun --sdk $SDK_NAME --show-sdk-path)"
CLANG="$(xcrun --sdk $SDK_NAME --find clang)"
mkdir -p "$BUILD_DIR" "$DEPS_DIR"

# Step 0: single-threaded libgc.a for watchOS (the program is single-threaded — no
# -Dpreview_mt — so we sidestep watchOS's missing thread_suspend/thread_resume).
if [[ ! -f "$DEPS_DIR/libgc.a" ]]; then
    info "Cross-building bdwgc (threads OFF) for watchOS..."
    BDWGC_SRC="/tmp/bdwgc-watch"
    [[ -d "$BDWGC_SRC" ]] || git clone --depth 1 --branch v8.2.8 https://github.com/ivmai/bdwgc "$BDWGC_SRC"
    cmake -S "$BDWGC_SRC" -B "$BDWGC_SRC/build-wsim-nt" \
        -DCMAKE_SYSTEM_NAME=watchOS -DCMAKE_OSX_SYSROOT="$SDK_PATH" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=10.0 \
        -Denable_threads=OFF -DBUILD_SHARED_LIBS=OFF -Denable_cplusplus=OFF \
        -DCMAKE_BUILD_TYPE=Release >/dev/null
    cmake --build "$BDWGC_SRC/build-wsim-nt" --config Release >/dev/null
    cp "$BDWGC_SRC/build-wsim-nt/libgc.a" "$DEPS_DIR/libgc.a"
fi
ok "libgc.a: $DEPS_DIR/libgc.a"

# NOTE: objc_bridge.m is NOT compiled for watchOS — it's an imperative UIKit/AppKit
# view bridge (UIView/UIScreen/labelColor/WebKit/…), none of which exist on watchOS.
# The watch renderer needs none of it: it composes via SwiftUI facades and the sender
# uses apsk_overrides_set_* (swiftkit_bridge.m). Verified the watch bridge .o
# references zero objc_bridge.m symbols (only _objc_release, from the runtime).

# Step 1: SwiftKit C trampolines + Swift facade.
"$CLANG" -c "$PROJECT_ROOT/src/ui/native/swiftkit_bridge.m" -o "$BUILD_DIR/swiftkit_bridge_watch.o" \
    -arch arm64 -isysroot "$SDK_PATH" $MIN_FLAG -fno-objc-arc
ok "swiftkit_bridge.m compiled"

# Step 1b: portable UserNotifications bridge. objc_bridge.m can't compile on
# watchOS (UIKit/AppKit), but notifications_bridge.m imports only Foundation +
# UserNotifications, so the watch gets ap_notifications_* (UI::Notifications uses
# them under -Dwatchos). Requires -framework UserNotifications at app link (see
# project.yml OTHER_LDFLAGS).
"$CLANG" -c "$PROJECT_ROOT/src/ui/native/notifications_bridge.m" -o "$BUILD_DIR/notifications_bridge_watch.o" \
    -arch arm64 -isysroot "$SDK_PATH" $MIN_FLAG -fno-objc-arc
ok "notifications_bridge.m compiled"

# Step 1c: portable AVSpeechSynthesizer bridge — the agent speaks on the wrist.
# AVFoundation is available on watchOS; this TU imports only Foundation +
# AVFoundation. Requires -framework AVFoundation at app link (see project.yml).
"$CLANG" -c "$PROJECT_ROOT/src/ui/native/speech_bridge.m" -o "$BUILD_DIR/speech_bridge_watch.o" \
    -arch arm64 -isysroot "$SDK_PATH" $MIN_FLAG -fno-objc-arc
ok "speech_bridge.m compiled"

SWIFTKIT_PACKAGE_DIR="$PROJECT_ROOT/swift/AssetPipelineSwiftKit"
# SwiftPM normalizes the triple for its .build dir (drops the OS version):
# --triple arm64-apple-watchos10.0-simulator -> .build/arm64-apple-watchos-simulator
SPM_DIR="arm64-apple-watchos-simulator"
info "Building SwiftKit for watchOS..."
swift build -c release --package-path "$SWIFTKIT_PACKAGE_DIR" \
    --triple "$LLVM_TARGET" --sdk "$SDK_PATH"
cp "$SWIFTKIT_PACKAGE_DIR/.build/$SPM_DIR/release/libAssetPipelineSwiftKit.a" \
    "$BUILD_DIR/swiftkit_watch.a"
MOD_SRC="$SWIFTKIT_PACKAGE_DIR/.build/$SPM_DIR/release/Modules"
if [[ -d "$MOD_SRC" ]]; then
    mkdir -p "$BUILD_DIR/Modules"
    cp -f "$MOD_SRC/"AssetPipelineSwiftKit.* "$BUILD_DIR/Modules/" 2>/dev/null || true
fi
ok "SwiftKit staged"

# Step 3: cross-compile the Crystal bridge.
info "Cross-compiling Crystal bridge..."
"$CRYSTAL" build "$BRIDGE_SRC" --cross-compile --target="$LLVM_TARGET" -Dwatchos -o "$BRIDGE_BASE"

# Step 4: hide _main to coexist with Swift @main.
ld -r -unexported_symbol _main "$BRIDGE_BASE.o" -o "$BUILD_DIR/bridge_fixed.o"
mv "$BUILD_DIR/bridge_fixed.o" "$BRIDGE_BASE.o"

# Step 5: pack into a static library (bridge + SwiftKit trampolines +
# notifications bridge; no objc_bridge).
ar rcs "$OUTPUT_LIB" "$BRIDGE_BASE.o" "$BUILD_DIR/swiftkit_bridge_watch.o" \
    "$BUILD_DIR/notifications_bridge_watch.o" "$BUILD_DIR/speech_bridge_watch.o"
ok "Static library: $OUTPUT_LIB"
