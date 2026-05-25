# Intent Backlog

**Companion to:** `intent-catalog.md`, `translation-matrix.md`.

Class A + Class D intents where no shipped widget covers the per-platform default. Buildable backlog for Phase 10+ implementation.

Each entry: ID, intent, platform with the gap, what's missing, rough size estimate (S/M/L), priority (P0/P1/P2).

---

## Class A gaps

### B-001 — `:swipe_actions` macOS default

- **Intent:** `:swipe_actions`
- **Platform:** macOS
- **Gap:** No `UI::InlineActionRow` class exists. Today `UI::SwipeActionRow` is used and the AppKit renderer emits inline trailing buttons (`appkit_renderer.cr:3801`), but the widget name is misleading.
- **Action:** Create `UI::InlineActionRow` as the named macOS default. Move the AppKit inline-button rendering logic from `UI::SwipeActionRow`'s renderer into `UI::InlineActionRow`. Migrate the override registry to use the new class.
- **Size:** M. Renderer move + new class + spec coverage + Voyager migration.
- **Priority:** P1. Voyager compliance.

### B-002 — `:swipe_actions` web_wide default

- **Intent:** `:swipe_actions`
- **Platform:** web_wide
- **Gap:** Same as B-001 but for desktop web. No native swipe gesture exists; inline buttons with hover affordance are idiomatic.
- **Action:** Extend `UI::InlineActionRow` to the web renderer. Hover state shows row backdrop + trailing buttons. Mobile-web (`web_narrow`) continues to use `UI::SwipeActionRow`.
- **Size:** M.
- **Priority:** P1. Voyager web compliance.

### B-035 — `:swipe_actions` Android proper integration

- **Intent:** `:swipe_actions`
- **Platform:** Android
- **Gap:** `android_renderer.cr:3148` is explicitly a stub that renders only the content view, omitting the swipe gesture + trailing actions. Comment notes: "Android proper integration is deferred per the brief."
- **Action:** Wire Material 3 `SwipeToDismissBox` (or equivalent Compose foundation `swipeable` modifier) into the Android renderer's `visit(UI::SwipeActionRow)` method. Honor `trailing_actions` + `leading_actions` properties. Respect destructive role for color tinting.
- **Size:** M.
- **Priority:** P1 if Android is in scope for a near-term release; P2 if Android remains deferred.

---

## Class D gaps (high priority)

### B-003 — `:refreshable` integration

- **Intent:** `:refreshable`
- **Platforms with gap:** All (no `UI::List.refreshable=` property exists today).
- **Gap:** `UI::List` (or equivalent list-rendering view) has no `refreshable` property. Authors cannot wire pull-to-refresh.
- **Action:** Add `refreshable : Proc(Nil)?` to `UI::List` (or `UI::ScrollView`?). UIKit renderer wires `UIRefreshControl`. Android renderer wires `PullRefreshContainer`. macOS renderer emits a refresh `UI::ToolbarItem` automatically. Web renderer custom JS OR toolbar fallback.
- **Size:** L. Cross-platform renderer work + native gesture handling + CI test coverage.
- **Priority:** P0 if mobile-list apps are a near-term target; P1 otherwise.

### B-004 — `:searchable` integration

- **Intent:** `:searchable`
- **Platforms with gap:** All (no integration).
- **Gap:** No `UI::List.searchable=` integration. Apps that want to surface search in the navigation toolbar have to write per-renderer code.
- **Action:** Add `searchable : String?` (placeholder) + `on_search : Proc(String, Nil)?` properties to `UI::List`. UIKit `UISearchController` integration. AppKit `NSSearchToolbarItem`. Android Material `SearchBar`. Web `<input type="search">`.
- **Size:** L.
- **Priority:** P1.

### B-005 — `:on_move` (reorder) integration

- **Intent:** `:on_move`
- **Platforms with gap:** All.
- **Gap:** `UI::List` has no `on_move` property. Drag-to-reorder is not exposed at the framework level.
- **Action:** Add `on_move : Proc(Int32, Int32, Nil)?` to `UI::List`. UIKit `UITableView.isEditing` + reorder. AppKit drag-source/destination protocols. Web HTML5 draggable.
- **Size:** L.
- **Priority:** P2 unless an app needs it; the widget gap matters less for Voyager-style demos.

### B-006 — `:context_menu` web-wide rendering

- **Intent:** `:context_menu`
- **Platforms with gap:** web_wide (partial).
- **Gap:** `UI::ContextMenu` exists but `UI::ContextMenuWithWebFallback` is the explicit web-fallback class per the Tier 3 conventions. The framework should be able to render context menus natively on right-click for web_wide without requiring the fallback class.
- **Action:** Extend web renderer to bind `contextmenu` event on the parent view and render the menu as a positioned overlay. Keep `ContextMenuWithWebFallback` as the explicit-opt-in for backwards compat.
- **Size:** S.
- **Priority:** P2.

### B-007 — `:presentation_detents` on Sheet

- **Intent:** `:presentation_detents`
- **Platforms with gap:** All.
- **Gap:** `UI::Sheet` has no `presentation_detents` property. Authors cannot ask for medium-height sheets.
- **Action:** Add `presentation_detents : Array(Symbol | Float64)?` to `UI::Sheet`. UIKit `UISheetPresentationController.detents`. Android Material `ModalBottomSheet` `sheetState`. macOS+web sheet uses fixed default.
- **Size:** M.
- **Priority:** P1.

---

## Class D gaps (lower priority)

