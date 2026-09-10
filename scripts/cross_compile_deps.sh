#!/usr/bin/env bash
# Cross-compile Crystal dependencies (libgc + libpcre2) for iOS and Android.
#
# Usage:
#   ./scripts/cross_compile_deps.sh [ios|android|all]
#
# Prerequisites:
#   - Xcode Command Line Tools (for iOS targets)
#   - Android NDK (set ANDROID_NDK_HOME; defaults to common Homebrew location)
#   - git, cmake, make, autoconf, automake, libtool
#
# Output layout:
#   $BUILD_DIR/
#     ios-device/lib/        libgc.a  libpcre2-8.a
#     ios-simulator/lib/     libgc.a  libpcre2-8.a
#     android/<abi>/api-<api>/<contract-sha256>/lib/
#                           libgc.a  libcord.a  libpcre2-8.a  libpcre2-posix.a
#
# After running this script, export CRYSTAL_CROSS_DEPS to $BUILD_DIR and
# pass --library-path / -L flags to Crystal and the linker.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=android_env.sh
source "$SCRIPT_DIR/android_env.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

BUILD_DIR="${BUILD_DIR:-/tmp/crystal-cross-deps}"
BDWGC_VERSION="${BDWGC_VERSION:-$BDWGC_ANDROID_VERSION}"
ATOMIC_OPS_VERSION="${ATOMIC_OPS_VERSION:-$ATOMIC_OPS_ANDROID_VERSION}"
PCRE2_VERSION="${PCRE2_VERSION:-$PCRE2_ANDROID_VERSION}"
IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-17.0}"
ANDROID_API="${ANDROID_API:-$ANDROID_NATIVE_API}"
ANDROID_ABIS="${ANDROID_ABIS:-$ANDROID_SUPPORTED_ABIS}"

ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-}"

BDWGC_SRC="${BUILD_DIR}/src/bdwgc"
PCRE2_SRC="${BUILD_DIR}/src/pcre2"

# Number of parallel make jobs
JOBS="${JOBS:-$(sysctl -n hw.physicalcpu 2>/dev/null || nproc 2>/dev/null || echo 4)}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { echo "==> $*"; }
step()  { echo "  -> $*"; }
die()   { echo "ERROR: $*" >&2; exit 1; }

check_tool() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not found in PATH."
}

require_xcode() {
    check_tool xcrun
    xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1 \
        || die "iOS SDK not found. Install Xcode and run 'sudo xcode-select --install'."
}





# Clone or update a git repository
clone_or_update() {
    local url="$1" dest="$2" tag="$3"
    if [[ -d "$dest/.git" ]]; then
        step "Source already present: $dest (skipping clone)"
    else
        step "Cloning $url -> $dest"
        git clone --depth 1 --branch "$tag" "$url" "$dest"
    fi

    local expected_commit actual_commit
    expected_commit="$(git -C "$dest" rev-list -n 1 "$tag")"
    actual_commit="$(git -C "$dest" rev-parse HEAD)"
    [[ -n "$expected_commit" && "$actual_commit" == "$expected_commit" ]] \
        || die "$dest is at $actual_commit, expected tag $tag ($expected_commit)"
}

# ---------------------------------------------------------------------------
# BoehmGC (libgc)
# ---------------------------------------------------------------------------

fetch_bdwgc() {
    mkdir -p "$(dirname "$BDWGC_SRC")"
    clone_or_update \
        "https://github.com/ivmai/bdwgc.git" \
        "$BDWGC_SRC" \
        "v${BDWGC_VERSION}"
    # The upstream bdwgc git checkout does not vendor libatomic_ops. It is
    # required for the thread-enabled configuration Crystal needs on iOS.
    # Pin it just as we pin bdwgc and PCRE2 so cross-builds stay reproducible.
    if [[ ! -d "$BDWGC_SRC/libatomic_ops/src" ]]; then
        step "Cloning libatomic_ops -> $BDWGC_SRC/libatomic_ops"
        git clone --depth 1 --branch "v${ATOMIC_OPS_VERSION}" \
            "https://github.com/ivmai/libatomic_ops.git" \
            "$BDWGC_SRC/libatomic_ops"
    fi
    local atomic_expected atomic_actual
    atomic_expected="$(git -C "$BDWGC_SRC/libatomic_ops" rev-list -n 1 "v${ATOMIC_OPS_VERSION}")"
    atomic_actual="$(git -C "$BDWGC_SRC/libatomic_ops" rev-parse HEAD)"
    [[ -n "$atomic_expected" && "$atomic_actual" == "$atomic_expected" ]] \
        || die "libatomic_ops is at $atomic_actual, expected v${ATOMIC_OPS_VERSION} ($atomic_expected)"
    # Run autoconf if configure doesn't exist
    if [[ ! -f "$BDWGC_SRC/configure" ]]; then
        step "Running autogen in bdwgc"
        (cd "$BDWGC_SRC" && ./autogen.sh)
    fi
}

