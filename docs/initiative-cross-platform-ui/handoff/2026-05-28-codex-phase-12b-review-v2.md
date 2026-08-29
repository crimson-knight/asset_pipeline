# Codex Phase 12.B Review v2

**Verdict: NEEDS_WORK**

The `simctl io touch tap` hallucination is fixed in the Crystal harness itself, and `cliclick c:<x>,<y>` is the right class of primitive for delivering a host OS click into the Simulator window. But Phase 12.B is not ready: the V1 spec still drives the wrong product path, the V2 spec waits on a marker the merged anchored-popover implementation never emits, the authoritative harness docs still describe the fake `simctl io touch tap` path, and the Sheet teardown probe is not a reliable intentional-vs-rerender discriminator.

## FINDING 1 — BLOCKER — V1 still taps the editor path, not the Share action sheet

`spec/native_ios/ui_interaction/confirmation_dialog_spec.cr` drives V1 with:

- `sim.tap_accessibility_id("voyager-todo-row-1-tap")`
- wait for `[APIC:ConfirmationDialog:present]`

That is still not the Share path. In the merged Voyager screen, whole-row tap dispatches `:edit_row`:

- `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:156-162`
- `samples/initiative-cross-platform-ui-voyager/controllers/todos_controller.cr:67-75`

The Share action is a trailing swipe action:

- `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:192-218`
- `samples/initiative-cross-platform-ui-voyager/controllers/todos_controller.cr:172-181`

The scenario file even labels `voyager-todo-row-1-tap` as "opens editor sheet" (`spec/native_ios/ui_interaction/scenarios/voyager.yml:65-69`). So the spec will either time out waiting for ConfirmationDialog markers or, worse, pass later only because coordinates drifted into a different target. Single-tap-on-row is not equivalent to the swipe-Share gesture. Phase 12.B needs either real multi-step swipe capture for the Share tile or a deliberate test-only Share trigger that is clearly not claimed to reproduce the production gesture.

## FINDING 2 — BLOCKER — V2's anchored popover bypasses Popover APIC markers

The merged `PopoverFacade` has two paths:

- Anchored UIKit path: returns `AnchoredPopoverHost` immediately when `overrides.anchorSourceView` is present (`swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/PopoverFacade.swift:31-45`).
- SwiftUI `.popover` path: creates `BoolStorage`, sets `markerWidget = "Popover"`, and emits `[APIC:Popover:present]` (`PopoverFacade.swift:48-59`).

Voyager explicitly uses the anchored path:

- `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:349-360`
- `src/ui/renderers/uikit_renderer.cr:1931-1943`

But `spec/native_ios/ui_interaction/voyager_toolbar_spec.cr` waits for `[APIC:Popover:present]` after tapping `voyager-todos-overflow`. That marker is never emitted by the actual anchored-popover path. This is a semantic merge conflict that git could not catch: polish added the anchored branch, marker instrumentation stayed on the non-anchored branch. The V2 positive tap assertion is therefore not wired to the code it is supposed to verify.

## FINDING 3 — BLOCKER — Specs are still globally pended by placeholder coordinates

Every coordinate in `spec/native_ios/ui_interaction/scenarios/voyager.yml` is still `captured: false`, and `captured_pose_sha` is null. Both V1 and V2 gate execution on:

```crystal
coordinates_captured = scenario_yaml.includes?("captured: true")
pending!(pending_reason) unless coordinates_captured
```

See `confirmation_dialog_spec.cr:37-46` and `voyager_toolbar_spec.cr:46-56`.

That means Phase 12.B HEAD does not deliver executable V1/V2 specs. There is also a latent bug: once any single coordinate flips to `captured: true`, the specs will run using all remaining placeholder coordinates. The gate must validate the specific IDs used by each example, not grep the whole YAML for one true value.

## FINDING 4 — BLOCKER — The authoritative harness doc still documents the fake simctl tap command

`spec/native_ios/ui_interaction/support/simulator_harness.cr` now calls `cliclick c:<x>,<y>`, which matches the host-pixel capture primitive. However, `docs/initiative-cross-platform-ui/architecture/interaction-contracts-harness.md` still repeatedly says the harness drives taps through `xcrun simctl io <udid> touch tap <x>,<y>`:

- line 25
- line 30
- line 103
- line 115
- line 120

`scripts/capture_tap_coordinates.sh:22-25` is also stale: it says Phase 12.B replaces this with `APSKAccessibilityTap.tap(id:)`, which contradicts the current reframe.

This matters because the doc is marked authoritative, and this session already lost time to the fake simctl subcommand. Keep the current implementation's `cliclick c` path, and update the docs to say XCUITest frame lookup is a possible future lookup layer only; tap delivery remains host OS click unless proven otherwise.

## FINDING 5 — BLOCKER — Sheet `apicIntentionalDismiss` is not a reliable teardown discriminator

