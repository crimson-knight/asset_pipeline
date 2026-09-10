#!/usr/bin/env bash
# The iOS lane: cross-compile the HIG host's Crystal bridge for the simulator,
# generate its Xcode project, and run the behavior UI tests on one simulator.
# `make test-ios` runs this; so does .github/workflows/apple-native.yml. It
# exits nonzero for a missing toolchain, a build error, a failed test or an
# empty run, and writes no tracked file (the visual tests, which write the
# tracked screenshots, stay in scripts/run_ios_hig_tests.sh).
#
# Environment:
#   CRYSTAL              compiler (default: acrystal, the AgentC fork; stock Crystal
#                        has no C bindings for the iOS targets and fails on c/fcntl)
#   CRYSTAL_CROSS_DEPS   where scripts/cross_compile_deps.sh put or will put
#                        ios-simulator/lib/{libgc.a,libpcre2-8.a}
#                        (default: /tmp/crystal-cross-deps, built when missing)
#   SIM_UDID | SIM_NAME  the simulator; default: an available iPhone Pro on the
#                        newest installed iOS runtime, a booted one preferred
#   IOS_TESTS            xcodebuild -only-testing identifier
#                        (default: CrystalHIGHostUITests/Phase03BehaviorTests)
#   IOS_TEST_EVIDENCE    directory for the log, the result bundle and the
#                        toolchain record (default: a fresh temporary directory)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IOS_DIR="$ROOT/samples/cross_platform/ios_host"
CRYSTAL="${CRYSTAL:-acrystal}"
DEPS="${CRYSTAL_CROSS_DEPS:-/tmp/crystal-cross-deps}"
IOS_TESTS="${IOS_TESTS:-CrystalHIGHostUITests/Phase03BehaviorTests}"
EVIDENCE="${IOS_TEST_EVIDENCE:-$(mktemp -d "${TMPDIR:-/tmp}/ios-host-proof.XXXXXX")}"
mkdir -p "$EVIDENCE"

info() { printf '[test-ios] %s\n' "$*"; }
fail() { printf '[test-ios] FAIL: %s\n' "$*" >&2; exit 1; }

for tool in "$CRYSTAL" xcrun xcodebuild xcodegen jq; do
  command -v "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done

{
  echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "host: $(sw_vers -productName) $(sw_vers -productVersion) ($(uname -m))"
  echo "xcode: $(xcodebuild -version | tr '\n' ' ')"
  echo "crystal: $("$CRYSTAL" --version | head -1)"
  echo "runtimes:"; xcrun simctl list runtimes | grep -E '^iOS' || true
} > "$EVIDENCE/toolchain.txt"
info "evidence: $EVIDENCE"

# 1. The cross-compiled C dependencies for the simulator.
if [ ! -f "$DEPS/ios-simulator/lib/libgc.a" ] || [ ! -f "$DEPS/ios-simulator/lib/libpcre2-8.a" ]; then
  info "cross-compiling libgc and pcre2 for iOS into $DEPS"
  BUILD_DIR="$DEPS" bash "$ROOT/scripts/cross_compile_deps.sh" ios > "$EVIDENCE/cross-deps.log" 2>&1 \
    || { tail -30 "$EVIDENCE/cross-deps.log" >&2; fail "cross_compile_deps.sh ios failed (see $EVIDENCE/cross-deps.log)"; }
fi
[ -f "$DEPS/ios-simulator/lib/libgc.a" ] || fail "libgc.a still missing under $DEPS/ios-simulator/lib"

# 2. The Crystal bridge as a static library for the simulator.
info "building libhighost.a with $CRYSTAL"
CRYSTAL="$CRYSTAL" bash "$IOS_DIR/build_crystal_lib.sh" simulator > "$EVIDENCE/build_crystal_lib.log" 2>&1 \
  || { tail -30 "$EVIDENCE/build_crystal_lib.log" >&2; fail "build_crystal_lib.sh failed (see $EVIDENCE/build_crystal_lib.log)"; }
