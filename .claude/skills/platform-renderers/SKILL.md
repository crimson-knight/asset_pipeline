---
name: platform-renderers
description: How each platform renderer maps UI::View types to native elements across Web, macOS, iOS, and Android
version: "1.0"
---

# Platform Renderers

Each platform renderer is a subclass of `UI::PlatformVisitor` that translates the abstract `UI::View` tree into platform-native elements. Only one renderer is compiled into any given binary, selected at compile time via `flag?()`.

## Compile-Time Selection

```crystal
{% if flag?(:macos) %}
  require "./renderers/appkit_renderer"
  alias PlatformRenderer = UI::AppKit::Renderer
{% elsif flag?(:ios) %}
  require "./renderers/uikit_renderer"
  alias PlatformRenderer = UI::UIKit::Renderer
{% elsif flag?(:android) %}
  require "./renderers/android_renderer"
  alias PlatformRenderer = UI::Android::Renderer
{% else %}
  require "./renderers/web_renderer"
  alias PlatformRenderer = UI::Web::Renderer
{% end %}
```

---

## Web::Renderer

**Target file:** `src/ui/renderers/web_renderer.cr`
**Compiled when:** No platform flag set (default), or explicitly for web targets

The web renderer delegates to the existing `Components::Elements` classes in the asset_pipeline shard. It does NOT reimplement HTML generation -- it maps each `UI::View` to the appropriate `Components::Elements` class and applies CSS styles.

### View-to-Element Mapping

| UI::View | Components::Elements class | CSS applied |
|----------|---------------------------|-------------|
| `Label` | `Elements::Span` | `font-family`, `font-size`, `font-weight`, `color`, `text-align`, line clamping |
| `Button` | `Elements::Button` | Foreground color, `data-action` attribute for reactive dispatch |
| `VStack` | `Elements::Div` | `display:flex; flex-direction:column; gap:{spacing}px; align-items:{alignment}` |
| `HStack` | `Elements::Div` | `display:flex; flex-direction:row; gap:{spacing}px; align-items:{alignment}` |
| `ZStack` | `Elements::Div` | `position:relative` with `position:absolute` on children |
| `Image` | `Elements::Img` | `object-fit` mapped from `ContentMode` |
| `TextField` | `Elements::Input` | `.text` or `.password` factory depending on `secure_entry` |
| `ScrollView` | `Elements::Div` | `overflow-x`/`overflow-y` based on scroll axes |
| `Spacer` | `Elements::Div` | `flex:1 1 0%; min-height:{min_length}px` or `min-width:{min_length}px` |

### CSS Strategy

- Layout CSS uses utility classes: `ui-vstack`, `ui-hstack`, `ui-spacer`, etc.
- Inline styles handle dynamic values (spacing, colors, fonts)
- The renderer produces standard HTML that works with the existing `ReactiveHandler` WebSocket system

### Integration with Components System

The `UI::ViewAdapter` class bridges the UI view tree into the reactive component system:

```crystal
class UI::ViewAdapter < Components::Reactive::ReactiveComponent
  def render_content : String
    renderer = UI::Web::Renderer.new
    @root.accept(renderer)
    renderer.output
  end
end
```

Existing `StatelessComponent`, `StatefulComponent`, and `ReactiveComponent` subclasses continue working without modifications.

---

## AppKit::Renderer (macOS)

**Target file:** `src/ui/renderers/appkit_renderer.cr`
**Compiled when:** `flag?(:macos)`
**Bridge:** `objc_bridge.c` + `collection_bridge.c`

Maps `UI::View` types to AppKit `NSView` subclasses via the ObjC runtime C API.

### View-to-NSView Mapping

| UI::View | AppKit class | Configuration |
|----------|-------------|---------------|
| `Label` | `NSTextField` | Non-editable, `setBezeled:NO`, `setDrawsBackground:NO` |
| `Button` | `NSButton` | `NSBezelStyleRounded`, target-action via `CrystalActionDispatcher` |
| `VStack` | `NSStackView` | `orientation: .vertical`, `spacing`, `alignment` |
| `HStack` | `NSStackView` | `orientation: .horizontal`, `spacing`, `alignment` |
| `ZStack` | `NSView` | Children added as subviews with manual frame layout |
| `Image` | `NSImageView` | `imageScaling` mapped from `ContentMode` |
| `TextField` | `NSTextField` | Editable, with delegate for change notifications |
| `ScrollView` | `NSScrollView` | `hasVerticalScroller`/`hasHorizontalScroller` |
| `Spacer` | (no view) | Flexible space via NSStackView gravity areas |

### ObjC Bridge Architecture

Crystal calls the ObjC runtime through C wrapper functions in `objc_bridge.c`. Each wrapper has a correctly-typed function signature matching the ARM64 calling convention (AAPCS64):

