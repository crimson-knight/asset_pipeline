#!/usr/bin/env bash
# Negative cases use copies under a fresh directory, never the caller's cache.
set -euo pipefail
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TEST_DIR/../android_deps.sh"
[[ $# == 1 ]] || { echo "Usage: $0 <verified-cache-root>" >&2; exit 2; }
root="$(cd "$1" && pwd -P)"
evidence="$(mktemp -d /tmp/ap-android-cache-tests.XXXXXX)"
count=0
expect_failure() {
    local label="$1"
    shift
    if "$@" > "$evidence/$label.txt" 2>&1; then
        echo "FAIL: accepted $label" >&2; exit 1
    fi
    count=$((count + 1))
    echo "PASS: rejected $label"
}
android_configure_abi arm64-v8a 31
android_deps_select "$root"
valid="$ANDROID_DEPS_DIR"
key="$ANDROID_DEPS_KEY"
android_deps_validate "$valid"
before="$(android_sha256 "$valid/android-deps.manifest")"
cp -R "$valid" "$evidence/changed-header"
cp "$TEST_DIR/android_archive_test.c" "$evidence/changed-header/include/gc/gc.h"
expect_failure changed-header android_deps_validate "$evidence/changed-header"
cp -R "$valid" "$evidence/empty-archive"
"$ANDROID_NDK_TOOLCHAIN/llvm-ar" rcs "$evidence/empty.a"
cp "$evidence/empty.a" "$evidence/empty-archive/lib/libgc.a"
expect_failure empty-archive android_deps_validate "$evidence/empty-archive"
cp -R "$valid" "$evidence/stale-manifest"
sed 's/^api=31$/api=32/' "$valid/android-deps.manifest" > "$evidence/stale-manifest/android-deps.manifest"
expect_failure stale-manifest android_deps_validate "$evidence/stale-manifest"
mkdir -p "$evidence/incomplete"
expect_failure incomplete android_deps_validate "$evidence/incomplete"
cp -R "$valid" "$evidence/symlink"
ln -s "$TEST_DIR/android_archive_test.c" "$evidence/symlink/include/untrusted.h"
expect_failure symlink-header android_deps_validate "$evidence/symlink"
cp -R "$valid" "$evidence/fifo"
mkfifo "$evidence/fifo/include/untrusted.h"
expect_failure nonregular-header android_deps_validate "$evidence/fifo"
mkdir -p "$evidence/legacy"
cp -R "$valid" "$evidence/legacy/android-arm64"
expect_failure legacy-flat-cache env ANDROID_API=31 CRYSTAL_CROSS_DEPS="$evidence/legacy" \
    BUILD_DIR="$evidence/legacy-output" bash "$TEST_DIR/../build_android.sh" "$TEST_DIR/android_archive_test.c"
grep -q 'legacy flat caches are not accepted' "$evidence/legacy-flat-cache.txt"
[[ ! -d "$evidence/legacy-output" ]]

android_configure_abi arm64-v8a 32
android_deps_select "$root"
[[ "$ANDROID_DEPS_KEY" != "$key" ]]
expect_failure wrong-api android_deps_validate "$valid"
expect_failure native-link-wrong-api env ANDROID_API=32 CRYSTAL_CROSS_DEPS="$root" \
    BUILD_DIR="$evidence/link-output" bash "$TEST_DIR/../build_android.sh" "$TEST_DIR/android_archive_test.c"
grep -q 'Verified Android dependency bundle missing' "$evidence/native-link-wrong-api.txt"
[[ ! -d "$evidence/link-output" ]]

android_configure_abi x86_64 31
android_deps_select "$root"
[[ "$ANDROID_DEPS_KEY" != "$key" ]]
expect_failure wrong-abi android_deps_validate "$valid"
android_configure_abi arm64-v8a 31
saved_commit="$BDWGC_ANDROID_COMMIT"
BDWGC_ANDROID_COMMIT=0000000000000000000000000000000000000000
android_deps_select "$root"
[[ "$ANDROID_DEPS_KEY" != "$key" ]]
expect_failure changed-source-pin android_deps_validate "$valid"
BDWGC_ANDROID_COMMIT="$saved_commit"
android_deps_select "$root"
expect_failure unpinned-version env BDWGC_VERSION=8.2.5 BUILD_DIR="$evidence/unpinned" \
    bash "$TEST_DIR/../build_android_deps.sh" arm64-v8a

mkdir -p "$evidence/kit/scripts" "$evidence/kit/config"
cp "$TEST_DIR/../android_deps.sh" "$TEST_DIR/../android_env.sh" "$TEST_DIR/../build_android_deps.sh" "$evidence/kit/scripts/"
cp "$TEST_DIR/../../config/android_toolchain.env" "$evidence/kit/config/"
printf '\n# A different build recipe must use a different cache key.\n' >> "$evidence/kit/scripts/build_android_deps.sh"
expect_failure changed-recipe bash -c '
    set -euo pipefail
    source "$1/scripts/android_deps.sh"
    android_configure_abi arm64-v8a 31
    android_deps_select "$2"
    [[ "$ANDROID_DEPS_KEY" != "$3" ]]
    android_deps_validate "$4"
' proof "$evidence/kit" "$root" "$key" "$valid"
grep -q 'Stale or mismatched' "$evidence/changed-recipe.txt"

mkdir -p "$evidence/wrong-ndk"
printf 'Pkg.Revision = 0.0.0\n' > "$evidence/wrong-ndk/source.properties"
expect_failure wrong-ndk env ANDROID_NDK_HOME="$evidence/wrong-ndk" bash -c '
    source "$1"
    android_configure_abi arm64-v8a 31
' proof "$TEST_DIR/../android_env.sh"
grep -q 'does not match the pinned' "$evidence/wrong-ndk.txt"
expect_failure below-minimum-api android_configure_abi arm64-v8a 30
expect_failure invalid-api android_configure_abi arm64-v8a nonsense
expect_failure unsupported-abi android_configure_abi arm64 31

mkdir -p "$evidence/bad-download/downloads"
cp "$TEST_DIR/android_archive_test.c" "$evidence/bad-download/downloads/bdwgc-$BDWGC_ANDROID_COMMIT.tar"
expect_failure corrupt-source-download env BUILD_DIR="$evidence/bad-download" \
    bash "$TEST_DIR/../build_android_deps.sh" arm64-v8a
grep -q 'Cached source checksum mismatch' "$evidence/corrupt-source-download.txt"
[[ "$before" == "$(android_sha256 "$valid/android-deps.manifest")" ]]
echo "PASS: $count negative cache/identity/source cases; original cache unchanged. Evidence: $evidence"
