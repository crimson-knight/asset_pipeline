#!/usr/bin/env bash
# No SDK/device required: prove routing, exact argument data and failure status.
# Real native behavior remains the separate mandatory device driver.
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$script_dir/../.." && pwd)"
evidence="${1:-$(mktemp -d /tmp/ap-android-target-contract.XXXXXX)}"
mkdir -p "$evidence"
evidence="$(cd "$evidence" && pwd -P)"
fixture="$evidence/project with spaces"
mkdir -p "$fixture/scripts"
cp "$project_root/Makefile" "$fixture/Makefile"
cp "$project_root/scripts/test_android_target.sh" "$fixture/scripts/"
cp "$script_dir/fixtures/android_target_driver.sh" "$fixture/scripts/test_android_java_failures.sh"
fail() { echo "FAIL: $* (evidence: $evidence)" >&2; exit 1; }
cases=0
run_case() {
  local name="$1" expected="$2" actual=0
  shift 2
  trace="$evidence/$name.trace"
  AP_ROUTE_TRACE="$trace" env -u ANDROID_SMOKE_TEST_CLASS -u ANDROID_SMOKE_EXTRA_TEST_SOURCE -u ANDROID_SMOKE_NETWORK_TEST_RESOURCES -u ANDROID_SMOKE_NOTIFICATION_TEST_RESOURCES -u ANDROID_SMOKE_APP_SLUG -u ANDROID_SMOKE_RESET_NOTIFICATION_PERMISSION "$@" > "$evidence/$name.log" 2>&1 || actual=$?
  [[ "$actual" == "$expected" ]] || fail "$name returned $actual instead of $expected"
  cases=$((cases + 1))
}
assert_trace() {
  local serial output cache
  [[ -s "$trace" ]] || fail "Driver was not called: $trace"
  { IFS= read -r -d '' serial; IFS= read -r -d '' output; IFS= read -r -d '' cache; } < "$trace"
  [[ "$serial" == "$1" && "$output" == "$2" && "$cache" == "$3" ]] || fail 'Argument/cache data changed in transit'
}

run_case missing 2 env -u ANDROID_SERIAL make -s -C "$fixture" test-android
[[ ! -e "$trace" ]] || fail 'Missing serial started a test'
for serial in '' '-s' 'emulator 5556' 'emulator; touch marker' 'emulator`touch marker`'; do
  run_case "invalid-$cases" 2 env ANDROID_SERIAL="$serial" make -s -C "$fixture" test-android
  [[ ! -e "$trace" ]] || fail 'Invalid serial started a test'
done
# Even Make expressions in the exported values are preserved as literal data.
injection='$(shell touch '${evidence}'/make-expression-executed)'
run_case make-expression 2 env ANDROID_SERIAL="$injection" make -s -C "$fixture" test-android
[[ ! -e "$trace" && ! -e "$evidence/make-expression-executed" ]] || fail 'Serial was evaluated as code'
for knob in ANDROID_SMOKE_TEST_CLASS ANDROID_SMOKE_EXTRA_TEST_SOURCE ANDROID_SMOKE_NETWORK_TEST_RESOURCES ANDROID_SMOKE_NOTIFICATION_TEST_RESOURCES ANDROID_SMOKE_APP_SLUG ANDROID_SMOKE_RESET_NOTIFICATION_PERMISSION; do
  run_case "override-$knob" 2 env ANDROID_SERIAL=emulator-5556 "$knob=partial" make -s -C "$fixture" test-android
  [[ ! -e "$trace" ]] || fail 'An inherited partial-test override reached the complete target'
done

output="$evidence/output ; literal spaces"
cache="$evidence/cache with spaces"
run_case explicit 0 env ANDROID_SERIAL=emulator-5556 ANDROID_TEST_EVIDENCE="$output" CRYSTAL_CACHE_DIR="$cache" make -s -C "$fixture" test-android
assert_trace emulator-5556 "$output" "$cache"
literal_output="$evidence/"'$(shell touch should-not-run)'
run_case literal-output 0 env ANDROID_SERIAL=emulator-5556 ANDROID_TEST_EVIDENCE="$literal_output" CRYSTAL_CACHE_DIR="$cache" make -s -C "$fixture" test-android
assert_trace emulator-5556 "$literal_output" "$cache"
[[ ! -e "$fixture/should-not-run" ]] || fail 'Evidence path was evaluated as code'
run_case command-line 0 env -u ANDROID_SERIAL -u ANDROID_TEST_EVIDENCE -u CRYSTAL_CACHE_DIR make -s -C "$fixture" test-android ANDROID_SERIAL=127.0.0.1:5555 'ANDROID_TEST_EVIDENCE=relative proof'
assert_trace 127.0.0.1:5555 "$fixture/relative proof" "$fixture/build/crystal-cache/android"

run_case wrapper-failure 17 env AP_ROUTE_STATUS=17 ANDROID_SERIAL=emulator-5556 ANDROID_TEST_EVIDENCE="$output" CRYSTAL_CACHE_DIR="$cache" bash "$fixture/scripts/test_android_target.sh"
assert_trace emulator-5556 "$output" "$cache"
run_case make-failure 2 env AP_ROUTE_STATUS=17 ANDROID_SERIAL=emulator-5556 ANDROID_TEST_EVIDENCE="$output" CRYSTAL_CACHE_DIR="$cache" make -s -C "$fixture" test-android
assert_trace emulator-5556 "$output" "$cache"
run_case unexpected-argument 2 env ANDROID_SERIAL=emulator-5556 bash "$fixture/scripts/test_android_target.sh" extra
[[ ! -e "$trace" ]] || fail 'Unexpected argument reached a driver'

mkdir -p "$evidence/temporary"
run_case default-evidence 0 env -u ANDROID_TEST_EVIDENCE ANDROID_SERIAL=emulator-5556 TMPDIR="$evidence/temporary" CRYSTAL_CACHE_DIR="$cache" make -s -C "$fixture" test-android
{ IFS= read -r -d '' actual_serial; IFS= read -r -d '' actual_output; IFS= read -r -d '' actual_cache; } < "$trace"
[[ "$actual_serial" == emulator-5556 && "$actual_cache" == "$cache" && "$actual_output" == "$evidence/temporary/asset-pipeline-android-target."* && -d "$actual_output" ]] || fail 'Default evidence was not an owned fresh directory'
printf 'PASS: %s Android entrypoint contracts; missing/invalid targets fail, exact data is preserved, real-driver failures propagate.\n' "$cases" | tee "$evidence/result.txt"
