# Phase 10D-polish — hand-test guide (iOS)

This is the canonical hand-test guide for Phase 10D-polish. It supersedes `phase-10-d-final-handtest.md` for the todos screen behavior.

## What's new vs 10D-final

| What changed | Where |
|---|---|
| **A1.** SwiftUI swipe-tile chrome is full-bleed square-corner (Mail-style) — no rounded button shape | `swift/.../Facades/ListViewFacade.swift:swipeTileLabel` |
| **A2.** `line.3.horizontal` drag handle on every row's trailing edge when `on_move` is wired | `swift/.../Facades/ListViewFacade.swift:baseWithDragHandle` |
| **A3.** Row removal collapses with ~400ms easeInOut animation | `swift/.../Facades/ListViewFacade.swift:.animation + .transition` |
| **A4.** 16pt row inset as a `UI::ListView` default (`.listRowInsets`) | `src/ui/views/list_view.cr:content_inset_horizontal` |
| **B1.** Trailing Delete swipe → `UI::Alert` confirmation (Cancel + Delete destructive) | `screens/todos_screen.cr:225-247` |
| **B2.** Trailing Share swipe → `UI::ActionSheet` (Copy / Print / Cancel) | `screens/todos_screen.cr:249-275` |
| **B3.** Add Todo + Edit row → `UI::Sheet` modal (instead of slug-pushed editor screen) | `screens/todos_screen.cr:277-294` + `build_editor_content` |
| **B4.** Editor sheet's deadline field → native `UI::DatePicker` | `screens/todos_screen.cr:build_editor_content:391-422` |
| **B5.** Header gains `•••` overflow button → `UI::Popover` (Sort by deadline / Hide completed / Clear all completed) | `screens/todos_screen.cr:296-340` |

## Launch the app

Simulator: iPhone 17 Pro, UUID `92DA97A0-5FEC-46BD-A525-8AFE2A4FDC21`.

```bash
SIM=92DA97A0-5FEC-46BD-A525-8AFE2A4FDC21
SIMCTL_CHILD_VOYAGER_ROOT_SLUG=voyager-todos \
  xcrun simctl launch $SIM com.assetpipeline.voyager.VoyagerDemo
```

To rebuild from source:

```bash
cd samples/initiative-cross-platform-ui-voyager/ios
bash build_crystal_lib.sh simulator
xcodegen generate
xcodebuild build -project VoyagerDemo.xcodeproj -scheme VoyagerDemo \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" \
  CODE_SIGNING_ALLOWED=NO
APP=$(find ~/Library/Developer/Xcode/DerivedData/VoyagerDemo-* \
  -name VoyagerDemo.app -path '*/Debug-iphonesimulator/*' | sort -r | head -1)
xcrun simctl uninstall $SIM com.assetpipeline.voyager.VoyagerDemo
xcrun simctl install $SIM "$APP"
SIMCTL_CHILD_VOYAGER_ROOT_SLUG=voyager-todos \
  xcrun simctl launch $SIM com.assetpipeline.voyager.VoyagerDemo
```

## 1. Todos screen — initial render (A1 + A2 + A4)

