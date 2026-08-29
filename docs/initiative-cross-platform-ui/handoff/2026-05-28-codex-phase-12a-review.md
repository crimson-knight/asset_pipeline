# Codex Phase 12.A review

Overall verdict: NEEDS_WORK. The direction is right, but the current artifacts do not yet reproduce the owner-reported V1/V2 failures. The specs are pending, several target identifiers do not exist on the current Voyager surface, and the V2 "process alive" check is not a process-liveness check.

## Deliverable 1 - Does the marker instrumentation actually reproduce V1?

### FINDING [BLOCKER] The V1 spec does not target the real Voyager surface.

The spec taps `voyager-todos-row-1`, `voyager-todos-row-1-share`, `voyager-action-sheet-cancel`, and `voyager-settings-noop-rerender` (`spec/native_ios/ui_interaction/confirmation_dialog_spec.cr:44`, `:55`, `:65`, `:80`, `:87`). Those ids exist only in the placeholder scenario file (`spec/native_ios/ui_interaction/scenarios/voyager.yml:22-62`, `:72-76`), not in the app. The actual Todos screen emits ids like `voyager-todo-row-#{todo.id}-tap` and `voyager-todo-row-#{todo.id}-check` (`samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:204-208`, `:239-243`), and Settings has `voyager-settings-hide-completed`, not `voyager-settings-noop-rerender` (`samples/initiative-cross-platform-ui-voyager/screens/settings_screen.cr:37-44`).

The user-reported V1 text says "row tap opens action sheet", but current row tap navigates to edit (`samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:235-244`; `samples/initiative-cross-platform-ui-voyager/controllers/todos_controller.cr:45-50`). Share/delete are swipe actions (`samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:267-280`) and `share_row` copies to clipboard, not a `UI::ConfirmationDialog` (`samples/initiative-cross-platform-ui-voyager/controllers/todos_controller.cr:81-88`). Until the spec drives the current failing path, it cannot reproduce V1.

### FINDING [BLOCKER] The spec is entirely pending, so Phase 12.A has no executable reproduction.

Both ConfirmationDialog examples call `pending!` unless the scenario YAML contains `captured: true` (`spec/native_ios/ui_interaction/confirmation_dialog_spec.cr:28-39`, `:75-77`). Every coordinate in the scenario is explicitly `captured: false` (`spec/native_ios/ui_interaction/scenarios/voyager.yml:22-76`). That means the claimed regression spec cannot fail yet. This violates the contract's own requirement that each known violation be reproduced by an interaction-contract spec before the fix lands (`docs/initiative-cross-platform-ui/architecture/presentation-lifecycle-contract.md:88-95`).

### FINDING [CONCERN] The proposed V1 marker sequence is only conditionally correct and misses host-removal dismissals.

If SwiftUI writes `false` through `BoolStorage.binding`, the instrumentation will emit `dismiss-token-fire`, call `CallbackBridge.fire`, then emit `platform-dismissed` (`swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/ValueStorage.swift:65-91`). A C1 test that observes `platform-dismissed` between `present` and explicit dismiss would catch that specific failure mode.

But V1 is described as Rerender rebuilding the tree (`docs/initiative-cross-platform-ui/architecture/presentation-lifecycle-contract.md:23-26`). If the action sheet disappears because the hosting view or presentation modifier is torn down/replaced, SwiftUI may dismiss without invoking this binding setter. In that case no `platform-dismissed` marker is emitted, and the only failure might be that the later cancel tap never produces `dismiss-token-fire`. The test should assert both negative markers and positive UI/action evidence: after unrelated Rerender, the sheet must still be hittable and the cancel action must fire from the sheet.

### FINDING [CONCERN] ConfirmationDialog has no real dismissal token; the marker says "dismiss-token-fire" but the token is `0`.

`ConfirmationDialogFacade` constructs `BoolStorage(initial: isPresented, token: 0)` (`swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/ConfirmationDialogFacade.swift:17-18`). `CallbackBridge.fire` explicitly drops token `0` (`swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/CallbackBridge.swift:154-161`; Crystal does the same at `src/ui/native/callback_registry.cr:50-52`). So the C3 marker is not proving the Crystal dismiss-token path required by the lifecycle contract (`docs/initiative-cross-platform-ui/architecture/presentation-lifecycle-contract.md:46-53`). It is proving only that SwiftUI wrote `false` into a local binding.

### FINDING [CONCERN] Crystal-side STDERR markers are asserted as unified-log markers without proof.

