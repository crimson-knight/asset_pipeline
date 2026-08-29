# A Minimal Cross-Platform App

This section walks through the smallest useful thing you can build with the
asset_pipeline UI system: **one `UI::View` tree** rendered to **web**, **macOS
native**, and the **iOS simulator** — from the same Crystal source.

The goal is to prove the core promise of the library: you author a view tree
once, and a compile-time-selected renderer turns it into HTML, AppKit, or
UIKit. Nothing in the tree below changes per platform; only the build command
and the renderer you instantiate differ.

The exact commands here mirror the Voyager sample's `Makefile`
(`samples/initiative-cross-platform-ui-voyager/Makefile`) and iOS bridge script
(`samples/initiative-cross-platform-ui-voyager/ios/build_crystal_lib.sh`). Paths
are written relative to the shard root (the directory containing `shard.yml`).
When consuming asset_pipeline as a dependency, that root is
`lib/asset_pipeline/` inside your project, and the source paths below become
`lib/asset_pipeline/src/...`.

> **Compiler matrix:** Use plain `crystal` for the web target. Use
> `crystal-alpha` (Homebrew CLI `acrystal`) for the macOS and iOS native
> targets — the native renderers require it. See
> `docs/web-design-system/compiler-command-matrix.md`.

---

## The shared view tree

Create one source file. This is the *entire* app logic, shared by all three
targets.

`hello/view.cr`:

```crystal
require "asset_pipeline/ui"

# A single function builds the tree. No platform branching here — that is
# the whole point. The renderer is chosen at build time, not in this code.
module Hello
  def self.build : UI::View
    stack = UI::VStack.new(spacing: 12.0)
    stack << UI::Label.new("Hello from Asset Pipeline")
    stack << UI::Button.new("Tap me") do
      puts "Button pressed!"
    end
    stack
  end
end
```

`UI::Button`'s block is the action callback. It fires natively on macOS/iOS
(driven by the AppKit/UIKit renderer) and is a no-op in the static web build
(static HTML cannot invoke a Crystal `Proc` — see the web target note below).

Every interactive element should carry an `accessibility_label`; `UI::Button`
derives one from its title by default, but set it explicitly for icon-only or
ambiguous controls.

---

## (a) Web

The web target is pure Crystal — **no native toolchain, no `-D` flag, no ObjC
bridge.** You instantiate `UI::Web::Renderer` and call `render`, which returns
an HTML string you write to disk (or serve).

`hello/web.cr`:

```crystal
require "./view"
require "asset_pipeline/ui/renderers/web_renderer"

renderer = UI::Web::Renderer.new

# Theme CSS (design tokens → :root custom properties) is emitted once.
theme_css = renderer.inject_theme_css
body_html = renderer.render(Hello.build)

html = String.build do |io|
  io << "<!doctype html>\n"
  io << %(<html lang="en" data-appearance="light">) << '\n'
  io << "<head>\n"
  io << %(<meta charset="utf-8">) << '\n'
  io << %(<meta name="viewport" content="width=device-width, initial-scale=1">) << '\n'
  io << "<style>" << theme_css << "</style>\n"
  io << "</head>\n<body>\n"
  io << body_html
  io << "\n</body>\n</html>\n"
end

File.write("output/hello.html", html)
puts "wrote output/hello.html"
```

Build and run with **plain `crystal`** (mirrors the Voyager `make web` target,
which runs `crystal run web/static_site.cr`):

```bash
mkdir -p output
crystal run hello/web.cr
open output/hello.html        # macOS; or just open the file in a browser
```

That is the complete web flow. No bridge compilation, no link flags.

> **Web target is static.** The button's Crystal `Proc` does not run in the
> emitted HTML. For interactivity on the web you either (1) drive a server-side
> render loop via Amber (`UI::AmberIntegration.routes_for`, the full-server
> target), or (2) layer client-side JS over the fragments (the static-site
> approach Voyager uses). Both are out of scope for this minimal example.

---

## (b) macOS native

The macOS target uses `crystal-alpha`, the `-Dmacos` flag (which activates
`UI::AppKit::Renderer`), and a set of **pre-compiled ObjC/SwiftKit bridge object
files** that must be linked into the binary.

`hello/macos.cr`:

```crystal
require "./view"
require "asset_pipeline/ui/renderers/appkit_renderer"

{% if flag?(:macos) %}
  renderer = UI::AppKit::Renderer.new   # MUST be constructed before build —
                                        # its initializer installs the device
                                        # provider screens read during build.
  native_view = renderer.render(Hello.build)
  # native_view wraps an NSStackView. A real app installs it as an NSWindow
  # contentView and pumps the run loop (see the Voyager macOS host for the
  # full NSWindow + run-loop wiring).
{% end %}
```

