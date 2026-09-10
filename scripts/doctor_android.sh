#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=android_env.sh
source "$SCRIPT_DIR/android_env.sh"

REQUIRE_DEVICE=0
TARGET_SERIAL=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --require-device) REQUIRE_DEVICE=1; shift ;;
        --serial)
            [[ $# -ge 2 && -n "$2" ]] || { echo "--serial requires an ADB target" >&2; exit 2; }
            TARGET_SERIAL="$2"; REQUIRE_DEVICE=1; shift 2 ;;
        *) echo "Usage: $0 [--require-device] [--serial <adb-serial>]" >&2; exit 2 ;;
    esac
done

pass() { printf '[pass] %s\n' "$*"; }
warn() { printf '[warn] %s\n' "$*"; }
fail() { printf '[fail] %s\n' "$*" >&2; exit 1; }

for tool in git cmake make tar autoconf automake autoreconf; do
    command -v "$tool" >/dev/null 2>&1 || fail "Required Android dependency build tool is missing: $tool"
done
command -v glibtoolize >/dev/null 2>&1 || command -v libtoolize >/dev/null 2>&1 \
    || fail "GNU libtoolize is missing (glibtoolize on Homebrew)"
pass "Native dependency build tools: Git, CMake, Make, tar, Autoconf, Automake, Libtool"

android_resolve_sdk_root || exit 1
android_resolve_ndk_home || exit 1
android_resolve_ndk_host_tag || exit 1
android_resolve_java_home || exit 1

ADB="$ANDROID_RESOLVED_SDK_ROOT/platform-tools/adb"
pass "SDK: $ANDROID_RESOLVED_SDK_ROOT"

NDK_REVISION="$(awk -F '= *' '/Pkg.Revision/ { print $2; exit }' "$ANDROID_RESOLVED_NDK_HOME/source.properties")"
[[ "$NDK_REVISION" == "$ANDROID_NDK_VERSION" ]] \
    || fail "NDK revision is $NDK_REVISION; expected $ANDROID_NDK_VERSION"
pass "NDK: $NDK_REVISION ($ANDROID_NDK_HOST_TAG)"

JAVA_VERSION_OUTPUT="$("$ANDROID_RESOLVED_JAVA_HOME/bin/java" -version 2>&1 | head -1)"
[[ "$JAVA_VERSION_OUTPUT" == *\"${ANDROID_JAVA_VERSION}.* ]] \
    || fail "JDK does not match required major $ANDROID_JAVA_VERSION: $JAVA_VERSION_OUTPUT"
pass "JDK: $JAVA_VERSION_OUTPUT"

CRYSTAL_VERSION_OUTPUT="$(crystal --version | awk 'NR == 1 { print $2 }')"
[[ "$CRYSTAL_VERSION_OUTPUT" == "$CRYSTAL_ANDROID_VERSION" ]] \
    || fail "Crystal is $CRYSTAL_VERSION_OUTPUT; expected $CRYSTAL_ANDROID_VERSION"
pass "Crystal: $CRYSTAL_VERSION_OUTPUT"

[[ -d "$ANDROID_RESOLVED_SDK_ROOT/platforms/android-$ANDROID_COMPILE_SDK" ]] \
    || fail "Android platform $ANDROID_COMPILE_SDK is not installed"
pass "Android platform: $ANDROID_COMPILE_SDK"
[[ -x "$ANDROID_RESOLVED_SDK_ROOT/build-tools/$ANDROID_BUILD_TOOLS_VERSION/aapt2" ]] \
    || fail "Android Build Tools $ANDROID_BUILD_TOOLS_VERSION are not installed"
pass "Android Build Tools: $ANDROID_BUILD_TOOLS_VERSION"

while IFS= read -r abi; do
    android_configure_abi "$abi" "$ANDROID_NATIVE_API" || exit 1
    pass "ABI compiler: $abi -> $(basename "$ANDROID_NDK_CLANG")"
done < <(android_each_abi)

DEVICE_LINES="$($ADB devices -l | awk 'NR > 1 && NF { print }')"
if [[ -n "$TARGET_SERIAL" ]]; then
    DEVICE_LINES="$(printf '%s\n' "$DEVICE_LINES" | awk -v serial="$TARGET_SERIAL" '$1 == serial { print }')"
    [[ -n "$DEVICE_LINES" ]] || fail "Selected ADB target is not connected: $TARGET_SERIAL"
fi
if [[ -z "$DEVICE_LINES" ]]; then
    if [[ "$REQUIRE_DEVICE" -eq 1 ]]; then
        fail "No Android device or emulator is connected"
    fi
    warn "No Android device or emulator is connected; compile/package prerequisites are ready"
elif printf '%s\n' "$DEVICE_LINES" | awk '$2 == "unauthorized" { found = 1 } END { exit !found }'; then
    fail "An Android device is unauthorized; unlock it and accept the USB debugging RSA prompt"
elif printf '%s\n' "$DEVICE_LINES" | awk '$2 == "offline" { found = 1 } END { exit !found }'; then
    fail "An Android device or emulator is offline"
elif ! printf '%s\n' "$DEVICE_LINES" | awk '$2 == "device" { found = 1 } END { exit !found }'; then
    fail "ADB sees devices, but none are ready: $DEVICE_LINES"
else
    pass "ADB target(s): $(printf '%s\n' "$DEVICE_LINES" | awk '$2 == "device" { printf "%s%s", separator, $1; separator="," }')"
fi

pass "Android toolchain is ready"
