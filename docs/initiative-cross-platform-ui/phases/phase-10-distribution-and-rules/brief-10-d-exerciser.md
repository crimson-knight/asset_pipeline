# Phase 10D — Voyager Phase-10 intent exerciser (iOS hands-on)

**Branch:** `phase-10-d-exerciser` from `phase-10` (tag `phase-10-complete-2026-05-26`).
**Status:** v1. Final Phase 10 sub-phase — owner hands-on test gate.

## Context

13 of 14 Phase 10 sub-phases shipped. None of Voyager's existing screens exercise Phase 10's new APIs. 10D adds a Phase 10 exerciser screen (or screens) to Voyager so the owner can hand-test each new API on a real device / simulator.

This is the FINAL phase 10 sub-phase. After this lands and owner verifies, Phase 10 is closed.

## Deliverables

### Deliverable 1 — Phase 10 exerciser screens

Add new screens to `samples/initiative-cross-platform-ui-voyager/screens/phase_10/`:

1. **`intent_resolver_screen.cr`** — demonstrates `UI::Intent.resolve(:swipe_actions, ctx)`:
   - Uses the resolver-returned widget class (so on iOS this renders SwipeActionRow; on Mac it would be InlineActionRow).
   - 3 rows with a mix of default + destructive actions.
   - Comment in the rendered screen titled "this row came from UI::Intent.resolve" so the tester can verify.

2. **`class_c_dispatch_screen.cr`** — buttons that fire Class C intents:
   - Copy "Hello, asset_pipeline!" to clipboard.
   - Paste from clipboard.
   - Open URL `https://example.com`.
   - Print a simple PDF (UIPrintInteractionController).
   - Request notification permission.
   - Each button shows a result label with the `DispatchResult` (Success / Unsupported / Failed).

3. **`ax_metadata_screen.cr`** — widgets carrying the new AX properties:
   - A Label with `accessibility_hint = "Tap for more"` and `accessibility_value = "42"`.
   - A Button with `accessibility_actions = [UI::AccessibilityAction.new("Refresh") { ... }]` (testable with VoiceOver rotor).
   - A Button with `keyboard_shortcut = UI::KeyboardShortcut.new("S", modifiers: [:command])` (testable with external keyboard).
   - A TextField with `accessibility_traits = [:not_enabled]` (verify it's disabled).

4. **`environment_reactivity_screen.cr`** — shows `UI::Environment` reactivity:
   - A Snackbar that auto-dismisses with the env-aware duration.
   - Header text showing current env state ("reduce_motion: false" / etc.).
   - Note: changing the env requires changing the Simulator's Accessibility settings (Reduce Motion).

5. **`new_widgets_screen.cr`** — demonstrates the new widgets:
   - `UI::FullScreenCover` — toggle to show/hide.
   - `UI::Inspector` — side panel with content.
   - `UI::ToolbarItemGroup` + `UI::ToolbarSpacer` — a toolbar at top.

### Deliverable 2 — Voyager app registration

Update `samples/initiative-cross-platform-ui-voyager/app.cr` to register the 5 new screens as routes. Add them to the navigation so they're reachable from a Phase 10 menu / hub screen.

Create a hub screen `screens/phase_10_hub_screen.cr` with NavigationLink buttons to each exerciser.

### Deliverable 3 — iOS build verification

- Run `samples/initiative-cross-platform-ui-voyager/ios/build_crystal_lib.sh` — must produce `libvoyager.a`.
- Run xcodegen + xcodebuild via `make` in the iOS directory — must produce the .app.
- Launch on iOS simulator (use `xcrun simctl boot` + `xcrun simctl install` + `xcrun simctl launch`).
- Verify each exerciser screen renders without crash.

### Deliverable 4 — Hand-test guide

`docs/initiative-cross-platform-ui/handoff/phase-10-d-exerciser-handtest.md` with:
- How to launch the simulator + app.
- Per-screen checklist of what to look at + what behavior validates the API.
- Known limitations / what NOT to expect.
- Sample VoiceOver / accessibility verifications.

## Constraints

- Forward commits only on `phase-10-d-exerciser`.
- Don't break Voyager's existing screens (todos, settings, sign_in, todo_editor).
- The exerciser screens are FOR DEMO PURPOSES — they don't need to be production-quality UX. Functional clarity > polish.
- All existing lint rules must remain green (Family 1 naming, etc.). New screens MUST end in `_screen.cr` and class names MUST end in `Screen` (Family 1).
- `[[codex-as-architect-antagonist]]` applies.
- `[[owner-hands-on-finds-real-bugs]]` — the goal is for the owner to actually find issues by tapping through.

## Workflow

1. `git checkout -b phase-10-d-exerciser phase-10`.
2. Build the 5 exerciser screens. After each: lint must remain green.
3. Build the hub screen + register routes.
4. Run iOS build path. Fix any compile errors. Document any blockers.
5. Launch on simulator. Take screenshots. Note any visual / runtime issues.
6. Write hand-test guide.
7. Standard `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>` footer on every commit.

## Acceptance

- ✅ 5 exerciser screens + 1 hub screen exist + registered in Voyager.
- ✅ Each screen demonstrates a distinct Phase 10 API surface.
- ✅ iOS simulator build produces a launchable .app.
- ✅ Each screen renders without crash on the simulator.
- ✅ Hand-test guide ships.
- ✅ `crystal run scripts/lint_conventions.cr` green (now ~488+ files).
- ✅ `crystal spec spec/web/` baseline preserved.

## Out of scope

- Production-quality UX polish.
- HIG validation captures.
- macOS / web / Android exerciser variants (iOS first per owner request; the screens are cross-platform but only iOS is hand-tested for now).
- Codex content review (architect dispatches after close).

— Architect (Claude Opus 4.7), 10D exerciser brief v1
