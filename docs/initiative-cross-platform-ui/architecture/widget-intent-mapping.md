# Widget → Intent Mapping

**Companion to:** `intent-catalog.md`, `translation-matrix.md`, `intent-backlog.md`.

Retro-classification of every `*.cr` file under `src/ui/views/` (including the gate-stub subdirectory). Each row carries:

- **View file** — path under `src/ui/views/`.
- **Primary intent (Apple name)** — the SwiftUI / UIKit / AppKit identifier this widget serves; `—` for pure layout primitives with no Apple-named intent.
- **Class** — exactly one of A / B / C / D (per brief-9 §"Item 6": every row carries an exact class assignment; layout primitives that map 1:1 to a SwiftUI primitive — `VStack`, `HStack`, `ZStack`, `Spacer`, `Divider`, `Rectangle`, `Circle`, `Capsule`, `RoundedRectangle`, `Path` — are Class D direct translations even though the catalog does not yet enumerate them).
- **Tier** — 1 (brand-universal), 2 (platform default), or 3 (platform-only gated). Tier assignments mirror `docs/initiative-cross-platform-ui/tier-matrix.md`.
- **Routing candidate?** — `YES` only for Class A widgets (per brief-9 §5 Item 6, only `swipe_action_row.cr` qualifies in this catalog).
- **Reason** — one sentence justifying the class assignment.
- **Gaps** — backlog ID(s) from `intent-backlog.md` for missing per-platform defaults; `—` if none.

**Row count: 82** (79 top-level `src/ui/views/*.cr` files + 3 gate-stub siblings under `_gate_stubs/`). The total file count and category breakdown are reconciled in `translation-matrix.md` §"Freshness reconciliation."

---

## Top-level views (79)

