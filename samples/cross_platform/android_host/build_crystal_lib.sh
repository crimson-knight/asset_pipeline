#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../../../scripts/android_env.sh
source "$PROJECT_ROOT/scripts/android_env.sh"

ANDROID_ABIS="${ANDROID_ABIS:-$ANDROID_SUPPORTED_ABIS}"
OUTPUT_NAME="${OUTPUT_NAME:-android_material_host}"
BRIDGE_SRC="${ASSET_PIPELINE_ANDROID_ENTRYPOINT:-$SCRIPT_DIR/android_material_bridge.cr}"

while IFS= read -r abi; do
  [[ -n "$abi" ]] || continue
  android_configure_abi "$abi" "${ANDROID_API:-$ANDROID_NATIVE_API}"
  HOST_LIB_DIR="$SCRIPT_DIR/app/src/main/jniLibs/$abi"
  mkdir -p "$HOST_LIB_DIR"

  ANDROID_ABI="$abi" \
  EXTRA_C_SOURCES="${PROJECT_ROOT}/src/ui/native/android_bridge.c ${PROJECT_ROOT}/src/ui/native/jni_collection_bridge.c ${PROJECT_ROOT}/src/ui/native/android_private_files.c ${SCRIPT_DIR}/android_host_jni.c" \
    "${PROJECT_ROOT}/scripts/build_android.sh" "$BRIDGE_SRC" "$OUTPUT_NAME"

  cp "${PROJECT_ROOT}/build/android-${ANDROID_ABI_SLUG}/lib${OUTPUT_NAME}.so" "${HOST_LIB_DIR}/lib${OUTPUT_NAME}.so"
  echo "Copied lib${OUTPUT_NAME}.so to ${HOST_LIB_DIR}"
done < <(android_each_abi "$ANDROID_ABIS")
