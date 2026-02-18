---
name: component-api
description: Full API reference for all UI::View types, value types, enums, and composition patterns
version: "1.0"
---

# Component API Reference

Complete API reference for the cross-platform `UI::View` hierarchy defined in `src/ui/`.

## Value Types

### `UI::Color`

RGBA color with floating-point components in the range 0.0 to 1.0.

```crystal
record Color,
  r : Float64,
  g : Float64,
  b : Float64,
  a : Float64 = 1.0
```

**Usage:**
```crystal
red   = UI::Color.new(r: 1.0, g: 0.0, b: 0.0)
white = UI::Color.new(r: 1.0, g: 1.0, b: 1.0)
semi  = UI::Color.new(r: 0.0, g: 0.0, b: 0.0, a: 0.5)
```

### `UI::Font`

Font specification with family, size, weight, and italic flag.

```crystal
record Font,
  family : String = "system",
  size : Float64 = 17.0,
  weight : Symbol = :regular,
  italic : Bool = false
```

**Weight values:** `:ultralight`, `:thin`, `:light`, `:regular`, `:medium`, `:semibold`, `:bold`, `:heavy`, `:black`

**Usage:**
```crystal
heading = UI::Font.new(size: 24.0, weight: :bold)
mono    = UI::Font.new(family: "monospace", size: 14.0)
italic  = UI::Font.new(weight: :medium, italic: true)
default = UI::Font.new  # system font, 17pt, regular
```

### `UI::EdgeInsets`

Edge insets for padding or margin values, in points.

```crystal
record EdgeInsets,
  top : Float64 = 0.0,
  trailing : Float64 = 0.0,
  bottom : Float64 = 0.0,
  leading : Float64 = 0.0
```

Note: Uses `leading`/`trailing` (not `left`/`right`) for RTL language support.

**Usage:**
```crystal
uniform = UI::EdgeInsets.new(top: 16.0, trailing: 16.0, bottom: 16.0, leading: 16.0)
vertical = UI::EdgeInsets.new(top: 8.0, bottom: 8.0)
none = UI::EdgeInsets.new  # all zeros
```

## Enums

### `UI::Alignment`

Controls alignment of children within stack layouts.

```crystal
enum Alignment
  Leading   # Left-aligned (or start, in RTL)
  Center    # Center-aligned
  Trailing  # Right-aligned (or end, in RTL)
  Top       # Top-aligned (for HStack vertical alignment)
  Bottom    # Bottom-aligned (for HStack vertical alignment)
  Fill      # Stretch to fill available space
end
```

- **VStack** uses `Leading`, `Center`, `Trailing`, `Fill` for horizontal alignment of children
- **HStack** uses `Top`, `Center`, `Bottom`, `Fill` for vertical alignment of children
- **ZStack** uses `Leading`, `Center`, `Trailing`, `Top`, `Bottom` for overlay positioning

### `UI::ContentMode`

Controls how an image is scaled to fit its bounds.

```crystal
enum ContentMode
  Fit      # Scale to fit within bounds, preserving aspect ratio (may letterbox)
  Fill     # Scale to fill bounds, preserving aspect ratio (may crop)
  Stretch  # Scale to exactly fill bounds (may distort)
end
```

### `UI::KeyboardType`

Hint for the platform's virtual keyboard type on mobile.

```crystal
enum KeyboardType
  Default       # Standard text keyboard
  EmailAddress  # Keyboard optimized for email input (@ key prominent)
  NumberPad     # Numeric-only keyboard
  PhonePad      # Phone number keyboard
  URL           # Keyboard optimized for URL input
end
```

---

## Abstract Base: `UI::View`

**File:** `src/ui/view.cr`

All 9 concrete view types inherit from this abstract class.

