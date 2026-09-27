#!/bin/sh
# Builds the main-thread affinity probe with and without UI::MainThread under
# the default execution-context runtime (no -Dwithout_mt), then runs each
# build RUNS times, alone and with a Parallel worker context, and prints how
# many runs migrated off the main thread and the exit-code histogram.
#
#   samples/main_thread_affinity_probe/run_matrix.sh [RUNS]
set -eu

RUNS="${1:-20}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${PROBE_OUT_DIR:-$(mktemp -d /tmp/main_thread_probe.XXXXXX)}"
export CRYSTAL_CACHE_DIR="$OUT/cache"
CRYSTAL="${CRYSTAL:-crystal-alpha}"

clang -c -fobjc-arc "$HERE/offscreen_window.m" -o "$OUT/offscreen_window.o"
LINK="$OUT/offscreen_window.o -framework AppKit"
"$CRYSTAL" build "$HERE/probe.cr" -Dmacos -o "$OUT/probe_without_fix" --link-flags="$LINK"
"$CRYSTAL" build "$HERE/probe.cr" -Dmacos -Dwith_main_thread_fix -o "$OUT/probe_with_fix" --link-flags="$LINK"

for build in probe_without_fix probe_with_fix; do
  for mode in plain --workers; do
    arg=""
    [ "$mode" = "--workers" ] && arg="--workers"
    migrated=0
    : > "$OUT/exits.txt"
    i=0
    while [ "$i" -lt "$RUNS" ]; do
      i=$((i + 1))
      set +e
      output="$("$OUT/$build" $arg 2>>"$OUT/$build.$mode.stderr")"
      code=$?
      set -e
      echo "$code" >> "$OUT/exits.txt"
      case "$output" in
        *main_thread_after_syscalls=false*) migrated=$((migrated + 1)) ;;
      esac
      [ "$mode" = "--workers" ] && [ "$i" -eq 1 ] && echo "  sample: $(echo "$output" | tail -1)"
    done
    histogram="$(sort -n "$OUT/exits.txt" | uniq -c | awk '{printf "exit %s x%s; ", $2, $1}')"
    echo "$build $mode: migrated $migrated/$RUNS; $histogram"
  done
done
echo "artifacts: $OUT"
