#!/usr/bin/env bash
# Immutable, ABI/API/toolchain/recipe-keyed Android dependency bundles.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/android_deps.sh"

build_payload() {
    local work="$1" prefix="$2" jobs="$3"
    local source="$work/source" gc_build="$work/build/gc" pcre_build="$work/build/pcre2"
    local flags="-O2 -fPIC -ffile-prefix-map=$work=/usr/src/asset-pipeline-android -fdebug-prefix-map=$work=/usr/src/asset-pipeline-android"
    mkdir -p "$gc_build" "$pcre_build"
    (cd "$source/bdwgc" && ./autogen.sh)
    (
        cd "$gc_build"
        "$source/bdwgc/configure" --host="$ANDROID_GNU_HOST" --prefix="$prefix" \
            --enable-static --disable-shared --disable-docs --enable-large-config \
            --enable-threads=posix --with-libatomic-ops=none \
            CC="$ANDROID_NDK_CLANG" CXX="${ANDROID_NDK_CLANG}++" CFLAGS="$flags" CXXFLAGS="$flags" \
            AR="$ANDROID_NDK_TOOLCHAIN/llvm-ar" RANLIB="$ANDROID_NDK_TOOLCHAIN/llvm-ranlib" \
            NM="$ANDROID_NDK_TOOLCHAIN/llvm-nm" STRIP="$ANDROID_NDK_TOOLCHAIN/llvm-strip"
        make -j"$jobs"
        make install
    )
    cmake -S "$source/pcre2" -B "$pcre_build" -G "Unix Makefiles" \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_RESOLVED_NDK_HOME/build/cmake/android.toolchain.cmake" \
        -DCMAKE_MAKE_PROGRAM="$(command -v make)" \
        -DANDROID_NDK="$ANDROID_RESOLVED_NDK_HOME" -DANDROID_ABI="$ANDROID_ABI" \
        -DANDROID_PLATFORM="android-$ANDROID_API" -DCMAKE_INSTALL_PREFIX="$prefix" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="$flags" -DCMAKE_C_FLAGS_RELEASE="-DNDEBUG" \
        -DCMAKE_AR="$ANDROID_NDK_TOOLCHAIN/llvm-ar" -DCMAKE_RANLIB="$ANDROID_NDK_TOOLCHAIN/llvm-ranlib" \
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF \
        -DBUILD_SHARED_LIBS=OFF -DPCRE2_BUILD_PCRE2_8=ON -DPCRE2_BUILD_PCRE2_16=OFF \
        -DPCRE2_BUILD_PCRE2_32=OFF -DPCRE2_BUILD_TESTS=OFF -DPCRE2_BUILD_PCRE2GREP=OFF -DPCRE2_SUPPORT_JIT=OFF
    cmake --build "$pcre_build" -j"$jobs"
    cmake --install "$pcre_build"
}

if [[ "${1:-}" == --payload ]]; then
    # Re-entered under env -i; compiler flags, SDK paths, configure-site and
    # cache variables from the caller cannot poison either native build.
    android_configure_abi "$2" "$3"
    build_payload "$4" "$5" "$6"
    exit 0
fi

