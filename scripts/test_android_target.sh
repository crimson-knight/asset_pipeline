#!/usr/bin/env bash
# Public Makefile entrypoint. Configuration is passed as environment data,
# never interpolated into a shell program by Make.
set -euo pipefail
[[ $# == 0 ]] || { echo 'Use ANDROID_SERIAL and optional ANDROID_TEST_EVIDENCE environment values, not arguments.' >&2; exit 2; }
serial="${ANDROID_SERIAL:-}"
[[ "$serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] || {
  echo 'ANDROID_SERIAL must explicitly identify one ADB device (for example emulator-5556).' >&2
  echo 'No device was selected and no build or test was started.' >&2
  exit 2
}
for knob in "${!ANDROID_SMOKE_@}"; do
  [[ -z "$knob" || -z "${!knob}" ]] || {
    echo "The complete Android target does not accept $knob. Use the scoped smoke helper explicitly for specialized probes." >&2
    exit 2
  }
done
script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
export CRYSTAL_CACHE_DIR="${CRYSTAL_CACHE_DIR:-$project_root/build/crystal-cache/android}"
evidence="${ANDROID_TEST_EVIDENCE:-}"
if [[ -z "$evidence" ]]; then
  evidence="$(mktemp -d "${TMPDIR:-/tmp}/asset-pipeline-android-target.XXXXXX")"
elif [[ "$evidence" != /* ]]; then
  evidence="$PWD/$evidence"
fi
printf 'Android target: %s\nEvidence: %s\n' "$serial" "$evidence"
# The real driver checks nonempty instrumentation completion, every failure
# lane, logs, package contents and a normal process restart. Preserve its status.
exec bash "$script_dir/test_android_java_failures.sh" "$serial" "$evidence"