### Step 1 — compile the bridges (one-time per source change)

The AppKit renderer calls through typed C wrappers (`objc_bridge.m`) and the
SwiftUI facade (`swiftkit_bridge.m` + the `AssetPipelineSwiftKit` Swift
package). Compile them with **`-fno-objc-arc`** before linking:

```bash
# ObjC bridge → objc_bridge.o
clang -c lib/asset_pipeline/src/ui/native/objc_bridge.m \
  -o lib/asset_pipeline/src/ui/native/objc_bridge.o -fno-objc-arc

# SwiftKit C trampolines → swiftkit_bridge.o
clang -c lib/asset_pipeline/src/ui/native/swiftkit_bridge.m \
  -o lib/asset_pipeline/src/ui/native/swiftkit_bridge.o -fno-objc-arc

# SwiftKit Swift facade → libAssetPipelineSwiftKit.a (arch-specific path)
swift build -c release \
  --package-path lib/asset_pipeline/swift/AssetPipelineSwiftKit
```

> **Why pin the arch-specific path?** SPM repoints its `.build/release` symlink
> to whichever triple was built last. If you build for iOS afterward, that
> symlink points at iOS objects and the macOS link fails with *"building for
> 'macOS' but linking object built for 'iOS-simulator'."* Reference the macOS
> slice directly (assumes an arm64 host):
> `lib/asset_pipeline/swift/AssetPipelineSwiftKit/.build/arm64-apple-macosx/release/libAssetPipelineSwiftKit.a`

### Step 2 — build with `crystal-alpha` and the link-flags line

```bash
crystal-alpha build hello/macos.cr -o bin/hello -Dmacos \
  --link-flags="lib/asset_pipeline/src/ui/native/objc_bridge.o \
    lib/asset_pipeline/src/ui/native/swiftkit_bridge.o \
    -Wl,-force_load,lib/asset_pipeline/swift/AssetPipelineSwiftKit/.build/arm64-apple-macosx/release/libAssetPipelineSwiftKit.a \
    -framework AppKit -framework Foundation \
    -framework SwiftUI -framework Combine \
    -framework CoreGraphics -framework QuartzCore \
    -lobjc \
    -Wl,-rpath,/usr/lib/swift"
```

The two object files are linked positionally; `-Wl,-force_load` pulls in the
whole Swift static archive (the SwiftUI facade types are referenced indirectly
and would otherwise be dead-stripped). `-Wl,-rpath,/usr/lib/swift` lets the
Swift runtime resolve at launch.

The Voyager `make macos` target links **more** frameworks (WebKit, MapKit,
AVKit, etc.) because it exercises media/web views. For this minimal tree
(`VStack` + `Label` + `Button`) the framework list above is sufficient; add a
framework only when you introduce a view that needs it.

Run it:

```bash
./bin/hello
```

> **Bare-minimum alternative (CLAUDE.md form).** If you only need the AppKit
> renderer and not the SwiftUI facade, you can drop the SwiftKit object,
> archive, and the `SwiftUI`/`Combine` frameworks, linking just:
> `--link-flags="lib/asset_pipeline/src/ui/native/objc_bridge.o -framework AppKit -framework Foundation -lobjc"`.
> The SwiftKit bridge is what supplies the Liquid Glass / SwiftUI-backed polish,
> so production Apple-native builds should keep it.

---

## (c) iOS simulator