The Sheet host probe reads `state.apicIntentionalDismiss` in the sheet content's `.onDisappear`, emits `host-disappeared intentional=...`, then resets it (`SheetFacade.swift:189-198`). The flag is set inside `.sheet(... onDismiss:)` (`SheetFacade.swift:205-224`).

That depends on `onDismiss` running before the presented content's `onDisappear`. That ordering is not established by this code, and the usual SwiftUI mental model is that content disappears as part of dismissal, while `onDismiss` is the post-dismiss callback. If `onDisappear` runs first, the probe emits `intentional=false` for a legitimate dismiss and then `onDismiss` leaves the flag true afterward.

The actual Voyager editor cancel path makes this worse: the Cancel button dispatches `:close_editor_sheet` (`todos_screen.cr:511-517`), and the controller clears `pending_editor_todo_id` (`todos_controller.cr:219-221`). On the next render, the `UI::Sheet` is removed from the tree; it does not call `sheet.is_presented = false` on the existing Sheet instance. So this "intentional" user action can look exactly like rerender teardown to the current probe.

`apsk_sheet_set_presented(false)` should set the intentional flag before flipping `state.isPresented`, but that only fixes binding-driven dismiss. The render-tree-removal path needs its own explicit signal or the probe must stop claiming it distinguishes all intentional dismissals from rerender teardown.

## FINDING 6 — CONCERN — `cliclick c` is the correct delivery class, but the coordinate model is fragile and under-gated

`cliclick c:<x>,<y>` generates a host-level mouse click. When the point is inside the Simulator device viewport, Simulator converts it through its normal touch path, which is exactly why it is a plausible replacement for XCUITest tap synthesis here. The same tool's `p` command captures the coordinates, so capture and delivery are at least in the same host coordinate space.

The gotchas are real:

- coordinates are host display pixels, not accessibility or app coordinates;
- Simulator window position, device chrome, zoom, display arrangement, and Retina scaling can invalidate them;
- `cliclick` needs macOS Accessibility permission; local `cliclick -h` warned that privileges are not enabled in this environment;
- the scenario file records no enforceable pose hash today.

So `cliclick c` is an honest primitive, but the harness must treat coordinates as volatile evidence, not stable selectors.

## FINDING 7 — CONCERN — V2 examples reopen per test, but action dismissal still lacks marker coverage

The V2 spec does not need to reopen the popover between the three button taps because each button has its own `it` block and relaunches Voyager. The controller also clears `show_overflow_menu = false` after each popover action (`todos_controller.cr:274-289`), which is appropriate product behavior.

The remaining problem is observability: the anchored popover path does not emit `binding-write-false`, `dismiss-token-fire`, or `platform-dismissed` markers when those actions close the popover by rerender. V2 currently only checks for a post-tap heartbeat, so it can prove "no crash/hang" after the marker blocker is fixed, but it still will not prove the popover lifecycle contract.

## FINDING 8 — CONCERN — ConfirmationDialog multi-action integration is mostly compatible, but only through SwiftUI's implicit dismissal write

The ActionSheet renderer now fills `ConfirmationDialogOverrides.actionLabels/actionStyles/actionTokens`, and `ConfirmationDialogFacade` renders them with a `ForEach`. That preserves the multi-action polish work (`uikit_renderer.cr:3970-4017`, `ConfirmationDialogFacade.swift:42-72`).

The marker path still depends on SwiftUI writing `false` to `storage.binding` after an action button fires. That should be how `.confirmationDialog(isPresented:)` behaves, and the storage setter emits `binding-write-false` then `platform-dismissed` (`ValueStorage.swift:68-104`). No textual conflict found here, but the V1 spec cannot validate it until it drives the real Share action sheet path.

## FINDING 9 — CONCERN — Intent-to-WidgetRoute rename does not appear to break Phase 12.B harness code

I found no old `UI::Intent` harness dependency in `spec/native_ios/ui_interaction`. The remaining "intent" hits in Voyager are names/comments for the Phase 10 intent-resolver demo or SystemAction concepts, while active routing uses `UI::WidgetRoute.resolve`. The V1/V2 specs reference test IDs and APIC markers, not intent identifiers.

## FINDING 10 — NIT — XCUITest rejection should be scoped to tap synthesis, not all future XCUITest use

The harness comment is directionally right that `XCUIElement.tap()` is rejected for this codebase's current callback path. But the durable doc/comment language should reserve the hybrid path: XCUITest may still be useful to find elements and read frames; `cliclick c` can remain the delivery primitive. `interaction-contracts-harness.md:120` already gestures at this future, but it still says "then simctl io delivers the tap"; update that to "then cliclick delivers the host click."

## Notes

I could not run `xcrun simctl io help` locally because CoreSimulatorService is unavailable in this sandboxed session. The review above does not depend on that command succeeding; the repository's own fixed harness and stale docs are enough to verify the current implementation state.
