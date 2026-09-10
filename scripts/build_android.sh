#!/usr/bin/env bash
# Build a Crystal shared library for Android (API 31+).
#
# Usage:
#   ./scripts/build_android.sh <source.cr> [output_name]
#
# Examples:
#   ./scripts/build_android.sh src/my_app.cr
#   ./scripts/build_android.sh src/my_app.cr myapp
#
# Prerequisites:
#   - Crystal compiler on PATH (or set CRYSTAL env var)
#   - Android NDK installed (set ANDROID_NDK_HOME)
#   - libgc.a + libpcre2-8.a already cross-compiled (run cross_compile_deps.sh first)
#     or set CRYSTAL_CROSS_DEPS to the verified dependency cache root
#
# Output:
#   build/android-arm64/lib<name>.so
#
# The .so can be loaded from Kotlin/Java via System.loadLibrary("<name>").
# The JNI bridge in src/ui/native/android_host_jni.c provides
# a template for wiring Crystal functions into JNI_OnLoad.
#
# Extra native sources:
#   Set EXTRA_C_SOURCES to a space-separated list of C sources that should be
#   compiled with the NDK clang and linked into the final shared library.
#   This is how Android JNI bridge files and renderer support shims are added.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=android_env.sh
source "$SCRIPT_DIR/android_deps.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CRYSTAL="${CRYSTAL:-crystal}"
CROSS_DEPS="${CRYSTAL_CROSS_DEPS:-/tmp/crystal-cross-deps}"
ANDROID_API="${ANDROID_API:-$ANDROID_NATIVE_API}"
TARGET_ANDROID_ABI="${ANDROID_ABI:-$ANDROID_DEFAULT_ABI}"
ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-}"
BUILD_DIR="${BUILD_DIR:-$(cd "$(dirname "$0")/.." && pwd)/build}"

# Flags passed to Crystal. Disable OpenSSL and LibXML2 which are not
# available in NDK sysroot. All other stdlib modules are available.
CRYSTAL_FLAGS="${CRYSTAL_FLAGS:--Dwithout_openssl -Dwithout_xml}"

# Extra flags passed to NDK clang at link time (e.g. -llog for Android logging)
EXTRA_LINK_FLAGS="${EXTRA_LINK_FLAGS:--llog -lz}"

# Optional extra C sources to compile and link into the final shared object.
EXTRA_C_SOURCES="${EXTRA_C_SOURCES:-}"

# Every embedded Android runtime needs the C-level Boehm thread-registration
# shim. It must run before an otherwise-unregistered JVM thread enters Crystal.
RUNTIME_C_SOURCES="$(cd "$(dirname "$0")" && pwd)/crystal_gc_threads.c"

# Optional extra CFLAGS for additional include paths or feature defines.
EXTRA_CFLAGS="${EXTRA_CFLAGS:-}"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <source.cr> [output_name]"
    echo ""
    echo "Arguments:"
    echo "  source.cr     Crystal source file to compile"
    echo "  output_name   Base name for output library (default: source filename stem)"
    echo ""
    echo "Environment variables:"
    echo "  CRYSTAL              Crystal binary to use (default: crystal)"
    echo "  CRYSTAL_CROSS_DEPS   Verified dependency cache root (default: /tmp/crystal-cross-deps)"
    echo "  ANDROID_API          Android minimum API level (default: 31)"
    echo "  ANDROID_ABI          Android ABI (arm64-v8a or x86_64)"
    echo "  ANDROID_NDK_HOME     Path to Android NDK"
    echo "  CRYSTAL_FLAGS        Extra -D flags for crystal build"
    echo "  EXTRA_LINK_FLAGS     Extra flags passed to NDK clang at link time"
    exit 1
fi

SOURCE="$1"
STEM="${2:-$(basename "${SOURCE%.cr}")}"