```crystal
abstract class UI::View
  property id : String? = nil
  property accessibility_label : String? = nil
  property padding : EdgeInsets = EdgeInsets.new
  property background : Color? = nil
  property hidden : Bool = false
  property opacity : Float64 = 1.0

  abstract def accept(visitor : PlatformVisitor)
end
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `id` | `String?` | `nil` | Optional identifier for lookup and testing |
| `accessibility_label` | `String?` | `nil` | Screen reader label |
| `padding` | `EdgeInsets` | all zeros | Content padding |
| `background` | `Color?` | `nil` | Background color (nil = transparent/inherited) |
| `hidden` | `Bool` | `false` | Whether the view is hidden from display |
| `opacity` | `Float64` | `1.0` | Opacity from 0.0 (transparent) to 1.0 (opaque) |

All properties are settable after construction via their property setters.

---

## Concrete View Types

### `UI::Label`

**File:** `src/ui/views/label.cr`

Read-only text display. On the web, renders to `<span>` or `<p>`. On macOS, maps to non-editable `NSTextField`.

```crystal
class UI::Label < UI::View
  property text : String
  property font : Font = Font.new
  property text_color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0)
  property text_alignment : Alignment = Alignment::Leading
  property number_of_lines : Int32 = 0

  def initialize(@text : String)
end
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `text` | `String` | (required) | The displayed text content |
| `font` | `Font` | system 17pt | Font specification |
| `text_color` | `Color` | black | Text foreground color |
| `text_alignment` | `Alignment` | `Leading` | Horizontal text alignment |
| `number_of_lines` | `Int32` | `0` | Max lines to display (0 = unlimited) |

**Example:**
```crystal
title = UI::Label.new("Welcome Back")
title.font = UI::Font.new(size: 28.0, weight: :bold)
title.text_color = UI::Color.new(r: 0.2, g: 0.2, b: 0.2)
title.text_alignment = UI::Alignment::Center
```

---

### `UI::Button`

**File:** `src/ui/views/button.cr`

A tappable button with a text label. The `on_tap` proc fires when activated.

```crystal
class UI::Button < UI::View
  property label : String
  property font : Font = Font.new
  property foreground_color : Color = Color.new(r: 0.0, g: 0.478, b: 1.0)
  property disabled : Bool = false
  property on_tap : Proc(Nil)? = nil

  def initialize(@label : String)
  def initialize(@label : String, &block : -> Nil)
end
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `label` | `String` | (required) | Button display text |
| `font` | `Font` | system 17pt | Label font |
| `foreground_color` | `Color` | system blue | Label and tint color |
| `disabled` | `Bool` | `false` | Whether interaction is disabled |
| `on_tap` | `Proc(Nil)?` | `nil` | Callback invoked on tap |

**Example:**
```crystal
# With block constructor
save = UI::Button.new("Save") { puts "Saved!"; nil }

# With explicit proc assignment
delete = UI::Button.new("Delete")
delete.foreground_color = UI::Color.new(r: 1.0, g: 0.0, b: 0.0)
delete.on_tap = ->{ handle_delete; nil }
```

**Callback pattern on native platforms:** On macOS/iOS, the `on_tap` proc is registered in `UI::CallbackRegistry` with a stable numeric ID. The ObjC target-action mechanism dispatches through a `CrystalActionDispatcher` class that looks up the ID and calls the stored proc. On Android, a JNI `CrystalCallbackBridge` serves the same purpose.

---

### `UI::VStack`

**File:** `src/ui/views/vstack.cr`

Vertical stack layout. Children are arranged top to bottom with configurable spacing and horizontal alignment.

```crystal
class UI::VStack < UI::View
  property spacing : Float64 = 8.0
  property alignment : Alignment = Alignment::Center
  getter children : Array(View) = [] of View

  def initialize(@spacing : Float64 = 8.0, @alignment : Alignment = Alignment::Center)
  def <<(child : View) : self
end
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `spacing` | `Float64` | `8.0` | Points between children |
| `alignment` | `Alignment` | `Center` | Horizontal alignment of children |
| `children` | `Array(View)` | `[]` | Ordered child views (getter only) |

**Example:**
```crystal
stack = UI::VStack.new(spacing: 12.0, alignment: UI::Alignment::Leading)
stack << UI::Label.new("First")
stack << UI::Label.new("Second")
stack << UI::Button.new("Action") { nil }
```

---

### `UI::HStack`

**File:** `src/ui/views/hstack.cr`

Horizontal stack layout. Children are arranged leading to trailing.