build_bdwgc() {
    local prefix="$1" cc="$2" host="$3" extra_cflags="${4:-}" extra_configure="${5:-}"
    local build_dir="${BUILD_DIR}/build/bdwgc-$(basename "$prefix")"

    if [[ -f "$prefix/lib/libgc.a" ]]; then
        step "libgc already built for $host (skipping)"
        return 0
    fi

    mkdir -p "$build_dir" "$prefix"
    step "Configuring libgc for $host"
    (
        cd "$build_dir"
        # Crystal's normal runtime calls Boehm's GC_pthread_* wrappers, even
        # when an application does not explicitly create a worker.  iOS allows
        # pthreads inside the app sandbox, so the cross-runtime must expose
        # those wrappers; a --disable-threads archive fails later at the final
        # Xcode link with unresolved GC_pthread_create/GC_pthread_detach.
        # Cross-builds must not inherit Homebrew/macOS include or library
        # paths from the developer shell. Those paths can silently poison a
        # target archive even when configure and make return success.
        env -u CPPFLAGS -u CFLAGS -u LDFLAGS -u LIBS \
        "$BDWGC_SRC/configure" \
            --host="$host" \
            --prefix="$prefix" \
            --enable-static \
            --disable-shared \
            --disable-docs \
            --enable-large-config \
            CC="$cc" \
            CFLAGS="-O2 $extra_cflags" \
            ${extra_configure}
    )
    step "Building libgc for $host (-j$JOBS)"
    make -C "$build_dir" -j"$JOBS"
    step "Installing libgc to $prefix"
    make -C "$build_dir" install
}

# ---------------------------------------------------------------------------
# PCRE2 (libpcre2)
# ---------------------------------------------------------------------------

fetch_pcre2() {
    mkdir -p "$(dirname "$PCRE2_SRC")"
    clone_or_update \
        "https://github.com/PCRE2Project/pcre2.git" \
        "$PCRE2_SRC" \
        "pcre2-${PCRE2_VERSION}"
}

build_pcre2_cmake() {
    local prefix="$1" cmake_toolchain_file="$2"
    shift 2
    # `set -u` trips on empty arrays with bash<5; guard with default.
    local extra_cmake_args=()
    if [[ $# -gt 0 ]]; then
        extra_cmake_args=("$@")
    fi
    local build_dir="${BUILD_DIR}/build/pcre2-$(basename "$prefix")"

    if [[ -f "$prefix/lib/libpcre2-8.a" ]]; then
        step "libpcre2 already built for $(basename "$prefix") (skipping)"
        return 0
    fi

    mkdir -p "$build_dir" "$prefix"
    step "Configuring libpcre2 via cmake"
    cmake -S "$PCRE2_SRC" -B "$build_dir" \
        -DCMAKE_INSTALL_PREFIX="$prefix" \
        -DBUILD_SHARED_LIBS=OFF \
        -DPCRE2_BUILD_PCRE2_16=OFF \
        -DPCRE2_BUILD_PCRE2_32=OFF \
        -DPCRE2_BUILD_TESTS=OFF \
        -DPCRE2_BUILD_PCRE2GREP=OFF \
        -DPCRE2_SUPPORT_JIT=OFF \
        ${cmake_toolchain_file:+-DCMAKE_TOOLCHAIN_FILE="$cmake_toolchain_file"} \
        ${extra_cmake_args[@]+"${extra_cmake_args[@]}"}
    step "Building libpcre2 (-j$JOBS)"
    cmake --build "$build_dir" -j"$JOBS"
    step "Installing libpcre2 to $prefix"
    cmake --install "$build_dir"
}

# ---------------------------------------------------------------------------
# iOS Device (arm64-apple-ios)
# ---------------------------------------------------------------------------

build_ios_device() {
    info "Building for iOS Device (arm64-apple-ios${IOS_DEPLOYMENT_TARGET})"

    require_xcode

    local prefix="${BUILD_DIR}/ios-device"
    local sdk
    sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
    local triple="arm64-apple-ios${IOS_DEPLOYMENT_TARGET}"
    local cc="xcrun --sdk iphoneos clang -target ${triple} -isysroot ${sdk}"
    # GNU configure uses a different --host value (aarch64, not arm64)
    local gnu_host="aarch64-apple-darwin"

    # --- libgc ---
    fetch_bdwgc
    build_bdwgc \
        "$prefix" \
        "$cc" \
        "$gnu_host" \
        "-mios-version-min=${IOS_DEPLOYMENT_TARGET}" \
        "--enable-threads=posix"

    # --- libpcre2 ---
    # Write a cmake toolchain file for iOS device
    local tc_file="${BUILD_DIR}/ios-device-toolchain.cmake"
    cat > "$tc_file" <<EOF
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_SYSROOT ${sdk})
set(CMAKE_OSX_DEPLOYMENT_TARGET ${IOS_DEPLOYMENT_TARGET})
set(CMAKE_C_COMPILER $(xcrun --sdk iphoneos --find clang))
set(CMAKE_C_FLAGS "-target ${triple}")
# No JIT: iOS App Sandbox forbids mmap(PROT_EXEC) on non-text pages
set(PCRE2_SUPPORT_JIT OFF CACHE BOOL "" FORCE)
EOF

    fetch_pcre2
    build_pcre2_cmake "$prefix" "$tc_file"

    info "iOS Device deps ready in $prefix"
    ls -lh "$prefix/lib/"*.a
}

# ---------------------------------------------------------------------------
# iOS Simulator (arm64-apple-ios-simulator)
# ---------------------------------------------------------------------------

build_ios_simulator() {
    info "Building for iOS Simulator (arm64-apple-ios${IOS_DEPLOYMENT_TARGET}-simulator)"

    require_xcode

    local prefix="${BUILD_DIR}/ios-simulator"
    local sdk
    sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
    local triple="arm64-apple-ios${IOS_DEPLOYMENT_TARGET}-simulator"
    local cc="xcrun --sdk iphonesimulator clang -target ${triple} -isysroot ${sdk}"
    local gnu_host="aarch64-apple-darwin"

    # --- libgc ---
    fetch_bdwgc
    build_bdwgc \
        "$prefix" \
        "$cc" \
        "$gnu_host" \
        "-mios-simulator-version-min=${IOS_DEPLOYMENT_TARGET}" \
        "--enable-threads=posix"

    # --- libpcre2 ---
    local tc_file="${BUILD_DIR}/ios-simulator-toolchain.cmake"
    cat > "$tc_file" <<EOF
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_SYSROOT ${sdk})
set(CMAKE_OSX_DEPLOYMENT_TARGET ${IOS_DEPLOYMENT_TARGET})
# Simulator target must be passed via C_FLAGS; CMake iOS toolchain uses XCODE internally
set(CMAKE_C_COMPILER $(xcrun --sdk iphonesimulator --find clang))
set(CMAKE_C_FLAGS "-target ${triple}")
set(PCRE2_SUPPORT_JIT OFF CACHE BOOL "" FORCE)
EOF

    fetch_pcre2
    build_pcre2_cmake "$prefix" "$tc_file"

    info "iOS Simulator deps ready in $prefix"
    ls -lh "$prefix/lib/"*.a
}

