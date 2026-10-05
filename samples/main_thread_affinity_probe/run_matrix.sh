#!/bin/sh
# Builds the main-thread affinity probe with and without UI::MainThread under
# the default execution-context runtime (no -Dwithout_mt), then runs each
# build RUNS times per mode and prints how many runs saw the main fiber off
# the main thread, how many cases lost data, and the exit-code histogram.
#
# Modes: plain, --workers, --blocking-io, --mutex, --native-callback.
#
#   samples/main_thread_affinity_probe/run_matrix.sh [RUNS]
set -eu

RUNS="${1:-20}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${PROBE_OUT_DIR:-$(mktemp -d /tmp/main_thread_probe.XXXXXX)}"
mkdir -p "$OUT"
export CRYSTAL_CACHE_DIR="$OUT/cache"
CRYSTAL="${CRYSTAL:-crystal-alpha}"
MODES="${PROBE_MODES:-plain --workers --blocking-io --mutex --native-callback}"

clang -c -fobjc-arc "$HERE/offscreen_window.m" -o "$OUT/offscreen_window.o"
clang -c -fobjc-arc "$HERE/native_callbacks.m" -o "$OUT/native_callbacks.o"
LINK="$OUT/offscreen_window.o $OUT/native_callbacks.o -framework AppKit -framework Foundation"
"$CRYSTAL" build "$HERE/probe.cr" -Dmacos -o "$OUT/probe_without_fix" --link-flags="$LINK"
"$CRYSTAL" build "$HERE/probe.cr" -Dmacos -Dwith_main_thread_fix -o "$OUT/probe_with_fix" --link-flags="$LINK"

for build in probe_without_fix probe_with_fix; do
  for mode in $MODES; do
    arg=""
    [ "$mode" != "plain" ] && arg="$mode"
    migrated=0
    case_failures=0
    : > "$OUT/exits.txt"
    i=0
    while [ "$i" -lt "$RUNS" ]; do
      i=$((i + 1))
      set +e
      output="$("$OUT/$build" $arg 2>>"$OUT/$build.$mode.stderr")"
      code=$?
      set -e
      echo "$code" >> "$OUT/exits.txt"
      printf '%s run %s exit %s\n%s\n' "$mode" "$i" "$code" "$output" >> "$OUT/$build.$mode.stdout"
      case "$output" in
        *main_thread_after_syscalls=false* | *off_main_observations=[1-9]*) migrated=$((migrated + 1)) ;;
      esac
      case "$output" in
        *"ok=false"*) case_failures=$((case_failures + 1)) ;;
      esac
      [ "$mode" != "plain" ] && [ "$i" -eq 1 ] && echo "  sample: $(echo "$output" | tail -1)"
    done
    histogram="$(sort -n "$OUT/exits.txt" | uniq -c | awk '{printf "exit %s x%s; ", $2, $1}')"
    echo "$build $mode: migrated $migrated/$RUNS; case failures $case_failures/$RUNS; $histogram"
  done
done
echo "artifacts: $OUT"
