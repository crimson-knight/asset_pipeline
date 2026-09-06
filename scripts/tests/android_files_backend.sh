#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
evidence="${1:-$(mktemp -d /tmp/ap-files-backend.XXXXXX)}"
mkdir -p "$evidence"
evidence="$(cd "$evidence" && pwd)"
test_root="$(mktemp -d "$evidence/files.XXXXXX")"
case "$(uname -s)" in Darwin|Linux) ;; *) echo "Unsupported host for POSIX backend contracts" >&2; exit 1 ;; esac
"${ANDROID_HOST_CC:-cc}" -std=c11 -D_GNU_SOURCE -Wall -Wextra -Werror \
  "$script_dir/android_files_backend.c" -o "$evidence/backend-test"
"$evidence/backend-test" "$test_root" | tee "$evidence/result.txt"
