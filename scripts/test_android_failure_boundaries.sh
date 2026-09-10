#!/usr/bin/env bash
# Deliberate application errors run separately from the clean runtime lane.
# Each process is terminal after one error; never add a production reset hook.
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
source "$script_dir/android_env.sh"
[[ $# == 2 ]] || { echo "Usage: $0 <adb-serial> <evidence-directory>" >&2; exit 2; }
serial="$1"
mkdir -p "$2"
evidence="$(cd "$2" && pwd)"
fail() { echo "ERROR: $* (evidence: $evidence)" >&2; exit 1; }
android_resolve_sdk_root
adb="$ANDROID_RESOLVED_SDK_ROOT/platform-tools/adb"

bash "$script_dir/run_android_smoke.sh" "$serial" "$evidence/positive"
for kind in 1 2 3 4 5 6; do
    report="$evidence/failure-$kind.txt"
    "$adb" -s "$serial" shell am instrument -w -r \
        -e class dev.assetpipeline.androidhost.AndroidFailureBoundaryTest \
        -e failure_kind "$kind" \
        dev.assetpipeline.androidhost.test/androidx.test.runner.AndroidJUnitRunner > "$report" 2>&1 \
        || fail "Failure-case instrumentation command failed: $kind"
    pid="$(sed -n 's/^INSTRUMENTATION_STATUS: failure_process=//p' "$report" | tr -d '\r')"
    [[ "$pid" =~ ^[0-9]+$ ]] || fail "Missing exact failure-process evidence: $kind"
    "$adb" -s "$serial" logcat -d -v threadtime --pid="$pid" > "$evidence/failure-$kind-logcat.txt"
    grep -Eq '^OK \(1 test\)' "$report" || fail "Deliberate-failure test did not pass: $kind"
    grep -q '^INSTRUMENTATION_CODE: -1' "$report" || fail "Incomplete failure-case protocol: $kind"
    grep -q "^INSTRUMENTATION_STATUS: failure_kind=$kind" "$report" || fail "Wrong failure case ran"
    if grep -Eq 'Process crashed|FAILURES!!!|INSTRUMENTATION_FAILED|INSTRUMENTATION_STATUS_CODE: -[1234]' "$report"; then
        fail "Failure-case runner reported failure or skip: $kind"
    fi
    if grep -Eq 'JNI DETECTED ERROR|FATAL EXCEPTION|Fatal signal|Cannot enter Crystal|Crystal (bootstrap|render) error' "$evidence/failure-$kind-logcat.txt"; then
        fail "A contained error became a native/JVM runtime failure: $kind"
    fi
    grep -q 'Crystal runtime ready (probe=42)' "$evidence/failure-$kind-logcat.txt" || fail "Missing runtime proof: $kind"
    grep -q 'Late-enabling -Xcheck:jni' "$evidence/failure-$kind-logcat.txt" || fail "Missing CheckJNI proof: $kind"
    if [[ "$kind" == 6 ]]; then
        grep -q 'Crystal application error:.*AndroidFailureFixture::ExpectedRenderFailure' "$evidence/failure-$kind-logcat.txt" \
            || fail "Missing deliberate render-failure diagnostic"
        [[ "$(grep -c 'Crystal application error:' "$evidence/failure-$kind-logcat.txt")" == 1 ]] \
            || fail "Unexpected extra application error in render case"
        if grep -q 'Crystal .*callback failed' "$evidence/failure-$kind-logcat.txt"; then fail "Unexpected callback error in render case"; fi
    else
        callback_kinds=(unused void string bool float int)
        grep -Fq "Crystal ${callback_kinds[$kind]} callback failed (AndroidFailureFixture::ExpectedCallbackFailure)" "$evidence/failure-$kind-logcat.txt" \
            || fail "Missing contained callback diagnostic: $kind"
        [[ "$(grep -c 'Crystal .*callback failed' "$evidence/failure-$kind-logcat.txt")" == 1 ]] \
            || fail "Unexpected extra callback error: $kind"
        if grep -q 'Crystal application error' "$evidence/failure-$kind-logcat.txt"; then fail "Unexpected application error in callback case: $kind"; fi
    fi
    if grep -q 'private-android-callback-' "$evidence/failure-$kind-logcat.txt"; then
        fail "Private callback data leaked into diagnostics: $kind"
    fi
    echo "PASS: failure kind $kind contained, reuse rejected, 100 partial renders cleaned, final native counts zero"
done

# Leave an ordinary, clean process mounted, not the deliberate FAILED session.
"$adb" -s "$serial" shell am start -S -W -n dev.assetpipeline.androidhost/.MainActivity \
    --es study_slug interaction-smoke > "$evidence/relaunch.txt"
"$adb" -s "$serial" shell uiautomator dump /sdcard/android-failure-boundary-relaunch.xml > /dev/null
"$adb" -s "$serial" pull /sdcard/android-failure-boundary-relaunch.xml "$evidence/relaunch-ui.xml" > /dev/null
grep -q 'Renderer mount live' "$evidence/relaunch-ui.xml" || fail "Post-failure ordinary process did not mount"
relaunch_pid="$("$adb" -s "$serial" shell pidof dev.assetpipeline.androidhost | tr -d '\r')"
[[ "$relaunch_pid" =~ ^[0-9]+$ ]] || fail "Post-failure ordinary process is not alive"
printf '%s\n' "$relaunch_pid" > "$evidence/relaunch-pid.txt"
"$adb" -s "$serial" logcat -d -v threadtime --pid="$relaunch_pid" > "$evidence/relaunch-logcat.txt"
grep -q 'Crystal runtime ready (probe=42)' "$evidence/relaunch-logcat.txt" || fail "Missing clean relaunch runtime proof"
grep -q 'Late-enabling -Xcheck:jni' "$evidence/relaunch-logcat.txt" || fail "Missing clean relaunch CheckJNI proof"
if grep -Eq 'JNI DETECTED ERROR|FATAL EXCEPTION|Fatal signal|Cannot enter Crystal|Crystal (bootstrap|render|application) error|Crystal .*callback failed' "$evidence/relaunch-logcat.txt"; then
    fail "Ordinary relaunch contains a runtime failure"
fi
"$adb" -s "$serial" exec-out screencap -p > "$evidence/relaunch.png"
echo "PASS: clean runtime regression and all six isolated failure boundaries" | tee "$evidence/result.txt"