[ -f "$IOS_DIR/build/libhighost.a" ] || fail "libhighost.a missing after the build"

# 3. The Xcode project.
(cd "$IOS_DIR" && xcodegen generate --spec project.yml > "$EVIDENCE/xcodegen.log" 2>&1) \
  || { cat "$EVIDENCE/xcodegen.log" >&2; fail "xcodegen failed"; }

# 4. One simulator: the newest iOS runtime, an iPhone Pro, booted preferred.
if [ -z "${SIM_UDID:-}" ]; then
  devices="$(xcrun simctl list devices available --json)"
  SIM_UDID="$(printf '%s' "$devices" | jq -r --arg name "${SIM_NAME:-}" '
    [ .devices | to_entries[]
      | select(.key | test("SimRuntime\\.iOS-"))
      | (.key | capture("iOS-(?<major>[0-9]+)-(?<minor>[0-9]+)")) as $v
      | .value[]
      | select(.isAvailable == true)
      | select(if $name == "" then (.name | test("^iPhone .* Pro$")) else .name == $name end)
      | {udid: .udid, name: .name, booted: (.state == "Booted"), major: ($v.major | tonumber), minor: ($v.minor | tonumber)} ]
    | sort_by([.major, .minor, (if .booted then 1 else 0 end)]) | last | .udid // empty')"
  [ -n "$SIM_UDID" ] || fail "no available iPhone Pro simulator${SIM_NAME:+ named $SIM_NAME}"
fi
SIM_LABEL="$(xcrun simctl list devices available --json | jq -r --arg u "$SIM_UDID" '.devices | to_entries[] | .key as $rt | .value[] | select(.udid == $u) | "\(.name) on \($rt | sub("com.apple.CoreSimulator.SimRuntime."; ""))"')"
info "simulator: $SIM_LABEL ($SIM_UDID)"
echo "simulator: $SIM_LABEL ($SIM_UDID)" >> "$EVIDENCE/toolchain.txt"
xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null 2>&1 || true

# 5. The tests. LIBRARY_SEARCH_PATHS is passed explicitly so a non-default
#    CRYSTAL_CROSS_DEPS is honored (project.yml names the default).
info "running $IOS_TESTS"
rc=0
xcodebuild test \
  -project "$IOS_DIR/CrystalHIGHost.xcodeproj" \
  -scheme CrystalHIGHost \
  -destination "platform=iOS Simulator,id=$SIM_UDID" \
  -only-testing:"$IOS_TESTS" \
  -resultBundlePath "$EVIDENCE/tests.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  LIBRARY_SEARCH_PATHS="$IOS_DIR/build $DEPS/ios-simulator/lib" \
  > "$EVIDENCE/xcodebuild.log" 2>&1 || rc=$?

passed="$(grep -cE "^Test Case '.*' passed" "$EVIDENCE/xcodebuild.log" || true)"
failed="$(grep -cE "^Test Case '.*' failed" "$EVIDENCE/xcodebuild.log" || true)"
grep -E "^Test Case '.*' (passed|failed)|\*\* TEST (SUCCEEDED|FAILED) \*\*|error:" "$EVIDENCE/xcodebuild.log" | tail -40 || true
info "passed: $passed failed: $failed xcodebuild exit: $rc"
printf 'passed: %s\nfailed: %s\nxcodebuild_exit: %s\n' "$passed" "$failed" "$rc" > "$EVIDENCE/summary.txt"
[ "$rc" -eq 0 ] || fail "xcodebuild test exited $rc (see $EVIDENCE/xcodebuild.log)"
[ "$passed" -gt 0 ] || fail "no test passed; an empty run is not a pass"
[ "$failed" -eq 0 ] || fail "$failed test(s) failed"
info "OK: $passed tests passed on $SIM_LABEL"