- **Integer/pointer args** go in registers `x0-x7`
- **Float/double args** go in registers `d0-d7` (independent bank)
- **CGRect/CGPoint/CGSize** are Homogeneous Floating-point Aggregates (HFA) passed in `d0-d3`

Every unique combination of (return type, parameter types) has its own wrapper to prevent register corruption. This is critical on ARM64 where `objc_msgSend` is a raw assembly trampoline that does not know argument types.

### Callback Dispatch

Button taps go through this chain:

1. `NSButton` target-action fires `CrystalActionDispatcher` (ObjC class created at runtime)
2. The SEL encodes a callback ID: `crystalAction_<id>:`
3. The dispatcher IMP calls `crystal_ui_callback_dispatch(id)` (exported C function)
4. Crystal looks up the `Proc` in `UI::CallbackRegistry` by ID and calls it

### Memory Management

- Every render pass is bracketed with `ObjC.autoreleasepool { }`
- Created views are wrapped in `NativeHandle` with `ReleaseStrategy::ObjCRelease`
- Borrowed references (e.g., `contentView`) use `ReleaseStrategy::ObjCBorrowed`
- `NativeView.teardown!` cascades through the child tree for deterministic cleanup

---

## UIKit::Renderer (iOS)

**Target file:** `src/ui/renderers/uikit_renderer.cr`
**Compiled when:** `flag?(:ios)`
**Bridge:** Same `objc_bridge.c` (ObjC runtime is shared between macOS and iOS)

Maps `UI::View` types to UIKit `UIView` subclasses. Uses the same ObjC bridge as macOS -- the only difference is the class names.

### View-to-UIView Mapping

| UI::View | UIKit class | Configuration |
|----------|------------|---------------|
| `Label` | `UILabel` | `numberOfLines`, `textAlignment`, `textColor`, `font` |
| `Button` | `UIButton` | `UIButton.systemButton(with:)`, target-action pattern |
| `VStack` | `UIStackView` | `axis: .vertical`, `spacing`, `alignment`, `distribution` |
| `HStack` | `UIStackView` | `axis: .horizontal`, `spacing`, `alignment`, `distribution` |
| `ZStack` | `UIView` | Children positioned with Auto Layout anchors |
| `Image` | `UIImageView` | `contentMode` mapped from `ContentMode` |
| `TextField` | `UITextField` | `placeholder`, `isSecureTextEntry`, `keyboardType` |
| `ScrollView` | `UIScrollView` | `showsVerticalScrollIndicator`/`showsHorizontalScrollIndicator` |
| `Spacer` | (layout guide) | `UILayoutGuide` with flexible priority constraints |

### iOS-Specific Considerations

- **No `Process.fork`:** iOS App Sandbox forbids forking. Never call `Process` module methods.
- **No JIT for PCRE2:** iOS blocks `mmap(PROT_EXEC)`, so `libpcre2` must be compiled with JIT disabled.
- **Signal handlers:** `SIGSEGV`/`SIGBUS` handlers may conflict with iOS crash reporting; guard with `{% unless flag?(:ios) %}`.
- **Build command:**
  ```bash
  crystal build src/app.cr --target aarch64-apple-ios --cross-compile \
    -Dwithout_openssl -Dwithout_xml -o app.o
  xcrun --sdk iphoneos clang app.o -lgc -lpcre2-8 \
    -framework UIKit -framework Foundation -o MyApp.framework/MyApp
  ```

---

## Android::Renderer

**Target file:** `src/ui/renderers/android_renderer.cr`
**Compiled when:** `flag?(:android)`
**Bridge:** `jni_bridge.c` + JNI portion of `collection_bridge.c`

Maps `UI::View` types to Android `View` subclasses via JNI (Java Native Interface).

### View-to-Android View Mapping

| UI::View | Android class | Configuration |
|----------|--------------|---------------|
| `Label` | `TextView` | `setText`, `setTextSize`, `setTypeface`, `setTextColor` |
| `Button` | `MaterialButton` | `setText`, `setOnClickListener` via JNI callback bridge |
| `VStack` | `LinearLayout` | `orientation: VERTICAL`, `LayoutParams` with margins |
| `HStack` | `LinearLayout` | `orientation: HORIZONTAL` |
| `ZStack` | `FrameLayout` | Children positioned with `LayoutParams` gravity |
| `Image` | `ImageView` | `setScaleType` mapped from `ContentMode` |
| `TextField` | `EditText` | `setHint`, `setInputType`, `addTextChangedListener` |
| `ScrollView` | `ScrollView` / `HorizontalScrollView` | Depends on scroll axis |
| `Spacer` | `Space` | `LayoutParams` with `weight=1` |

### JNI Bridge Architecture