```crystal
class UI::HStack < UI::View
  property spacing : Float64 = 8.0
  property alignment : Alignment = Alignment::Center
  getter children : Array(View) = [] of View

  def initialize(@spacing : Float64 = 8.0, @alignment : Alignment = Alignment::Center)
  def <<(child : View) : self
end
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `spacing` | `Float64` | `8.0` | Points between children |
| `alignment` | `Alignment` | `Center` | Vertical alignment of children |
| `children` | `Array(View)` | `[]` | Ordered child views (getter only) |

**Example:**
```crystal
row = UI::HStack.new(spacing: 16.0)
row << UI::Image.new("icon_star")
row << UI::Label.new("Favorites")
row << UI::Spacer.new
row << UI::Button.new("Edit") { nil }
```

---

### `UI::ZStack`

**File:** `src/ui/views/zstack.cr`

Z-axis overlay stack. Children are drawn in order, with later children rendered on top of earlier ones.

```crystal
class UI::ZStack < UI::View
  property alignment : Alignment = Alignment::Center
  getter children : Array(View) = [] of View

  def initialize(@alignment : Alignment = Alignment::Center)
  def <<(child : View) : self
end
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `alignment` | `Alignment` | `Center` | Positioning of children within the overlay |
| `children` | `Array(View)` | `[]` | Ordered child views (later = on top) |

**Example:**
```crystal
overlay = UI::ZStack.new
background_image = UI::Image.new("hero_bg")
background_image.content_mode = UI::ContentMode::Fill
overlay << background_image
overlay << UI::Label.new("Hero Title")
```

---

### `UI::Image`

**File:** `src/ui/views/image.cr`

Displays an image from a named resource. The `source` is resolved by the platform renderer (asset catalog name on iOS, drawable on Android, URL or path on web).

```crystal
class UI::Image < UI::View
  property source : String
  property content_mode : ContentMode = ContentMode::Fit
  property tint_color : Color? = nil

  def initialize(@source : String)
end
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | `String` | (required) | Logical image name or path |
| `content_mode` | `ContentMode` | `Fit` | Scaling mode |
| `tint_color` | `Color?` | `nil` | Optional tint overlay (nil = no tint) |

**Example:**
```crystal
avatar = UI::Image.new("user_avatar")
avatar.content_mode = UI::ContentMode::Fill
avatar.tint_color = UI::Color.new(r: 0.0, g: 0.478, b: 1.0)
```

---

### `UI::TextField`

**File:** `src/ui/views/text_field.cr`

Editable single-line text input with placeholder text, secure entry mode for passwords, keyboard type hints, and a change callback.

```crystal
class UI::TextField < UI::View
  property text : String = ""
  property placeholder : String = ""
  property font : Font = Font.new
  property text_color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0)
  property secure_entry : Bool = false
  property keyboard_type : KeyboardType = KeyboardType::Default
  property on_change : Proc(String, Nil)? = nil

  def initialize(@placeholder : String = "")
  def initialize(@placeholder : String = "", &block : String -> Nil)
end
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `text` | `String` | `""` | Current text value |
| `placeholder` | `String` | `""` | Placeholder shown when empty |
| `font` | `Font` | system 17pt | Content font |
| `text_color` | `Color` | black | Text color |
| `secure_entry` | `Bool` | `false` | Obscure input (password mode) |
| `keyboard_type` | `KeyboardType` | `Default` | Virtual keyboard hint |
| `on_change` | `Proc(String, Nil)?` | `nil` | Callback receiving new text on change |

**Example:**
```crystal
# Plain text field
name_field = UI::TextField.new("Enter your name")

# Password field with callback
password = UI::TextField.new("Password") { |new_text|
  validate_password(new_text)
  nil
}
password.secure_entry = true

# Email field
email = UI::TextField.new("Email address")
email.keyboard_type = UI::KeyboardType::EmailAddress
```

---

### `UI::ScrollView`

**File:** `src/ui/views/scroll_view.cr`

A scrollable container wrapping a single child view (typically a stack).

