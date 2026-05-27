# Phase 10D-polish — ListView default chrome + animations + 5 catalog extensions in todos

**Branch:** `phase-10-d-polish` from `phase-10-d-final` (HEAD `57206987`).
**Status:** v1. Owner-aligned this session after 10D-final hand-test.

## Owner alignment (verbatim, this session)

> "The thing that sticks out is that I would have expected the buttons that appear for the swipe actions ... I expect these corners to actually be square ... so that these buttons are, you know, sliced into this row, not separate items entirely."

> "Anything that removes a row happens too quickly. We need to have some kind of animation that shows the row what I like and what has worked out really well so far is that we have it collapse from right to left over the course of, you know, a couple seconds" → clarified: 300-500ms range, start at 400-500ms.

> "I would have expected the rows to have something on the icon or on the row to indicate that it was draggable, so it gave me like an anchoring point like the grayed out little lines that look like a grip." → confirmed `line.3.horizontal`, right side, always visible, touch-initiates-drag.

> "Do the row inset to 16 point."

> Re catalog scope: "We haven't tried sheets, we haven't tried some of the other pull downs or popovers ... we should be ... demonstrating these widgets and the various functionalities."

## Scope split

This brief covers **two concerns merged into one implementer pass**:

**A. Polish the `UI::ListView` widget defaults** so every consumer of that widget gets Mail-style chrome + animations for free. (Not a Voyager tweak — defaults baked into the widget.)

**B. Add five catalog widgets to the todos flow** so the hand-test exercises more of the Phase 10 catalog: Alert, ActionSheet, Sheet, DatePicker, Popover (or ContextMenu).

Both are scoped so they can land in one focused implementer dispatch.

## Deliverables

### Deliverable A1 — Action tile corners

In `swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/ListViewFacade.swift`, the swipe action tiles currently render as SwiftUI Buttons with the default capsule shape inside `.swipeActions(edge:)`. iOS Mail-style tiles are rectangles with all-four-corner-square — they look "punched into" the row.

**Fix:** Apply `.buttonStyle(.borderedProminent)` with custom `.tint(...)` and a `.background(.<color>)` so each tile is a solid color rectangle, OR use the labeled `Button(role:)` initializer which SwiftUI already renders as a full-tile rectangle inside `.swipeActions`. The latter is the iOS-native default.

The tile should:
- Fill the full row height (this already works).
- Have square corners on all four sides (no rounded-button chrome).
- Visually appear as if "sliced into" the row from the swipe edge — i.e., the row body content gets clipped where the tile begins, the tile starts immediately at the swipe-edge boundary with no inter-tile padding.

### Deliverable A2 — Drag handle

Add `line.3.horizontal` SF Symbol on the right edge of every row in a `UI::ListView` that has `on_move` set. Always visible (not edit-mode-only). Touching the handle initiates the drag immediately.

Implementation:
- In `ListViewFacade.swift`, when `overrides.moveToken != nil`, render the SF Symbol image inline at the row's trailing edge with appropriate padding (`12pt`-ish from the right edge).
- Use the system gray tertiary color so it reads as a "secondary affordance" not a primary control.
- Tap-gesture-on-handle starts the drag. Long-press-anywhere still works as fallback per current behavior.
- The handle should not occupy more than ~24pt width on the right side.

Crystal-side: this is a default behavior driven by `on_move != nil`. No new `UI::ListView` property needed — the handle appears automatically when reorder is enabled. Document this in the `UI::ListView` source comments.

### Deliverable A3 — Row removal animation (400-500ms)

Currently when a Mark Done / Delete fires, the row instantly disappears. Owner wants a deliberate animation that signals removal:

1. Phase 1 (~250ms): row content (title + subtitle + handle) collapses horizontally right-to-left, fading to opacity 0.
2. Phase 2 (~150-200ms): row height collapses to 0, adjacent rows ease up into the gap.

Implementation:
- In `ListViewFacade.swift`, when items are removed (the `items` array shrinks between calls), animate the removal via SwiftUI's `withAnimation(.easeInOut(duration: 0.4))` or `.transition(.asymmetric(insertion: ..., removal: .opacity.combined(with: .scale(scale: 0, anchor: .leading))))`.
- The animation should be the widget's default — no Crystal-side property needed. If a future consumer needs to disable it, they can override later.

Verify by triggering Delete or Mark Done in the simulator and visually confirming the row collapses smoothly.

### Deliverable A4 — Row edge inset (16pt)

Currently the todos screen pads each row 20pt from the screen edge (plus safe-area). Owner wants 16pt as the default, AND wants this to be a `UI::ListView` default behavior, not a Voyager tweak.

Fix:
- Remove the screen-level `padding: leading: 20.0 + safe_area_leading` on the todos screen's outer VStack.
- Update `UI::ListView` (or `ListViewFacade.swift`) to apply 16pt leading/trailing insets by default.
- If `UI::ListView` already has an inset property, set its default to 16pt. If not, add `content_inset_horizontal : Float64 = 16.0`.

### Deliverable B1 — Delete tile → `UI::Alert` confirmation

Currently Delete fires immediately. Owner wants a destructive-confirmation alert: title "Delete '{todo.title}'?", message "This can't be undone.", buttons Cancel + Delete (destructive role).

Implementation:
- The Delete swipe action's `on_tap` no longer dispatches `:delete_row` directly. Instead, it sets a screen-state flag `pending_delete_todo_id` and re-renders.
- The screen's `build(ctx)` checks if `pending_delete_todo_id` is set and renders a `UI::Alert` view at the bottom of the view tree, configured with the two buttons.
- Cancel: clears the pending flag.
- Delete: dispatches `:delete_row` AND clears the pending flag.

