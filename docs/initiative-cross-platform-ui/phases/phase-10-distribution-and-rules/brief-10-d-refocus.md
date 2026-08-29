# Phase 10D-refocus — Voyager todos app as the Phase 10 demo

**Branch:** `phase-10-d-refocus` from `phase-10` (post-10D-exerciser merge).
**Status:** v1. Owner-driven refocus after hands-on test of 10D exerciser.

## Context

10D shipped a Phase 10 exerciser hub with 5 isolated demo screens. Owner hand-test feedback: the todo app SHOULD BE the integrated demo of Phase 10's intents, not a separate hub. The exerciser hub was a misframing — refocus around the todos screen with intents wired in naturally.

Plus 4 rendering bugs surfaced during the hand-test that must be fixed.

## Deliverables

### Deliverable 1 — Fix iOS SwipeActionRow tile rendering

**Current state:** On iOS the swipe reveal currently surfaces actions as INLINE BUTTONS in a horizontal stack, not as the iOS-native tile-style action sheet (full-row-height squares that slide out from the edge — the SwiftUI `.swipeActions` modifier behavior).

**Fix:**
- Audit `src/ui/renderers/uikit_renderer.cr` SwipeActionRow visit path (around line 3854 per the 10B.1b audit).
- Verify `make_swipe_reveal_row` actually produces the swipe-to-reveal gesture, not an inline horizontal layout.
- If the existing path produces inline buttons, replace with proper SwiftUI `.swipeActions(edge: .trailing) { ... }` + `.swipeActions(edge: .leading) { ... }` via the SwiftKit facade.
- Tiles should:
  - Fill the row height.
  - Show icon + label.
  - Map destructive role to system red tint.
  - Fire the on_tap callback on tap (currently broken — actions don't fire).

### Deliverable 2 — Enable leading edge swipe

Per the 10B.1b capability audit, `supports_edge_leading` for iOS / iPadOS / macOS is currently declared `false`. That declaration was honest about the renderer not iterating `leading_actions`.

**Fix:**
- In UIKit renderer: add `.swipeActions(edge: .leading) { ... }` emission. Iterate `view.leading_actions`.
- In AppKit renderer: macOS doesn't have native swipe-to-reveal — implement the leading actions as a left-aligned inline tile bar OR mirror iOS via a custom NSGestureRecognizer-backed approach. Pick the simpler honest path.
- Update `UI::SwipeActionRow` `declares_capabilities` to flip `supports_edge_leading` true for the platforms now supporting it.
- Update `docs/initiative-cross-platform-ui/architecture/swipe-actions-capability-audit.md` to reflect.

### Deliverable 3 — Refocus `todos_screen.cr` around Phase 10

Rebuild the existing `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr` as the integrated Phase 10 demo:

1. **Use `UI::Intent.resolve(:swipe_actions, ctx)`** to get the widget class (not direct `UI::SwipeActionRow.new`). Proves the Phase 10B.0 resolver in production use.

2. **Add per-row actions:**
   - Leading (right-swipe): **Archive** (single tile, blue/system tint).
   - Trailing (left-swipe): **Edit** + **Delete** (two tiles, Delete is destructive).
   - Each action fires a real handler (archive moves to archived list; edit opens editor; delete removes from list).

3. **Add "Add Todo" workflow** — floating + button at bottom right OR top-right toolbar button:
   - Tapping opens an editor screen (extend the existing `todo_editor_screen.cr`).
   - Editor has: text field for title, date picker for deadline (optional).
   - On submit, append to todos list.

4. **Add tap-to-edit** — tapping a row opens the editor populated with that todo's data.

5. **Add tap-and-drag reorder** — long-press + drag to reorder rows. Use iOS native list reorder (`onMove` SwiftUI modifier — wire through SwiftKit facade if needed).

### Deliverable 4 — Integrate Class C intents naturally

1. **First-launch notification permission** — when the app loads the todos screen for the first time, dispatch `UI::Intent.dispatch(:request_permission, kind: "notifications")`. Store the result so we don't re-prompt every launch.
2. **"Share Todo" swipe action** — add a third trailing-swipe tile "Share" that fires `UI::Intent.dispatch(:copy_to_clipboard, text: todo.title)` (or `:share_link` if a URL representation makes sense).
3. **"Print List" toolbar button** — top-right Toolbar button that fires `UI::Intent.dispatch(:print, text: formatted_todo_list)`.

### Deliverable 5 — Fix FullScreenCover + Inspector visuals

Hand-test confirmed both render only the title text, not the actual cover/inspector content.

- `src/ui/views/full_screen_cover.cr` + the relevant renderer paths — verify content is actually emitted.
- Same for `src/ui/views/inspector.cr`.
- Add a smoke spec that asserts the body content renders inside the cover/inspector chrome.

### Deliverable 6 — Reframe exerciser hub as developer tools

- Move "Phase 10 Exerciser" link off the primary navigation.
- Put it under Settings → "Developer / Internals".
- Rename the hub to "Phase 10 Internals" or "Phase 10 Developer Tools".
- AX Metadata + Environment + New Widgets screens stay — they're useful for verification but not for end-user UX.

## Constraints

- Forward commits only on `phase-10-d-refocus`.
- Don't break the existing todo state model — `state.cr` carries the todo list.
- iOS class-init gap mitigations from 10D iter 2 stay in place.
- All existing 84 lint-convention specs pass.
- The 2 documented iOS crashes (`accessibility_actions` + `keyboard_shortcut` via SwiftKit populator) remain TODO — don't try to fix those in this slice unless trivial.

## Workflow

1. `git checkout -b phase-10-d-refocus phase-10`.
2. Deliverable 1 first — the SwipeActionRow rendering is the foundation everything else depends on.
3. Deliverable 2 — leading edge swipe.
4. Deliverable 3 — rebuild todos_screen.
5. Deliverable 4 — wire Class C intents.
6. Deliverable 5 — fix FullScreenCover + Inspector.
7. Deliverable 6 — re-nav exerciser hub.
8. Run iOS build + simulator launch. Take screenshots of the refocused todos screen with each action surfaced.
9. Update `phase-10-d-exerciser-handtest.md` with the new test path.
10. Standard `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>` footer on every commit.

## Acceptance

- ✅ Swipe gestures on iOS show full-height tile actions, not inline buttons. Both edges work.
- ✅ Action tap callbacks fire correctly.
- ✅ `todos_screen.cr` resolves swipe widget via `UI::Intent.resolve` (no direct `UI::SwipeActionRow.new`).
- ✅ Add / edit / delete / archive / reorder flows work end-to-end.
- ✅ Class C intents (notification permission, copy, print) fire from todo-app contexts.
- ✅ FullScreenCover + Inspector render content, not just titles.
- ✅ Exerciser hub still reachable, but under Settings → Developer.
- ✅ iOS .app launches + the todos screen exercises the full flow.
- ✅ Hand-test guide updated.
- ✅ Lint + build green.

## Out of scope

- Fixing the SwiftKit populator crashes on `accessibility_actions` + `keyboard_shortcut`.
- macOS / web / Android refocus (iOS first per owner).
- HIG validation captures.
- Codex content review (architect dispatches after close).

— Architect (Claude Opus 4.7), 10D-refocus brief v1
