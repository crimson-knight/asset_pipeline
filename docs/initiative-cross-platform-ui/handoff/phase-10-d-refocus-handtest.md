# Phase 10D-refocus — hand-test guide (iOS)

This replaces the earlier `phase-10-d-exerciser-handtest.md`. After the refocus, the **todos screen IS the integrated Phase 10 demo** — you exercise the new APIs by using the app, not by visiting a separate exerciser hub.

## App is already running

- Simulator: iPhone 17 Pro, UUID `A517D070-5008-4577-B7B0-B6914D11B391`
- App: `com.assetpipeline.voyager.VoyagerDemo`
- Launched with `VOYAGER_ROOT_SLUG=voyager-todos` so you land directly on the todos screen (skipping sign-in).

If the simulator went to sleep, re-launch with:

```bash
SIMCTL_CHILD_VOYAGER_ROOT_SLUG=voyager-todos \
  xcrun simctl launch A517D070-5008-4577-B7B0-B6914D11B391 \
    com.assetpipeline.voyager.VoyagerDemo
```

---

## What to test, in order

### 1. First-launch notification permission

**On first launch (already happened in the current session):** a system alert appears asking permission for notifications.

- **What it validates:** `UI::Intent.dispatch(:request_permission, kind: "notifications")` Class C bridge firing into UNUserNotificationCenter at the right lifecycle moment.
- **What you should see:** a standard iOS "VoyagerDemo Would Like to Send You Notifications" alert with Allow / Don't Allow.
- **Action:** tap Allow (or Don't Allow — either is fine). The app should not crash on either.
- **Known limitation:** guard is process-level. If you re-launch the app, the alert won't reappear unless you erase the simulator's settings for the bundle.

### 2. Todos screen header

**What you should see:** "Todos" title, "Open" / "Done" count cards, "Print" + "Settings" buttons in the top-right.

- **Open count card** shows the number of open todos.
- **Done count card** shows the number of completed todos.
- **Print button** (top-right): tap it.
  - **What it validates:** `UI::Intent.dispatch(:print, text: ...)` Class C bridge firing into UIPrintInteractionController.
  - **What you should see:** the system print preview sheet with the formatted todo list. Cancel or AirPrint — either works.

### 3. Swipe gestures on a row (THE big rendering fix)

This is the critical fix from your hand-test feedback. The previous build rendered swipe actions as inline buttons; this build uses SwiftUI's `.swipeActions(edge:)` modifier via the new `APSKSwipeActionRowFacade`.

**Swipe a row to the LEFT (trailing edge):**
- **What you should see:** three full-row-height square-ish tinted tiles slide out from the right edge: Edit (system tint), Share (system tint), Delete (red / destructive role).
- **NOT what you should see:** inline horizontal button stack like before. If you see inline buttons, the SwiftKit facade integration didn't take effect — report that.

**Swipe a row to the RIGHT (leading edge):**
- **What you should see:** one full-row-height square tile slides out from the left edge: Archive.
- **NOT what you should see:** no swipe response at all, OR the row scrolling past the screen edge. If either, the leading-edge `.swipeActions` wiring didn't activate.

**Tap each tile:**
- **Edit tile:** should navigate to the todo editor with the row's data populated.
- **Share tile:** fires `UI::Intent.dispatch(:copy_to_clipboard, text: <todo title>)`. The clipboard now contains the title. You can verify by long-pressing a text field elsewhere and choosing Paste.
- **Delete tile:** removes the row from the list. Re-rendering should drop it from the visible stack.
- **Archive tile:** removes the row from the visible list AND moves it to the archive state (state model has an archive list per `state.cr`).
- **What it validates:** the callback tokens registered via `UI::CallbackRegistry` flow correctly through the SwiftUI Button `action: { ... }` block into the Crystal-side `SwipeAction#on_tap` proc. Previously this was broken (you confirmed callbacks didn't fire).

### 4. Tap-to-edit (whole-row tap)

**Action:** tap a row's title text (not the checkbox, not a swipe tile).
- **What you should see:** navigation to the todo editor with the tapped row's data prefilled.
- **What it validates:** the `tap_btn` borderless Button wrapping the title area fires `Voyager.dispatch(:edit_row, ...)`.

### 5. Add Todo workflow

**Action:** scroll to the bottom of the todos screen. Tap "Add Todo".
- **What you should see:** the todo editor opens with empty fields.
- **Editor fields:** Title (TextField), Note (TextField), **Deadline (TextField, NOT a native DatePicker)**.
- **Known limitation:** the deadline is a plain text field expecting `YYYY-MM-DD`. A native `UI::DatePicker` bridge for cross-platform deadline entry is a deferred follow-up. The text field is documented in the editor screen code (line 83-87 of `todo_editor_screen.cr`).
- **Action:** enter a title (e.g. "Test todo"), optionally a deadline (e.g. "2026-06-01"), tap Save.
- **What you should see:** the editor closes; the new todo appears in the list on the todos screen.

### 6. Toggle complete

**Action:** tap the checkbox on a row.
- **What you should see:** the checkbox toggles. The title gets strikethrough when completed. The Done count card increments.

### 7. Hide-completed filter

**Action:** tap Settings → toggle "Hide completed".
- **What you should see:** completed rows disappear from the list. A banner appears: "Completed items hidden (toggle in Settings)". The Done count card dims.

### 8. Phase 10 Developer Tools (re-nav'd exerciser)

The original exerciser hub is now reframed as a developer / verification tool, reachable from Settings rather than the primary navigation.

**Action:** Settings → scroll down to "Developer / Internals" section → tap "Phase 10 Developer Tools".
- **What you should see:** the original Phase 10 hub with 5 screens: Intent Resolver, Class C Dispatch, AX Metadata, Environment, New Widgets.
- These remain useful for verifying individual Phase 10 API surfaces in isolation. They are NOT the primary demo of the phase — the todos screen is.

### 9. FullScreenCover + Inspector (visual fixes)

**Action:** Settings → Developer Tools → New Widgets.
- **What you should see (this is the fix):** the FullScreenCover toggle, when tapped, should now show actual cover content (a label + button), not just a title. Same for Inspector — tapping "Show Inspector" should reveal a side panel with content, not an empty box.
- **What it validates:** the smoke spec `full_screen_cover_inspector_body_smoke_spec.cr` asserts the body content gets emitted through the renderer; the visual confirmation is your eyes here.

---

## What is NOT shipped (deferred follow-ups)

These were in the refocus brief but explicitly deferred. Don't expect them:

1. **Tap-and-drag to reorder rows.** Wired in `move_row` controller action but the iOS gesture-recognizer + visual drag affordance isn't shipped yet. Reordering happens only programmatically.
2. **Native DatePicker for deadlines.** Plain text field shipped instead. Native bridge is a follow-up.
3. **`accessibility_actions` + `keyboard_shortcut` on iOS.** Still crash via the SwiftKit populator (pre-existing 10D bug). The AX Metadata screen has these commented out with TODO markers. macOS host honors both correctly.

---

## If something doesn't match the description

The most likely failure modes, in order of probability:

1. **Swipe still shows inline buttons, not tiles.** → SwiftKit facade integration failed at runtime. Report this; I'll need to dig into `LibSwiftKitBridge.apsk_make_swipe_action_row` linking.
2. **Swipe tile tap does nothing.** → Callback token registration broken. Report.
3. **App crashes on launch.** → Class init gap regression. Report the crash log from Console.app.
4. **FullScreenCover / Inspector still show only title.** → Renderer fix didn't actually take effect. Report.

Send me a screenshot + a one-sentence description of what you saw vs. what the guide said. I'll dig in.

---

## Commit checkpoint

The work above is committed on `phase-10-d-refocus`:

```
a3915f0e [10D-refocus] First post-build iOS launch — sign-in + notification alert
1bff3c8f [10D-refocus] Fix audit spec to match flipped iOS leading capability
787db4d9 [10D-refocus] Allowlist FullScreenCover+Inspector smoke spec
57bea1b0 [10D-refocus checkpoint] Preserve prior agent's work
5744e099 [Phase 10D-refocus] Brief — Voyager todos app as the integrated Phase 10 demo
```

The `57bea1b0` checkpoint recovered the prior (dead) agent's work, which included the `todos_screen.cr` rebuild + SwiftKit `SwipeActionRowFacade.swift` + the FullScreenCover/Inspector smoke spec + state model updates + supporting bridge changes.

The current build was launched on the simulator from this state. After your hand-test, if everything checks out, I'll merge `phase-10-d-refocus` into `phase-10` and tag `phase-10-d-pass-2026-05-27`. If gaps remain, I'll dispatch a remediation iter.

— Architect (Claude Opus 4.7), 10D-refocus hand-test guide