The harness tails unified log via `xcrun simctl spawn <udid> log stream --predicate eventMessage CONTAINS "[APIC:"` (`spec/native_ios/ui_interaction/support/simulator_harness.cr:187-207`). The harness doc says markers are NSLog markers (`docs/initiative-cross-platform-ui/architecture/interaction-contracts-harness.md:29-43`) and says the Crystal module writes NSLog (`docs/initiative-cross-platform-ui/architecture/interaction-contracts-harness.md:112-120`). The implementation writes `STDERR.puts` instead (`src/ui/native/interaction_contracts.cr:12-16`, `:46-56`).

Swift-side markers use `NSLog` (`swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/InteractionContracts.swift:43-58`), so they should land in `log stream`. Crystal STDERR may be visible for some simulator launch modes, but this harness does not launch with `--console` or explicit stdout/stderr capture (`spec/native_ios/ui_interaction/support/simulator_harness.cr:226-236`). Treating STDERR as equivalent to NSLog is an unproven assumption. Either make Crystal emit through a real NSLog/os_log bridge or add a harness self-test that proves Crystal-only markers are captured from the launched app.

### FINDING [NIT] The init-time `BoolStorage` marker path is dead code as written.

`BoolStorage.init` checks `if initial, let widget = markerWidget`, but `markerWidget` is set only after init returns in each facade (`swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/ValueStorage.swift:25-39`; `swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/ConfirmationDialogFacade.swift:17-27`; `swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/PopoverFacade.swift:18-24`; `swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/AlertFacade.swift:27-36`). The facade's second explicit emit is the one that works.

That is not functionally broken, but it is misleading instrumentation. Make marker metadata constructor arguments or delete the init emit path and keep facade-owned initial-present emits.

### FINDING [CONCERN] Sheet instrumentation is not equivalent to BoolStorage instrumentation.

Sheet uses `APSKSheetState`, not `BoolStorage` (`swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/SheetFacade.swift:58-80`; `swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/ReactiveState.swift:106-114`). It emits `present` only for initial `true` (`SheetFacade.swift:60-68`) and emits dismissal markers only inside `.sheet(onDismiss:)` (`SheetFacade.swift:160-179`). Programmatic writes go through `apsk_sheet_set_presented` and simply assign `state.isPresented` (`ReactiveState.swift:251-260`), with no write-side marker.

`onDismiss` is broader than swipe-down; it generally fires when the sheet is dismissed. But it is not a binding-write probe, and it will not tell us whether dismissal originated from Crystal explicit false, interactive platform dismissal, or host lifecycle teardown. For C1/C2 enforcement, add write-side markers in `apsk_sheet_set_presented` or move Sheet onto a storage object with the same instrumentation surface.

## Deliverable 2 - Is timeout-based crash detection in V2 spec sufficient?

### FINDING [BLOCKER] `simctl listapps` does not prove the app process is alive.

The V2 spec sleeps and then runs `xcrun simctl listapps #{sim.udid}`, passing if the installed-app listing contains the bundle id (`spec/native_ios/ui_interaction/voyager_toolbar_spec.cr:36-45`, `:52-58`, `:65-70`, `:86-90`). `listapps` reports installed apps. It will still include `com.assetpipeline.voyager` after the app crashes because the harness installed the app before launch (`spec/native_ios/ui_interaction/support/simulator_harness.cr:89-99`, `:135-143`). This is a false negative factory, not a crash detector.

Concrete fix: capture the PID from `simctl launch` output, then use a real running-process check, or make the app emit a post-tap heartbeat marker from the next main-runloop turn and fail if the marker does not arrive. The latter catches crash, hang, and callback misrouting in one assertion.

### FINDING [BLOCKER] The V2 spec targets controls that do not exist.

The spec taps `voyager-todos-header-sort-newest`, `voyager-todos-header-sort-oldest`, `voyager-todos-header-sort-deadline`, and `voyager-todos-overflow-trigger` (`spec/native_ios/ui_interaction/voyager_toolbar_spec.cr:33-34`, `:52-53`, `:65-66`, `:78-83`). Those ids appear only in the placeholder YAML (`spec/native_ios/ui_interaction/scenarios/voyager.yml:34-56`). The current Todos header has Print and Settings buttons (`samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:72-91`), and no sort or overflow controls. Even a perfect crash detector would not be testing V2 until the app surface or the spec is corrected.

### FINDING [CONCERN] The V2 spec needs a positive "tap reached the intended action" assertion.