# ---------------------------------------------------------------------------
# Android (aarch64-linux-android, API 31)
# ---------------------------------------------------------------------------

build_android_abi() {
    BUILD_DIR="$BUILD_DIR" ANDROID_API="$ANDROID_API" JOBS="$JOBS" \
        bash "$SCRIPT_DIR/build_android_deps.sh" "$1"
}

build_android() {
    local abi
    while IFS= read -r abi; do
        [[ -n "$abi" ]] || continue
        build_android_abi "$abi"
    done < <(android_each_abi "$ANDROID_ABIS")
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

TARGET="${1:-all}"

# Validate required tools common to all targets
check_tool git
check_tool cmake
check_tool make

case "$TARGET" in
    ios)
        build_ios_device
        build_ios_simulator
        ;;
    android)
        build_android
        ;;
    all)
        build_ios_device
        build_ios_simulator
        build_android
        ;;
    *)
        echo "Usage: $0 [ios|android|all]"
        echo ""
        echo "  ios       Build libgc + libpcre2 for iOS device and simulator"
        echo "  android   Build libgc + libpcre2 for Android ABIs (API ${ANDROID_API})"
        echo "  all       Build all three targets (default)"
        echo ""
        echo "Environment variables:"
        echo "  BUILD_DIR              Output directory (default: /tmp/crystal-cross-deps)"
        echo "  BDWGC_VERSION          BoehmGC version to fetch (default: ${BDWGC_VERSION})"
        echo "  ATOMIC_OPS_VERSION     libatomic_ops version (default: ${ATOMIC_OPS_VERSION})"
        echo "  PCRE2_VERSION          PCRE2 version to fetch  (default: ${PCRE2_VERSION})"
        echo "  IOS_DEPLOYMENT_TARGET  Minimum iOS version     (default: ${IOS_DEPLOYMENT_TARGET})"
        echo "  ANDROID_API            Android API level        (default: ${ANDROID_API})"
        echo "  ANDROID_ABIS           Comma-separated ABIs      (default: ${ANDROID_ABIS})"
        echo "  ANDROID_NDK_HOME       Path to Android NDK"
        echo "  JOBS                   Parallel make jobs       (default: auto)"
        exit 1
        ;;
esac

echo ""
echo "Done. Built libraries are in: $BUILD_DIR"
echo ""
echo "Next steps:"
echo "  iOS device:    ./scripts/build_ios.sh <source.cr> device"
echo "  iOS simulator: ./scripts/build_ios.sh <source.cr> simulator"
echo "  Android:       ./scripts/build_android.sh <source.cr>"