| View file | Primary intent (Apple name) | Class | Tier | Routing candidate? | Reason | Gaps |
|---|---|---|---|---|---|---|
| `action_sheet.cr` | `confirmationDialog` (iOS surface) | D | 3 | NO | Tier 3 iOS-only action sheet; uses SwiftUI `.confirmationDialog` via the ConfirmationDialogFacade. | — |
| `action_sheet_with_web_fallback.cr` | `confirmationDialog` | D | 3 | NO | Cross-platform companion to `UI::ActionSheet`; delegates to iOS facade or synthesizes `UI::ConfirmationDialog` on every other target. | — |
| `activity_indicator.cr` | `ProgressView` (indeterminate) | D | 2 | NO | Indeterminate spinner; maps 1:1 to SwiftUI `ProgressView()`, `UIActivityIndicatorView`, `NSProgressIndicator`. | — |
| `activity_ring.cr` | `Gauge` (`accessoryCircularCapacity`) | D | 2 | NO | Single circular activity ring; renders as a shared fallback surface mirroring SwiftUI `Gauge` semantics. | — |
| `activity_rings.cr` | `Gauge` (Move/Exercise/Stand triplet) | D | 2 | NO | Three-ring HIG activity summary; a composition over `Gauge` semantics, not a routed widget. | — |
| `activity_view.cr` | `ShareLink` / `UIActivityViewController` | C | 2 | NO | Activity view for sharing; single Crystal API surface that bridges to `ShareLink` (iOS 16+), `UIActivityViewController`, `NSSharingService`, Web Share, Android `Intent.ACTION_SEND`. Carries an `ActivityViewPresenter` helper. | B-026 |
| `alert.cr` | `alert` | D | 2 | NO | Modal alert dialog; maps to SwiftUI `.alert`, `UIAlertController`, `NSAlert`. | — |
| `async_image.cr` | `AsyncImage` | D | 2 | NO | Asynchronous remote image loader; maps 1:1 to SwiftUI `AsyncImage`. | — |
| `button.cr` | `Button` | D | 2 | NO | Clean SwiftUI `Button` / `UIButton` / `NSButton` mapping; concrete widget, never routed. | — |
| `canvas.cr` | `Canvas` | D | 2 | NO | Immediate-mode drawing surface; maps to SwiftUI `Canvas`, `UIGraphicsImageRenderer`, `NSGraphicsContext`. | — |
| `capsule.cr` | `Capsule` (shape) | D | 1 | NO | Tier 1 brand-universal shape primitive; direct 1:1 mapping to SwiftUI `Capsule`. | — |
| `card.cr` | `GroupBox` / Boxes (HIG) | D | 1 | NO | Brand-universal container that follows HIG Boxes guidance; closest Apple analog is SwiftUI `GroupBox`. | — |
| `chart_view.cr` | `Chart` (Swift Charts) | D | 2 | NO | Maps to SwiftUI `Chart` (Swift Charts framework). | — |
| `checkbox.cr` | `Toggle` (`.checkbox` style) | D | 2 | NO | Boolean toggle styled as a checkbox; maps to SwiftUI `Toggle(...).toggleStyle(.checkbox)`, `NSButton(checkboxWithTitle:)`. | — |
| `circle.cr` | `Circle` (shape) | D | 1 | NO | Tier 1 brand-universal shape primitive; direct 1:1 mapping to SwiftUI `Circle`. | — |
| `color_picker.cr` | `ColorPicker` | D | 2 | NO | Maps 1:1 to SwiftUI `ColorPicker`, `UIColorPickerViewController`, `NSColorWell`. | — |
| `column_view.cr` | `NSBrowser` (Finder-style columns) | D | 1 | NO | Tier 1 column browser; renderer-agnostic primitive whose closest Apple analog is `NSBrowser`. | — |
| `combo_box.cr` | `NSComboBox` | D | 2 | NO | Hybrid text field + pull-down; maps to `NSComboBox` on macOS; HIG marks iOS as N/A so the widget degrades to a `Picker`-style fallback. | — |
| `confirmation_dialog.cr` | `confirmationDialog` | D | 2 | NO | Cross-platform confirmation dialog; maps to SwiftUI `.confirmationDialog`, `UIAlertController(.actionSheet)`, `NSAlert`. | — |
| `context_menu.cr` | `contextMenu` | D | 3 | NO | Tier 3 Apple-family-only context menu; SwiftUI `.contextMenu` / `UIContextMenuConfiguration`. | — |
| `context_menu_with_web_fallback.cr` | `contextMenu` | D | 3 | NO | Cross-platform companion that delegates on Apple targets and emits a vanilla-JS positioned dropdown on web. | B-006 |
| `date_picker.cr` | `DatePicker` | D | 2 | NO | Maps to SwiftUI `DatePicker`, `UIDatePicker`, `NSDatePicker`. | B-013 |
| `disclosure_group.cr` | `DisclosureGroup` | D | 2 | NO | Header + collapsible content; maps to SwiftUI `DisclosureGroup`, `NSDisclosureView` patterns. | — |
| `divider.cr` | `Divider` | D | 1 | NO | Tier 1 layout primitive; direct 1:1 mapping to SwiftUI `Divider`, `<hr>`. | — |
| `form.cr` | `Form` | D | 2 | NO | Form container that also doubles as a web `<form>` host when `action` is non-nil; maps to SwiftUI `Form`. | B-008 |
| `gauge.cr` | `Gauge` | D | 2 | NO | Circular gauge primitive; maps to SwiftUI `Gauge`, `NSLevelIndicator` (capacity/relevancy styles). | — |
| `glass_background.cr` | `Material` / `UIVisualEffectView` | D | 2 | NO | Liquid Glass material backdrop; maps to SwiftUI `.background(.regularMaterial)`, `UIVisualEffectView(effect: UIBlurEffect)`, `NSVisualEffectView`. | — |
| `grid.cr` | `Grid` | D | 1 | NO | Tier 1 layout primitive; maps to SwiftUI `Grid` / `LazyVGrid`. | — |
| `hstack.cr` | `HStack` | D | 1 | NO | Tier 1 layout primitive; direct 1:1 mapping to SwiftUI `HStack`, `UIStackView(.horizontal)`, `NSStackView(.horizontal)`. | — |
| `icon_button.cr` | `Button` (icon-only label) | D | 2 | NO | Icon-only button using SF Symbol on Apple and material icons elsewhere; specialization of `Button`. | — |
| `image.cr` | `Image` | D | 1 | NO | Tier 1 image primitive; maps to SwiftUI `Image`, `UIImageView`, `NSImageView`. | — |
| `image_well.cr` | `NSImageView` (image well) | D | 2 | NO | Bordered image drop-target; maps to `NSImageView` with `isEditable = true`; iOS uses a custom drop-zone analog. | — |
| `label.cr` | `Text` | D | 1 | NO | Tier 1 read-only text primitive; maps to SwiftUI `Text`, `UILabel`, `NSTextField(labelWithString:)`. | — |
| `link_button.cr` | `Link` | D | 2 | NO | URL-opening button; maps to SwiftUI `Link`, `UIButton`-with-URL-handler, web `<a>`. | — |
| `list_view.cr` | `List` | D | 2 | NO | Scrollable list with optional sections; maps to SwiftUI `List`, `UITableView` / `UICollectionView`, `NSTableView`. | B-003, B-004, B-005 |
| `map_view.cr` | `Map` (MapKit) | D | 2 | NO | Map view; maps to SwiftUI `Map`, `MKMapView`, web Leaflet/Google embed. | — |
| `menu_button.cr` | `Menu` / `NSPopUpButton` | D | 2 | NO | Pop-up / pull-down menu trigger; maps to SwiftUI `Menu`, `NSPopUpButton`, `UIButton` with `UIMenu`. | — |
| `navigation_link.cr` | `NavigationLink` | D | 2 | NO | Push-style nav link; maps to SwiftUI `NavigationLink`. | — |
| `navigation_split_view.cr` | `NavigationSplitView` | D | 2 | NO | Two/three-column split navigation; maps to SwiftUI `NavigationSplitView`, `UISplitViewController`, `NSSplitViewController`. Future Class A candidate per `translation-matrix.md`. | — |
| `navigation_stack.cr` | `NavigationStack` | D | 2 | NO | Push/pop stack navigation; maps to SwiftUI `NavigationStack`, `UINavigationController`. | — |
| `outline_view.cr` | `OutlineGroup` / `NSOutlineView` | D | 2 | NO | Hierarchical outline; maps to SwiftUI `OutlineGroup` (in `List`), `NSOutlineView`. Carries a `Node` record. | — |
| `page_control.cr` | `UIPageControl` | D | 2 | NO | Dot indicators showing position in a paged list; UIKit-named primitive with macOS/web fallbacks. | — |
| `panel.cr` | `Inspector` / `NSPanel` | D | 1 | NO | Tier 1 inspector/auxiliary panel surface; nearest Apple analog is SwiftUI `.inspector` or `NSPanel`. | B-009 |
| `path_control.cr` | `NSPathControl` | D | 3 | NO | Tier 3 macOS-only path control; maps to `NSPathControl`. | — |
| `path_control_with_web_fallback.cr` | `NSPathControl` | D | 3 | NO | Cross-platform companion; delegates on macOS and emits a semantic `<nav aria-label="Breadcrumb">` everywhere else. | — |
| `path_view.cr` | `Path` (shape) | D | 1 | NO | Tier 1 SVG/path primitive; direct 1:1 mapping to SwiftUI `Path`. | — |
| `picker.cr` | `Picker` | D | 2 | NO | Selection control; maps to SwiftUI `Picker` (all styles). | B-012 |
| `popover.cr` | `popover` | D | 2 | NO | Anchored popover surface; maps to SwiftUI `.popover`, `UIPopoverPresentationController`, `NSPopover`. Carries a `PopoverPresenter` helper. | — |
| `progress_view.cr` | `ProgressView` | D | 2 | NO | Determinate / indeterminate progress; maps to SwiftUI `ProgressView`, `UIProgressView`, `NSProgressIndicator`. | — |
| `radio_group.cr` | `Picker(.radioGroup)` | D | 2 | NO | Mutually exclusive radio options; maps to SwiftUI `Picker(...).pickerStyle(.radioGroup)` on macOS, custom on iOS. | — |
| `rating_indicator.cr` | `NSLevelIndicator(.rating)` | D | 2 | NO | Star-style rating row; maps to `NSLevelIndicator` with `.rating` style on macOS, custom on iOS/web. | — |
| `rectangle.cr` | `Rectangle` (shape) | D | 1 | NO | Tier 1 shape primitive; direct 1:1 mapping to SwiftUI `Rectangle`. | — |
| `rich_text.cr` | `AttributedString` `Text` | D | 2 | NO | Attributed-string text view; maps to SwiftUI `Text(AttributedString(...))`. | — |
| `rounded_rectangle.cr` | `RoundedRectangle` (shape) | D | 1 | NO | Tier 1 shape primitive; direct 1:1 mapping to SwiftUI `RoundedRectangle`. | — |
| `scroll_view.cr` | `ScrollView` | D | 2 | NO | Scrollable container; maps to SwiftUI `ScrollView`, `UIScrollView`, `NSScrollView`. | — |
| `search_field.cr` | `searchable` / `UISearchBar` | D | 2 | NO | Search input; maps to SwiftUI `.searchable`, `UISearchBar`, `NSSearchField`. | B-004 |
| `secure_field.cr` | `SecureField` | D | 2 | NO | Password input; convenience wrapper that maps to SwiftUI `SecureField`, `UITextField(isSecureTextEntry:)`, `NSSecureTextField`. | — |
| `segmented_control.cr` | `Picker(.segmented)` | D | 2 | NO | Segmented selection; maps to SwiftUI `Picker(...).pickerStyle(.segmented)`, `UISegmentedControl`, `NSSegmentedControl`. | — |
| `sheet.cr` | `sheet` | D | 2 | NO | Modal sheet presentation; maps to SwiftUI `.sheet`. Carries a `SheetPresenter` helper. | B-007 |
| `slider.cr` | `Slider` | D | 2 | NO | Continuous-value slider; maps to SwiftUI `Slider`, `UISlider`, `NSSlider`. | — |
| `snackbar.cr` | `Toast` / transient banner | D | 2 | NO | Transient feedback banner; Material `Snackbar` analog on Apple is a custom transient overlay (no first-party HIG name). Carries a `SnackbarPresenter` helper. | — |
| `spacer.cr` | `Spacer` | D | 1 | NO | Tier 1 layout primitive; direct 1:1 mapping to SwiftUI `Spacer`. | — |
| `stepper.cr` | `Stepper` | D | 2 | NO | Increment/decrement control; maps to SwiftUI `Stepper`, `UIStepper`, `NSStepper`. | — |
| `surface.cr` | Material/elevation surface | D | 1 | NO | Tier 1 themed surface primitive; nearest Apple analog is SwiftUI `.background(.background)` over a `GroupBox`-style container. | — |
| `swipe_action_row.cr` | `swipeActions` | A | 2 | YES | The single Class A intent — materially different per platform (iOS swipe-reveal vs macOS/web inline buttons); also defines a `SwipeAction` record. | B-001, B-002, B-035 |
| `tab_view.cr` | `TabView` | D | 2 | NO | Tab-bar navigation; maps to SwiftUI `TabView`, `UITabBarController`. | — |
| `text_area.cr` | `TextField(axis: .vertical)` | D | 2 | NO | Multi-line text input; maps to SwiftUI `TextField(axis: .vertical)`, `UITextView`, `NSTextView`. | — |
| `text_editor.cr` | `TextEditor` | D | 2 | NO | Long-form text editor; maps to SwiftUI `TextEditor`, `UITextView`, `NSTextView`. | — |
| `text_field.cr` | `TextField` | D | 2 | NO | Single-line editable input; maps to SwiftUI `TextField`, `UITextField`, `NSTextField`. | — |
| `time_picker.cr` | `DatePicker(displayedComponents: .hourAndMinute)` | D | 2 | NO | Time-only specialization of `DatePicker`. | — |
| `toggle.cr` | `Toggle` | D | 2 | NO | Boolean toggle (switch); maps to SwiftUI `Toggle`, `UISwitch`, `NSSwitch`. | — |
| `toggle_button.cr` | `Button` (toggle role) | D | 2 | NO | Two-state pushable button; maps to SwiftUI `Toggle(...).toggleStyle(.button)`, `NSButton(.toggle)`. | — |
| `token_field.cr` | `NSTokenField` | D | 2 | NO | Pill-style token entry; maps to `NSTokenField` on macOS, custom on iOS/web. | — |
| `toolbar.cr` | `toolbar` | D | 2 | NO | Toolbar surface; maps to SwiftUI `.toolbar`, `UIToolbar`, `NSToolbar`. | B-011 |
| `tooltip.cr` | `help` / tooltip | D | 2 | NO | Hover/long-press tooltip; maps to SwiftUI `.help(_:)`, `NSView.toolTip`. | — |
| `video_player.cr` | `VideoPlayer` (AVKit) | D | 2 | NO | Media playback; maps to SwiftUI `VideoPlayer`, `AVPlayerViewController`. | — |
| `vstack.cr` | `VStack` | D | 1 | NO | Tier 1 layout primitive; direct 1:1 mapping to SwiftUI `VStack`, `UIStackView(.vertical)`, `NSStackView(.vertical)`. | — |
| `web_view.cr` | `WKWebView` | D | 2 | NO | Embedded web content; maps to `WKWebView` on Apple, `WebView` (Android), `<iframe>` (web). | — |
| `zstack.cr` | `ZStack` | D | 1 | NO | Tier 1 layout primitive; direct 1:1 mapping to SwiftUI `ZStack`. | — |

