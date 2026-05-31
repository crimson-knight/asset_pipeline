# Platform Flags & Renderer Activation

A single `UI::View` tree is rendered by a *platform renderer*. Which renderer
your build uses is decided **at compile time** by a `-D` flag, not at runtime.
Pick the wrong flag (or forget it) and you silently get the wrong renderer.

## The four renderers

| Target  | Compile flag | Renderer class          | Native backing                    |
|---------|--------------|-------------------------|-----------------------------------|
| Web     | *(none)*     | `UI::Web::Renderer`     | HTML/CSS (`Components::Elements`)  |
| macOS   | `-Dmacos`    | `UI::AppKit::Renderer`  | AppKit + SwiftUI (NSStackView, …)  |
| iOS     | `-Dios`      | `UI::UIKit::Renderer`   | UIKit + SwiftUI (UIStackView, …)   |
| Android | `-Dandroid`  | `UI::Android::Renderer` | JNI / Android Views                |

The three native renderer classes are wrapped in compile-time guards
(`{% if flag?(:macos) %}`, `{% if flag?(:ios) %}`, `{% if flag?(:android) %}`).
They literally **do not exist** in a build that lacks the matching flag — so
the renderer you can instantiate is determined entirely by how you compiled.

## ⚠️ Critical gotcha: no flag = Web renderer, even on macOS

`crystal-alpha` (the native compiler, aliased `acrystal`) does **not**
auto-detect your host OS. If you build on a Mac without `-Dmacos`, the AppKit
renderer is not compiled in, and your app silently falls back to
`UI::Web::Renderer` — producing HTML strings instead of an NSWindow. There is
no error; it just renders the wrong target.

```bash
# WRONG on macOS — compiles, runs, but uses UI::Web::Renderer (HTML output)
crystal-alpha build src/app.cr -o bin/app

# RIGHT — activates UI::AppKit::Renderer
crystal-alpha build src/app.cr -o bin/app -Dmacos --link-flags="..."
```

Rule of thumb: **web is the only target that takes no flag.** Every native
target must pass its flag. If a native app is emitting HTML or "looks like the
browser version," the missing `-D` flag is the first thing to check.

> **Compiler matrix:** use `crystal-alpha` / `acrystal` for native
> (`-Dmacos` / `-Dios` / `-Dandroid`) builds; use plain `crystal` for the web
> target. See `docs/web-design-system/compiler-command-matrix.md`.

## Requiring the UI system

All four renderers come from one require. The path is `asset_pipeline/ui`
(it maps to `src/ui.cr`), **not** `"ui"`:

```crystal
require "asset_pipeline/ui"
```

This pulls in `UI::Web::Renderer` unconditionally and the native renderers
behind their compile-time guards, so the only renderer you can name is the one
your `-D` flag enabled.

## Selecting / instantiating the renderer per target

### Web (no flag)

Plain `crystal`, no `-D`, no link flags:

```crystal
require "asset_pipeline/ui"

view = UI::VStack.new(spacing: 12.0)
view << UI::Label.new("Hello from Asset Pipeline")

renderer = UI::Web::Renderer.new
html = renderer.render(view) # -> HTML string
```

```bash
crystal run web/static_site.cr     # or: crystal build ... -o bin/site
```

This is exactly what the Voyager web sample does
(`samples/initiative-cross-platform-ui-voyager/web/static_site.cr`):
`renderer = UI::Web::Renderer.new`.

### macOS (`-Dmacos` → `UI::AppKit::Renderer`)

Compile the ObjC bridge first, then build with `-Dmacos` and link the bridge
object plus AppKit/Foundation:

```bash
# 1. Compile the ObjC bridge (no ARC)
clang -c src/ui/native/objc_bridge.m \
  -o src/ui/native/objc_bridge.o -fno-objc-arc

# 2. Build the app with the macOS renderer enabled
crystal-alpha build src/app.cr -o bin/app -Dmacos \
  --link-flags="src/ui/native/objc_bridge.o \
    -framework AppKit -framework Foundation -lobjc"
```

```crystal
require "asset_pipeline/ui"

renderer = UI::AppKit::Renderer.new
native_view = renderer.render(view) # -> UI::NativeView wrapping an NSStackView
```

If your app reaches SwiftUI defaults / Liquid Glass (the Phase 3 SwiftUI
facade), you must also build `AssetPipelineSwiftKit`, compile
`swiftkit_bridge.m`, and force-load the Swift static lib. The Voyager macOS
Makefile (`samples/initiative-cross-platform-ui-voyager/Makefile`) is the
canonical recipe — note it uses `crystal-alpha`, force-loads the
arch-specific `libAssetPipelineSwiftKit.a`, and links a broad framework set:

```makefile
crystal-alpha build $(MACOS_SRC) -o $(MACOS_BIN) -Dmacos \
    --link-flags="$(AP_BRIDGE) $(SWIFTKIT_BRIDGE) $(WIN_HELPER) \
      -Wl,-force_load,$(SWIFTKIT_LIB) \
      -framework AppKit -framework Foundation -framework SwiftUI \
      -framework Combine ... -lobjc \
      -Wl,-rpath,/usr/lib/swift"
```

Build it via the sample with `make macos` (or `make macos-run` to open a
window). Plain `-framework AppKit -framework Foundation -lobjc` is enough only
for builds that do not exercise the SwiftUI facade.

> **Renderer ordering gotcha:** construct `UI::AppKit::Renderer.new` *before*
> `screen.build` — the initializer installs the `DesignTokens::Device` provider
> that screens query during build. (The same construct-before-build rule
> applies to `UI::UIKit::Renderer.new`.)

### iOS (`-Dios` → `UI::UIKit::Renderer`)

iOS is a **cross-compile**: Crystal produces a static library that links into
an Xcode/Swift app, so you never run `crystal-alpha build ... -o bin/app`
directly. Cross-compile the bridge with `--cross-compile`, `--target`, and
`-Dios`:

```bash
crystal-alpha build ios/bridge.cr --cross-compile \
  --target="arm64-apple-ios-simulator" -Dios -o build/bridge
```

`samples/initiative-cross-platform-ui-voyager/ios/build_crystal_lib.sh` drives
the full pipeline (run it as `./build_crystal_lib.sh simulator` or
`./build_crystal_lib.sh device`):

1. Compile the ObjC bridge for the iOS triple:
   ```bash
   clang -c src/ui/native/objc_bridge.m -o build/objc_bridge_ios.o \
     -target arm64-apple-ios-simulator \
     -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
     -mios-version-min=16.0 -fno-objc-arc
   ```
2. Build `AssetPipelineSwiftKit` for the iOS triple
   (`swift build -c release --triple arm64-apple-ios-simulator --sdk ...`).
3. Cross-compile the Crystal bridge with `-Dios` (command above).
4. Hide the `_main` symbol so the Crystal lib coexists with Swift's `@main`:
   ```bash
   ld -r -unexported_symbol _main build/bridge.o -o build/bridge_fixed.o
   ```
5. Pack everything into `libvoyager.a` with `ar rcs`, then build the app with
   `xcodebuild` (the sample uses `xcodegen` to generate the project, then
   `xcodebuild build -scheme VoyagerDemo -destination "platform=iOS Simulator,name=iPhone 17"`).

In Crystal code the renderer is the same shape:

```crystal
require "asset_pipeline/ui"

renderer = UI::UIKit::Renderer.new
native_view = renderer.render(view) # -> UI::NativeView wrapping a UIStackView
```

Run the whole pipeline via the sample with `make ios`. (The device vs.
simulator triple — `arm64-apple-ios` vs. `arm64-apple-ios-simulator`, SDK
`iphoneos` vs. `iphonesimulator` — is the only difference; min iOS version is
16.0.)

### Android (`-Dandroid` → `UI::Android::Renderer`)

Build with `-Dandroid` to compile in `UI::Android::Renderer` (JNI / Android
Views backing). Like iOS this is a cross-compile that links into the host app.

```crystal
require "asset_pipeline/ui"

renderer = UI::Android::Renderer.new # only exists under -Dandroid
```

## Quick verification

- Building for native and seeing HTML or browser-style output → the `-D` flag
  is missing; the build fell back to `UI::Web::Renderer`.
- `Error: undefined constant UI::AppKit::Renderer` (or `UIKit` / `Android`) →
  you named a native renderer without the matching flag. Add `-Dmacos` /
  `-Dios` / `-Dandroid`.
- Link errors mentioning `objc_msgSend` / `_objc_*` on macOS or iOS → the
  `objc_bridge.o` was not compiled or not in `--link-flags`.
- "building for 'macOS' but linking object built for 'iOS-simulator'" → a prior
  iOS `swift build` repointed `.build/release`; pin the arch-specific SwiftKit
  lib path (the Voyager Makefile documents this).

## Picking the renderer in app code

The renderer class is fixed by the flag, so most apps just instantiate the one
their build enabled. If you want a single source file that compiles to multiple
targets, gate the instantiation on the same flags:

```crystal
require "asset_pipeline/ui"

renderer =
  {% if flag?(:macos) %}
    UI::AppKit::Renderer.new
  {% elsif flag?(:ios) %}
    UI::UIKit::Renderer.new
  {% elsif flag?(:android) %}
    UI::Android::Renderer.new
  {% else %}
    UI::Web::Renderer.new
  {% end %}
```

Because the branches are `flag?` macro conditions, only the selected
renderer's code is compiled in — there is zero runtime dispatch overhead, and
naming a native renderer without its flag is a compile-time error rather than a
silent fallback. For the full web app path (Amber full-server), prefer
`UI::AmberIntegration.routes_for(App)`, which wires the `UI::View` tree to
`UI::Web::Renderer` for you.