[[ $# == 1 ]] || { echo "Usage: BUILD_DIR=<cache-root> $0 <arm64-v8a|x86_64>" >&2; exit 2; }
for tool in git cmake make autoconf automake autoreconf tar; do
    command -v "$tool" >/dev/null || { android_die "Missing build prerequisite: $tool"; exit 1; }
done
for pair in "BDWGC_VERSION:$BDWGC_ANDROID_VERSION" "ATOMIC_OPS_VERSION:$ATOMIC_OPS_ANDROID_VERSION" "PCRE2_VERSION:$PCRE2_ANDROID_VERSION"; do
    variable="${pair%%:*}"
    expected="${pair#*:}"
    [[ -z "${!variable:-}" || "${!variable}" == "$expected" ]] || {
        android_die "$variable overrides are not supported for Android; update the reviewed source/toolchain pins"; exit 1;
    }
done
android_configure_abi "$1" "${ANDROID_API:-$ANDROID_NATIVE_API}"
root="${BUILD_DIR:-/tmp/crystal-cross-deps}"
mkdir -p "$root"
root="$(cd "$root" && pwd -P)"
android_deps_select "$root"
if [[ -e "$ANDROID_DEPS_DIR" ]]; then
    android_deps_validate "$ANDROID_DEPS_DIR"
    echo "Verified Android dependency cache hit: $ANDROID_DEPS_DIR"
    exit 0
fi

mkdir -p "$(dirname "$ANDROID_DEPS_DIR")" "$root/downloads" "$root/work"
lock="$ANDROID_DEPS_DIR.lock"
mkdir "$lock" || { android_die "Another builder owns $lock; do not delete a live build lock"; exit 1; }
trap 'rmdir "$lock"' EXIT
# Another builder may have published after our first existence check but before
# this lock was acquired. Never nest a second payload inside an existing bundle.
if [[ -e "$ANDROID_DEPS_DIR" ]]; then
    android_deps_validate "$ANDROID_DEPS_DIR"
    echo "Verified concurrently completed Android bundle: $ANDROID_DEPS_DIR"
    exit 0
fi
work="$(mktemp -d "$root/work/$ANDROID_ABI-api-$ANDROID_API.XXXXXX")"
echo "Fresh Android dependency build (PID $$): $work"

fetch_source() {
    local name="$1" url="$2" tag="$3" commit="$4" checksum="$5"
    local archive="$root/downloads/$name-$commit.tar"
    if [[ -f "$archive" ]]; then
        [[ "$(android_sha256 "$archive")" == "$checksum" ]] || {
            android_die "Cached source checksum mismatch: $archive (retained)"; return 1;
        }
    else
        local checkout="$work/download-$name"
        git clone --depth 1 --branch "$tag" "$url" "$checkout"
        [[ "$(git -C "$checkout" rev-parse HEAD)" == "$commit" ]] || {
            android_die "Upstream $name tag $tag no longer matches pinned commit $commit"; return 1;
        }
        git -C "$checkout" -c tar.umask=0022 archive --format=tar "$commit" > "$work/$name.tar"
        [[ "$(android_sha256 "$work/$name.tar")" == "$checksum" ]] || {
            android_die "Pinned $name source archive checksum mismatch"; return 1;
        }
        mv "$work/$name.tar" "$archive"
    fi
    mkdir -p "$work/source/$name"
    tar -xf "$archive" -C "$work/source/$name"
}
fetch_source bdwgc https://github.com/ivmai/bdwgc.git "v$BDWGC_ANDROID_VERSION" "$BDWGC_ANDROID_COMMIT" "$BDWGC_ANDROID_SOURCE_SHA256"
fetch_source atomic_ops https://github.com/ivmai/libatomic_ops.git "v$ATOMIC_OPS_ANDROID_VERSION" "$ATOMIC_OPS_ANDROID_COMMIT" "$ATOMIC_OPS_ANDROID_SOURCE_SHA256"
fetch_source pcre2 https://github.com/PCRE2Project/pcre2.git "pcre2-$PCRE2_ANDROID_VERSION" "$PCRE2_ANDROID_COMMIT" "$PCRE2_ANDROID_SOURCE_SHA256"
# The pinned modern Clang build uses compiler atomics explicitly. Keep the
# separately pinned atomic_ops source/licence in the recipe, without accidentally
# discovering an unrelated host install through configure.
mkdir -p "$work/install" "$work/tmp"
jobs="${JOBS:-4}"
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { android_die "JOBS must be a positive integer"; exit 1; }
libtoolize="$(command -v glibtoolize || command -v libtoolize)"
env -i PATH="$PATH" HOME="$HOME" TMPDIR="$work/tmp" LC_ALL=C TZ=UTC LIBTOOLIZE="$libtoolize" \
    CONFIG_SITE=/dev/null SOURCE_DATE_EPOCH="$ANDROID_DEPS_SOURCE_DATE_EPOCH" \
    ANDROID_SDK_ROOT="$ANDROID_RESOLVED_SDK_ROOT" ANDROID_NDK_HOME="$ANDROID_RESOLVED_NDK_HOME" \
    bash "$SCRIPT_DIR/build_android_deps.sh" --payload "$ANDROID_ABI" "$ANDROID_API" "$work" "$work/install" "$jobs" \
    > "$work/build.log" 2>&1 || { tail -80 "$work/build.log" >&2; android_die "Native dependency build failed; full log: $work/build.log"; exit 1; }

# Only the supported link/header payload is published. Autotools/CMake metadata
# contains temporary absolute install paths and is not a relocatable SDK.
payload="$work/payload"
mkdir -p "$payload/lib" "$payload/include" "$payload/licenses"
cp "$work/install/lib/libgc.a" "$work/install/lib/libcord.a" "$work/install/lib/libpcre2-8.a" "$work/install/lib/libpcre2-posix.a" "$payload/lib/"
cp -R "$work/install/include/." "$payload/include/"
cp "$work/source/bdwgc/README.QUICK" "$payload/licenses/bdwgc.txt"
cp "$work/source/atomic_ops/COPYING" "$payload/licenses/atomic_ops.txt"
cp "$work/source/pcre2/LICENCE" "$payload/licenses/pcre2.txt"
android_deps_files_manifest "$payload" > "$payload/files.sha256"
android_deps_manifest "$payload" > "$payload/android-deps.manifest"
android_deps_validate "$payload"
# One same-filesystem rename publishes the completed, verified bundle. Failures
# leave only a work directory, never a partially usable cache entry.
mv "$payload" "$ANDROID_DEPS_DIR"
echo "Built and verified Android dependencies: $ANDROID_DEPS_DIR"
echo "Build log retained at $work/build.log"
