#!/usr/bin/env bash
# Shared Android SDK/NDK/JDK and ABI resolver. Source this file; do not execute
# it directly. Explicit environment variables always win over local defaults.

ANDROID_ENV_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_PROJECT_ROOT="$(cd "$ANDROID_ENV_SCRIPT_DIR/.." && pwd)"
# shellcheck source=../config/android_toolchain.env
source "$ANDROID_PROJECT_ROOT/config/android_toolchain.env"

android_die() {
    echo "ERROR: $*" >&2
    return 1
}

android_resolve_sdk_root() {
    local candidate
    for candidate in \
        "${ANDROID_SDK_ROOT:-}" \
        "${ANDROID_HOME:-}" \
        "/opt/homebrew/share/android-commandlinetools" \
        "${HOME:-}/Library/Android/sdk"; do
        if [[ -n "$candidate" && -x "$candidate/platform-tools/adb" ]]; then
            ANDROID_RESOLVED_SDK_ROOT="$candidate"
            return 0
        fi
    done
    android_die "Android SDK not found. Set ANDROID_SDK_ROOT to a directory containing platform-tools/adb."
}

android_resolve_ndk_home() {
    android_resolve_sdk_root || return 1
    # Prefer the first candidate whose Pkg.Revision matches the pin. CI hosts
    # export an ambient ANDROID_NDK_HOME for whatever NDK they preinstalled, so
    # an env value that does not match must not shadow the pinned SDK install.
    local candidate revision seen=""
    for candidate in \
        "${ANDROID_NDK_HOME:-}" \
        "${ANDROID_NDK_ROOT:-}" \
        "$ANDROID_RESOLVED_SDK_ROOT/ndk/$ANDROID_NDK_VERSION"; do
        [[ -n "$candidate" && -f "$candidate/source.properties" ]] || continue
        revision="$(awk -F '= *' '/^Pkg.Revision/ { print $2; exit }' "$candidate/source.properties")"
        if [[ "$revision" == "$ANDROID_NDK_VERSION" ]]; then
            ANDROID_RESOLVED_NDK_HOME="$candidate"
            return 0
        fi
        seen="$seen $candidate=$revision"
    done
    if [[ -n "$seen" ]]; then
        android_die "No NDK matching the pinned $ANDROID_NDK_VERSION; found:$seen. Install ndk;$ANDROID_NDK_VERSION or point ANDROID_NDK_HOME at it."
    else
        android_die "Android NDK $ANDROID_NDK_VERSION not found under $ANDROID_RESOLVED_SDK_ROOT/ndk. Install ndk;$ANDROID_NDK_VERSION or set ANDROID_NDK_HOME."
    fi
    return 1
}

android_resolve_ndk_host_tag() {
    android_resolve_ndk_home || return 1
    local tag
    for tag in darwin-arm64 darwin-x86_64 linux-x86_64; do
        if [[ -d "$ANDROID_RESOLVED_NDK_HOME/toolchains/llvm/prebuilt/$tag" ]]; then
            ANDROID_NDK_HOST_TAG="$tag"
            ANDROID_NDK_TOOLCHAIN="$ANDROID_RESOLVED_NDK_HOME/toolchains/llvm/prebuilt/$tag/bin"
            return 0
        fi
    done
    android_die "No supported NDK LLVM prebuilt was found under $ANDROID_RESOLVED_NDK_HOME."
}

android_resolve_java_home() {
    local candidate
    for candidate in \
        "${JAVA_HOME:-}" \
        "/Applications/Android Studio.app/Contents/jbr/Contents/Home"; do
        if [[ -n "$candidate" && -x "$candidate/bin/java" ]]; then
            ANDROID_RESOLVED_JAVA_HOME="$candidate"
            return 0
        fi
    done
    android_die "JDK $ANDROID_JAVA_VERSION not found. Set JAVA_HOME or install Android Studio."
}

android_configure_abi() {
    local abi="${1:-$ANDROID_DEFAULT_ABI}"
    local api="${2:-$ANDROID_NATIVE_API}"
    [[ "$api" =~ ^[1-9][0-9]*$ && "$api" -ge "$ANDROID_MIN_SDK" ]] || {
        android_die "Android API must be an integer >= $ANDROID_MIN_SDK (received '$api')"
        return 1
    }

    case "$abi" in
        arm64-v8a)
            ANDROID_ABI="$abi"
            ANDROID_ABI_SLUG="arm64"
            ANDROID_GNU_HOST="aarch64-linux-android"
            ANDROID_CRYSTAL_TARGET="aarch64-linux-android${api}"
            ANDROID_CMAKE_PROCESSOR="aarch64"
            ANDROID_ELF_MACHINE="AArch64"
            ;;
        x86_64)
            ANDROID_ABI="$abi"
            ANDROID_ABI_SLUG="x86_64"
            ANDROID_GNU_HOST="x86_64-linux-android"
            ANDROID_CRYSTAL_TARGET="x86_64-linux-android${api}"
            ANDROID_CMAKE_PROCESSOR="x86_64"
            ANDROID_ELF_MACHINE="Advanced Micro Devices X86-64"
            ;;
        *)
            android_die "Unsupported Android ABI '$abi'. Supported: $ANDROID_SUPPORTED_ABIS"
            return 1
            ;;
    esac

    ANDROID_API="$api"
    android_resolve_ndk_host_tag || return 1
    ANDROID_NDK_CLANG="$ANDROID_NDK_TOOLCHAIN/${ANDROID_GNU_HOST}${api}-clang"
    [[ -x "$ANDROID_NDK_CLANG" ]] \
        || android_die "NDK target compiler not found: $ANDROID_NDK_CLANG"
}

android_each_abi() {
    local list="${1:-$ANDROID_SUPPORTED_ABIS}"
    printf '%s\n' "$list" | tr ',' '\n' | sed '/^$/d'
}

# Inspect every member, not only the first: a mixed host/target archive can
# otherwise appear valid until the linker happens to need a poisoned member.
android_validate_archive() {
    local archive="$1" expected_symbol="$2" label="${3:-archive}"
    local members headers symbols count
    [[ -f "$archive" ]] || { android_die "$label not found: $archive"; return 1; }
    members="$("$ANDROID_NDK_TOOLCHAIN/llvm-ar" t "$archive")" || return 1
    count="$(printf '%s\n' "$members" | awk 'NF { n++ } END { print n+0 }')"
    [[ "$count" -gt 0 ]] || { android_die "$label archive has no members: $archive"; return 1; }
    headers="$("$ANDROID_NDK_TOOLCHAIN/llvm-readelf" -h "$archive")" \
        || { android_die "$label contains a non-ELF member: $archive"; return 1; }
    printf '%s\n' "$headers" | awk -F ': *' -v expected="$ANDROID_ELF_MACHINE" -v count="$count" \
        '/Machine:/ { n++; if ($2 != expected) wrong++ } END { exit(n != count || wrong > 0) }' \
        || { android_die "$label has wrong or mixed architectures: $archive"; return 1; }
    symbols="$("$ANDROID_NDK_TOOLCHAIN/llvm-nm" --defined-only --format=posix "$archive")" || return 1
    printf '%s\n' "$symbols" | awk -v symbol="$expected_symbol" \
        '$1 == symbol { found=1 } END { exit !found }' \
        || { android_die "$label is missing $expected_symbol: $archive"; return 1; }
    printf 'Validated %s: %s %s members\n' "$label" "$count" "$ANDROID_ELF_MACHINE"
}
