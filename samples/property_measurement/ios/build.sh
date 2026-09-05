#!/usr/bin/env bash
set -euo pipefail
# Isolated native fixture; requires prebuilt iOS-simulator gc/PCRE2 only.
task_dir="$(cd "$(dirname "$0")" && pwd)"
task_root="$(cd "$task_dir/../../.." && pwd)"
task_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
task_build="$task_dir/build"
mkdir -p "$task_build"
xcrun --sdk iphonesimulator clang -c "$task_root/src/ui/native/objc_bridge.m" -o "$task_build/objc.o" -target arm64-apple-ios17.0-simulator -isysroot "$task_sdk" -fno-objc-arc
xcrun --sdk iphonesimulator clang -c "$task_root/src/ui/native/swiftkit_bridge.m" -o "$task_build/swiftkit.o" -target arm64-apple-ios17.0-simulator -isysroot "$task_sdk" -fno-objc-arc
# No package downloads: this library target has no external dependencies.
task_swift_sources=()
while IFS= read -r task_source; do
  task_swift_sources+=("$task_source")
done < <(rg --files "$task_root/swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit" -g '*.swift')
swiftc -emit-library -static -O -module-name AssetPipelineSwiftKit -target arm64-apple-ios17.0-simulator -sdk "$task_sdk" "${task_swift_sources[@]}" -o "$task_build/swiftkit_simulator.a"
"${CRYSTAL:-crystal-alpha}" build "$task_dir/bridge.cr" --cross-compile --target=arm64-apple-ios-simulator -Dios -o "$task_build/bridge"
ld -r -unexported_symbol _main "$task_build/bridge.o" -o "$task_build/bridge_fixed.o"
ar rcs "$task_build/libpropertyfixture.a" "$task_build/bridge_fixed.o" "$task_build/objc.o" "$task_build/swiftkit.o"
xcodegen generate --spec "$task_dir/project.yml"
