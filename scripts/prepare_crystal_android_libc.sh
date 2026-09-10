#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=android_env.sh
source "$SCRIPT_DIR/android_env.sh"

OUTPUT_ROOT="${1:-$ANDROID_PROJECT_ROOT/build/crystal-android-libc-overlay}"
CRYSTAL_BIN="${CRYSTAL:-crystal}"
CRYSTAL_PATH_VALUE="$($CRYSTAL_BIN env CRYSTAL_PATH)"
CRYSTAL_STDLIB_ROOT=""

while IFS= read -r candidate; do
    if [[ -d "$candidate/lib_c/aarch64-linux-android/c" ]]; then
        CRYSTAL_STDLIB_ROOT="$candidate"
        break
    fi
done < <(printf '%s\n' "$CRYSTAL_PATH_VALUE" | tr ':' '\n')

[[ -n "$CRYSTAL_STDLIB_ROOT" ]] || {
    echo "ERROR: Crystal's aarch64 Android libc bindings were not found in CRYSTAL_PATH." >&2
    exit 1
}

CRYSTAL_VERSION="$($CRYSTAL_BIN --version | awk 'NR == 1 { print $2 }')"
[[ "$CRYSTAL_VERSION" == "$CRYSTAL_ANDROID_VERSION" ]] || {
    echo "ERROR: Crystal $CRYSTAL_VERSION cannot generate the pinned $CRYSTAL_ANDROID_VERSION Android overlay." >&2
    exit 1
}

SOURCE_TARGET="$CRYSTAL_STDLIB_ROOT/lib_c/aarch64-linux-android"
X86_SOURCE="$CRYSTAL_STDLIB_ROOT/lib_c/x86_64-linux-gnu"
OVERLAY_TARGET="$OUTPUT_ROOT/lib_c/x86_64-linux-android"
mkdir -p "$OVERLAY_TARGET"

# Most Android bionic bindings are shared by these LP64 architectures. The
# x86_64 va_list, stat layout, and getrandom syscall number differ.
cp -R "$SOURCE_TARGET/." "$OVERLAY_TARGET/"
cp "$X86_SOURCE/c/stdarg.cr" "$OVERLAY_TARGET/c/stdarg.cr"
cp "$SCRIPT_DIR/android_libc_overrides/x86_64/c/sys/stat.cr" "$OVERLAY_TARGET/c/sys/stat.cr"
sed -i.bak 's/SYS_getrandom = 278/SYS_getrandom = 318/' "$OVERLAY_TARGET/c/sys/syscall.cr"
rm -f "$OVERLAY_TARGET/c/sys/syscall.cr.bak"

# Crystal resolves Android requires through <architecture>-android. Its
# bundled aarch64 bindings provide the same alias to the full triple path.
ln -sfn x86_64-linux-android "$OUTPUT_ROOT/lib_c/x86_64-android"

android_configure_abi x86_64 "$ANDROID_NATIVE_API"
"$ANDROID_NDK_CLANG" \
    -c \
    -std=c11 \
    "$SCRIPT_DIR/validate_android_libc_overlay.c" \
    -o "$OUTPUT_ROOT/x86_64-android-libc-layouts.o"

{
    echo "format=asset-pipeline-crystal-android-libc-v1"
    echo "crystal_version=$CRYSTAL_VERSION"
    echo "source_target=aarch64-linux-android"
    echo "target=x86_64-linux-android"
    echo "native_api=$ANDROID_NATIVE_API"
    echo "validation=ndk-static-assertions-passed"
} > "$OUTPUT_ROOT/overlay.manifest"

printf '%s\n' "$OUTPUT_ROOT"
