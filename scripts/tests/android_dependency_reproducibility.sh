#!/usr/bin/env bash
# Build twice, independently, from empty roots; never accept a supplied cache.
set -euo pipefail
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
[[ $# == 0 ]] || { echo "Usage: $0 (creates fresh independent caches)" >&2; exit 2; }
proof="$(mktemp -d /tmp/ap-android-dependency-proof.XXXXXX)"
echo "Independent Android dependency proof: $proof"
hash_recipe() (
    cd "$TEST_DIR/../.."
    shasum -a 256 scripts/android_env.sh scripts/android_deps.sh scripts/build_android_deps.sh \
        scripts/cross_compile_deps.sh config/android_toolchain.env
)
hash_recipe > "$proof/recipe-before.sha256"
BUILD_DIR="$proof/first" bash "$TEST_DIR/../cross_compile_deps.sh" android > "$proof/first-build.txt" 2>&1
# Deliberately poison settings that must not enter the clean build environment.
BUILD_DIR="$proof/second" CFLAGS=-I/invalid-host-headers CPPFLAGS=-I/invalid-host-headers \
    LDFLAGS=-L/invalid-host-libraries CPATH=/invalid-host-headers \
    LIBRARY_PATH=/invalid-host-libraries CMAKE_PREFIX_PATH=/invalid-host-packages \
    CONFIG_SITE=/invalid-host-config \
    bash "$TEST_DIR/../cross_compile_deps.sh" android > "$proof/second-build.txt" 2>&1
bash "$TEST_DIR/compare_android_dependencies.sh" "$proof/first" "$proof/second" | tee "$proof/comparison.txt"
bash "$TEST_DIR/android_dependency_cache.sh" "$proof/first" | tee "$proof/cache-tests.txt"
bash "$TEST_DIR/android_archives.sh" | tee "$proof/archive-tests.txt"
hash_recipe > "$proof/recipe-after.sha256"
cmp "$proof/recipe-before.sha256" "$proof/recipe-after.sha256"
echo "PASS: independent builds, byte-identical payloads, cache rejection and archive tests. Evidence: $proof" | tee "$proof/result.txt"
