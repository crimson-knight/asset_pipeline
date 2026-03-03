# Asset Pipeline

A front-end library written in pure Crystal that provides type-safe HTML generation, utility-first CSS, JavaScript/Stimulus management, and reactive server-side components. Ships as a single shard with zero runtime dependencies.

## Architecture

```
src/components/
  elements/          94 HTML element classes (Div, Input, Table, etc.)
  base/              Component base classes (Stateless, Stateful, Reactive)
  css/               CSS engine (ClassBuilder, Config, Generator, Parser)
  reactive/          WebSocket-based real-time component updates
  examples/          6 reference components (Button, Card, Counter, Form, Chat, LiveSearch)
  integration.cr     Amber framework helpers and view macros

src/asset_pipeline.cr  FrontLoader — import maps and script rendering
src/asset_pipeline/
  stimulus/          StimulusRenderer — auto-detects controllers from import maps
  import_map/        ESM import map management
```

## Key Entry Points

- `Components::Elements::*` — 94 type-safe HTML element classes matching HTML tags
- `Components::StatelessComponent` — cacheable, pure-render components
- `Components::StatefulComponent` — components with internal JSON state
- `Components::Reactive::ReactiveComponent` — WebSocket-enabled real-time components
- `Components::CSS::ClassBuilder` — fluent DSL for building CSS class strings
- `Components::CSS::Config` — design token configuration (OKLCH colors, spacing, typography)
- `Components::CSS::Engine::Generator` — generates utility CSS with @layer structure
- `AssetPipeline::FrontLoader` — JavaScript import map and Stimulus management

## Naming Conventions

- Element classes match HTML tag names: `Div`, `Article`, `Input`, `Th`, `Dialog`
- Factory methods on `Input`: `.text()`, `.email()`, `.radio()`, `.search()`, `.range()`, `.color()`, etc.
- Factory methods on `Meta`: `.charset()`, `.viewport()`, `.description()`
- Factory methods on `Link`: `.stylesheet()`, `.preload()`, `.preconnect()`
- Component CSS registered via `component_css <<-CSS ... CSS` macro
- Utility classes follow Tailwind naming: `bg-blue-500`, `hover:text-white`, `sm:flex`

## Design Philosophy

- No templates — all HTML generated from Crystal classes with compile-time type safety
- Utility-first CSS with OKLCH color space and `@layer` cascade structure
- WCAG 2.2 AA accessibility built into defaults (focus rings, motion preferences, ARIA states)
- Stimulus-only JavaScript — no frameworks, ESM import maps, automatic controller detection
- Components render to strings via `.render()` for server-side rendering

## Cross-Platform UI System

The asset_pipeline extends beyond web with a cross-platform native UI component system. A single Crystal source tree compiles to web (HTML), macOS (AppKit), iOS (UIKit), and Android (JNI/Views) using Crystal's compile-time `flag?()` for zero-overhead platform dispatch.

**Core model:** App code builds a tree of `UI::View` objects. A compile-time-selected `PlatformRenderer` (a `PlatformVisitor` subclass) walks the tree and produces native UI. The web renderer delegates to `Components::Elements`; native renderers call through ObjC or JNI bridges.

### Key Architecture Decisions

- Native components only — no custom drawing engine (unlike Flutter)
- Layout delegated to platform engines (NSStackView, UIStackView, LinearLayout, CSS flexbox)
- Visitor pattern for platform dispatch — adding a view type = one method per renderer
- `NativeHandle` with explicit `ReleaseStrategy` for memory management
- `CallbackRegistry` prevents Crystal Proc GC while native code holds function pointers

### Current View Types (9)

| UI::View | Web | macOS (AppKit) | iOS (UIKit) | Android |
|----------|-----|----------------|-------------|---------|
| `Label` | `<span>` | NSTextField | UILabel | TextView |
| `Button` | `<button>` | NSButton | UIButton | MaterialButton |
| `VStack` | flex column | NSStackView | UIStackView | LinearLayout |
| `HStack` | flex row | NSStackView | UIStackView | LinearLayout |
| `ZStack` | position:relative | NSView | UIView | FrameLayout |
| `Image` | `<img>` | NSImageView | UIImageView | ImageView |
| `TextField` | `<input>` | NSTextField | UITextField | EditText |
| `ScrollView` | overflow:auto | NSScrollView | UIScrollView | ScrollView |
| `Spacer` | flex:1 | gravity space | UILayoutGuide | Space weight=1 |

## Quick Reference

| Topic | Skill |
|-------|-------|
| Building UIs with elements and components | `build-ui` |
| CSS styling, ClassBuilder, design tokens | `css-styling` |
| JavaScript, Stimulus, reactive components | `javascript` |
| WCAG 2.2 AA accessibility | `accessibility` |
| Cross-platform UI overview and 9 core views | `cross-platform-components` |
| Full API reference for UI::View types | `component-api` |
| Platform renderer implementations | `platform-renderers` |
| Apple glass/translucency effects | `glass-effects` |
| iOS 26 / macOS 26 native component catalog | `ios26-native-components` |
| Android Compose / Material 3 component catalog | `android-compose-components` |
| Cross-platform component mapping matrix | `component-mapping-matrix` |
| Flutter architecture lessons and patterns | `flutter-architecture-lessons` |
| Graphics/3D rendering API survey (stub) | `graphics-rendering` |

## Using in a Project (Shard Dependency)

**Require statement:**
```crystal
require "asset_pipeline/ui"  # Cross-platform UI views (NOT "ui")
```

**Platform flags (REQUIRED for native renderers):**

crystal-alpha does NOT auto-detect platform renderers. You MUST pass the appropriate `-D` flag:
- **macOS:** `-Dmacos` → activates `UI::AppKit::Renderer`
- **iOS:** `-Dios` → activates `UI::UIKit::Renderer`
- **Android:** `-Dandroid` → activates `UI::Android::Renderer`
- **Web (default):** No flag needed → uses `UI::Web::Renderer`

Without the flag, the build will silently use the Web renderer even on macOS.

**ObjC bridge compilation (required for macOS/iOS):**

The AppKit and UIKit renderers use typed C wrappers for ARM64-safe `objc_msgSend` calls. You must compile the bridge before linking:
```bash
clang -c lib/asset_pipeline/src/ui/native/objc_bridge.m \
  -o lib/asset_pipeline/src/ui/native/objc_bridge.o -fno-objc-arc
```

Then include the `.o` in your link flags:
```bash
crystal-alpha build src/app.cr -o bin/app -Dmacos \
  --link-flags="lib/asset_pipeline/src/ui/native/objc_bridge.o \
    -framework AppKit -framework Foundation -lobjc"
```

**Example (minimal macOS native app):**
```crystal
require "asset_pipeline/ui"

main_view = UI::VStack.new(spacing: 12.0)
main_view << UI::Label.new("Hello from Asset Pipeline")
main_view << UI::Button.new("Click Me") { puts "Button pressed!" }

renderer = UI::AppKit::Renderer.new
native_view = renderer.render(main_view)
# native_view is a UI::NativeView wrapping an NSStackView
```

## Build & Test

```bash
crystal spec                    # Run tests
crystal tool format --check     # Check formatting
crystal run src/generators/brand_kit.cr  # Generate style guide
```
