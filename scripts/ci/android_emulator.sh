#!/usr/bin/env bash
# android_emulator.sh: the emulator lifecycle the CI lane owns.
#
#   android_emulator.sh up   <api> [port]              install, create, boot, wait
#   android_emulator.sh down <port>                    kill the emulator on that port
#   android_emulator.sh run  <api> <port> -- <command...>
#                                                      up, run the command with
#                                                      ANDROID_SERIAL set, always down;
#                                                      exits with the command's status
#
# Why this exists: the third-party emulator action runs one `input keyevent 82`
# the instant sys.boot_completed reads 1, with no retry, and Android 17's
# (API 37.0) image answers that first call with a broken pipe because its input
# service is not up yet. The lane's own launcher waits for the input service
# too, and otherwise reproduces the settings the lane stabilized on: a Google
# APIs x86_64 Pixel 6 image, 4 cores, 4 GiB RAM, 1 GiB heap, a 4 GiB data
# partition (Android 17's default refused the APKs for space), no window,
# SwiftShader, no snapshot, animations left on, no hardware keyboard.
#
# Environment (all optional):
#   ANDROID_SDK_ROOT or ANDROID_HOME   the SDK (required, one of them)
#   EMULATOR_TARGET=google_apis  EMULATOR_ARCH=x86_64  EMULATOR_PROFILE=pixel_6
#   EMULATOR_CORES=4  EMULATOR_RAM_MB=4096  EMULATOR_HEAP_MB=1024  EMULATOR_DISK_MB=4096
#   EMULATOR_OPTIONS='-no-window -gpu swiftshader_indirect -no-snapshot -noaudio -no-boot-anim'
#   EMULATOR_BOOT_TIMEOUT=900 (seconds)  EMULATOR_INPUT_TIMEOUT=120 (seconds)
#   EMULATOR_LOG_DIR=build/android-ci/emulator   logs, the pid file, the boot record
#   EMULATOR_SKIP_INSTALL=1   do not call sdkmanager (the image is already present)
set -euo pipefail

sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[ -n "$sdk" ] || { echo "android_emulator: set ANDROID_SDK_ROOT or ANDROID_HOME" >&2; exit 2; }
target="${EMULATOR_TARGET:-google_apis}"
arch="${EMULATOR_ARCH:-x86_64}"
profile="${EMULATOR_PROFILE:-pixel_6}"
cores="${EMULATOR_CORES:-4}"
ram_mb="${EMULATOR_RAM_MB:-4096}"
heap_mb="${EMULATOR_HEAP_MB:-1024}"
# Android 17's image refused the debug and test APKs with "Requested internal
# only, but not enough space" on the default data partition; size it explicitly.
disk_mb="${EMULATOR_DISK_MB:-4096}"
options="${EMULATOR_OPTIONS:--no-window -gpu swiftshader_indirect -no-snapshot -noaudio -no-boot-anim}"
boot_timeout="${EMULATOR_BOOT_TIMEOUT:-900}"
input_timeout="${EMULATOR_INPUT_TIMEOUT:-120}"
log_dir="${EMULATOR_LOG_DIR:-build/android-ci/emulator}"
adb="$sdk/platform-tools/adb"
emulator_bin="$sdk/emulator/emulator"
# One AVD home for both tools: on the GitHub runner avdmanager writes under the
# XDG config directory while the emulator searches ANDROID_AVD_HOME, the SDK
# home and ~/.android/avd; both honor ANDROID_AVD_HOME, so the launcher owns it.
export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
mkdir -p "$ANDROID_AVD_HOME"
avd_home="$ANDROID_AVD_HOME"

