#!/usr/bin/env bash
# Source-only dependency contract shared by the builder and native linker.
# No manifest is evaluated as shell code.
ANDROID_DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ANDROID_DEPS_SCRIPT_DIR/android_env.sh"

android_sha256() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{ print $1 }'
    else
        sha256sum "$1" | awk '{ print $1 }'
    fi
}

android_sha256_stream() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{ print $1 }'
    else
        sha256sum | awk '{ print $1 }'
    fi
}

android_deps_contract() {
    local tool libtoolize
    libtoolize="$(command -v glibtoolize || command -v libtoolize)" || {
        android_die "GNU libtoolize is required for Android dependency builds"; return 1;
    }
    printf '%s\n' \
        'format=asset-pipeline-android-deps-v2' \
        "abi=$ANDROID_ABI" "target=$ANDROID_CRYSTAL_TARGET" "api=$ANDROID_API" \
        "ndk_revision=$ANDROID_NDK_VERSION" "ndk_host_tag=$ANDROID_NDK_HOST_TAG" \
        "bdwgc_version=$BDWGC_ANDROID_VERSION" "bdwgc_commit=$BDWGC_ANDROID_COMMIT" \
        "bdwgc_source_sha256=$BDWGC_ANDROID_SOURCE_SHA256" \
        "atomic_ops_version=$ATOMIC_OPS_ANDROID_VERSION" "atomic_ops_commit=$ATOMIC_OPS_ANDROID_COMMIT" \
        "atomic_ops_source_sha256=$ATOMIC_OPS_ANDROID_SOURCE_SHA256" \
        "pcre2_version=$PCRE2_ANDROID_VERSION" "pcre2_commit=$PCRE2_ANDROID_COMMIT" \
        "pcre2_source_sha256=$PCRE2_ANDROID_SOURCE_SHA256" \
        "source_date_epoch=$ANDROID_DEPS_SOURCE_DATE_EPOCH" \
        'environment=clean;LC_ALL=C;TZ=UTC;CONFIG_SITE=/dev/null' \
        'cflags=-O2 -fPIC -ffile-prefix-map=<work>=/usr/src/asset-pipeline-android -fdebug-prefix-map=<work>=/usr/src/asset-pipeline-android' \
        'gc_configure=--enable-static --disable-shared --disable-docs --enable-large-config --enable-threads=posix --with-libatomic-ops=none' \
        'pcre2_cmake=Unix Makefiles;Release;static;8bit;no16bit;no32bit;noJIT;noTests;noGrep'
    for tool in clang llvm-ar llvm-ranlib llvm-strip llvm-nm llvm-readelf; do
        [[ -x "$ANDROID_NDK_TOOLCHAIN/$tool" ]] || return 1
        printf 'ndk_%s_sha256=%s\n' "$tool" "$(android_sha256 "$ANDROID_NDK_TOOLCHAIN/$tool")"
    done
    for tool in cmake make autoconf automake autoreconf; do
        command -v "$tool" >/dev/null || { android_die "Required build tool missing: $tool"; return 1; }
        printf '%s_version=%s\n' "$tool" "$("$tool" --version | awk 'NR == 1 { print }')"
    done
    printf 'libtoolize_version=%s\n' "$("$libtoolize" --version | awk 'NR == 1 { print }')"
    for tool in android_deps.sh build_android_deps.sh android_env.sh; do
        printf 'recipe_%s_sha256=%s\n' "$tool" "$(android_sha256 "$ANDROID_DEPS_SCRIPT_DIR/$tool")"
    done
}

android_deps_select() {
    local root="$1"
    [[ -d "$root" ]] || { android_die "Android dependency root does not exist: $root"; return 1; }
    root="$(cd "$root" && pwd -P)"
    ANDROID_DEPS_CONTRACT="$(android_deps_contract)" || return 1
    ANDROID_DEPS_KEY="$(printf '%s\n' "$ANDROID_DEPS_CONTRACT" | android_sha256_stream)"
    ANDROID_DEPS_DIR="$root/android/$ANDROID_ABI/api-$ANDROID_API/$ANDROID_DEPS_KEY"
}

android_deps_files_manifest() (
    cd "$1" || exit 1
    # Generate the file list ourselves. Never trust paths read from a manifest.
    for dir in lib include licenses; do
        [[ -d "$dir" && ! -L "$dir" ]] || exit 1
        [[ -z "$(find "$dir" ! -type f ! -type d -print)" ]] || exit 1
    done
    find lib include licenses -type f -print | LC_ALL=C sort |
        while IFS= read -r file; do
            printf '%s  %s\n' "$(android_sha256 "$file")" "$file"
        done
)

android_deps_manifest() {
    printf '%s\n' "$ANDROID_DEPS_CONTRACT"
    printf 'contract_sha256=%s\n' "$ANDROID_DEPS_KEY"
    printf 'files_manifest_sha256=%s\n' "$(android_sha256 "$1/files.sha256")"
}

android_deps_validate() {
    local prefix="$1" library symbol
    [[ -d "$prefix" && ! -L "$prefix" ]] || {
        android_die "Verified Android dependency bundle missing: $prefix. Run cross_compile_deps.sh android; legacy flat caches are not accepted."
        return 1
    }
    [[ -f "$prefix/android-deps.manifest" && -f "$prefix/files.sha256" ]] || {
        android_die "Incomplete Android dependency bundle: $prefix"; return 1;
    }
    cmp -s "$prefix/android-deps.manifest" <(android_deps_manifest "$prefix") || {
        android_die "Stale or mismatched Android dependency contract: $prefix"; return 1;
    }
    local actual_files
    actual_files="$(android_deps_files_manifest "$prefix")" || {
        android_die "Invalid Android dependency payload: $prefix"; return 1;
    }
    cmp -s "$prefix/files.sha256" <(printf '%s\n' "$actual_files") || {
        android_die "Android dependency checksum mismatch: $prefix (retained for inspection)"; return 1;
    }
    [[ -f "$prefix/include/gc/gc.h" && -f "$prefix/include/pcre2.h" ]] || {
        android_die "Android dependency headers are missing"; return 1;
    }
    for library in libgc.a libcord.a libpcre2-8.a libpcre2-posix.a; do
        case "$library" in
            libgc.a) symbol=GC_init ;;
            libcord.a) symbol=CORD_len ;;
            libpcre2-8.a) symbol=pcre2_compile_8 ;;
            libpcre2-posix.a) symbol=pcre2_regcomp ;;
        esac
        android_validate_archive "$prefix/lib/$library" "$symbol" "$library" || return 1
    done
}