Dismiss the notification permission alert (tap Allow or Don't Allow — both fine).

**What you should see:**

- "Todos" title (28pt bold) top-left.
- "Print" / "•••" / "Settings" buttons top-right (all `:secondary`).
- "Open" and "Done" count cards.
- Rounded white card with 5 rows: Buy groceries, Finish quarterly report, Call dentist (strikethrough), Read a book, Water plants (strikethrough).
- **Every row has a `≡` (three horizontal lines) icon on its right edge** — this is the `line.3.horizontal` drag handle (A2).
- Rows are flush-aligned to 16pt from the screen edge (A4 — the `UI::ListView` default).
- Hairline separators between rows.
- "Add Todo" prominent button at the bottom.

**Reference:** `phase-10-d-polish-screenshots/01_drag_handle_visible.png`

## 2. Trailing Delete swipe → Alert (B1)

Swipe LEFT on any row. The Delete tile (red) is the leftmost (closest to swipe edge) — full-swipe fires it immediately.

**What you should see:**

- Mid-swipe, the action tiles appear with **full-bleed square corners** (A1) — no rounded button chrome. Order from left to right when fully revealed: Edit (blue), Share (blue), Done (blue), Delete (red).
- Tap Delete (or full-swipe).
- A `UI::Alert` mounts: title `Delete "<todo title>"?`, message `This can't be undone.`, Cancel + Delete buttons.
- Tap Cancel → alert dismisses, row remains.
- Tap Delete → alert dismisses, the row collapses over ~400ms (A3) and disappears.

**Reference:** `phase-10-d-polish-screenshots/03_alert_delete_confirm.png`

## 3. Trailing Share swipe → ActionSheet (B2)

Swipe LEFT on any row, tap the Share tile (square-with-arrow icon).

**What you should see:**

- A `UI::ActionSheet` mounts at the bottom: title `Share "<todo title>"`, message `Choose how to share this todo.`, action buttons Copy to Clipboard / Cancel.
- *Note: ActionSheet currently degrades to binary {primary, cancel} on iOS — Print This Todo button is not shown. Tracked in backlog item `B-ACTIONSHEET-MULTI-ACTION`.*
- Tap Copy to Clipboard → action sheet dismisses, the todo text is in the clipboard.
- Tap Cancel → action sheet dismisses, no mutation.

**Reference:** `phase-10-d-polish-screenshots/04_actionsheet_share.png`

## 4. Editor sheet — Add Todo (B3 + B4)

Tap "Add Todo" at the bottom of the screen.

**What you should see:**

- A `UI::Sheet` slides up from the bottom with medium detent.
- Drag-handle bar at the top.
- "New todo" header (Primary role).
- Title TextField (empty, focusable).
- Note TextField (placeholder "Note (optional)").
- "Deadline" label + native `UI::DatePicker` showing today's date (compact field — tap to expand calendar).
- "No deadline" button (secondary) for clearing the deadline.
- Completed toggle (off).
- Cancel / Save row (Save disabled until title is non-empty).
- Drag the sheet down → it dismisses, returning to the todos list.
- Type a title → Save enables.
- Tap Save → sheet dismisses, new row appears in the list.

**Reference:** `phase-10-d-polish-screenshots/05_sheet_editor_new.png`

## 5. Editor sheet — Edit row (B3 + B4)

Tap any existing row (not the swipe edges).

**What you should see:**

- Same sheet chrome as above but with "Edit todo" header and the row's data pre-filled.
- If the editing target is completed, the header has strikethrough + Secondary role.
- DatePicker shows the parsed deadline (or today if empty).

*Note: The DatePicker currently displays the year as ~3995 due to a Crystal-to-Swift epoch conversion bug. The day-of-week and month are correct; only the year is offset. Tracked in backlog item `B-DATEPICKER-EPOCH-CONVERSION`.*

**Reference:** `phase-10-d-polish-screenshots/06_datepicker_deadline.png`

## 6. Overflow menu → Popover (B5)

Tap the "•••" button in the header.

**What you should see:**

- A `UI::Popover` mounts. On iPhone, SwiftUI falls back to a sheet-like overlay (per `popovers.md` HIG note — iPhone has no popover affordance, so the system substitutes a sheet). Content: VStack with three buttons:
  - "Sort by deadline" (blue, secondary)
  - "Hide completed" or "Show completed" (blue, secondary; label reflects current state)
  - "Clear all completed" (red, destructive)
- Tap any option → action fires, popover dismisses, list reflects the change:
  - Sort by deadline: rows reorder by ISO date ascending (empty deadlines sink).
  - Hide completed: completed rows hidden from the list (also reflected in the Done count).
  - Clear all completed: completed rows mutated out of the underlying todo array.
- Tap outside (swipe-down on iPhone) → popover dismisses without action.

**Reference:** `phase-10-d-polish-screenshots/07_popover_overflow.png`

## 7. Drag-reorder (A2 confirmation)

Long-press on any row's drag handle (the `≡` on the right edge), then drag up or down.

**What you should see:**

- Row lifts visually (SwiftUI's drag-elevation chrome).
- Drop it on another row's position → rows reorder; the list updates immediately.
- Releasing → SwiftUI fires `.onMove(perform:)`; Crystal dispatches `:move_row` with the absolute indexes; state mutation persists across rerenders.

(No dedicated screenshot for the drag motion — `simctl io screenshot` cannot capture mid-gesture state.)

## Known issues (Phase 10D-polish)

| Issue | Tracked in |
|-------|------------|
| DatePicker year display shows ~3995 instead of current year | backlog `B-DATEPICKER-EPOCH-CONVERSION` |
| ActionSheet shows only first non-cancel action + cancel (drops middle actions) | backlog `B-ACTIONSHEET-MULTI-ACTION` |
| iPhone Popover falls back to full-screen overlay (SwiftUI default — `presentationCompactAdaptation(.popover)` not exposed) | backlog `B-POPOVER-COMPACT-ADAPTATION` |
| macOS does not yet honor drag handle / removal animation / 16pt inset | backlog `B-LIST-MACOS-CHROME` |
| Web does not honor swipe-action / drag / removal animation chrome | (existing — outside Phase 10D-polish scope) |
| `UI::SwipeAction` has no per-action tint override (tints derive from role) | backlog `B-LIST-SWIPE-TINT` |

Full backlog: `docs/initiative-cross-platform-ui/architecture/intent-backlog.md` (Phase 10D-polish section).

## Capture scenarios

Five capture scenarios are wired for screenshot automation. Each pre-seeds the relevant state flag so the modal renders on first frame:

```bash
SIM=92DA97A0-5FEC-46BD-A525-8AFE2A4FDC21
SIMCTL_CHILD_VOYAGER_ROOT_SLUG=voyager-todos \
SIMCTL_CHILD_VOYAGER_SKIP_NOTIF_PROMPT=1 \
SIMCTL_CHILD_VOYAGER_CAPTURE_SCENARIO=polish-01-delete-alert \
  xcrun simctl launch $SIM com.assetpipeline.voyager.VoyagerDemo
```

| Scenario id | Renders |
|---|---|
| `polish-01-delete-alert` | Alert with first todo selected |
| `polish-02-share-actionsheet` | ActionSheet for first todo |
| `polish-03-editor-sheet-new` | Sheet with empty editor (new draft) |
| `polish-04-editor-sheet-edit` | Sheet with first todo loaded |
| `polish-05-overflow-popover` | Popover with overflow menu |

Source: `samples/initiative-cross-platform-ui-voyager/capture_scenarios.cr:60-110`.

## What to do if something breaks

- Crash on launch → check `~/Library/Logs/DiagnosticReports/VoyagerDemo-*.ips` for the last crash.
- iOS class-init gap suspicion (`Time::Location.find_zoneinfo_file`, `Crystal::once`) → use `Time.utc` / static constants instead of `Time.local` / `@@class_var = ...`. See `[[crystal-ios-class-init-gap]]` memory.
- Stale build cached → wipe `~/Library/Developer/Xcode/DerivedData/VoyagerDemo-*` and rebuild.

— Implementer (Claude Opus 4.7), Phase 10D-polish handoff 2026-05-27.
