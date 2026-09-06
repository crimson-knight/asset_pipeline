#!/usr/bin/env bash
# Complete clean/Crystal-failure regression, then genuine Java failures in a
# separate terminal session. Keep intentional failures out of the clean lane.
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
bash "$script_dir/test_android_failure_boundaries.sh" "$serial" "$evidence/crystal-failures"

"$adb" -s "$serial" shell am instrument -w -r \
  -e class dev.assetpipeline.androidhost.AndroidJavaFailureBoundaryTest \
  dev.assetpipeline.androidhost.test/androidx.test.runner.AndroidJUnitRunner > "$evidence/java-instrumentation.txt" 2>&1 \
  || fail "Java failure instrumentation command failed"
pid="$(sed -n 's/^INSTRUMENTATION_STATUS: java_failure_process=//p' "$evidence/java-instrumentation.txt" | tr -d '\r')"
[[ "$pid" =~ ^[0-9]+$ ]] || fail "Missing exact Java failure process"
"$adb" -s "$serial" logcat -d -v threadtime --pid="$pid" > "$evidence/java-logcat.txt"
grep -q '^OK (1 test)' "$evidence/java-instrumentation.txt" || fail "Java failure test did not pass"
grep -q '^INSTRUMENTATION_CODE: -1' "$evidence/java-instrumentation.txt" || fail "Incomplete instrumentation protocol"
grep -q '^INSTRUMENTATION_STATUS: java_failure_probes=400' "$evidence/java-instrumentation.txt" || fail "Missing repeated-failure proof"
if grep -Eq 'Process crashed|FAILURES!!!|INSTRUMENTATION_FAILED|INSTRUMENTATION_STATUS_CODE: -[1234]' "$evidence/java-instrumentation.txt"; then fail "Java test failed or skipped"; fi
if grep -Eq 'JNI DETECTED ERROR|FATAL EXCEPTION|Fatal signal|Cannot enter Crystal|Crystal (bootstrap|render) error|Crystal .*callback failed|private-java-' "$evidence/java-logcat.txt"; then fail "Java failure escaped containment or exposed private data"; fi
grep -q 'Crystal runtime ready (probe=42)' "$evidence/java-logcat.txt" || fail "Missing initialized runtime"
grep -q 'Late-enabling -Xcheck:jni' "$evidence/java-logcat.txt" || fail "Missing CheckJNI"
grep -q 'Crystal application error: UI::Android::PendingJavaException' "$evidence/java-logcat.txt" || fail "Missing contained public-render diagnostic"
[[ "$(grep -c 'Crystal application error:' "$evidence/java-logcat.txt")" == 1 ]] || fail "Unexpected extra application error"

# Post-layout/window work also executes outside the original JNI render call.
# Verify its terminal cleanup while a real custom-content sheet is mounted.
"$adb" -s "$serial" shell am instrument -w -r \
  -e class dev.assetpipeline.androidhost.AndroidSheetFailureBoundaryTest \
  dev.assetpipeline.androidhost.test/androidx.test.runner.AndroidJUnitRunner > "$evidence/sheet-failure-instrumentation.txt" 2>&1 \
  || fail "Sheet failure instrumentation command failed"
sheet_pid="$(sed -n 's/^INSTRUMENTATION_STATUS: sheet_failure_process=//p' "$evidence/sheet-failure-instrumentation.txt" | tr -d '\r')"
[[ "$sheet_pid" =~ ^[0-9]+$ && "$sheet_pid" != "$pid" ]] || fail "Missing separate sheet failure process"
"$adb" -s "$serial" logcat -d -v threadtime --pid="$sheet_pid" > "$evidence/sheet-failure-logcat.txt"
grep -q '^OK (1 test)' "$evidence/sheet-failure-instrumentation.txt" || fail "Sheet failure test did not pass"
grep -q '^INSTRUMENTATION_CODE: -1' "$evidence/sheet-failure-instrumentation.txt" || fail "Incomplete sheet failure protocol"
if grep -Eq 'Process crashed|FAILURES!!!|INSTRUMENTATION_FAILED|INSTRUMENTATION_STATUS_CODE: -[1234]' "$evidence/sheet-failure-instrumentation.txt"; then fail "Sheet failure test failed or skipped"; fi
if grep -Eq 'JNI DETECTED ERROR|FATAL EXCEPTION|Fatal signal|Cannot enter Crystal|Crystal (bootstrap|render|application) error|Crystal .*callback failed|private-sheet-' "$evidence/sheet-failure-logcat.txt"; then fail "Sheet window failure escaped containment or exposed private data"; fi
grep -q 'Crystal runtime ready (probe=42)' "$evidence/sheet-failure-logcat.txt" || fail "Missing sheet runtime proof"
grep -q 'Late-enabling -Xcheck:jni' "$evidence/sheet-failure-logcat.txt" || fail "Missing sheet CheckJNI proof"

"$adb" -s "$serial" shell am start -S -W -n dev.assetpipeline.androidhost/.MainActivity \
  --es study_slug interaction-smoke > "$evidence/relaunch.txt"
"$adb" -s "$serial" shell uiautomator dump /sdcard/ap-java-failure-relaunch.xml > /dev/null
"$adb" -s "$serial" pull /sdcard/ap-java-failure-relaunch.xml "$evidence/relaunch-ui.xml" > /dev/null
grep -q 'Renderer mount live' "$evidence/relaunch-ui.xml" || fail "Normal post-failure app did not mount"
relaunch_pid="$("$adb" -s "$serial" shell pidof dev.assetpipeline.androidhost | tr -d '\r')"
[[ "$relaunch_pid" =~ ^[0-9]+$ && "$relaunch_pid" != "$pid" && "$relaunch_pid" != "$sheet_pid" ]] || fail "No fresh normal process"
printf '%s\n' "$relaunch_pid" > "$evidence/relaunch-pid.txt"
"$adb" -s "$serial" logcat -d -v threadtime --pid="$relaunch_pid" > "$evidence/relaunch-logcat.txt"
grep -q 'Crystal runtime ready (probe=42)' "$evidence/relaunch-logcat.txt" || fail "Missing normal runtime proof"
grep -q 'Late-enabling -Xcheck:jni' "$evidence/relaunch-logcat.txt" || fail "Missing normal CheckJNI proof"
if grep -Eq 'JNI DETECTED ERROR|FATAL EXCEPTION|Fatal signal|Cannot enter Crystal|Crystal (bootstrap|render|application) error|Crystal .*callback failed' "$evidence/relaunch-logcat.txt"; then fail "Normal relaunch has runtime errors"; fi
"$adb" -s "$serial" exec-out screencap -p > "$evidence/relaunch.png"
echo 'PASS: clean runtime, six Crystal failure cases, 400 Java partial-render failures, original Throwable, sheet window mutation failure and terminal host cleanup' | tee "$evidence/result.txt"
