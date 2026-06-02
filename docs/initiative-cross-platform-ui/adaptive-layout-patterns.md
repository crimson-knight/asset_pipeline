# Adaptive layout patterns — one `UI::Screen`, every Apple canvas

A single Crystal `UI::Screen` should render natively and *beautifully* on the Apple
Watch (~140–180pt wide), iPhone (~390pt), and Mac (a resizable window up to 480pt+
content columns), in both light and dark appearance — with **no per-platform forks**.
This is the practical recipe for writing such a screen, plus the cross-platform layout
gotchas that bite if you don't.

For the underlying model see
[`architecture/foundational-output-and-layout-model.md`](architecture/foundational-output-and-layout-model.md).
For proof, see the
[Voyager cohesion gallery](../../samples/initiative-cross-platform-ui-voyager/handoff/cohesion-gallery/)
(`voyager-cohesion-gallery.png`, `voyager-dark-mode-cohesion.png`) and the worked
screens `Voyager::AgentChatScreen` / `Voyager::TodosScreen`.

## The three primitives

All three read the live `UI::DesignTokens::DeviceMetrics.current`, which the active
renderer populates from the real OS (UIScreen / NSScreen / a watch-class provider).

### 1. `DeviceMetrics#adaptive_content_width(compact, regular, horizontal_padding)`

The content-column width, clamped to what the device actually offers. Use it for the
width you pin your title, rows, cards, and buttons to.

```crystal
metrics = UI::DesignTokens::DeviceMetrics.current
pad_h   = metrics.responsive(compact: 16.0, regular: 24.0)
# 340 on a compact iPhone, 460 on a Mac window — but never wider than the device,
# so on a 176pt watch it collapses to ~140pt and the whole column reflows.
content_width = metrics.adaptive_content_width(compact: 340.0, regular: 460.0, horizontal_padding: pad_h)
```

It is `min(responsive(compact:, regular:), content_width_pt - 2*horizontal_padding)`.
On phone/desktop the size-class value wins (unchanged); only narrow canvases clamp.
Pass the **same** horizontal padding your root applies, or the column won't fit inside it.

### 2. `UI::View#fill_horizontal` (chainable `#grow!`)

The cross-platform flex-grow: the view grows to fill the remaining space along its
`HStack`'s main axis — the row's flexible "absorber", like a `Spacer` but as a real
control (a compose `TextField` that expands beside a fixed send button; a title that
takes the slack so it never compresses/wraps).

```crystal
field = UI::TextField.new(placeholder: "Message…", name: "msg")
field.fill_horizontal = true          # grows to fill the row beside the fixed button
row = UI::HStack.new(spacing: 8.0)
row << field.as(UI::View)
row << UI::IconButton.new("paperplane.fill").as(UI::View)
```

A horizontal row of otherwise fixed-width children has **no absorber** and
over-constrains the layout (see Gotcha A). Give one child `fill_horizontal`. Do **not**
also pin that child to an exact width — the pin wins and defeats the grow.

### 3. `DeviceMetrics#compact_canvas?(below = 280.0)`

`true` when the canvas is too narrow to lay a multi-item horizontal row side-by-side
(watch ~176pt vs phone ~390pt+). The companion to #1: that *sizes* a column, this
decides whether a **row should become a column**. A width clamp can shrink a column,
but it cannot fit a 4-button toolbar into 176pt — the buttons just squeeze to
unreadable 1-character strips. Reflow instead.

## The reflow recipe (a header that adapts its axis)

Define the actions once as data, then render two ways:

```crystal
actions = [
  {label: "Agent", icon: "bubble.left.fill", tid: "x-agent", act: :open_agent_chat},
  # …
]

header =
  if metrics.compact_canvas?
    # Watch: title on its own line, actions as full-width STACKED TEXT buttons (readable).
    col = UI::VStack.new(spacing: 6.0)
    col.alignment = UI::Alignment::Leading
    col.minimum_width = content_width; col.maximum_width = content_width
    col << title.as(UI::View)
    actions.each do |a|
      b = UI::Button.new(a[:label]); b.test_id = a[:tid]
      b.on_tap = -> { App.dispatch(a[:act]) }
      b.minimum_width = content_width; b.maximum_width = content_width
      col << b.as(UI::View)
    end
    col.as(UI::View)
  else
    # Phone/desktop: large title on its own line + a compact SF-Symbol ICON toolbar.
    outer = UI::VStack.new(spacing: 8.0)
    outer.alignment = UI::Alignment::Leading
    outer.minimum_width = content_width; outer.maximum_width = content_width
    outer << title.as(UI::View)
    bar = UI::HStack.new(spacing: 18.0)
    actions.each do |a|
      b = UI::IconButton.new(a[:icon]); b.accessibility_label = a[:label]; b.test_id = a[:tid]
      b.on_tap = -> { App.dispatch(a[:act]) }
      bar << b.as(UI::View)
    end
    outer << bar.as(UI::View)
    outer.as(UI::View)
  end
```

Notes proven in practice:
- Per-canvas *chrome*, shared *behavior*: icons where there's room (idiomatic), readable
  text where stacked. One action set, preserved `test_id`s so the same XCUITest resolves
  both forms.
- Keep the title on its **own line** in dense headers — an inline title beside several
  controls fights for width and wraps.

## Gotchas (each one cost a debugging session — don't repeat them)

**A. UIStackView `.fill` ≠ NSStackView gravity-areas.** UIKit's `UIStackView` defaults to
`.fill` distribution, so a low-content-hugging child stretches automatically — `fill_horizontal`
"just works" on iOS. `NSStackView` defaults to *gravity areas* and leaves a no-width child at
its tiny intrinsic size (a collapsed "sliver"). The AppKit renderer therefore switches the
`HStack` to `.fill` distribution when any child is `fill_horizontal`. If you add a new
fill-bearing container path, mirror that.

**B. A conditional stack widens its type.** `header = (cond ? VStack.new : HStack.new)` infers
`UI::View+`, which lacks `<<` / `alignment=`. **Configure each branch as a concrete stack and
yield `.as(UI::View)`** (as the recipe above does). Don't call stack-only methods on the
combined variable.

**C. A greedy `Spacer` compresses its neighbors.** `HStack { title; Spacer(); icons }` lets the
Spacer expand and squeeze the title below its intrinsic width → it wraps. Make the element that
should keep its size the flex element (`title.fill_horizontal = true`) instead of pairing it
with a Spacer, or give it its own line.

**D. Appearance adaptation needs semantic colors, not static ones.** The SwiftKit facades use
dynamic SwiftUI semantic colors / materials (`.primary`, `.secondary`, `regularMaterial`), which
track the trait collection — so light/dark "just works". A static `UI::View#background =
UI::Color.hex(...)` is **baked** and will NOT adapt to dark. Prefer a `Card` material / a
`LabelRole` over a hardcoded color for anything that must survive dark mode.

**E. watchOS is dark-first and single-screen-at-a-glance.** `simctl ui appearance` is
unsupported on watchOS; the watch renders in its natural (dark) appearance and the other
platforms adapt to match. The watch hosts content in a vertical scroll context — wrap the
root in a SwiftUI `ScrollView` (the WatchKit host does this) so multi-line labels wrap fully
instead of truncating/overlapping in the height-constrained canvas.

## Checklist for a new adaptive screen

- [ ] Compute `pad_h` first, then `content_width = metrics.adaptive_content_width(...)`.
- [ ] Pin titles/rows/cards/buttons to `content_width` (min == max for an exact column).
- [ ] One flexible element per horizontal row (`fill_horizontal`) — never an all-fixed row.
- [ ] Dense horizontal chrome? Branch on `compact_canvas?` and reflow to a column.
- [ ] Colors via materials / roles, not static `UI::Color`, so dark mode adapts.
- [ ] Verify by capturing on the macOS host + an iOS sim + a watch sim (all three).
