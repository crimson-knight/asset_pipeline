# Phase 10D-final — hand-test guide (iOS)

This is the canonical hand-test guide for Phase 10D-final. It replaces `phase-10-d-refocus-handtest.md`. The todos screen IS the integrated Phase 10 demo — exercise the new APIs by using the app.

## What's new vs 10D-refocus

| What changed | Where |
|---|---|
| `UI::Intent` → `UI::WidgetRoute` + `UI::SystemAction` rename | All internal call sites (D1) |
| Per-row swipe actions live on `UI::ListView` (not `UI::SwipeActionRow`) | `src/ui/views/list_view.cr` (D3.1), `src/ui/renderers/uikit_renderer.cr` (D3.5) |
| Per-row whole-row tap, leading swipe, trailing swipe, drag-reorder | New `UI::ListView` callbacks: `on_row_tap`, `on_move`, `leading_swipe_actions`, `trailing_swipe_actions` (D3) |
| Mail-app row visual: plain Label rows, no checkbox / borderless-button wrap | `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr` (D4) |
| Trailing swipe order: `[Delete, Done, Share, Edit]` — full-swipe fires Delete | D4 |
| Mark Done button + completion-styled header on the detail screen | `screens/todo_editor_screen.cr` + `controllers/todo_editor_controller.cr` (D5) |
| Subtitle humanization ("Due Today", "Due Tomorrow", "Due Mon Jun 1") | `humanize_deadline` in todos_screen.cr (D6) |

## Launch the app

Simulator: iPhone 17 Pro, UUID `92DA97A0-5FEC-46BD-A525-8AFE2A4FDC21`.

If the prior install is still on the device, just launch:

```bash
SIM=92DA97A0-5FEC-46BD-A525-8AFE2A4FDC21
SIMCTL_CHILD_VOYAGER_ROOT_SLUG=voyager-todos \
  xcrun simctl launch $SIM com.assetpipeline.voyager.VoyagerDemo
```

If the install is stale (binary older than `2026-05-27 16:50`), rebuild and reinstall:

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

**Important:** if the build seems cached and you're seeing the old UI (Toggle switches in row labels), wipe `~/Library/Developer/Xcode/DerivedData/VoyagerDemo-*` and rebuild. xcodebuild's dependency tracking doesn't always see `libvoyager.a` changes.

## First launch: notification permission alert

On a fresh install, iOS shows a system permission alert ("VoyagerDemo Would Like to Send You Notifications") on the first cold launch. The alert is fired by the screen's first-launch `UI::SystemAction.perform(:request_permission, kind: "notifications")` dispatch.

- **What to do:** tap Allow OR Don't Allow — both are fine. The app must not crash on either choice.
- **What it validates:** the Class C `:request_permission` binding's iOS path through `UNUserNotificationCenter.requestAuthorizationWithOptions`.
- **Why we don't dismiss it programmatically:** iOS system modals can't be reliably dismissed from `xcrun simctl`. The `SIMCTL_CHILD_VOYAGER_SKIP_NOTIF_PROMPT=1` env var skips the dispatch entirely for capture flows; for owner hand-testing, just respond manually once and the alert won't re-appear (process-level guard).
- **If the alert reappears every launch:** the `@@requested_notification_permission` class-var guard isn't holding. File a bug.

## 1. Todos screen — initial render

After dismissing the permission alert, the todos screen renders.

**What you should see:**

- "Todos" title (28pt bold) in the top-left.
- "Print" + "Settings" buttons in the top-right (both `:secondary` role).
- Two count cards: "Open" (3) and "Done" (2). The Done count is dimmed if Settings → Hide Completed is on (default off).
- A rounded white card (SwiftUI insetGrouped list style) containing five rows:
  1. **Buy groceries** — open, Primary role (full opacity), no strikethrough.
  2. **Finish quarterly report** — open, Primary role.
  3. **Call dentist** — completed, Secondary role + strikethrough.
  4. **Read a book** — open, Primary role.
  5. **Water plants** — completed, Secondary role + strikethrough.
