#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
evidence="${1:-$(mktemp -d /tmp/ap-unicode-codec.XXXXXX)}"
mkdir -p "$evidence"
"${ANDROID_HOST_CC:-cc}" -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined \
  "$script_dir/android_unicode_codec.c" -o "$evidence/unicode-test"
"$evidence/unicode-test" | tee "$evidence/result.txt"