```crystal
class UI::ScrollView < UI::View
  property content : View? = nil
  property scroll_horizontal : Bool = false
  property scroll_vertical : Bool = true
  property shows_indicators : Bool = true

  def initialize(@content : View? = nil)
end
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `content` | `View?` | `nil` | The scrollable content view |
| `scroll_horizontal` | `Bool` | `false` | Enable horizontal scrolling |
| `scroll_vertical` | `Bool` | `true` | Enable vertical scrolling |
| `shows_indicators` | `Bool` | `true` | Show scroll indicators |

**Example:**
```crystal
list = UI::VStack.new(spacing: 4.0)
100.times { |i| list << UI::Label.new("Item #{i}") }

scroll = UI::ScrollView.new(list)
scroll.shows_indicators = true
```

---

### `UI::Spacer`

**File:** `src/ui/views/spacer.cr`

Flexible space that expands within a `VStack` or `HStack` to push adjacent views apart.

```crystal
class UI::Spacer < UI::View
  property min_length : Float64 = 0.0

  def initialize(@min_length : Float64 = 0.0)
end
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `min_length` | `Float64` | `0.0` | Minimum size in points |

**Example:**
```crystal
# Push button to the right side of a horizontal bar
bar = UI::HStack.new
bar << UI::Label.new("Title")
bar << UI::Spacer.new          # fills available space
bar << UI::Button.new("Done") { nil }
```

---

## PlatformVisitor Abstract Interface

**File:** `src/ui/platform_visitor.cr`

Every platform renderer implements this abstract class, providing one `visit` method per view type.

```crystal
abstract class UI::PlatformVisitor
  abstract def visit(view : Label)
  abstract def visit(view : Button)
  abstract def visit(view : VStack)
  abstract def visit(view : HStack)
  abstract def visit(view : ZStack)
  abstract def visit(view : Image)
  abstract def visit(view : TextField)
  abstract def visit(view : ScrollView)
  abstract def visit(view : Spacer)
end
```

Each concrete `View` subclass implements `accept` as:

```crystal
def accept(visitor : PlatformVisitor)
  visitor.visit(self)
end
```

This visitor pattern means:
- Adding a **new view type** requires adding one `visit` method to each renderer
- Adding a **new platform** requires creating one new `PlatformVisitor` subclass

---

## View Composition Patterns

### Building Trees with `<<`

Container views (`VStack`, `HStack`, `ZStack`) support the `<<` operator for appending children. It returns `self` for chaining.

```crystal
stack = UI::VStack.new
stack << UI::Label.new("Line 1")
stack << UI::Label.new("Line 2")
```

### Nesting Containers

Views compose by nesting containers arbitrarily deep:

```crystal
page = UI::VStack.new(spacing: 20.0)

# Header row
header = UI::HStack.new
header << UI::Image.new("logo")
header << UI::Spacer.new
header << UI::Button.new("Menu") { nil }
page << header

# Content
content = UI::ScrollView.new
body = UI::VStack.new(spacing: 8.0)
body << UI::Label.new("Article title")
body << UI::Label.new("Article body text...")
content.content = body
page << content

# Footer
page << UI::Spacer.new(min_length: 20.0)
page << UI::Label.new("Footer text")
```

### Setting Common Properties After Construction

All `View` base properties can be set on any view type:

```crystal
card = UI::VStack.new(spacing: 12.0)
card.id = "main-card"
card.padding = UI::EdgeInsets.new(top: 16.0, trailing: 16.0, bottom: 16.0, leading: 16.0)
card.background = UI::Color.new(r: 1.0, g: 1.0, b: 1.0)
card.accessibility_label = "Main content card"
```

### Callback Patterns

**Button `on_tap`:**
```crystal
# Block constructor
btn = UI::Button.new("Tap Me") { handle_tap; nil }

# Explicit assignment
btn = UI::Button.new("Tap Me")
btn.on_tap = ->{ handle_tap; nil }
```

**TextField `on_change`:**
```crystal
# Block constructor
field = UI::TextField.new("Search") { |text| filter_results(text); nil }

# Explicit assignment
field = UI::TextField.new("Search")
field.on_change = ->(text : String) { filter_results(text); nil }
```

Both callback types return `Nil`. The proc signature for `on_tap` is `Proc(Nil)` and for `on_change` is `Proc(String, Nil)`.