- Hairline separators between each row (SwiftUI default insetGrouped chrome).
- "Add Todo" Prominent button at the bottom.

**Reference screenshot:** `phase-10-d-final-screenshots/02_after_row_rebuild_plain.png`

**What you should NOT see:**
- Toggle switches in the rows (those were the old Checkbox-based chrome from 10D-refocus; D4 removed them entirely).
- Borderless-button styling on the title labels.
- A "Print" button only — the rename from `UI::Intent` → `UI::WidgetRoute` + `UI::SystemAction` is internal-only; the toolbar UI is identical to 10D-refocus.

## 2. Whole-row tap → editor

Tap anywhere on a row (the row text area, not the swipe edges).

- **What you should see:** the editor screen mounts with the tapped todo's data populated.
- **What it validates:** the new `UI::ListView.on_row_tap : Proc(Int32, Nil)` callback (D3.1) firing through CallbackBridge to the Crystal dispatcher's `:edit_row` action.
- **Reference screenshot for an open todo:** `phase-10-d-final-screenshots/06b_detail_screen_open_todo.png` (tap "Read a book" — Mark Done button visible).

## 3. Editor screen — Mark Done + completion styling (D5)

The editor renders with these elements:

- **Header:** "Edit todo" — strikethrough + Secondary role if the editing target is completed, otherwise no strikethrough and Primary role.
- **Title field:** populated with the todo's title.
- **Note field:** populated with the todo's note (or "Note (optional)" placeholder if empty).
- **Deadline field:** populated with the todo's deadline (YYYY-MM-DD), or empty.
- **Completed Toggle:** reflects the current completed state.
- **Mark Done button:** ONLY visible when editing an existing todo (not a new draft). Label flips between "Mark Done" and "Mark as Not Done" based on the current completed state.
- **Cancel + Save buttons:** Save is disabled when title is blank.

**Reference screenshots:**
- `06_detail_screen.png` — editor for a completed todo ("Call dentist"), strikethrough header + "Mark as Not Done" button visible.
- `06b_detail_screen_open_todo.png` — editor for an open todo ("Read a book"), header no strikethrough + "Mark Done" button visible.

**Test:** tap Mark Done. The todo's completed flag flips, the editor pops back to the list, and the row's strikethrough state matches the new value.

## 4. Trailing-edge swipe (right-to-left) — the Mail-app reveal

Swipe a row from right to left (slowly, with your finger / trackpad).

- **What you should see:** four full-row-height tinted tiles slide out from the right edge. **Visual left-to-right order when fully revealed: `[Edit, Share, Done, Delete]`** with Delete on the outermost (rightmost) edge in destructive red.
- **What it validates:** the new `UI::ListView.trailing_swipe_actions : Proc(Int32, Array(UI::SwipeAction))` callback (D3.1) building tiles through the per-row flat-arrays in `ListViewOverrides.swift` + SwiftUI `.swipeActions(edge: .trailing, allowsFullSwipe: true)` modifier in `ListViewFacade.swift`.

**Continue the swipe past the row's full width:** SwiftUI commits the full-swipe and fires the FIRST action in the array (Crystal-side `[Delete, Done, Share, Edit]`), which means **full-swipe deletes the row**. The Delete tile is the visually-rightmost AND the full-swipe-primary by design — `.swipeActions` renders in array-declaration order, so SwiftUI iterates `Delete, Done, Share, Edit` placing the first action at the outermost edge.

**Tap any tile** (without full-swipe):
- **Delete** — removes the todo from `state.visible_todos`. The list re-renders without that row.
- **Done** — toggles the todo's completed flag. The row's strikethrough state flips.
- **Share** — fires the Class C `:copy_to_clipboard` system action (formatted as "todo: <title>").
- **Edit** — navigates to the editor screen with that todo's data.

## 5. Leading-edge swipe (left-to-right) — Archive

Swipe a row from left to right.

