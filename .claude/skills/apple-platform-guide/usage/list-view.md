# UI::ListView

**Phase 10D-polish default chrome.** `UI::ListView` is the scrollable list of section-grouped rows with iOS Mail-style row chrome wired by default: 16pt row inset, removal-animation, drag handle when reorder is enabled, and SwiftUI swipe-action tiles.

## Default experience

- **iOS:** SwiftUI `List { Section { ForEach { row } } }`. Each row renders with:
  - 16pt horizontal `.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))`.
  - `line.3.horizontal` SF Symbol on the trailing edge (`.foregroundStyle(Color.secondary.opacity(0.6))`, 24pt wide) whenever `on_move` is wired AND `shows_drag_handle != false`.
  - `.transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 0.0, anchor: .leading))))` on row removal.
  - Outer `.animation(.easeInOut(duration: 0.4), value: childViews.count)` so deletes collapse over 400ms.
  - `.swipeActions(edge: .leading|.trailing, allowsFullSwipe: true)` when the row has actions; first action in `trailing` is the full-swipe target. Tiles render with SwiftUI's `.tint(color)` (full-bleed, square-corner Mail-style chrome) plus `Label(label, systemImage: icon).labelStyle(.titleAndIcon)`.
  - `.onTapGesture` when `on_row_tap` is set (whole-row tap → callback).
  - `.onMove(perform:)` on the inner ForEach when `on_move` is set (long-press-drag reorder; handle also visible on the row).
- **iPadOS:** same as iOS; multi-column list styles (sidebar, inset) honor `style` property.
- **macOS:** AppKit visit emits NSTableView; per-row tap/swipe/move callbacks fire through CallbackBridge. Drag handle + removal animation NOT yet ported to macOS — backlog item `B-LIST-MACOS-CHROME`.
- **web (wide / narrow):** Web renderer emits `<ul>` / `<table>` markup; swipe / drag / animation not honored on desktop web. Mobile-web swipe + drag tracked separately under the SwipeActionRow path.
- **Android:** Compose `LazyColumn`; per-row callbacks not yet wired. Tracked under `B-LIST-ANDROID-CALLBACKS`.

## Crystal API

```crystal
# Minimal invocation
list = UI::ListView.new
list.sections = [
  UI::ListView::Section.new(items: [row1, row2, row3]),
]
```

```crystal
# Realistic Voyager invocation
# samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:127-209
list = UI::ListView.new
list.minimum_width = content_width
list.maximum_width = content_width
list.minimum_height = (visible.size * 72.0).clamp(120.0, 560.0)
list.shows_separators = true
list.test_id = "voyager-todos-list"
list.accessibility_label = "Todo list"

list.sections = [
  UI::ListView::Section.new(
    items: visible.map { |todo| build_todo_row(todo).as(UI::View) },
  ),
]

list.on_row_tap = ->(idx : Int32) { ... }
list.on_move    = ->(from : Int32, to : Int32) { ... }
list.leading_swipe_actions  = ->(idx : Int32) : Array(UI::SwipeAction) { ... }
list.trailing_swipe_actions = ->(idx : Int32) : Array(UI::SwipeAction) { ... }
```

## Behavior contract

- **Callbacks:**
  - `on_item_tap : Proc(Int32, Int32, Nil)?` — section + item index when a row is tapped (legacy; pre-10D).
  - `on_row_tap : Proc(Int32, Nil)?` — flat absolute row index. Fires on `.onTapGesture` per row.
  - `on_move : Proc(Int32, Int32, Nil)?` — fires from SwiftUI's `.onMove(perform:)` with absolute from/to indices.
  - `leading_swipe_actions : Proc(Int32, Array(SwipeAction))?` — returns the leading-edge action set for a row.
  - `trailing_swipe_actions : Proc(Int32, Array(SwipeAction))?` — returns the trailing-edge action set; first action is the full-swipe target.
