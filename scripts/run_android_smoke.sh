#!/usr/bin/env bash
# Fresh package + device runtime proof. ADB's instrumentation command can exit
# zero on a crashed test process, so verify its result protocol as well.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/android_env.sh"

[[ $# -ge 1 && $# -le 2 ]] || {
    echo "Usage: $0 <adb-serial> [evidence-directory]" >&2
    exit 2
}
SERIAL="$1"
EVIDENCE_DIR="${2:-$(mktemp -d /tmp/asset-pipeline-android-smoke.XXXXXX)}"
mkdir -p "$EVIDENCE_DIR"
EVIDENCE_DIR="$(cd "$EVIDENCE_DIR" && pwd)"
android_resolve_sdk_root
android_resolve_java_home
export ANDROID_HOME="$ANDROID_RESOLVED_SDK_ROOT"
export ANDROID_SDK_ROOT="$ANDROID_RESOLVED_SDK_ROOT"
export JAVA_HOME="$ANDROID_RESOLVED_JAVA_HOME"
ADB="$ANDROID_RESOLVED_SDK_ROOT/platform-tools/adb"
HOST_DIR="$ANDROID_PROJECT_ROOT/samples/cross_platform/android_host"
APP_ID=dev.assetpipeline.androidhost
TEST_CLASS="${ANDROID_SMOKE_TEST_CLASS:-dev.assetpipeline.androidhost.AndroidNativeSmokeTest,dev.assetpipeline.androidhost.AndroidTextContractTest,dev.assetpipeline.androidhost.AndroidNavigationContractTest,dev.assetpipeline.androidhost.AndroidLayoutContractTest,dev.assetpipeline.androidhost.AndroidViewStateTest,dev.assetpipeline.androidhost.AndroidSemanticsTest,dev.assetpipeline.androidhost.AndroidFocusVisibilityTest,dev.assetpipeline.androidhost.AndroidCompoundFocusTest,dev.assetpipeline.androidhost.AndroidDialogContractTest,dev.assetpipeline.androidhost.AndroidSheetContractTest,dev.assetpipeline.androidhost.AndroidSheetViewportTest,dev.assetpipeline.androidhost.AndroidSheetWindowMatrixTest,dev.assetpipeline.androidhost.AndroidBasicsContractTest,dev.assetpipeline.androidhost.AndroidStructureContractTest,dev.assetpipeline.androidhost.AndroidPickersContractTest,dev.assetpipeline.androidhost.AndroidTabsContractTest,dev.assetpipeline.androidhost.AndroidTickContractTest,dev.assetpipeline.androidhost.AndroidViewportContractTest,dev.assetpipeline.androidhost.AndroidAssetsContractTest,dev.assetpipeline.androidhost.AndroidDirectoriesContractTest,dev.assetpipeline.androidhost.AndroidPhotoContractTest,dev.assetpipeline.androidhost.AndroidAsyncImageContractTest,dev.assetpipeline.androidhost.AndroidButtonContractTest,dev.assetpipeline.androidhost.AndroidSettingsContractTest,dev.assetpipeline.androidhost.AndroidTextFieldStyleContractTest,dev.assetpipeline.androidhost.AndroidAppearanceContractTest},dev.assetpipeline.androidhost.StoragePlatformTest,dev.assetpipeline.androidhost.SecretsPlatformTest,dev.assetpipeline.androidhost.FilesPlatformTest"
fail() { echo "ERROR: $* (evidence: $EVIDENCE_DIR)" >&2; exit 1; }
LOG_CAPTURE_PID=""
SYSTEM_LOG_CAPTURE_PID=""
stop_log_capture() {
    local pid
    for pid in "$LOG_CAPTURE_PID" "$SYSTEM_LOG_CAPTURE_PID"; do
        [[ -n "$pid" ]] || continue
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done
    LOG_CAPTURE_PID=""
    SYSTEM_LOG_CAPTURE_PID=""
}
PREVIOUS_UNTRUSTED_TOUCHES=""
PREVIOUS_SPELL_CHECKER=""
restore_device_settings() {
    if [[ -n "$PREVIOUS_UNTRUSTED_TOUCHES" ]]; then
        if [[ "$PREVIOUS_UNTRUSTED_TOUCHES" == null ]]; then
            "$ADB" -s "$SERIAL" shell settings delete global block_untrusted_touches >/dev/null 2>&1 || true
        else
            "$ADB" -s "$SERIAL" shell settings put global block_untrusted_touches "$PREVIOUS_UNTRUSTED_TOUCHES" >/dev/null 2>&1 || true
        fi
        PREVIOUS_UNTRUSTED_TOUCHES=""
    fi
    if [[ -n "$PREVIOUS_SPELL_CHECKER" ]]; then
        if [[ "$PREVIOUS_SPELL_CHECKER" == null ]]; then
            "$ADB" -s "$SERIAL" shell settings delete secure spell_checker_enabled >/dev/null 2>&1 || true
        else
            "$ADB" -s "$SERIAL" shell settings put secure spell_checker_enabled "$PREVIOUS_SPELL_CHECKER" >/dev/null 2>&1 || true
        fi
        PREVIOUS_SPELL_CHECKER=""
    fi
}
finish_run() { stop_log_capture; restore_device_settings; }
trap finish_run EXIT
snapshot_logs() {
    kill -0 "$LOG_CAPTURE_PID" 2>/dev/null || fail "Continuous app log capture stopped unexpectedly"
    # Drain the latest device-buffer tail too. The live stream preserves early
    # evidence after ring-buffer wrap; the tail covers in-flight stream writes.
    # Duplicate records are intentional; positive gates never count log lines.
    "$ADB" -s "$SERIAL" logcat -d -v threadtime -T "$DEVICE_LOG_START" --uid="$APP_UID" > "$EVIDENCE_DIR/logcat-tail.txt"
    awk '{ print }' "$EVIDENCE_DIR/logcat-live.txt" "$EVIDENCE_DIR/logcat-tail.txt" > "$EVIDENCE_DIR/logcat.txt"
}

[[ "$($ADB -s "$SERIAL" get-state)" == device ]] || fail "ADB target is not ready"
[[ "$($ADB -s "$SERIAL" shell getprop sys.boot_completed | tr -d '\r')" == 1 ]] \
    || fail "Android has not finished booting"
"$SCRIPT_DIR/doctor_android.sh" --serial "$SERIAL" > "$EVIDENCE_DIR/doctor.txt"
bash "$SCRIPT_DIR/tests/android_files_backend.sh" "$EVIDENCE_DIR/native-file-backend"
bash "$SCRIPT_DIR/tests/android_unicode_codec.sh" "$EVIDENCE_DIR/unicode-codec"
bash "$SCRIPT_DIR/tests/android_jni_guard.sh" "$EVIDENCE_DIR/jni-guard"
(cd "$ANDROID_PROJECT_ROOT" && crystal spec spec/android_assets_spec.cr) > "$EVIDENCE_DIR/asset-compiler-spec.txt" 2>&1 || fail "Android image compiler specs failed"
(cd "$ANDROID_PROJECT_ROOT" && crystal spec spec/web/ui/android_navigation_state_spec.cr spec/web/ui/navigation_coordinator_spec.cr) > "$EVIDENCE_DIR/navigation-state-spec.txt" 2>&1 || fail "Android navigation state specs failed"
(cd "$ANDROID_PROJECT_ROOT" && crystal spec spec/web/ui/android_callback_boundary_spec.cr spec/web/ui/native/callback_registry_spec.cr) > "$EVIDENCE_DIR/callback-boundary-spec.txt" 2>&1 || fail "Android callback boundary specs failed"
(cd "$ANDROID_PROJECT_ROOT" && crystal spec spec/web/ui/android_layout_fixture_spec.cr) > "$EVIDENCE_DIR/layout-fixture-spec.txt" 2>&1 || fail "Android layout structure specs failed"
(cd "$ANDROID_PROJECT_ROOT" && crystal spec spec/web/ui/android_view_state_fixture_spec.cr) > "$EVIDENCE_DIR/view-state-fixture-spec.txt" 2>&1 || fail "Android view state structure specs failed"
(cd "$ANDROID_PROJECT_ROOT" && crystal spec spec/web/ui/android_semantics_spec.cr) > "$EVIDENCE_DIR/semantics-spec.txt" 2>&1 || fail "Android semantics structure specs failed"
(cd "$ANDROID_PROJECT_ROOT" && crystal spec spec/web/ui/android_focus_fixture_spec.cr) > "$EVIDENCE_DIR/focus-fixture-spec.txt" 2>&1 || fail "Android focus structure specs failed"
(cd "$ANDROID_PROJECT_ROOT" && crystal spec spec/web/ui/android_dialog_spec.cr) > "$EVIDENCE_DIR/dialog-spec.txt" 2>&1 || fail "Android dialog structure specs failed"
(cd "$ANDROID_PROJECT_ROOT" && crystal spec spec/web/ui/android_sheet_spec.cr) > "$EVIDENCE_DIR/sheet-spec.txt" 2>&1 || fail "Android sheet structure specs failed"

echo "Building fresh native libraries, APK, tests, and release bundle..."
GRADLE_ARGS=(--no-daemon -Dorg.gradle.vfs.watch=false :app:testDebugUnitTest :app:assembleDebug :app:assembleDebugAndroidTest :app:bundleRelease --console=plain)
if [[ -n "${ANDROID_SMOKE_EXTRA_TEST_SOURCE:-}" ]]; then
    [[ -d "$ANDROID_SMOKE_EXTRA_TEST_SOURCE" ]] || fail "External instrumentation sources do not exist"
    GRADLE_ARGS+=("-PexternalAndroidTestSource=$ANDROID_SMOKE_EXTRA_TEST_SOURCE")
fi
if [[ -n "${ANDROID_SMOKE_NETWORK_TEST_RESOURCES:-}" ]]; then
    GRADLE_ARGS+=("-PnetworkTestResources=$ANDROID_SMOKE_NETWORK_TEST_RESOURCES")
fi
if [[ -n "${ANDROID_SMOKE_NOTIFICATION_TEST_RESOURCES:-}" ]]; then
    GRADLE_ARGS+=("-PnotificationTestResources=$ANDROID_SMOKE_NOTIFICATION_TEST_RESOURCES")
fi
(cd "$HOST_DIR" && ./gradlew "${GRADLE_ARGS[@]}") \
    > "$EVIDENCE_DIR/build.log" 2>&1 || fail "Android build failed"
HOST_TEST_REPORT="$HOST_DIR/app/build/test-results/testDebugUnitTest/TEST-dev.assetpipeline.androidhost.HostSessionTest.xml"
[[ -s "$HOST_TEST_REPORT" ]] || fail "Canonical host-session unit tests did not produce a report"
grep -Eq '<testsuite .*tests="[1-9][0-9]*".*failures="0".*errors="0"' "$HOST_TEST_REPORT" \
    || fail "Host-session unit tests were empty or failed"
cp "$HOST_TEST_REPORT" "$EVIDENCE_DIR/host-session-unit-tests.xml"
SERVICE_TEST_REPORT="$HOST_DIR/app/build/test-results/testDebugUnitTest/TEST-dev.assetpipeline.androidhost.ServiceQueueTest.xml"
[[ -s "$SERVICE_TEST_REPORT" ]] || fail "Canonical service-queue unit tests did not produce a report"
grep -Eq '<testsuite .*tests="[1-9][0-9]*".*failures="0".*errors="0"' "$SERVICE_TEST_REPORT" || fail "Service-queue unit tests were empty or failed"
cp "$SERVICE_TEST_REPORT" "$EVIDENCE_DIR/service-queue-unit-tests.xml"
for suite in HttpWireTest PlatformHttpTest SecretVaultTest FilePolicyTest NotificationWireTest PermissionRequestsTest EditorActionsTest LayoutPolicyTest ScrollGesturePolicyTest TickPolicyTest ViewportPolicyTest BundlePolicyTest FontPolicyTest ViewStatePolicyTest SemanticsPolicyTest CompoundFocusPolicyTest DialogPolicyTest SheetPolicyTest; do
    report="$HOST_DIR/app/build/test-results/testDebugUnitTest/TEST-dev.assetpipeline.androidhost.$suite.xml"
    [[ -s "$report" ]] || fail "Missing service unit test report: $suite"
    grep -Eq '<testsuite .*tests="[1-9][0-9]*".*failures="0".*errors="0"' "$report" || fail "Service tests were empty or failed: $suite"
    cp "$report" "$EVIDENCE_DIR/$suite.xml"
done
APK="$HOST_DIR/app/build/outputs/apk/debug/app-debug.apk"
TEST_APK="$HOST_DIR/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
BUNDLE="$HOST_DIR/app/build/outputs/bundle/release/app-release.aab"
[[ -s "$APK" && -s "$TEST_APK" && -s "$BUNDLE" ]] || fail "Missing package output"
AAPT2="$ANDROID_RESOLVED_SDK_ROOT/build-tools/$ANDROID_BUILD_TOOLS_VERSION/aapt2"
"$AAPT2" dump permissions "$APK" > "$EVIDENCE_DIR/debug-permissions.txt"
expected_internet=false
[[ -z "${ANDROID_SMOKE_NETWORK_TEST_RESOURCES:-}" ]] || expected_internet=true
actual_internet=false
if grep -Eq "^uses-permission: name='android.permission.INTERNET'" "$EVIDENCE_DIR/debug-permissions.txt"; then actual_internet=true; fi
[[ "$actual_internet" == "$expected_internet" ]] || fail "A library changed the explicit host internet permission"
expected_notifications=false
[[ -z "${ANDROID_SMOKE_NOTIFICATION_TEST_RESOURCES:-}" ]] || expected_notifications=true
actual_notifications=false
if grep -Eq "^uses-permission: name='android.permission.POST_NOTIFICATIONS'" "$EVIDENCE_DIR/debug-permissions.txt"; then actual_notifications=true; fi
[[ "$actual_notifications" == "$expected_notifications" ]] || fail "A library changed the explicit notification permission"
unzip -Z1 "$APK" > "$EVIDENCE_DIR/apk-entries.txt"
unzip -Z1 "$BUNDLE" > "$EVIDENCE_DIR/bundle-entries.txt"
while IFS= read -r abi; do
    grep -Fxq "lib/$abi/libandroid_material_host.so" "$EVIDENCE_DIR/apk-entries.txt" \
        || fail "APK is missing $abi"
    grep -Fxq "base/lib/$abi/libandroid_material_host.so" "$EVIDENCE_DIR/bundle-entries.txt" \
        || fail "App Bundle is missing $abi"
    grep -Fxq "BUNDLE-METADATA/com.android.tools.build.debugsymbols/$abi/libandroid_material_host.so.dbg" "$EVIDENCE_DIR/bundle-entries.txt" \
        || fail "App Bundle is missing $abi native debug symbols"
done < <(android_each_abi)

# Preserve hashes of the actual dirty source tree, including untracked runtime
# files. A commit ID alone cannot identify a local development build.
while IFS= read -r -d '' source_path; do
    [[ -f "$ANDROID_PROJECT_ROOT/$source_path" ]] || continue
    (cd "$ANDROID_PROJECT_ROOT" && shasum -a 256 "$source_path")
done < <(git -C "$ANDROID_PROJECT_ROOT" ls-files --cached --others --exclude-standard -z -- \
    src scripts config android/runtime samples/cross_platform/android_host) > "$EVIDENCE_DIR/source-sha256.txt"

# A freshly booted CI emulator can sit on the keyguard or an unfocused
# launcher; Espresso then waits ten seconds per interaction for window focus.
"$ADB" -s "$SERIAL" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" shell wm dismiss-keyguard >/dev/null 2>&1 || true
# A slow CI emulator can boot into "Pixel Launcher isn't responding", a
# SYSTEM_ALERT window that keeps focus and starves every Espresso root wait
# (API 35 x86_64, runs 5 and 7). Suppress error dialogs for this session and
# close any that already exist before the app is installed.
"$ADB" -s "$SERIAL" shell settings put global hide_error_dialogs 1 >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS >/dev/null 2>&1 || true
if "$ADB" -s "$SERIAL" shell dumpsys window displays 2>/dev/null | grep -q 'Application Not Responding'; then
    echo "Dismissing an application-not-responding dialog that held window focus" >&2
    "$ADB" -s "$SERIAL" shell input keyevent KEYCODE_BACK >/dev/null 2>&1 || true
    sleep 2
fi
"$ADB" -s "$SERIAL" shell dumpsys window displays 2>/dev/null | grep -E 'mCurrentFocus|mFocusedApp' > "$EVIDENCE_DIR/window-focus-before.txt" || true
# Record which autofill and spell-check services the image runs, as found;
# both can open focusable popups over an editor and they differ between
# images and hosts. The spell checker is then disabled for the run (below).
{
    printf 'autofill_service=%s\n' "$("$ADB" -s "$SERIAL" shell settings get secure autofill_service 2>/dev/null | tr -d '\r')"
    printf 'spell_checker_enabled=%s\n' "$("$ADB" -s "$SERIAL" shell settings get secure spell_checker_enabled 2>/dev/null | tr -d '\r')"
    printf 'selected_spell_checker=%s\n' "$("$ADB" -s "$SERIAL" shell settings get secure selected_spell_checker 2>/dev/null | tr -d '\r')"
    printf 'screen_off_timeout=%s\n' "$("$ADB" -s "$SERIAL" shell settings get system screen_off_timeout 2>/dev/null | tr -d '\r')"
} > "$EVIDENCE_DIR/device-services.txt" 2>/dev/null || true
# Android 12+ drops touches to a window covered by another UID's opaque
# window, and androidx test-core's EmptyActivity (the test package's own UID)
# still covers the app after a scenario closes on a slow emulator (CI run 15);
# permissive mode logs those touches instead of dropping them. Restored on exit.
PREVIOUS_UNTRUSTED_TOUCHES="$("$ADB" -s "$SERIAL" shell settings get global block_untrusted_touches 2>/dev/null | tr -d '\r')"
[[ -n "$PREVIOUS_UNTRUSTED_TOUCHES" ]] || PREVIOUS_UNTRUSTED_TOUCHES=null
"$ADB" -s "$SERIAL" shell settings put global block_untrusted_touches 1 >/dev/null 2>&1 || true
# The image's spell checker (Gboard's on Google APIs images) marks tokens its
# dictionary does not know with easy-correction spans, and a tap that leaves
# the cursor on such a span makes Android's Editor open its focusable
# text-suggestions popup over the editor, which takes window focus from the
# sheet (CI run 17, API 35 x86_64: the previous test's draft ended in an
# accented letter). Which tokens a third-party dictionary flags, and whether
# its result lands before the tap, must not decide a run. Restored on exit.
PREVIOUS_SPELL_CHECKER="$("$ADB" -s "$SERIAL" shell settings get secure spell_checker_enabled 2>/dev/null | tr -d '\r')"
[[ -n "$PREVIOUS_SPELL_CHECKER" ]] || PREVIOUS_SPELL_CHECKER=null
"$ADB" -s "$SERIAL" shell settings put secure spell_checker_enabled 0 >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" install -r "$APK" > "$EVIDENCE_DIR/install.txt"
"$ADB" -s "$SERIAL" install -r "$TEST_APK" >> "$EVIDENCE_DIR/install.txt"
if [[ "${ANDROID_SMOKE_RESET_NOTIFICATION_PERMISSION:-0}" == 1 ]]; then
    [[ "$expected_notifications" == true ]] || fail "Permission reset requires the explicit notification fixture"
    [[ "$($ADB -s "$SERIAL" shell getprop ro.build.version.sdk | tr -d '\r')" -ge 33 ]] || fail "Runtime permission dialog proof requires API 33+"
    [[ "$($ADB -s "$SERIAL" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]] || fail "Permission reset is limited to the test emulator app"
    "$ADB" -s "$SERIAL" shell pm revoke "$APP_ID" android.permission.POST_NOTIFICATIONS
    "$ADB" -s "$SERIAL" shell pm clear-permission-flags "$APP_ID" android.permission.POST_NOTIFICATIONS user-set
    "$ADB" -s "$SERIAL" shell pm clear-permission-flags "$APP_ID" android.permission.POST_NOTIFICATIONS user-fixed
fi
"$ADB" -s "$SERIAL" shell setprop debug.checkjni 1
[[ "$($ADB -s "$SERIAL" shell getprop debug.checkjni | tr -d '\r')" == 1 ]] \
    || fail "CheckJNI could not be enabled"
DEVICE_LOG_START="$($ADB -s "$SERIAL" shell "date '+%m-%d %H:%M:%S.000'" | tr -d '\r')"
APP_UID="$($ADB -s "$SERIAL" shell cmd package list packages -U "$APP_ID" | tr -d '\r' | awk -v package="package:$APP_ID" '$1 == package { sub(/^uid:/, "", $2); print $2 }')"
[[ "$APP_UID" =~ ^[0-9]+$ ]] || fail "Could not resolve the exact installed application's logging UID"
"$ADB" -s "$SERIAL" logcat -v threadtime -T "$DEVICE_LOG_START" --uid="$APP_UID" \
    > "$EVIDENCE_DIR/logcat-live.txt" 2> "$EVIDENCE_DIR/logcat-capture-stderr.txt" &
LOG_CAPTURE_PID=$!
# System-side decisions (dropped or rejected input, window focus, IME and
# power transitions) never appear in the app-scoped stream above. Capture the
# relevant system tags separately for diagnosis. No gate reads this file, so
# an unexpected system log line can neither pass nor fail the target.
"$ADB" -s "$SERIAL" logcat -v threadtime -T "$DEVICE_LOG_START" -b main,system \
    InputDispatcher:V InputManager:V InputManagerService:V InputReader:V WindowManager:V \
    ActivityTaskManager:V ActivityManager:V PowerManagerService:V InputMethodManagerService:V \
    ImeTracker:V ToastPresenter:V AutofillManagerService:V AutofillSession:V '*:S' \
    > "$EVIDENCE_DIR/logcat-system.txt" 2> "$EVIDENCE_DIR/logcat-system-stderr.txt" &
SYSTEM_LOG_CAPTURE_PID=$!
echo "Testing Crystal runtime, input, callbacks, lifecycle and JNI cleanup on $SERIAL..."
"$ADB" -s "$SERIAL" shell am instrument -w -r -e class "$TEST_CLASS" \
    "$APP_ID.test/androidx.test.runner.AndroidJUnitRunner" \
    > "$EVIDENCE_DIR/instrumentation.txt" 2>&1 || fail "Instrumentation command failed"
snapshot_logs
if ! grep -Eq '^OK \([1-9][0-9]* tests?\)' "$EVIDENCE_DIR/instrumentation.txt"; then
    # Keep what was on screen and who held focus; a CI emulator cannot be inspected afterwards.
    "$ADB" -s "$SERIAL" exec-out screencap -p > "$EVIDENCE_DIR/failure-screen.png" 2>/dev/null || true
    "$ADB" -s "$SERIAL" shell dumpsys window displays 2>/dev/null | grep -E 'mCurrentFocus|mFocusedApp|mHoldScreen' > "$EVIDENCE_DIR/window-focus-after.txt" || true
    "$ADB" -s "$SERIAL" shell dumpsys activity top 2>/dev/null | head -40 > "$EVIDENCE_DIR/activity-top-after.txt" || true
    "$ADB" -s "$SERIAL" shell dumpsys window windows 2>/dev/null | grep -E 'Window #|mAttrs|isOnScreen|mHasSurface' | head -60 > "$EVIDENCE_DIR/windows-after.txt" || true
    # Dispatcher and power state explain rejected input better than a screenshot.
    "$ADB" -s "$SERIAL" shell dumpsys input 2>/dev/null | head -2000 > "$EVIDENCE_DIR/input-state-after.txt" || true
    "$ADB" -s "$SERIAL" shell dumpsys power 2>/dev/null | grep -E 'mWakefulness|mInteractive|mDisplayReady|mHoldingDisplay|mStayOn|mUserActivityTimeout|Screen off timeout|mScreenOffTimeout' > "$EVIDENCE_DIR/power-state-after.txt" || true
    # The tests write their own failure screenshots and Espresso's view-op
    # captures into app-owned storage; keep them with the rest of the evidence.
    "$ADB" -s "$SERIAL" pull "/storage/emulated/0/Android/data/$APP_ID/files/sheet-proof" "$EVIDENCE_DIR/sheet-proof" >/dev/null 2>&1 || true
    "$ADB" -s "$SERIAL" pull "/storage/emulated/0/Android/media/$APP_ID/additionalTestOutputDir" "$EVIDENCE_DIR/espresso-output" >/dev/null 2>&1 || true
    fail "No successful nonempty instrumentation result"
fi
grep -q '^INSTRUMENTATION_CODE: -1' "$EVIDENCE_DIR/instrumentation.txt" \
    || fail "Instrumentation did not complete normally"
if grep -Eq 'Process crashed|FAILURES!!!|INSTRUMENTATION_FAILED|INSTRUMENTATION_STATUS_CODE: -[1234]' "$EVIDENCE_DIR/instrumentation.txt"; then
    fail "Instrumentation reported a failure"
fi
grep -q 'Crystal runtime ready (probe=42)' "$EVIDENCE_DIR/logcat.txt" \
    || fail "Embedded runtime probe was not observed"
grep -q 'Late-enabling -Xcheck:jni' "$EVIDENCE_DIR/logcat.txt" \
    || fail "Process did not confirm CheckJNI"

# A separate process start catches initialization that only works inside the
# instrumentation runner. Use the same freshly installed APK in dark mode.
RELAUNCH_ARGS=(--es study_slug interaction-smoke --es study_appearance dark)
if [[ -n "${ANDROID_SMOKE_APP_SLUG:-}" ]]; then
    RELAUNCH_ARGS+=(--es app_slug "$ANDROID_SMOKE_APP_SLUG")
fi
"$ADB" -s "$SERIAL" shell am start -S -W -n "$APP_ID/.MainActivity" \
    "${RELAUNCH_ARGS[@]}" > "$EVIDENCE_DIR/relaunch.txt"
"$ADB" -s "$SERIAL" shell uiautomator dump /sdcard/asset-pipeline-smoke.xml > /dev/null
"$ADB" -s "$SERIAL" pull /sdcard/asset-pipeline-smoke.xml "$EVIDENCE_DIR/relaunch-ui.xml" > /dev/null
grep -q 'Renderer mount live' "$EVIDENCE_DIR/relaunch-ui.xml" || fail "Relaunch did not mount the native tree"
if [[ -n "${ANDROID_SMOKE_EXPECTED_TEXT:-}" ]]; then
    grep -Fq "$ANDROID_SMOKE_EXPECTED_TEXT" "$EVIDENCE_DIR/relaunch-ui.xml" || fail "Relaunch did not render the external application"
fi
APP_PID="$($ADB -s "$SERIAL" shell pidof "$APP_ID" | tr -d '\r')"
[[ "$APP_PID" =~ ^[0-9]+$ ]] || fail "Relaunched app is not alive"
if [[ "${ANDROID_SMOKE_REQUIRE_NEW_PROCESS:-0}" == 1 ]]; then
    PREVIOUS_PID="$(sed -n 's/^INSTRUMENTATION_STATUS: persisted_process=//p' "$EVIDENCE_DIR/instrumentation.txt" | tr -d '\r')"
    [[ "$PREVIOUS_PID" =~ ^[0-9]+$ && "$PREVIOUS_PID" != "$APP_PID" ]] || fail "Persistence proof did not start a new process"
fi
"$ADB" -s "$SERIAL" exec-out screencap -p > "$EVIDENCE_DIR/relaunch.png"
snapshot_logs
stop_log_capture

# Scope Java/CheckJNI diagnostics to processes that loaded this library.
awk '/AssetPipelineNative: JNI_OnLoad: starting/ { pids[$3] = 1 }
     { lines[NR] = $0; owners[NR] = $3 }
     END { for (i = 1; i <= NR; i++) if (owners[i] in pids) print lines[i] }' \
    "$EVIDENCE_DIR/logcat.txt" > "$EVIDENCE_DIR/app-logcat.txt"
if grep -Eq 'JNI DETECTED ERROR|FATAL EXCEPTION|Fatal signal|Crystal (bootstrap|render|application) error|Crystal .*callback failed|Cannot enter Crystal|AP_PRIVATE_VIEW_STATE_MALFORMED_SENTINEL' "$EVIDENCE_DIR/app-logcat.txt"; then
    fail "App logs contain a runtime failure"
fi

{
    echo "format=asset-pipeline-android-smoke-v1"
    echo "source_commit=$(git -C "$ANDROID_PROJECT_ROOT" rev-parse HEAD)"
    echo "serial=$SERIAL"
    echo "device_model=$($ADB -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')"
    echo "device_api=$($ADB -s "$SERIAL" shell getprop ro.build.version.sdk | tr -d '\r')"
    echo "device_abi=$($ADB -s "$SERIAL" shell getprop ro.product.cpu.abi | tr -d '\r')"
    echo "emulator=$($ADB -s "$SERIAL" shell getprop ro.kernel.qemu | tr -d '\r')"
    echo "checkjni=1"
    echo "log_capture=continuous-app-uid-with-buffer-tail"
    echo "app_uid=$APP_UID"
    echo "relaunch_pid=$APP_PID"
    shasum -a 256 "$APK" "$TEST_APK" "$BUNDLE" "$ANDROID_PROJECT_ROOT/config/android_toolchain.env" "$EVIDENCE_DIR/source-sha256.txt"
} > "$EVIDENCE_DIR/proof.txt"
git -C "$ANDROID_PROJECT_ROOT" status --short > "$EVIDENCE_DIR/source-status.txt"
unzip -l "$APK" > "$EVIDENCE_DIR/apk-contents.txt"
unzip -l "$BUNDLE" > "$EVIDENCE_DIR/bundle-contents.txt"
echo "Android smoke passed. Evidence: $EVIDENCE_DIR"
