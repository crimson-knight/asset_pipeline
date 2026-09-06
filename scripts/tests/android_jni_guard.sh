#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
source "$script_dir/../android_env.sh"
evidence="${1:-$(mktemp -d /tmp/ap-jni-guard.XXXXXX)}"
mkdir -p "$evidence"
android_resolve_ndk_home
android_resolve_ndk_host_tag
# Structural gate: new raw calls must be reviewed as cleanup/exception work,
# rather than silently bypassing the shared checked-operation layer.
if rg -n '\(\*env\)->(?!DeleteGlobalRef|DeleteLocalRef|ExceptionCheck|PopLocalFrame)' --pcre2 \
    "$script_dir/../../src/ui/native/android_bridge.c" "$script_dir/../../src/ui/native/jni_collection_bridge.c"; then
    echo 'Unchecked non-cleanup JNI invocation in a view/collection bridge' >&2; exit 1
fi
mkdir -p "$evidence/include"
# The NDK JNI declaration is VM-neutral and includes only standard host headers.
# Copy just this pinned header, not the Android libc/sysroot include directory.
cp "$ANDROID_RESOLVED_NDK_HOME/toolchains/llvm/prebuilt/$ANDROID_NDK_HOST_TAG/sysroot/usr/include/jni.h" "$evidence/include/jni.h"
"${ANDROID_HOST_CC:-cc}" -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined \
    -I"$evidence/include" \
    "$script_dir/android_jni_guard.c" -o "$evidence/jni-guard-test"
"$evidence/jni-guard-test" | tee "$evidence/result.txt"