This exercises `UI::Alert`'s `is_presented` pattern + destructive button role.

### Deliverable B2 — Share tile → `UI::ActionSheet`

Currently Share immediately copies to clipboard. Owner wants an action sheet that offers options: Copy / Print This Todo / Cancel.

Implementation:
- Share tile sets a `pending_share_todo_id` flag instead of dispatching directly.
- Screen renders `UI::ActionSheet` with three actions: Copy (→ `:copy_to_clipboard`), Print (→ `:print_one_todo` — new controller action that prints just this one), Cancel.
- Exercises `UI::ActionSheet`'s action array + iOS-native bottom-sheet chrome.

### Deliverable B3 — Editor → `UI::Sheet` modal

Currently the editor is reached via dispatcher-driven slug navigation that pushes a new full screen. Owner wants the editor to appear as a SwiftUI Sheet (modal bottom-sheet that you can drag-to-dismiss), exercising `UI::Sheet`'s `is_presented` pattern.

Implementation:
- Add `pending_editor_todo_id : Int32?` state in `Voyager.state`.
- Tapping a row OR Add Todo sets the flag and triggers Rerender.
- Todos screen's `build` renders `UI::Sheet` wrapping the editor content when the flag is set.
- The editor's Cancel and Save clear the flag (and Save additionally mutates state).
- This exercises `UI::Sheet`'s `is_presented` + `on_dismiss` callback.

Keep the existing slug-based editor as a fallback in case the Sheet path has any iOS issues — but use the Sheet path as the primary on iOS.

### Deliverable B4 — Deadline → `UI::DatePicker`

Currently the editor's deadline is a `UI::TextField` expecting YYYY-MM-DD. Replace with a `UI::DatePicker` widget that produces a `Date` value.

Implementation:
- Add `UI::DatePicker` to the editor form below the title field.
- Bind its value to a new `Voyager.state.editor_deadline` (a `Time?` field, nilable so "no deadline" stays representable).
- On Save, serialize the Date back to the existing `deadline : String` field as ISO YYYY-MM-DD.
- Exercises `UI::DatePicker`'s native iOS wheel/calendar chrome.

If `UI::DatePicker` doesn't support nilable / clearable state on iOS, add a "Clear" button next to it that resets the editor state.

### Deliverable B5 — "More" overflow → `UI::Popover` OR `UI::ContextMenu`

Add a right-side overflow chrome to expose secondary actions that don't fit on the swipe row. Per-row OR screen-level — pick the natural one:

**Option A (recommended):** screen-level toolbar button "•••" that opens a `UI::Popover` with options: "Sort by deadline", "Hide completed", "Clear all completed". Exercises `UI::Popover` chrome.

**Option B:** per-row long-press → `UI::ContextMenu` with options: Edit / Mark Done / Share / Delete (duplicates the swipe actions but in a different chrome). Less useful UX-wise but exercises `UI::ContextMenu`.

**Owner preference unstated** — implementer picks A unless investigating reveals A is harder. Both ship the same intent (demonstrate one of these chromes).

### Deliverable C — Build + screenshots + hand-test guide update

iOS build commands per the established pattern. Launch with `SIMCTL_CHILD_VOYAGER_ROOT_SLUG=voyager-todos`.

**New screenshots** (commit each, in `docs/initiative-cross-platform-ui/handoff/phase-10-d-polish-screenshots/`):

- `01_drag_handle_visible.png` — todos list showing line.3.horizontal handles on each row
- `02_swipe_left_square_tiles.png` — mid-swipe (best effort) showing tile corner shape
- `03_alert_delete_confirm.png` — Alert dialog showing
- `04_actionsheet_share.png` — ActionSheet showing
- `05_sheet_editor.png` — Sheet-presented editor
- `06_datepicker_deadline.png` — DatePicker exposed
- `07_popover_or_contextmenu.png` — overflow chrome showing

If mid-swipe screenshots are infeasible (per 10D-final agent's note about `simctl io`), document and skip.

Update `phase-10-d-final-handtest.md` to reflect the new polish + extensions. Or write a fresh `phase-10-d-polish-handtest.md` and link from the final guide.

## Hard commit discipline

Per established 10D-final pattern. Commit after every meaningful unit. Standard footer: `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`.

## Acceptance gate

- ✅ Swipe action tiles render with square corners (all 4 corners), Mail-style.
- ✅ Drag handle (line.3.horizontal) visible on every row when `on_move` is wired.
- ✅ Row removal animates over 400-500ms (collapse + height reduction, table easing).
- ✅ Row inset 16pt as `UI::ListView` default; Voyager screen no longer overrides.
- ✅ Delete tile shows Alert confirmation.
- ✅ Share tile shows ActionSheet with Copy / Print / Cancel.
- ✅ Editor opens as Sheet from bottom.
- ✅ Deadline editor uses native DatePicker.
- ✅ Popover OR ContextMenu surfaces somewhere natural.
- ✅ iOS .app launches; all 5 catalog widgets exercise without crash.
- ✅ Screenshots committed.
- ✅ Hand-test guide updated.
- ✅ Lint + build green.

## Out of scope

- iOS home-screen widgets (WidgetKit) — separate phase brief, will be queued.
- Other widget categories (charts, maps, media, drawing, etc.) — separate demo apps, brief deferred.
- HIG validation captures.
- macOS / web / Android parity for the polish.

— Architect (Claude Opus 4.7), 10D-polish brief v1