- **What you should see:** a single full-row-height tile slides out from the left edge: **Archive** (system green).
- **What it validates:** `leading_swipe_actions` returning a single `UI::SwipeAction.new("Archive", icon: "archivebox")`.

**Tap Archive:** the todo's `archived` flag is set; `state.visible_todos` filters archived rows out, so the row disappears.

**Continue the swipe past the row's full width:** SwiftUI commits full-swipe on the Archive tile (the only action in the leading array).

## 6. Drag-reorder (D3 + D4)

Long-press on a row title until the row lifts visually (iOS 15+ list reorder gesture).

- **What you should see:** the row lifts above the list and follows your finger. Other rows shift to make space.
- **Drop it on a new position:** the row settles into the new position.
- **What it validates:** the new `UI::ListView.on_move : Proc(Int32, Int32, Nil)` callback (D3.1) wired through SwiftUI's `.onMove(perform:)` modifier on the inner `ForEach` (D3.3). The Crystal side reads `"from=N,to=M"` via the string-channel callback and forwards to `state.move_todo(from, to)`.

**Drag-reorder is iOS 15+; macOS uses a different mechanism (not exercised here).**

## 7. Subtitle humanization (D6)

The seed todos all have empty deadlines, so no subtitles render on the default state. To verify:

1. Tap a row → editor opens.
2. Type a date into the Deadline field. Try:
   - Today's date (e.g. `2026-05-27` if today is 27 May 2026) → row subtitle should read "Due Today".
   - Tomorrow's date → "Due Tomorrow".
   - A future date → "Due Mon Jun 1" style (using `%a %b %-d`).
   - A non-date string (e.g. "next week") → passes through as "Due next week".
   - Empty → no subtitle.

## 8. Print button — `:print` Class C dispatch

Tap "Print" in the top-right.

- **What you should see:** the iOS print preview sheet with the formatted todo list. AirPrint or Cancel.
- **What it validates:** `UI::SystemAction.perform(:print, text: ...)` (renamed from `UI::Intent.dispatch` in D1) firing UIPrintInteractionController.

## 9. Settings button

Tap "Settings".

- **What you should see:** the settings screen with a "Hide completed" Toggle (and an "Archived" section header for future use).
- **What it validates:** standard `:open_settings` navigation; the screen-tier UI is unchanged from 10D-refocus.

---

## Known limitations

1. **Screenshot-capture flow can't dismiss the permission alert.** The brief explicitly says "leave it alone." The owner dismisses manually on first cold launch; subsequent launches skip the prompt because the OS-level grant decision is persisted.

2. **Mid-swipe screenshots are infeasible.** `xcrun simctl io` has no swipe primitive, and `cliclick` mouse-drag doesn't generate the touch-velocity SwiftUI requires for `.swipeActions` reveals. The reveal-then-tap flow IS verifiable by hand; programmatic capture of the revealed-tile state is not.

3. **Drag-reorder screenshot is infeasible** for the same reason: long-press-drag isn't reproducible from cliclick.

4. **macOS rendering deferred.** Phase 10D-final's per-row swipe + tap + drag wiring lives in `uikit_renderer.cr` only. The AppKit renderer's `visit(UI::ListView)` is unchanged — macOS uses `UI::InlineActionRow` (inline buttons) per the existing intent registry routing.

5. **`xcodebuild` dependency tracking misses `libvoyager.a` changes.** After a Crystal rebuild, `touch Sources/VoyagerApp.swift` then `xcodebuild build` to force a relink. Or `rm -rf ~/Library/Developer/Xcode/DerivedData/VoyagerDemo-*` for a clean rebuild.

## What to report

Per `[[owner-hands-on-finds-real-bugs]]`: the hand-test is the gate. If anything in section 1-9 doesn't match the expected behavior, file specific bug reports with screenshot + repro steps. The audit harness has not been re-run against the new D3 `UI::ListView` per-row swipe path — the implementer build verified compile + lint cleanliness + the 02/05/06/06b screenshots, but the hand-test exercises behaviors the harness doesn't cover (touch gestures, full-swipe commits, mid-render state transitions).
