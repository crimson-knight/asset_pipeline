#!/usr/bin/env bash
set -euo pipefail
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TEST_DIR/../android_env.sh"
OUTPUT_DIR="$(mktemp -d /tmp/asset-pipeline-archive-test.XXXXXX)"
expect_failure() {
    if android_validate_archive "$1" "$2" fixture > "$OUTPUT_DIR/last-failure.txt" 2>&1; then
        echo "ERROR: invalid archive accepted: $1 ($2)" >&2
        exit 1
    fi
}

android_configure_abi x86_64
"$ANDROID_NDK_CLANG" -c "$TEST_DIR/android_archive_test.c" -o "$OUTPUT_DIR/x86.o"
android_configure_abi arm64-v8a
"$ANDROID_NDK_CLANG" -c "$TEST_DIR/android_archive_test.c" -o "$OUTPUT_DIR/arm.o"
"$ANDROID_NDK_TOOLCHAIN/llvm-ar" rcs "$OUTPUT_DIR/valid.a" "$OUTPUT_DIR/arm.o"
"$ANDROID_NDK_TOOLCHAIN/llvm-ar" rcs "$OUTPUT_DIR/mixed.a" "$OUTPUT_DIR/arm.o" "$OUTPUT_DIR/x86.o"
"$ANDROID_NDK_TOOLCHAIN/llvm-ar" rcs "$OUTPUT_DIR/empty.a"
android_validate_archive "$OUTPUT_DIR/valid.a" asset_pipeline_archive_probe fixture
expect_failure "$OUTPUT_DIR/empty.a" asset_pipeline_archive_probe
expect_failure "$OUTPUT_DIR/mixed.a" asset_pipeline_archive_probe
expect_failure "$OUTPUT_DIR/valid.a" asset_pipeline_archive_prob
expect_failure "$OUTPUT_DIR/missing.a" asset_pipeline_archive_probe
echo "Archive validation passed: valid, empty, mixed architecture, exact symbol, missing file."