The Android renderer requires a `JNIEnv*` pointer (obtained from the Java VM when the native library is loaded). All JNI calls go through typed C wrappers in `jni_bridge.c`:

- **String creation:** `jni_string_create_with_bytes(env, bytes, len)` creates a `jstring`
- **Batch child add:** `jni_viewgroup_add_views_batch(env, parent, children, count)` adds multiple children in one JNI crossing
- **Global refs:** Local references must be promoted to global refs (`jni_new_global_ref`) to survive beyond the current JNI call

### Callback Dispatch

1. A Java `CrystalCallbackBridge` class has a `static native void dispatch(long callbackId)` method
2. The JNI implementation calls `crystal_ui_callback_dispatch(id)` -- the same entry point as ObjC
3. Crystal looks up the `Proc` in `UI::CallbackRegistry` by ID

### Memory Management

- Every batch operation is bracketed with `JNI.local_frame(env, capacity) { }`
- Created views are wrapped in `NativeHandle` with `ReleaseStrategy::JNIGlobalRef`
- `teardown!` calls `DeleteGlobalRef` on each handle
- **Build command:**
  ```bash
  crystal build src/app.cr --target aarch64-linux-android --cross-compile \
    --shared -Dwithout_openssl -Dwithout_xml -o libapp.o
  $NDK_CLANG --target=aarch64-linux-android31 -shared -fPIC \
    libapp.o -lgc -lpcre2-8 -o libapp.so
  ```

---

## Platform Mapping Table (Complete)

| UI::View | Web (HTML + CSS) | macOS (AppKit) | iOS (UIKit) | Android |
|----------|-----------------|----------------|-------------|---------|
| `Label` | `<span>` styled via CSS | `NSTextField` (non-editable) | `UILabel` | `TextView` |
| `Button` | `<button>` with `data-action` | `NSButton` (rounded bezel) | `UIButton` (system) | `MaterialButton` |
| `VStack` | `<div>` flex column | `NSStackView` (vertical) | `UIStackView` (.vertical) | `LinearLayout` (VERTICAL) |
| `HStack` | `<div>` flex row | `NSStackView` (horizontal) | `UIStackView` (.horizontal) | `LinearLayout` (HORIZONTAL) |
| `ZStack` | `<div>` position:relative | `NSView` + frame layout | `UIView` + Auto Layout | `FrameLayout` |
| `Image` | `<img>` with object-fit | `NSImageView` | `UIImageView` | `ImageView` |
| `TextField` | `<input type=text/password>` | `NSTextField` (editable) | `UITextField` | `EditText` |
| `ScrollView` | `<div>` overflow:auto | `NSScrollView` | `UIScrollView` | `ScrollView` / `HorizontalScrollView` |
| `Spacer` | `<div>` flex:1 | NSStackView gravity space | `UILayoutGuide` flexible | `Space` weight=1 |

---

## How to Add a New View Type

1. **Create the view class** in `src/ui/views/new_view.cr`:
   ```crystal
   class UI::NewView < UI::View
     # properties...
     def accept(visitor : PlatformVisitor)
       visitor.visit(self)
     end
   end
   ```

2. **Add the abstract visit method** to `src/ui/platform_visitor.cr`:
   ```crystal
   abstract def visit(view : NewView)
   ```

3. **Implement `visit` in each renderer:**
   - `Web::Renderer#visit(view : NewView)` -- map to `Components::Elements` class
   - `AppKit::Renderer#visit(view : NewView)` -- map to `NSView` subclass
   - `UIKit::Renderer#visit(view : NewView)` -- map to `UIView` subclass
   - `Android::Renderer#visit(view : NewView)` -- map to Android `View` subclass

4. **Add specs** in `spec/ui/views_spec.cr` to verify construction, property defaults, and visitor acceptance.

The compiler enforces completeness: if a renderer does not implement the new `visit` overload, the build fails with a missing abstract method error.

---

## How to Add a New Platform

1. **Create the renderer file** at `src/ui/renderers/new_platform_renderer.cr`:
   ```crystal
   module UI::NewPlatform
     class Renderer < UI::PlatformVisitor
       def visit(view : Label)
         # platform-specific rendering
       end
       # ... implement all 9 visit methods
     end
   end
   ```

2. **Add the compile-time flag check** in the platform selection block:
   ```crystal
   {% elsif flag?(:new_platform) %}
     require "./renderers/new_platform_renderer"
     alias PlatformRenderer = UI::NewPlatform::Renderer
   ```

3. **Create a native bridge** (C file) if the platform requires FFI calls, following the pattern of `objc_bridge.c` or `jni_bridge.c`.

4. **Add the platform column** to the mapping table and update all documentation.

The compiler enforces that every `visit` method is implemented. Missing methods result in a compile-time error.
