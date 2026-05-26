# Phase 10B.5 audit — Remaining Class D modifier coverage

**Branch:** `phase-10-b-5` cut from `phase-10` @ `d189c4c4` (after 10A.final).
**Brief:** `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/brief-10-b-5.md` (v1).
**Status:** Audit complete. **No-op close** — see "Disposition" below.

---

## TL;DR

Audit covers all 64 Class D entries in `intent-catalog.md`. Per the
brief's "no-op close is fine" clause, **10B.5 ships zero new modifiers**.
The remaining Class D modifier gap is large (40 missing entries) but
already correctly scoped into `intent-backlog.md` items B-003 through
B-019 (P1/P2 multi-phase work). Shipping any subset here would either
require new framework subsystems (animation, haptics, drag/drop, full
gesture surface) or create new stored-not-applied gaps on the Swift
facade — both anti-patterns flagged by prior Codex / freshness audits.

| Status | Count | Class D entries |
|---|---|---|
| SHIPPED | 12 | sheet, popover, alert, confirmation_dialog, toolbar, toolbar_item, navigation_stack, navigation_destination, navigation_path, segmented_picker_style, menu, context_menu |
| PARTIAL | 12 | list, list_row_separator, on_delete, presentation_detents, presentation_drag_indicator, navigation_split_view, navigation_link, menu_picker_style, compact_date_picker_style, ui_menu, ui_action, tap_gesture |
| MISSING | 40 | list_section_spacing, list_section_index_visibility, refreshable, searchable, search_suggestions, search_scopes, on_move, full_screen_cover, inspector, interactive_dismiss_disabled, toolbar_item_group, toolbar_item_placement, toolbar_background, toolbar_spacer, form_style, grouped_form_style, columns_form_style, wheel_picker_style, palette_picker_style, inline_picker_style, graphical_date_picker_style, wheel_date_picker_style, primary_action, draggable, drop_destination, transferable, transition, matched_geometry_effect, animation, phase_animator, keyframe_animator, sensory_feedback, ui_impact_feedback_generator, ui_notification_feedback_generator, ui_selection_feedback_generator, long_press_gesture, drag_gesture, magnify_gesture, rotate_gesture, spatial_tap_gesture |

Totals: **12 shipped / 12 partial / 40 missing = 64 Class D entries**
(matches `intent-catalog.md` final summary: "Class D: 64").

---

## Disposition: no-op close

The Class D gap is real but **not addressable inside a single sub-phase**:

1. **Most missing entries require new framework subsystems**, not single
   property additions:

   - **Animation system** — `:transition`, `:matched_geometry_effect`,
     `:animation`, `:phase_animator`, `:keyframe_animator`. Tracked under
     **B-015 Animation modifiers**. Requires a `UI::Animation` value
     type, a renderer animation lifecycle, and Swift-side `withAnimation`
     plumbing.
   - **Haptics system** — `:sensory_feedback`, `:ui_impact_feedback_generator`,
     `:ui_notification_feedback_generator`, `:ui_selection_feedback_generator`.
     Tracked under **B-016 Haptics**. Requires `CHHapticEngine` / UIKit
     feedback generators bridged through SwiftKit + Android `Vibrator`
     bridge.
   - **Drag & drop** — `:draggable`, `:drop_destination`, `:transferable`.
     Tracked under **B-014 Drag and drop**. Requires a `UI::Transferable`
     module + `UIDragInteraction` / `NSDragDestination` /
     `dragAndDropSource` Compose bridges.
   - **Gesture-modifier surface** — `:long_press_gesture`, `:drag_gesture`,
     `:magnify_gesture`, `:rotate_gesture`. Tracked under **B-018** /
     **B-019**. Requires a gesture-recognizer abstraction on
     `UI::View` plus per-platform gesture lifecycle.
   - **Search subsystem** — `:searchable`, `:search_suggestions`,
     `:search_scopes`. Tracked under **B-004** / **B-017**. Requires
     `UISearchController` + `NSSearchToolbarItem` + Compose `SearchBar`
     bridges and a search-state coordination story.
   - **Form modifiers** — `:form_style`, `:grouped_form_style`,
     `:columns_form_style`. Tracked under **B-008 Form modifiers**.
   - **Picker / date picker styles** — `:wheel_picker_style`,
     `:palette_picker_style`, `:inline_picker_style`,
     `:graphical_date_picker_style`, `:wheel_date_picker_style`. Tracked
     under **B-012 Picker styles** and **B-013 Date picker styles**.
     Requires renderer-side style switches that the SwiftKit Picker /
     DatePicker facades do not yet honor.