iOS is the most involved target because Crystal cannot produce an iOS app
bundle directly. The flow (mirroring Voyager's `make ios`) is three stages:

1. **Cross-compile** the Crystal view code into a static library
   (`libhello.a`) with `crystal-alpha --cross-compile -Dios`.
2. **Generate** an Xcode project (the Swift `@main` app links `libhello.a`).
3. **Build** with `xcodebuild` against an iPhone simulator destination.

### Step 1 — cross-compile the Crystal bridge to a static library

Use the Voyager `ios/build_crystal_lib.sh` script as the template. The essential
commands it runs (simulator target, arm64 host):

```bash
# Resolve the simulator SDK + clang once.
LLVM_TARGET="arm64-apple-ios-simulator"
SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"
CLANG="$(xcrun --sdk iphonesimulator --find clang)"
MIN_IOS_VER="16.0"

mkdir -p ios/build

# 1a. ObjC bridge for the simulator slice.
"$CLANG" -c lib/asset_pipeline/src/ui/native/objc_bridge.m \
  -o ios/build/objc_bridge_ios.o \
  -target "$LLVM_TARGET" -isysroot "$SDK_PATH" \
  -mios-version-min=$MIN_IOS_VER -fno-objc-arc

# 1b. SwiftKit C trampolines for the simulator slice.
"$CLANG" -c lib/asset_pipeline/src/ui/native/swiftkit_bridge.m \
  -o ios/build/swiftkit_bridge_ios.o \
  -target "$LLVM_TARGET" -isysroot "$SDK_PATH" \
  -mios-version-min=$MIN_IOS_VER -fno-objc-arc

# 1c. SwiftKit Swift facade for the simulator triple.
swift build -c release \
  --package-path lib/asset_pipeline/swift/AssetPipelineSwiftKit \
  --triple "$LLVM_TARGET" --sdk "$SDK_PATH"

# 1d. Cross-compile the Crystal view code (-Dios) to an object file.
#     `hello/ios_bridge.cr` requires ./view and the uikit_renderer, and
#     exposes a C-callable entry the Swift @main app calls (see Voyager
#     ios/bridge.cr for the exported-function pattern).
crystal-alpha build hello/ios_bridge.cr --cross-compile \
  --target="$LLVM_TARGET" -Dios -o ios/build/bridge

# 1e. Hide Crystal's _main so it coexists with the Swift @main entry point.
ld -r -unexported_symbol _main ios/build/bridge.o -o ios/build/bridge_fixed.o
mv ios/build/bridge_fixed.o ios/build/bridge.o

# 1f. Pack everything into one static library the Xcode app links.
ar rcs ios/build/libhello.a \
  ios/build/bridge.o \
  ios/build/objc_bridge_ios.o \
  ios/build/swiftkit_bridge_ios.o
```

The simplest path is to **copy `samples/initiative-cross-platform-ui-voyager/ios/build_crystal_lib.sh`**,
point `BRIDGE_SRC` at your `hello/ios_bridge.cr`, and rename the output lib. Run
it as:

```bash
bash ios/build_crystal_lib.sh simulator
```

> The `-Dios` cross-compile and the `_main` hiding step are mandatory. Without
> hiding `_main`, the Crystal library collides with Swift's `@main`. (Note: on
> iOS, Crystal class-var initializers and `Crystal::once` lookup tables may not
> run because `_main` is suppressed — a known platform gap; keep iOS-only init
> defensive.)

### Step 2 — generate the Xcode project

Voyager uses `xcodegen` with a `project.yml` that sets `SWIFT_INCLUDE_PATHS` to
the staged `Modules/` directory and links `libhello.a`:

```bash
cd ios && xcodegen generate
```

### Step 3 — build for the simulator with `xcodebuild`

```bash
xcodebuild build \
  -project ios/HelloDemo.xcodeproj \
  -scheme HelloDemo \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  CODE_SIGNING_ALLOWED=NO
```

Override the destination device with the Voyager-style variable if needed
(`-destination "platform=iOS Simulator,name=iPhone 16 Pro"`). To launch the
built `.app`, install it on a booted simulator with `xcrun simctl install` /
`xcrun simctl launch`, or run the scheme from Xcode.

---

## Command summary

| Target | Compiler | Flag | Bridge / link step | Output |
|--------|----------|------|--------------------|--------|
| Web | `crystal` | none | none | `output/hello.html` |
| macOS | `crystal-alpha` | `-Dmacos` | `objc_bridge.o` + `swiftkit_bridge.o` + `-force_load` SwiftKit `.a` | `bin/hello` |
| iOS sim | `crystal-alpha` | `-Dios` (cross-compile) | `ar` into `libhello.a` → `xcodebuild` | `HelloDemo.app` |

The view tree (`hello/view.cr`) is identical across all three rows. That is the
deliverable this section set out to demonstrate.

---

## Where to go from here

- **Multiple screens + navigation + action dispatch:** see the `ui-app` skill
  and `docs/initiative-cross-platform-ui/tutorial-ui-app.md` (`UI::App`,
  `UI::Screen`, `UI::Controller`, `UI::ActionDispatcher`).
- **Full server-side web with live actions:** `UI::AmberIntegration.routes_for`
  (the Amber full-server target).
- **A complete, real reference for all three hosts:**
  `samples/initiative-cross-platform-ui-voyager/` — its `Makefile`,
  `web/static_site.cr`, `macos/host.cr`, and `ios/build_crystal_lib.sh` are the
  authoritative source for the commands above.
