# Install & Require

This section gets `asset_pipeline` into your project as a shard, shows the one
`require` you actually need for the cross-platform UI system, and explains which
Crystal compiler to invoke for each target (web vs. native).

## 1. Add the shard dependency

The shard name is **`asset_pipeline`** (see `shard.yml`: `name: asset_pipeline`,
`version: 0.36.0`, `crystal: '>= 1.10.1'`). It ships with **zero runtime
dependencies**.

Add it to your project's `shard.yml`:

```yaml
dependencies:
  asset_pipeline:
    github: crimson-knight/asset_pipeline
    version: ~> 0.36.0
```

If you are tracking a branch instead of a tagged release:

```yaml
dependencies:
  asset_pipeline:
    github: crimson-knight/asset_pipeline
    branch: main
```

Then install:

```bash
shards install
```

This vendors the shard into `lib/asset_pipeline/`. That path matters later: the
native ObjC bridge source lives at
`lib/asset_pipeline/src/ui/native/objc_bridge.m` once the shard is installed
(see step 4).

## 2. The require

For the cross-platform `UI::View` system (`UI::VStack`, `UI::Button`,
`UI::App`, `UI::Screen`, etc.) require **`asset_pipeline/ui`** — note the
`asset_pipeline/` prefix:

```crystal
require "asset_pipeline/ui"   # Cross-platform UI views — CORRECT
```

Do **not** require `"ui"`. That resolves to the wrong path (or nothing) and will
not load the view tree, the design tokens, or the platform renderers:

```crystal
require "ui"                  # WRONG — do not use
```

`require "asset_pipeline/ui"` pulls in the full UI surface: the view types, the
`UI::Environment` / `UI::RenderContext` machinery, `UI::FormState`,
`UI::NavigationCoordinator`, the widget-route registry, and every
`PlatformRenderer`. The renderer that actually runs is chosen at compile time
from your `-D` flags (step 3).

If instead you only want the web-side HTML/CSS/component library (the 94
`Components::Elements::*` classes, `Components::CSS`, Amber integration helpers
in `Components::Integration`, and `AssetPipeline::FrontLoader`), require the
top-level shard:

```crystal
require "asset_pipeline"       # Web HTML elements, CSS engine, Amber helpers, FrontLoader
```

For a cross-platform app you generally want `require "asset_pipeline/ui"`.

## 3. crystal vs. crystal-alpha (acrystal)

There are two compilers, and the target decides which one you use:

| Target | Compiler | Why |
|--------|----------|-----|
| **Web** (default renderer, HTML output) | plain `crystal` | Pure Crystal, no native toolchain needed |
| **macOS / iOS / Android** (native renderers) | `crystal-alpha` (CLI: `acrystal`) | Native bridges require the alpha compiler |

`crystal-alpha` is the native compiler (installed via the Homebrew tap
`crimson-knight/homebrew-agent-crystal`; its CLI is `acrystal`, and it accepts
standard Crystal flags). The Voyager sample encodes exactly this split in its
`Makefile`:

```makefile
CRYSTAL_VANILLA := crystal        # web target
CRYSTAL_NATIVE  := crystal-alpha  # macOS / iOS native targets
```

### Web (plain `crystal`, no `-D` flag)

With no platform flag, the build uses `UI::Web::Renderer` and emits HTML:

```bash
crystal run path/to/your_web_site.cr
```

(The Voyager sample's `make web` runs `crystal run .../web/static_site.cr`.)

### macOS native (`crystal-alpha` + `-Dmacos`)

`crystal-alpha` does **not** auto-detect the platform — you MUST pass the
`-D` flag, or the build silently falls back to the Web renderer even on macOS:

- `-Dmacos` → `UI::AppKit::Renderer`
- `-Dios`   → `UI::UIKit::Renderer`
- `-Dandroid` → `UI::Android::Renderer`
- no flag → `UI::Web::Renderer`

The AppKit/UIKit renderers call through a typed ObjC bridge that must be
compiled to a `.o` before linking. From an installed shard the bridge source is
under `lib/asset_pipeline/src/ui/native/`:

```bash
clang -c lib/asset_pipeline/src/ui/native/objc_bridge.m \
  -o lib/asset_pipeline/src/ui/native/objc_bridge.o -fno-objc-arc
```

Then build and link the `.o` with the AppKit frameworks:

```bash
crystal-alpha build src/app.cr -o bin/app -Dmacos \
  --link-flags="lib/asset_pipeline/src/ui/native/objc_bridge.o \
    -framework AppKit -framework Foundation -lobjc"
```

> A full Liquid-Glass / SwiftUI-backed macOS host links more frameworks and the
> `AssetPipelineSwiftKit` Swift static library as well. See the Voyager sample
> `Makefile` `macos-build` target for the complete `--link-flags` set
> (SwiftUI, Combine, QuartzCore, WebKit, MapKit, AVKit, the `swiftkit_bridge.o`
> trampolines, and `-Wl,-force_load,...libAssetPipelineSwiftKit.a`).

### iOS native (`crystal-alpha` cross-compile + `-Dios`)

iOS is a cross-compile: build the Crystal bridge to an object file, hide
`_main` so it coexists with Swift `@main`, and pack it into a static library
that Xcode links. The Voyager sample's `ios/build_crystal_lib.sh` does this; the
core cross-compile step is:

```bash
crystal-alpha build src/bridge.cr --cross-compile \
  --target="arm64-apple-ios-simulator" -Dios -o build/bridge
```

Use `--target="arm64-apple-ios"` for a device build instead of the simulator.
The minimum iOS version targeted is `16.0` (`-mios-version-min=16.0` on the
clang bridge compile). The ObjC bridge is compiled per-target with the iOS SDK:

```bash
clang -c lib/asset_pipeline/src/ui/native/objc_bridge.m \
  -o build/objc_bridge_ios.o \
  -target arm64-apple-ios-simulator \
  -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -mios-version-min=16.0 -fno-objc-arc
```

After cross-compiling, `_main` is stripped so Swift owns the entry point:

```bash
ld -r -unexported_symbol _main build/bridge.o -o build/bridge_fixed.o
ar rcs build/libapp.a build/bridge_fixed.o build/objc_bridge_ios.o
```

The resulting `.a` is linked into the iOS app by `xcodebuild`. See the
`build_crystal_lib.sh` and `ios-build` Makefile target in
`samples/initiative-cross-platform-ui-voyager/` for the full SwiftKit-staging
and `xcodegen` flow.

## 4. Quick check

A minimal native macOS smoke build after `shards install`:

```crystal
# src/app.cr
require "asset_pipeline/ui"

view = UI::VStack.new(spacing: 12.0)
view << UI::Label.new("Hello from Asset Pipeline")
view << UI::Button.new("Click Me") { puts "pressed" }

renderer = UI::AppKit::Renderer.new
renderer.render(view)
```

```bash
clang -c lib/asset_pipeline/src/ui/native/objc_bridge.m \
  -o lib/asset_pipeline/src/ui/native/objc_bridge.o -fno-objc-arc

crystal-alpha build src/app.cr -o bin/app -Dmacos \
  --link-flags="lib/asset_pipeline/src/ui/native/objc_bridge.o \
    -framework AppKit -framework Foundation -lobjc"
```

For the same source compiled to web, drop the flag and the bridge, and use
plain `crystal` — the Web renderer is selected automatically.