2. **`:full_screen_cover` and `:inspector` are widgets, not modifiers.**
   Phase 10B.4 owns these (branch `phase-10-b-4` exists; not yet merged
   into `phase-10`). They are out of scope for 10B.5 per the brief
   ("10B.4 closed the missing-WIDGET gap; 10B.5 closes any remaining
   Class D MODIFIER gap"). When 10B.4 merges, the catalog rows for
   `:full_screen_cover` and `:inspector` flip from MISSING to SHIPPED
   without 10B.5 action.

3. **The "small, easy" property candidates each have a Swift-facade
   blocker** that makes them stored-not-applied on iOS/macOS:

   - `:interactive_dismiss_disabled` — `SheetFacade.swift` has no
     `interactiveDismissDisabled(_:)` call. Adding a Crystal property +
     populator forward but no facade application repeats the
     `:presentation_drag_indicator` anti-pattern flagged by Codex
     (`intent-catalog.md` row for `:presentation_drag_indicator`:
     *"stored-not-applied for iOS/macOS"*). The catalog already
     classifies this as the wrong outcome.
   - `:toolbar_background` — `ToolbarFacade.swift` has no
     `toolbarBackground(_:for:)` call. Same anti-pattern.
   - `:toolbar_item_placement` — `populate_toolbar` already sets
     `:setItemPlacements` to `"primary"` for every item (see
     `src/ui/native/swiftkit_overrides.cr:649-650`); the SwiftKit
     facade reads but ignores anything other than `primary`. Plumbing a
     per-item `placement` field requires the same Swift-side update
     plus a renderer-side branch.
   - `:list_section_spacing` — `ListViewFacade.swift` has no
     `.listSectionSpacing(_:)` call.
   - `:primary_action` (on `UI::MenuButton`) — `MenuButtonFacade.swift`
     has no `Button(action:primaryAction:)` form; adding the Crystal
     property without the facade work just stores it.

4. **The remaining "MISSING" entries that *could* be Crystal-side
   property additions all hit one of the three barriers above** —
   subsystem, widget, or Swift-side blocker. There is no clean 1-3
   modifier subset that ships end-to-end inside 10B.5.

Per the brief: *"If nothing's missing, ship an honest no-op close."*
The audit finds: it IS missing, but every gap is already correctly
scoped into either (a) the 10B.4 widget brief, (b) an `intent-backlog.md`
entry tracking the subsystem, or (c) a Swift-facade follow-up that
needs its own scope. The honest call is to publish this audit, leave
the catalog rows as-is, and close 10B.5 as a no-op.

---

## Per-entry audit table

Each row cites either the shipping source path OR the backlog ID
gating the work. "Renderers" abbreviates the four-renderer set: iOS
(`uikit_renderer.cr`), macOS (`appkit_renderer.cr`), Web
(`web_renderer.cr`), Android (`android_renderer.cr`).

### SHIPPED (12)

| Intent | Source citation |
|---|---|
| `:sheet` | `src/ui/views/sheet.cr:12`; renderers visit at uikit 1687, appkit 1668, web 1357, android 1843. |
| `:popover` | `src/ui/views/popover.cr:4`; renderers visit at uikit 1723, appkit 1697, web 1390, android 1907. |
| `:alert` | `src/ui/views/alert.cr:5`; renderers visit at uikit 951, appkit 970, web 713, android 1046. |
| `:confirmation_dialog` | `src/ui/views/confirmation_dialog.cr:4`; renderers visit at uikit 1758, appkit 1733, web 1418, android 1984. |
| `:toolbar` | `src/ui/views/toolbar.cr:9`; renderers visit at uikit 1656, appkit 1633, web 1327, android 1821. |
| `:toolbar_item` | `src/ui/views/toolbar.cr:10` (`record ToolbarItem`); added via `Toolbar#add_item` at 28,32; consumed inside `visit(Toolbar)` paths. |
| `:navigation_stack` | `src/ui/views/navigation_stack.cr:10`; coordinator at `src/ui/navigation_coordinator.cr:30,38-39,59-67`; renderers at uikit 779, appkit 800, web 530, android 946. |
| `:navigation_destination` | `src/asset_pipeline/native_app.cr:227` (`macro screen`); registers route→destination on `UI::App` subclasses. |
| `:navigation_path` | `src/ui/navigation_coordinator.cr:38-39` (`getter routes : Array(Route)`); mutators at 59-67. |
| `:segmented_picker_style` | `src/ui/views/segmented_control.cr:4-7`; renderers at uikit 1381, appkit 1323, web 924, android 1408. |
| `:menu` | `src/ui/views/menu_button.cr:22-53`; renderers at uikit 2122, appkit 2133, web 1680, android 2250. |
| `:context_menu` | `src/ui/views/context_menu.cr:10` (iOS-gated) + `src/ui/views/context_menu_with_web_fallback.cr:15`; renderers at appkit 2164,3782, web 1720,1737, android 2263. |

### PARTIAL (12)

| Intent | Citation + gap |
|---|---|
| `:list` | `src/ui/views/list_view.cr:5,13,37`; renderers at uikit 1064, appkit 1067, web 811, android 1243. Composition is real native List visitor (not VStack fallback). Gap: missing modifiers below. |
| `:list_row_separator` | `src/ui/views/list_view.cr:36` (`shows_separators : Bool`); honored at uikit 1235, appkit 1216-1229. Gap: per-row override missing (catalog flag). |
| `:on_delete` | Via `UI::SwipeActionRow` trailing actions (`src/ui/views/swipe_action_row.cr:65`). Standalone `on_delete` on `UI::ListView` not exposed. Gap tracked under **B-005**. |
| `:presentation_detents` | `src/ui/views/sheet.cr:36`; iOS/macOS forwarded via `src/ui/native/swiftkit_overrides.cr:573-576`. Web/Android stubs echo values. Gap tracked under **B-007**. |
| `:presentation_drag_indicator` | `src/ui/views/sheet.cr:35`; web/Android honored. iOS/macOS: SwiftKit STORES via `setShowsDragIndicator` but `SheetFacade.swift` does NOT apply `.presentationDragIndicator(_:)`. Stored-not-applied gap (Codex MED-2). Tracked under **B-007**. |
| `:navigation_split_view` | `src/ui/views/navigation_split_view.cr:4-10`; renderers at uikit 1576, appkit 1547, web 1274, android 1782. Gap: compact-collapse to stack not implemented at renderer level. |
| `:navigation_link` | `src/ui/views/navigation_link.cr:10-21`. Gap: route-driven `Voyager.dispatch(:open_X)` integration is per-app, not on the link type itself. |
| `:menu_picker_style` | `src/ui/views/picker.cr:16` (`property style : PickerStyle = PickerStyle::Menu`); renderers at uikit 1000, appkit 1003, web 748, android 1106-1108. Only Menu and Segmented styles render today; Wheel/Inline enum values exist but no renderer branch. |
| `:compact_date_picker_style` | `src/ui/views/date_picker.cr:4-10`; renderers at uikit 1408, appkit 1353, web 957, android 1456. Gap: no `date_picker_style` switch — only one rendering mode per platform. |
| `:ui_menu` | `src/ui/views/menu_button.cr:23-35` (`record MenuItem` nested in `UI::MenuButton`). No top-level `UI::UIMenu` class — items live on the button. |
| `:ui_action` | `src/ui/views/menu_button.cr:23-35` (`MenuItem` carries `label`, `icon`, `is_destructive`, `action : Proc(Nil)?`). No standalone `UI::UIAction` class. |
| `:tap_gesture` | `on_tap` exists on `src/ui/views/button.cr:93`, `icon_button.cr:22`, `link_button.cr:8`, `swipe_action_row.cr:23` (`SwipeAction`). NOT on base `UI::View`. Gap tracked adjacent to **B-037**. |

### MISSING (40)

Grouped by gating backlog item.

| Intent | Gating backlog / blocker |
|---|---|
| `:list_section_spacing` | **B-008-adjacent** (list-modifier follow-up). Needs `ListViewFacade.swift` to apply `.listSectionSpacing(_:)`. |
| `:list_section_index_visibility` | **B-008-adjacent** (iOS/iPadOS only per catalog). Needs SwiftKit + UIKit `sectionIndexTitles` wiring. |
| `:refreshable` | **B-003**. Needs `UIRefreshControl` + Material `PullRefreshContainer` bridges. |
| `:searchable` | **B-004**. Needs `UISearchController` + `NSSearchToolbarItem` + Compose `SearchBar` bridges. |
| `:search_suggestions` | **B-017** (depends on B-004). |
| `:search_scopes` | **B-017** (depends on B-004). |
| `:on_move` | **B-005**. Needs list reorder gesture lifecycle. |
| `:full_screen_cover` | **B-010** — widget, owned by Phase 10B.4. |
| `:inspector` | **B-009** — widget, owned by Phase 10B.4. |
| `:interactive_dismiss_disabled` | **B-007-adjacent**. Needs `SheetFacade.swift` `.interactiveDismissDisabled(_:)`. |
| `:toolbar_item_group` | **B-011** — widget refactor, owned by Phase 10B.4. |
| `:toolbar_item_placement` | **B-011**. Needs per-item placement model + Swift facade switch. |
| `:toolbar_background` | **B-011**. Needs `ToolbarFacade.swift` `.toolbarBackground(_:for:)`. |
| `:toolbar_spacer` | **B-011** — widget, owned by Phase 10B.4. |
| `:form_style` | **B-008**. Needs `FormFacade.swift` `.formStyle(_:)` switch. |
| `:grouped_form_style` | **B-008** (depends on `:form_style`). |
| `:columns_form_style` | **B-008** (depends on `:form_style`). |
| `:wheel_picker_style` | **B-012**. Enum value exists; renderer wiring + facade switch missing. |
| `:palette_picker_style` | **B-012**. Enum value not yet defined. |
| `:inline_picker_style` | **B-012**. Enum value exists; renderer wiring + facade switch missing. |
| `:graphical_date_picker_style` | **B-013**. Needs `DatePicker#style` enum + facade switch. |
| `:wheel_date_picker_style` | **B-013**. Needs `DatePicker#style` enum + facade switch. |
| `:primary_action` | Needs `MenuButton#primary_action : Proc(Nil)?` + `MenuButtonFacade.swift` `Button(primaryAction:)` form. |
| `:draggable` | **B-014** — drag/drop subsystem. |
| `:drop_destination` | **B-014** — drag/drop subsystem. |
| `:transferable` | **B-014** — drag/drop subsystem (`UI::Transferable` module). |
| `:transition` | **B-015** — animation system. |
| `:matched_geometry_effect` | **B-015** — animation system. |
| `:animation` | **B-015** — animation system (`UI::Animation` value type). |
| `:phase_animator` | **B-015** — animation system. |
| `:keyframe_animator` | **B-015** — animation system. |
| `:sensory_feedback` | **B-016** — haptics subsystem. |
| `:ui_impact_feedback_generator` | **B-016** — haptics subsystem. |
| `:ui_notification_feedback_generator` | **B-016** — haptics subsystem. |
| `:ui_selection_feedback_generator` | **B-016** — haptics subsystem. |
| `:long_press_gesture` | **B-018** — standalone gesture surface. |
| `:drag_gesture` | **B-019** — gesture surface. |
| `:magnify_gesture` | **B-019** — gesture surface. |
| `:rotate_gesture` | **B-019** — gesture surface. |
| `:spatial_tap_gesture` | Out of scope (visionOS, per catalog row). |

---

## What 10B.5 ships

Nothing functional. Only this audit document.

- No `src/` changes.
- No `spec/` changes.
- No `intent-catalog.md` status row flips (the freshness audit from
  Phase 10-pre.1 and 10-pre.2 remains current — re-verified against
  `phase-10` tip @ `d189c4c4`).
- No new backlog rows (every MISSING entry was already tracked).

## Verification

- `crystal spec spec/web/ui` — unchanged baseline (no Crystal source
  was modified).
- `crystal tool format --check` — unchanged baseline.
- `scripts/lint_conventions.cr` — unchanged baseline.

(Run on the close commit; results identical to `phase-10` @ `d189c4c4`.)

## New gaps surfaced

None. The audit confirms the existing catalog + backlog classification
is accurate. The freshness audit from Phase 10-pre.1 / pre.2 needs no
revision.

## Reflection — why 10B.5 lands as no-op

The 10B.5 brief explicitly listed "no-op close is fine" as a valid
outcome alongside "small gap → ship" and "larger gap → use judgment."
The audit-first discipline matters here: it would have been easy to
ship a partial set of modifier properties to look productive, but every
candidate failed the end-to-end honesty bar (creates stored-not-applied
gaps, depends on a subsystem brief that hasn't run, or duplicates work
10B.4 already owns).

The lesson reinforced: when the gap is large AND already correctly
scoped into the backlog, the right move is to publish the audit and
let the next phase pick a backlog item with the right per-item scope.
Compressing 13 P2 backlog items into one sub-phase by stripping their
native integration would re-introduce the kind of false-progress gap
the Phase 10-pre.1 freshness audit had to correct.

— Implementer (Claude Opus 4.7), Phase 10B.5 audit