Button and Toolbar action closures currently call `CallbackBridge.fire` without APIC markers (`swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/ButtonFacade.swift:81-84`; `swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/ToolbarFacade.swift:109-116`). A coordinate tap can miss the intended control and still pass today's process check. Add a marker before and after the target action, for example `[APIC:Button:tap] view=<accessibility-id>` in the Swift facade and `[APIC:Voyager:<action>-handled]` in the Crystal controller. Then V2 should assert: tap marker arrives, controller marker arrives, and a post-tap heartbeat marker arrives.

### FINDING [CONCERN] Hung/unresponsive state is not covered.

The spec sleeps one second and checks installation state (`spec/native_ios/ui_interaction/voyager_toolbar_spec.cr:36-45`). A main-thread hang, dead callback, or modal obstruction can leave the bundle installed and the process alive but unusable. A liveness check should require a marker emitted after the tap on the main queue, plus an optional visual/state assertion that the expected screen remains active.

## Deliverable 3 - Critique the URL-scheme accessibility-id query plan

### FINDING [CONCERN] The custom URL-scheme plan is viable only if it queries the accessibility tree, not just `UIView.accessibilityIdentifier`.

The documented requirement is correct: tap delivery must resolve stable accessibility identifiers, not hardcoded coordinates (`docs/initiative-cross-platform-ui/architecture/interaction-contracts-harness.md:102-110`). The proposed URL-scheme round trip can be made to work, but "walk the UIView hierarchy looking for a UIView with matching accessibilityIdentifier" is too weak for this app. Many targets are SwiftUI facade controls where identifiers are applied through SwiftUI modifiers (`swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Modifiers/CommonModifiers.swift:123-124`), not necessarily as a direct `UIView.accessibilityIdentifier` on the tappable leaf. Some UIKit-rendered paths do set identifiers directly (`src/ui/renderers/uikit_renderer.cr:4752-4759`), but the SwiftUI-hosted Button path uses the facade/modifier stack.

If keeping the URL approach, the query endpoint must return frames from the app's accessibility elements in screen coordinates, not just raw UIView frames. It also needs a marker schema that includes id, frame, route, timestamp, and a "not found" result so the harness can fail clearly.

### FINDING [CONCERN] `openurl` is not side-effect free.

Driving `xcrun simctl openurl <udid> voyager://apic-query?...` activates the app and enters its URL handling path. During a presentation-lifecycle test, that can perturb scene activation, routing, or modal focus. That is especially risky for V1, where the behavior under test is a presentation disappearing during unrelated churn (`docs/initiative-cross-platform-ui/architecture/presentation-lifecycle-contract.md:11-18`, `:88-95`). If this route is used, the handler must be explicitly test-only, must not route or rebuild UI, and should be disabled unless `APIC_ENABLED=1`.

### FINDING [CONCERN] The repo already has an XCUITest precedent; rejecting it should be revisited for frame lookup.

The harness doc rejects XCUITest for the whole MVP (`docs/initiative-cross-platform-ui/architecture/interaction-contracts-harness.md:19-27`), but this repo already has Voyager iOS UI tests that discover AX elements and tap them (`samples/initiative-cross-platform-ui-voyager/ios/UITests/VoyagerVisualTests.swift:103-168`, `:343-383`). A small XCUITest helper that resolves accessibility identifiers to frames, paired with the existing APIC log markers for semantic assertions, is likely cleaner than adding an app URL protocol solely for coordinate lookup.

That does not mean migrate all assertions to XCUITest. The simplest correct split is: use accessibility tooling for locating/tapping elements, and keep `[APIC:...]` markers for lifecycle semantics. `idb` can do tap-by-accessibility-id, but it adds a nonstandard dependency. `xcrun simctl io --json` does not expose a general accessibility tree. A harness-side script "inside the app" is not a real option unless the app exposes an endpoint, which collapses back to the URL-scheme plan.

### FINDING [NIT] The scenario-file freshness story is aspirational.

The scenario file claims a source-hash freshness gate catches stale coordinates (`spec/native_ios/ui_interaction/scenarios/voyager.yml:5-7`), but it stores `captured_pose_sha: null` and every coordinate is placeholder (`spec/native_ios/ui_interaction/scenarios/voyager.yml:16-18`, `:22-76`). The current catalog validator is about catalog source hashes, not this tap-coordinate file. Do not present coordinate freshness as enforced until the validator actually reads and checks these scenarios.