sdk_tool() { # sdk_tool <name>: cmdline-tools/latest first, then any
  local name="$1" candidate
  for candidate in "$sdk/cmdline-tools/latest/bin/$name" "$sdk"/cmdline-tools/*/bin/"$name" "$sdk/tools/bin/$name"; do
    [ -x "$candidate" ] && { echo "$candidate"; return 0; }
  done
  echo "android_emulator: $name not found under $sdk" >&2
  return 1
}

say() { printf '[emulator] %s\n' "$*"; }

up() {
  local api="$1" port="${2:-5554}" serial name image sdkmanager avdmanager config started attempt
  serial="emulator-$port"
  name="ci-api-${api//./_}"
  image="system-images;android-${api};${target};${arch}"
  mkdir -p "$log_dir"
  if [ "${EMULATOR_SKIP_INSTALL:-0}" != "1" ]; then
    sdkmanager="$(sdk_tool sdkmanager)"
    say "installing platforms;android-${api}, emulator and ${image}"
    "$sdkmanager" --install "platforms;android-${api}" emulator "$image" > "$log_dir/sdkmanager.log" 2>&1 \
      || { tail -20 "$log_dir/sdkmanager.log" >&2; echo "android_emulator: sdkmanager failed" >&2; return 1; }
  fi
  avdmanager="$(sdk_tool avdmanager)"
  say "creating AVD $name from $image ($profile)"
  echo no | "$avdmanager" create avd --force -n "$name" --package "$image" --device "$profile" > "$log_dir/avdmanager.log" 2>&1 \
    || { cat "$log_dir/avdmanager.log" >&2; echo "android_emulator: avdmanager failed" >&2; return 1; }
  # Ask avdmanager where it put the AVD: the AVD home differs between machines
  # (ANDROID_AVD_HOME, ANDROID_USER_HOME, the runner image) and the emulator
  # resolves it the same way avdmanager does.
  "$avdmanager" list avd > "$log_dir/avdmanager-list.log" 2>&1 || true
  config="$(awk -v n="$name" '$1 == "Name:" { found = ($2 == n) } found && $1 == "Path:" { print $2; exit }' "$log_dir/avdmanager-list.log")/config.ini"
  [ -f "$config" ] || config="$avd_home/$name.avd/config.ini"
  [ -f "$config" ] || { cat "$log_dir/avdmanager-list.log" >&2; echo "android_emulator: no config.ini for $name after create" >&2; return 1; }
  say "AVD config: $config"
  {
    printf 'hw.cpu.ncore=%s\n' "$cores"
    printf 'hw.ramSize=%s\n' "$ram_mb"
    printf 'vm.heapSize=%s\n' "$heap_mb"
    printf 'disk.dataPartition.size=%sM\n' "$disk_mb"
    printf 'hw.keyboard=no\n'
  } >> "$config"
  say "launching $serial: $emulator_bin -port $port -avd $name $options"
  # shellcheck disable=SC2086
  nohup "$emulator_bin" -port "$port" -avd "$name" $options > "$log_dir/emulator-$port.log" 2>&1 &
  echo $! > "$log_dir/emulator-$port.pid"
  started="$(date +%s)"
  "$adb" start-server > /dev/null 2>&1 || true
  while :; do
    if [ "$("$adb" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then break; fi
    if ! kill -0 "$(cat "$log_dir/emulator-$port.pid")" 2>/dev/null; then
      tail -30 "$log_dir/emulator-$port.log" >&2; echo "android_emulator: the emulator process exited before boot" >&2; return 1
    fi
    if [ $(( $(date +%s) - started )) -ge "$boot_timeout" ]; then
      tail -30 "$log_dir/emulator-$port.log" >&2; echo "android_emulator: no boot within ${boot_timeout}s" >&2; return 1
    fi
    sleep 2
  done
  say "booted after $(( $(date +%s) - started ))s; waiting for the input service"
  # Android 17's image reports boot before its input service accepts a call.
  started="$(date +%s)"; attempt=0
  while :; do
    attempt=$((attempt + 1))
    if "$adb" -s "$serial" shell input keyevent 82 > "$log_dir/input-$port.log" 2>&1; then break; fi
    if [ $(( $(date +%s) - started )) -ge "$input_timeout" ]; then
      cat "$log_dir/input-$port.log" >&2; echo "android_emulator: the input service did not answer within ${input_timeout}s" >&2; return 1
    fi
    sleep 2
  done
  say "input service answered on attempt $attempt"
  {
    printf 'serial=%s\napi=%s\nimage=%s\nprofile=%s\ncores=%s\nram_mb=%s\nheap_mb=%s\ndisk_mb=%s\noptions=%s\n' \
      "$serial" "$api" "$image" "$profile" "$cores" "$ram_mb" "$heap_mb" "$disk_mb" "$options"
    printf 'input_attempts=%s\nbuild=%s\nsdk_int=%s\n' "$attempt" \
      "$("$adb" -s "$serial" shell getprop ro.build.fingerprint | tr -d '\r')" \
      "$("$adb" -s "$serial" shell getprop ro.build.version.sdk | tr -d '\r')"
  } > "$log_dir/boot-$port.txt"
  say "ready: $serial ($(grep '^build=' "$log_dir/boot-$port.txt" | cut -d= -f2-))"
}

down() {
  local port="${1:-5554}" serial pid
  serial="emulator-$port"
  "$adb" -s "$serial" emu kill > /dev/null 2>&1 || true
  if [ -f "$log_dir/emulator-$port.pid" ]; then
    pid="$(cat "$log_dir/emulator-$port.pid")"
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$pid" 2>/dev/null || break; sleep 2; done
    kill -9 "$pid" 2>/dev/null || true
  fi
  say "stopped $serial"
}

case "${1:-}" in
  up) up "${2:?api}" "${3:-5554}" ;;
  down) down "${2:-5554}" ;;
  run)
    api="${2:?api}"; port="${3:?port}"
    [ "${4:-}" = "--" ] || { echo "usage: $0 run <api> <port> -- <command...>" >&2; exit 2; }
    shift 4
    trap 'down "$port"' EXIT
    up "$api" "$port"
    status=0
    ANDROID_SERIAL="emulator-$port" "$@" || status=$?
    exit "$status"
    ;;
  *) sed -n '2,25p' "$0"; exit 2 ;;
esac