### B-008 — Form modifiers
`:form_style`, `:grouped_form_style`, `:columns_form_style`. No `UI::Form.form_style=` integration today. Size: M. Priority: P2.

### B-009 — Inspector view
`:inspector`. No `UI::Inspector` view. Size: L (cross-platform split-view extension). Priority: P2.

### B-010 — Full-screen cover
`:full_screen_cover`. No `UI::FullScreenCover` view. Size: S. Priority: P2.

### B-011 — Toolbar modifiers
`:toolbar_item_group`, `:toolbar_background`, `:toolbar_spacer`. Partial coverage today. Size: S each. Priority: P2.

### B-012 — Picker styles
`:wheel_picker_style`, `:palette_picker_style`, `:inline_picker_style`. Currently `UI::Picker` has no `picker_style` property exposing these. Size: M total. Priority: P2.

### B-013 — Date picker styles
`:graphical_date_picker_style`, `:wheel_date_picker_style`. `UI::DatePicker` has no style property. Size: M. Priority: P2.

### B-014 — Drag and drop (full)
`:draggable`, `:drop_destination`, `:transferable`. No drag-drop integration in any view. Size: L. Priority: P2.

### B-015 — Animation modifiers
`:transition`, `:matched_geometry_effect`, `:animation`, `:phase_animator`, `:keyframe_animator`. No animation modifier integration. Size: L. Priority: P2.

### B-016 — Haptics
`:sensory_feedback`. No `view.sensory_feedback=` property. Size: S. Priority: P2.

### B-017 — Search suggestions / scopes
`:search_suggestions`, `:search_scopes`. Depend on B-004 landing first. Size: M total. Priority: P2.

### B-018 — Long-press as standalone
`:long_press_gesture`. Currently only used internally by ContextMenu. Size: S. Priority: P2.

### B-019 — Magnify / Rotate gestures
`:magnify_gesture`, `:rotate_gesture`. No view-level integration. Size: M. Priority: P2.

---

## Class B gaps (accessibility — significant)

### B-020 — Accessibility action surface

- **Intent:** `:accessibility_action`
- **Gap:** No `view.accessibility_actions=` property. Critical for swipe-action rows per HIG `accessibility.md:134`.
- **Action:** Add `accessibility_actions : Array(UI::AccessibilityAction)?` to base `UI::View`. UIKit `UIAccessibilityCustomAction`. AppKit `NSAccessibilityCustomAction`.
- **Size:** M.
- **Priority:** P0. HIG-mandated for any view that uses gestures.

### B-021 — Accessibility hint / value surfacing

- **Intent:** `:accessibility_hint`, `:accessibility_value`
- **Gap:** Inconsistent surfacing on existing views.
- **Action:** Add to base `UI::View`. Renderers map to native properties.
- **Size:** S.
- **Priority:** P1.

### B-022 — Reduce-motion contract

- **Intent:** `:accessibility_reduce_motion`
- **Gap:** No framework helper for querying `prefersReducedMotion`. Authors have to know per-platform APIs.
- **Action:** Add `UI::Environment.reduce_motion? : Bool` that reads the platform setting. Document the contract that animation modifiers should consult this.
- **Size:** S.
- **Priority:** P1.

### B-023 — Dynamic-type runtime scaling

- **Intent:** `:dynamic_type_size`
- **Gap:** Design tokens carry semantic font sizes but runtime scaling is not wired.
- **Action:** Renderers honor system text-size preference and scale `UI::Font` sizes proportionally.
- **Size:** M.
- **Priority:** P1.

### B-024 — Full keyboard access

- **Intent:** `:full_keyboard_access`
- **Gap:** Partial. Some views are focusable but the framework doesn't have a documented contract.
- **Action:** Audit every interactive widget for keyboard focusability; add focus-ring rendering; document the contract.
- **Size:** L.
- **Priority:** P1.

### B-025 — VoiceOver landmark grouping

- **Intent:** `:voiceover_landmark`
- **Gap:** No `accessibility_element_grouping` property; VoiceOver users hear leaf elements.
- **Action:** Add `accessibility_grouping : Symbol?` (or equivalent) to container views. Renderers map to platform grouping.
- **Size:** M.
- **Priority:** P1.

---

## Class C gaps (system integration — entirely missing)

All Class C intents are missing — no Crystal API surfaces today.

| ID | Intent | Size | Priority |
|---|---|---|---|
| B-026 | `:share_link` | M | P1 |
| B-027 | `:copy_to_clipboard` | S | P1 |
| B-028 | `:paste_from_clipboard` | S | P2 |
| B-029 | `:request_permission` (per-resource) | L | P1 (camera, photos); P2 (others) |
| B-030 | `:open_url` | S | P1 |
| B-031 | `:open_deep_link` | M | P2 |
| B-032 | `:print_document` | M | P2 |
| B-033 | `:file_importer` | M | P2 |
| B-034 | `:file_exporter` | M | P2 |

These can ship as `UI::System.*` module-level functions (single Crystal API, renderer translates to platform).

---

## Total backlog

| Class | Count | P0 | P1 | P2 |
|---|---|---|---|---|
| A | 2 | 0 | 2 | 0 |
| B | 6 | 1 | 5 | 0 |
| C | 9 | 0 | 4 | 5 |
| D | 17 | 0 | 4 | 13 |
| **Total** | **34** | **1** | **15** | **18** |

**P0 (1):** B-020 (accessibility actions — HIG-mandated for swipe rows).
**P1 (15):** Mostly Voyager-compliance work + key Class C surfaces.
**P2 (18):** Nice-to-haves, ships as needed.

— Architect (Claude Opus 4.7)
