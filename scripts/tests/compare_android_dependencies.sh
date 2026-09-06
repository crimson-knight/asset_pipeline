#!/usr/bin/env bash
set -euo pipefail
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TEST_DIR/../android_deps.sh"
[[ $# == 2 ]] || { echo "Usage: $0 <first-independent-cache> <second-independent-cache>" >&2; exit 2; }
first_root="$(cd "$1" && pwd -P)"
second_root="$(cd "$2" && pwd -P)"
[[ "$first_root" != "$second_root" ]] || { echo "Independent cache roots are required" >&2; exit 1; }
while IFS= read -r abi; do
    android_configure_abi "$abi" "${ANDROID_API:-$ANDROID_NATIVE_API}"
    android_deps_select "$first_root"
    first="$ANDROID_DEPS_DIR"
    android_deps_validate "$first"
    android_deps_select "$second_root"
    second="$ANDROID_DEPS_DIR"
    android_deps_validate "$second"
    cmp "$first/android-deps.manifest" "$second/android-deps.manifest"
    cmp "$first/files.sha256" "$second/files.sha256"
    echo "PASS: $abi API $ANDROID_API manifests and complete library/header payload are byte-identical"
    echo "  contract: $ANDROID_DEPS_KEY"
    echo "  manifest: $(android_sha256 "$first/android-deps.manifest")"
done < <(android_each_abi "${ANDROID_ABIS:-$ANDROID_SUPPORTED_ABIS}")