- **Dismissal paths:** N/A (not a modal; lists are persistent surfaces).
- **Focus / keyboard:** SwiftUI default — list rows are focusable via VoiceOver swipe-right; drag handle has `accessibilityLabel("Reorder row")`.
- **Reduced motion:** `row_removal_duration_seconds = 0.0` disables the easeInOut animation. Future work: read `accessibility_reduce_motion` env var per `[[platform-defaults-reduce-motion]]`.
- **Reactivity:** Each render rebuilds the SwiftUI `List` from the Crystal-side tree. Mutating `Voyager.state.todos` + dispatching `Rerender` produces a new ListView; SwiftUI's diff drives the removal-animation transition off the row count change.

## Customization knobs

| Property | Type | Default | Effect |
|----------|------|---------|--------|
| `sections` | `Array(Section)` | `[]` | Section + item layout. Use `UI::ListView.flat(items:)` for a single section. |
| `style` | `ListStyle` | `Plain` | Maps to SwiftUI `.listStyle(...)`. Supports `Plain`, `Grouped`, `Inset`, `InsetGrouped`, `Sidebar`. |
| `layout` | `ListLayout` | `List` | `Grid` switches to multi-column collection layout (iOS UICollectionView). |
| `columns` | `Int32` | `3` | Grid column count when layout == Grid. |
| `item_spacing` | `Float64` | `8.0` | Grid-mode cell gap. |
| `shows_separators` | `Bool` | `true` | Hides row separators when false (uses SwiftUI `.listRowSeparator(.hidden)` per row). |
| `content_inset_horizontal` | `Float64?` | `16.0` | **Phase 10D-polish A4.** Default 16pt row inset (Mail-style). Set to `nil` to delegate to SwiftUI's platform default. |
| `row_removal_duration_seconds` | `Float64` | `0.4` | **Phase 10D-polish A3.** Row-removal animation duration. `0.0` disables. |
| `shows_drag_handle` | `Bool` | `true` | **Phase 10D-polish A2.** When false (with `on_move` still set) the visible `line.3.horizontal` affordance is suppressed; long-press-drag still works. |
| `on_row_tap` | `Proc(Int32, Nil)?` | `nil` | Whole-row tap callback. |
| `on_move` | `Proc(Int32, Int32, Nil)?` | `nil` | Drag-reorder callback. Setting this enables the drag handle by default. |
| `leading_swipe_actions` | `Proc(Int32, Array(SwipeAction))?` | `nil` | Per-row leading-edge swipe actions. |
| `trailing_swipe_actions` | `Proc(Int32, Array(SwipeAction))?` | `nil` | Per-row trailing-edge swipe actions. First action is the full-swipe target. |

## Override path

**Default chrome is widget-level**, applied by `src/ui/native/swiftkit_overrides.cr:792-805` (`populate_list_view`) and `swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/ListViewFacade.swift:90-180` (`makeListView` + `rowBuilder`).

**Override paths:**

- **Disable removal animation:** `list.row_removal_duration_seconds = 0.0`. SwiftUI's `.animation` modifier is suppressed when duration ≤ 0.
- **Disable drag handle (keep reorder):** `list.shows_drag_handle = false`. Long-press-drag still works via `.onMove`.
- **Custom row inset:** `list.content_inset_horizontal = 24.0` (or any Float64). `nil` delegates to SwiftUI platform default.
- **Change swipe tile colors:** today the iOS renderer derives tints from action `role` (`default_tint_for_leading` / `default_tint_for_trailing` in `src/ui/renderers/uikit_renderer.cr:1238-1253`). A `tint` property on `UI::SwipeAction` is tracked in backlog item `B-LIST-SWIPE-TINT` — not yet shipped.
- **macOS-side chrome parity:** backlog item `B-LIST-MACOS-CHROME` covers porting drag handle + removal animation to AppKit.

## Evidence

- **Canonical example:** `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:127-209`
- **Screenshot:** `docs/initiative-cross-platform-ui/handoff/phase-10-d-polish-screenshots/01_drag_handle_visible.png`
- **Spec coverage:** `spec/web/ui/views/list_view_spec.cr` covers basic construction + section flattening. iOS-side per-row callback specs land under the renderer integration suite when iOS spec harness re-enables (post `[[crystal-ios-class-init-gap]]`).