[[ -f "$SOURCE" ]] || { echo "ERROR: Source file not found: $SOURCE" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info() { echo "==> $*"; }
step() { echo "  -> $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

check_tool() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not found in PATH."
}

# ---------------------------------------------------------------------------
# Locate NDK clang
# ---------------------------------------------------------------------------

android_configure_abi "$TARGET_ANDROID_ABI" "$ANDROID_API" || exit 1
ANDROID_NDK_HOME="$ANDROID_RESOLVED_NDK_HOME"
NDK_TOOLCHAIN="$ANDROID_NDK_TOOLCHAIN"
NDK_CLANG="$ANDROID_NDK_CLANG"
NDK_STRIP="${NDK_TOOLCHAIN}/llvm-strip"
NDK_AR="${NDK_TOOLCHAIN}/llvm-ar"
NDK_NM="${NDK_TOOLCHAIN}/llvm-nm"
NDK_READELF="${NDK_TOOLCHAIN}/llvm-readelf"

[[ -x "$NDK_CLANG" ]] \
    || die "NDK clang not found: $NDK_CLANG"

info "Target: Android $ANDROID_ABI ($ANDROID_CRYSTAL_TARGET)"

# ---------------------------------------------------------------------------
# Configuration (derived)
# ---------------------------------------------------------------------------

CRYSTAL_TARGET="$ANDROID_CRYSTAL_TARGET"
android_deps_select "$CROSS_DEPS" || exit 1
DEPS_DIR="$ANDROID_DEPS_DIR"
OUT_DIR="${BUILD_DIR}/android-${ANDROID_ABI_SLUG}"
OBJECT_FILE="${OUT_DIR}/${STEM}.o"
SO_FILE="${OUT_DIR}/lib${STEM}.so"
C_OBJECTS=()
ALL_C_SOURCES="$RUNTIME_C_SOURCES $EXTRA_C_SOURCES"

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

check_tool "$CRYSTAL"
CRYSTAL_VERSION="$($CRYSTAL --version | awk 'NR == 1 { print $2 }')"
[[ "$CRYSTAL_VERSION" == "$CRYSTAL_ANDROID_VERSION" ]] \
    || die "Android embedding is pinned to Crystal $CRYSTAL_ANDROID_VERSION (found $CRYSTAL_VERSION); review runtime startup before upgrading."

android_deps_validate "$DEPS_DIR" || exit 1
mkdir -p "$OUT_DIR"
cp "$DEPS_DIR/android-deps.manifest" "$OUT_DIR/$STEM.dependencies.manifest"
cp "$DEPS_DIR/files.sha256" "$OUT_DIR/$STEM.dependencies-files.sha256"

# ---------------------------------------------------------------------------
# Step 1: Crystal cross-compile -> object file
# ---------------------------------------------------------------------------

info "Step 1/2: Crystal cross-compile"
step "Source:  $SOURCE"
step "Target:  $CRYSTAL_TARGET"
step "Output:  $OBJECT_FILE"

CRYSTAL_PATH_VALUE="$($CRYSTAL env CRYSTAL_PATH)"
if [[ "$ANDROID_ABI" == "x86_64" ]]; then
    CRYSTAL_ANDROID_OVERLAY="$(CRYSTAL="$CRYSTAL" "$SCRIPT_DIR/prepare_crystal_android_libc.sh" "$OUT_DIR/crystal-stdlib-overlay")"
    CRYSTAL_PATH_VALUE="$CRYSTAL_ANDROID_OVERLAY:$CRYSTAL_PATH_VALUE"
    step "Crystal libc overlay: $CRYSTAL_ANDROID_OVERLAY"
fi

CRYSTAL_PATH="$CRYSTAL_PATH_VALUE" "$CRYSTAL" build "$SOURCE" \
    --cross-compile \
    --target "$CRYSTAL_TARGET" \
    $CRYSTAL_FLAGS \
    -o "${OUT_DIR}/${STEM}"

[[ -f "$OBJECT_FILE" ]] \
    || die "Crystal did not produce $OBJECT_FILE"

step "Object file produced:"
file "$OBJECT_FILE"

# ---------------------------------------------------------------------------
# Step 1.5: Compile extra C bridge sources
# ---------------------------------------------------------------------------

if [[ -n "$ALL_C_SOURCES" ]]; then
    info "Step 1.5/2: Compiling extra C sources"
    for source in $ALL_C_SOURCES; do
        [[ -f "$source" ]] || die "Extra C source not found: $source"
        obj_name="$(basename "${source%.*}")"
        obj_path="${OUT_DIR}/${obj_name}.o"
        step "Compiling: $source -> $obj_path"
        env -u CPPFLAGS -u CFLAGS -u CXXFLAGS -u LDFLAGS -u LIBRARY_PATH \
            -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u SDKROOT -u MACOSX_DEPLOYMENT_TARGET \
        "$NDK_CLANG" \
            --target="$CRYSTAL_TARGET" \
            -c \
            -fPIC \
            -I"${DEPS_DIR}/include" \
            $EXTRA_CFLAGS \
            "$source" \
            -o "$obj_path"
        C_OBJECTS+=("$obj_path")
    done
fi

# ---------------------------------------------------------------------------
# Step 2: Link with NDK clang -> .so
# ---------------------------------------------------------------------------

info "Step 2/2: Linking shared library"
step "Output:  $SO_FILE"

# -fPIC: Position-independent code required for shared libraries on Android.
# -Wl,--build-id: Adds a GNU build ID, required by Android's linker since API 23.
# -Wl,--no-undefined: Fail at link time if any symbol is unresolved.
# -Wl,-z,noexecstack: Security hardening required by the Play Store.
env -u CPPFLAGS -u CFLAGS -u CXXFLAGS -u LDFLAGS -u LIBRARY_PATH \
    -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u SDKROOT -u MACOSX_DEPLOYMENT_TARGET \
"$NDK_CLANG" \
    --target="$CRYSTAL_TARGET" \
    -shared \
    -fPIC \
    -o "$SO_FILE" \
    "$OBJECT_FILE" \
    "${C_OBJECTS[@]}" \
    "${DEPS_DIR}/lib/libgc.a" \
    "${DEPS_DIR}/lib/libpcre2-8.a" \
    -Wl,--build-id \
    -Wl,--no-undefined \
    -Wl,-z,noexecstack \
    -lc \
    -lm \
    -ldl \
    ${EXTRA_LINK_FLAGS}

step "Library produced:"
file "$SO_FILE"
ls -lh "$SO_FILE"

# ---------------------------------------------------------------------------
# Optional: strip debug symbols for release
# ---------------------------------------------------------------------------

if [[ "${STRIP:-0}" == "1" ]]; then
    step "Stripping debug symbols"
    "$NDK_STRIP" --strip-unneeded "$SO_FILE"
    ls -lh "$SO_FILE"
fi

# ---------------------------------------------------------------------------
# Verify JNI_OnLoad is exported (if present)
# ---------------------------------------------------------------------------

if [[ -x "$NDK_NM" ]]; then
    # Consume the full symbol stream. grep -q can close the pipe early, making
    # nm fail with SIGPIPE under pipefail and falsely report a missing symbol.
    if "$NDK_NM" --dynamic --defined-only "$SO_FILE" 2>/dev/null | awk '$3 == "JNI_OnLoad" { found = 1 } END { exit !found }'; then
        step "JNI_OnLoad symbol verified present in $SO_FILE"
    else
        step "Note: JNI_OnLoad not found. Add it to your source or a C bridge file."
    fi
fi

# ---------------------------------------------------------------------------
# Show Crystal-exported symbols
# ---------------------------------------------------------------------------

if [[ -x "$NDK_NM" ]]; then
    CRYSTAL_SYMBOLS=$("$NDK_NM" --defined-only --extern-only "$SO_FILE" 2>/dev/null \
        | grep -E "crystal_|^[0-9a-f]+ T crystal" | head -20 || true)
    if [[ -n "$CRYSTAL_SYMBOLS" ]]; then
        step "Crystal-exported symbols (first 20):"
        echo "$CRYSTAL_SYMBOLS" | while read -r line; do echo "     $line"; done
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "Build successful!"
echo ""
echo "  Library: $SO_FILE"
echo ""
echo "Android Studio integration:"
echo "  1. Copy $SO_FILE to app/src/main/jniLibs/${ANDROID_ABI}/"
echo "  2. In Kotlin/Java: System.loadLibrary(\"${STEM}\")"
echo "  3. Declare native methods with 'external' keyword in Kotlin"
echo "     (or 'native' in Java), matching the JNI naming convention:"
echo "     Java_<package_underscored>_<ClassName>_<methodName>"
echo ""
echo "JNI bridge template:"
echo "  samples/cross_platform/android_host/android_host_jni.c"
echo ""
echo "See CROSS_COMPILE.md for full integration guide."
