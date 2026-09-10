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
# The scan uses perl, present on every supported host, so a missing search
# tool cannot turn this gate into a silent pass: the previous ripgrep call
# exited 127 inside `if` and the branch that reports violations never ran.
raw_jni_pattern='\(\*env\)->(?!DeleteGlobalRef|DeleteLocalRef|ExceptionCheck|PopLocalFrame)'
scan_raw_jni() {
    perl -ne 'BEGIN { $pattern = shift @ARGV } print "$ARGV:$.: $_" if /$pattern/; close ARGV if eof' \
        "$raw_jni_pattern" "$@"
}
# Self-test first: the scanner must flag a known raw call and ignore a cleanup
# call, otherwise the gate is not actually running.
probe="$evidence/raw-jni-probe.c"
printf '%s\n' 'static void probe(JNIEnv *env, jobject o) { (*env)->NewGlobalRef(env, o); (*env)->DeleteGlobalRef(env, o); }' > "$probe"
probe_hits="$(scan_raw_jni "$probe")"
[[ "$(printf '%s\n' "$probe_hits" | grep -c 'NewGlobalRef')" == 1 ]] || { echo 'JNI guard self-test failed: scanner did not flag a raw call' >&2; exit 1; }
[[ "$(printf '%s\n' "$probe_hits" | grep -c 'DeleteGlobalRef')" == 1 ]] || { echo 'JNI guard self-test failed: cleanup exclusion changed' >&2; exit 1; }
bridge_hits="$(scan_raw_jni "$script_dir/../../src/ui/native/android_bridge.c" "$script_dir/../../src/ui/native/jni_collection_bridge.c")"
if [[ -n "$bridge_hits" ]]; then
    printf '%s\n' "$bridge_hits" >&2
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