## Gate-stub siblings (3)

These files live under `src/ui/views/_gate_stubs/` and exist solely to emit a `{% raise %}` compile-time error on non-matching builds (per CLAUDE.md:148-160). They mirror an existing Tier 3 widget and inherit its classification.

| View file | Primary intent (Apple name) | Class | Tier | Routing candidate? | Reason | Gaps |
|---|---|---|---|---|---|---|
| `_gate_stubs/action_sheet.cr` | `confirmationDialog` (iOS surface) | D | 3 | NO | Compile-time stub mirroring `UI::ActionSheet`; emits a `{% raise %}` error on non-iOS builds. | — |
| `_gate_stubs/context_menu.cr` | `contextMenu` | D | 3 | NO | Compile-time stub mirroring `UI::ContextMenu`; emits a `{% raise %}` error on non-Apple-family builds. | — |
| `_gate_stubs/path_control.cr` | `NSPathControl` | D | 3 | NO | Compile-time stub mirroring `UI::PathControl`; emits a `{% raise %}` error on non-macOS builds. | — |

---

## Summary

- **Total rows:** 82 (79 top-level + 3 gate-stub siblings).
- **Class A (routing candidates):** 1 (`swipe_action_row.cr`).
- **Class B:** 0 (Class B intents are framework invariants, not view files; cross-cutting accessibility lives on every `UI::View`, not in a dedicated view file).
- **Class C:** 1 (`activity_view.cr`).
- **Class D:** 80 (every concrete widget that maps 1:1 to a SwiftUI / UIKit / AppKit named API, modifier, or primitive — including the 10 Tier 1 layout primitives that map directly to SwiftUI `VStack` / `HStack` / `ZStack` / `Spacer` / `Divider` / `Rectangle` / `Circle` / `Capsule` / `RoundedRectangle` / `Path`).
- **Tier 1:** 17. **Tier 2:** 56 (incl. the WithWebFallback companions that ride along the Tier 3 widget but render universally). **Tier 3:** 3 gated + 3 companions + 3 gate stubs = 9 files in the Tier 3 orbit, but only 3 widget rows in `tier-matrix.md` (per brief-9 §6 and Codex iter 1's note: `swipe_action_row.cr` is also currently absent from `tier-matrix.md` — a documented staleness in the matrix, not a discrepancy in the source tree).

**Row math:** 1 (A) + 0 (B) + 1 (C) + 80 (D) = 82. Matches the source-tree count.

— Implementer (Claude Opus 4.7), Phase 9 iter 1
