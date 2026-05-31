# Native Bridge Compilation (macOS / iOS)

When you build a native macOS or iOS app with asset_pipeline, the Crystal
renderers (`UI::AppKit::Renderer`, `UI::UIKit::Renderer`) do **not** call
AppKit/UIKit directly. They call through two ObjC C-bridges plus a Swift
facade that you must compile and link yourself:

| Artifact | Source | Purpose |
|----------|--------|---------|
| `objc_bridge.o` | `src/ui/native/objc_bridge.m` | Typed C wrappers for ARM64-safe `objc_msgSend` calls (NSView / UIView, stacks, labels, buttons, etc.) |
| `swiftkit_bridge.o` | `src/ui/native/swiftkit_bridge.m` | C trampolines that bridge Crystal into the Swift facade |
| `libAssetPipelineSwiftKit.a` | `swift/AssetPipelineSwiftKit/` | The Phase 3 SwiftUI facade (Liquid Glass, semantic colors, HIG chrome) |

> **Compiler:** native macOS / iOS builds use `crystal-alpha` (Homebrew CLI
> `acrystal`), **not** plain `crystal`. Plain `crystal` is for the web /
> design-system targets only. All paths below are relative to the
> asset_pipeline shard root. In a consumer project the shard lives at
> `lib/asset_pipeline/`, so prefix accordingly (e.g.
> `lib/asset_pipeline/src/ui/native/objc_bridge.m`).

The require in your app is always:

```crystal
require "asset_pipeline/ui"   # NOT "ui" — resolves to lib/asset_pipeline/src/ui.cr
```

---

## 1. Compile the ObjC bridges (`clang -c -fno-objc-arc`)

Both ObjC bridges are compiled with **ARC disabled** (`-fno-objc-arc`) — the
Crystal side owns object lifetimes through `NativeHandle` / `ReleaseStrategy`,
so ARC must stay out of the way.

### macOS

```bash
clang -c src/ui/native/objc_bridge.m \
  -o src/ui/native/objc_bridge.o -fno-objc-arc

clang -c src/ui/native/swiftkit_bridge.m \
  -o src/ui/native/swiftkit_bridge.o -fno-objc-arc
```

### iOS (cross-compiled against the simulator or device SDK)

For iOS you must compile each bridge against the right SDK and triple. Resolve
the SDK path and the SDK-pinned clang with `xcrun`, then pass `-target`,
`-isysroot`, and `-mios-version-min`:

```bash
# Pick one:
#   simulator -> arm64-apple-ios-simulator / iphonesimulator
#   device    -> arm64-apple-ios           / iphoneos
LLVM_TARGET="arm64-apple-ios-simulator"
SDK_NAME="iphonesimulator"

SDK_PATH="$(xcrun --sdk $SDK_NAME --show-sdk-path)"
CLANG="$(xcrun --sdk $SDK_NAME --find clang)"

"$CLANG" -c src/ui/native/objc_bridge.m -o build/objc_bridge_ios.o \
  -target "$LLVM_TARGET" -isysroot "$SDK_PATH" \
  -mios-version-min=16.0 -fno-objc-arc

"$CLANG" -c src/ui/native/swiftkit_bridge.m -o build/swiftkit_bridge_ios.o \
  -target "$LLVM_TARGET" -isysroot "$SDK_PATH" \
  -mios-version-min=16.0 -fno-objc-arc
```

iOS minimum deployment target is **16.0** (matches the platform minimums).

---

## 2. Build AssetPipelineSwiftKit (`swift build -c release`)

The Swift facade is an SPM package at `swift/AssetPipelineSwiftKit`. Build it
in release mode.

### macOS

```bash
swift build -c release --package-path swift/AssetPipelineSwiftKit
```

This produces the static library at the **arch-specific** path:

```
swift/AssetPipelineSwiftKit/.build/arm64-apple-macosx/release/libAssetPipelineSwiftKit.a
```

### iOS

For iOS, build against the same triple + SDK you used for the bridges:

```bash
swift build -c release --package-path swift/AssetPipelineSwiftKit \
  --triple "$LLVM_TARGET" --sdk "$SDK_PATH"
```

The iOS static library lands at the triple-specific path:

```
swift/AssetPipelineSwiftKit/.build/$LLVM_TARGET/release/libAssetPipelineSwiftKit.a
```

You also need the Swift module artifacts (`AssetPipelineSwiftKit.swiftmodule`,
`.swiftdoc`, `.abi.json`) for `import AssetPipelineSwiftKit` in your app's
Swift `@main` host. They live alongside the `.a` under
`.build/$LLVM_TARGET/release/Modules`; stage them into a directory your Xcode
project points at via `SWIFT_INCLUDE_PATHS`.

---

## ⚠️ The `.build/release` contamination gotcha (real bug)

SPM exposes a convenience symlink, `.build/release`, that points at the
**last-built triple's** release directory. This symlink is a trap when you
build both macOS and iOS slices of AssetPipelineSwiftKit from the same package
checkout:

- A macOS `swift build -c release` points `.build/release` at
  `arm64-apple-macosx/release`.
- An iOS `swift build -c release --triple arm64-apple-ios-simulator` then
  **repoints** `.build/release` at `arm64-apple-ios-simulator/release`.

If your macOS link flags reference the symlink
(`.build/release/libAssetPipelineSwiftKit.a`), the macOS link will pick up the
**iOS** library after an iOS build ran, and the linker fails with:

```
building for 'macOS' but linking object built for 'iOS-simulator'
```

**Fix: always reference the arch-specific slice path, never the
`.build/release` symlink.** Pin macOS to:

```
swift/AssetPipelineSwiftKit/.build/arm64-apple-macosx/release/libAssetPipelineSwiftKit.a
```

and pin iOS to its triple-specific path
(`.build/arm64-apple-ios-simulator/release/...`). The iOS build script
additionally **copies** the staged library out to a target-named file
(`swiftkit_simulator.a` / `swiftkit_device.a`) so the iOS and macOS targets can
coexist without clobbering each other. (arm64 host is assumed throughout,
consistent with the iOS triples.)

---

## 3. Link the bridges + SwiftKit into your Crystal binary

### macOS (single binary via `crystal-alpha build`)

Pass the two `.o` bridges, force-load the SwiftKit static lib, the frameworks,
and an rpath to the Swift runtime. `-Wl,-force_load` is required so the
linker keeps the SwiftKit symbols even though Crystal has no direct reference
to them:

```bash
crystal-alpha build src/app.cr -o bin/app -Dmacos \
  --link-flags="src/ui/native/objc_bridge.o \
    src/ui/native/swiftkit_bridge.o \
    -Wl,-force_load,swift/AssetPipelineSwiftKit/.build/arm64-apple-macosx/release/libAssetPipelineSwiftKit.a \
    -framework AppKit -framework Foundation \
    -framework SwiftUI -framework Combine \
    -framework ApplicationServices -framework CoreFoundation \
    -framework CoreGraphics -framework ImageIO -framework QuartzCore \
    -framework UserNotifications -framework WebKit \
    -framework MapKit -framework CoreLocation \
    -framework AVKit -framework AVFoundation \
    -lobjc \
    -Wl,-rpath,/usr/lib/swift"
```

> The full framework list above is what the Voyager sample links. A minimal
> app that only uses core views can trim to `-framework AppKit -framework
> Foundation -framework SwiftUI -framework Combine -lobjc
> -Wl,-rpath,/usr/lib/swift` and add the rest only as you adopt
> media / map / web / notification views.

If you ship a `.app`, code-sign after the build (ad-hoc `-` is fine for local
runs):

```bash
codesign --force --sign - --timestamp=none bin/app
```

### iOS (cross-compile + pack into a static lib for Xcode)

iOS does **not** produce a standalone Crystal binary. Instead:

1. Cross-compile the Crystal bridge to an object file:

   ```bash
   crystal-alpha build ios/bridge.cr --cross-compile \
     --target="$LLVM_TARGET" -Dios -o build/bridge
   ```

2. Hide the Crystal `_main` symbol so it can coexist with Swift `@main`:

   ```bash
   ld -r -unexported_symbol _main build/bridge.o -o build/bridge_fixed.o
   mv build/bridge_fixed.o build/bridge.o
   ```

3. Pack the Crystal object + both iOS ObjC bridges into one static library
   that Xcode links:

   ```bash
   ar rcs build/libvoyager.a \
     build/bridge.o build/objc_bridge_ios.o build/swiftkit_bridge_ios.o
   ```

The SwiftKit `.a` and staged `Modules/` are wired into the Xcode project
(via `SWIFT_INCLUDE_PATHS` / link settings), then built with `xcodebuild`.

The canonical, end-to-end iOS recipe lives in the Voyager sample script
`samples/initiative-cross-platform-ui-voyager/ios/build_crystal_lib.sh`
(`bash build_crystal_lib.sh simulator`).

---

## Reference Makefile (Voyager sample)

The Voyager sample's `Makefile`
(`samples/initiative-cross-platform-ui-voyager/Makefile`) is the most concise
copy-pasteable reference. Key variables:

```make
CRYSTAL_NATIVE := crystal-alpha

AP_BRIDGE     := $(SHARD_ROOT)/src/ui/native/objc_bridge.o
SWIFTKIT_BRIDGE := $(SHARD_ROOT)/src/ui/native/swiftkit_bridge.o

# Pin the arch-specific slice — NOT the .build/release symlink (see gotcha).
SWIFTKIT_LIB := $(SWIFTKIT_DIR)/.build/arm64-apple-macosx/release/libAssetPipelineSwiftKit.a

# Compile rules
$(AP_BRIDGE):       clang -c $(AP_BRIDGE_SRC)       -o $@ -fno-objc-arc
$(SWIFTKIT_BRIDGE): clang -c $(SWIFTKIT_BRIDGE_SRC) -o $@ -fno-objc-arc
$(SWIFTKIT_LIB):    swift build -c release --package-path $(SWIFTKIT_DIR)
```

Targets:

```bash
make macos    # compiles bridges + SwiftKit, links bin/voyager with crystal-alpha
make ios      # ios-bridge (build_crystal_lib.sh) -> xcodegen -> xcodebuild
```

---

## Checklist

- [ ] `objc_bridge.o` compiled with `-fno-objc-arc`
- [ ] `swiftkit_bridge.o` compiled with `-fno-objc-arc`
- [ ] `libAssetPipelineSwiftKit.a` built with `swift build -c release`
- [ ] macOS link references the **arch-specific** SwiftKit `.a`, not
      `.build/release` (avoids the iOS/macOS contamination bug)
- [ ] `-Wl,-force_load` on the SwiftKit lib + `-Wl,-rpath,/usr/lib/swift`
- [ ] iOS bridges compiled per-SDK with `xcrun`-resolved `-isysroot` /
      `-target` / `-mios-version-min=16.0`
- [ ] iOS Crystal object's `_main` hidden before `ar rcs`
- [ ] built with `crystal-alpha` (`acrystal`), not plain `crystal`
