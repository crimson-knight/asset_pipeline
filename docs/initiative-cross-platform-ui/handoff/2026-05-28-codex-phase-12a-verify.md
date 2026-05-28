# Codex Phase 12.A verification pass

Overall verdict: NEEDS_WORK. The response is more honest than the original Phase 12.A handoff, but it is not ready for owner sign-off. The V1/V2 target-surface reframe is evidence-backed; the current main checkout really does not contain the owner's polish-worktree action-sheet/sort/overflow surface. But the response overclaims the harness proof, leaves stale URL/XCUITest documentation behind, and introduces a new compile failure in the V2 spec.

The most important fact: `crystal build --no-codegen spec/native_ios/ui_interaction/voyager_toolbar_spec.cr -Dios` fails today:

```text
Error: can't declare def dynamically
spec/native_ios/ui_interaction/voyager_toolbar_spec.cr:38
def self.assert_runloop_alive(...)
```

That alone blocks approval.

## Verification matrix

| Finding | Status | Reason |
|---|---|---|
| BLOCKER 1 — V1/V2 specs target absent Voyager surface | PARTIALLY CLEARED | The reframe is honest, but it changes the deliverable from reproduction to scaffold. |
| BLOCKER 2 — specs are pending / no executable reproduction | PARTIALLY CLEARED | A smoke spec was added, but it does not prove V1/V2 and has harness gaps. |
| BLOCKER 3 — `simctl listapps` liveness check | NOT CLEARED | Replaced with heartbeat markers, but the V2 spec does not compile and the helper can false-pass. |
| CONCERN 4 — host-removal dismissals | NOT CLEARED | Acknowledged/deferred, not instrumented. |
| CONCERN 5 — misleading `dismiss-token-fire` for token 0 widgets | PARTIALLY CLEARED | Swift split is mostly correct, but the C1 spec still waits for a ConfirmationDialog `dismiss-token-fire`. |
| CONCERN 6 — Crystal STDERR vs unified log | CLEARED | The C bridge and Crystal binding are ABI-correct for a synchronous null-terminated string call. |
| CONCERN 7 — Sheet not equivalent to BoolStorage instrumentation | NOT CLEARED | Still deferred; Sheet write-side mutations remain uninstrumented. |
| CONCERN 8 — V2 needs positive tap/action assertion | NOT CLEARED | Overflow has a Popover marker in a non-compiling spec; sort taps still only assert heartbeat. |
| CONCERN 9 — hung/unresponsive state | NOT CLEARED | Same broken heartbeat helper; no post-tap freshness guarantee. |
| CONCERN 10/11 — URL-scheme accessibility lookup / `openurl` side effects | PARTIALLY CLEARED | The response says deprecated, but the harness doc and capture script still describe URL/coordinate-era plans. |
| CONCERN 12 — XCUITest helper for tap-by-id | PARTIALLY CLEARED | Correct direction, not shipped; current `tap_accessibility_id` still uses coordinates. |
| NIT — scenario freshness story | CLEARED | Scenario YAML now says freshness is not validator-enforced. |

## FINDING [BLOCKER] PARTIALLY CLEARED — BLOCKER 1 reframe is honest, but it is also a scope retreat

The architect is not inventing a story about current main. Current `TodosScreen` has Print and Settings buttons in the header, not sort filters or overflow (`samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:72-86`). Todo row tap still navigates to edit through `Voyager.dispatch(:edit_row, ...)`, not an action sheet (`samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:235-243`).

The lifecycle contract now states the same thing: V1/V2 manifested in `phase-10-d-polish`, current `phase-10-d-refocus` does not contain those paths, and the specs are pre-staged until the worktree merge plus coordinate capture (`docs/initiative-cross-platform-ui/architecture/presentation-lifecycle-contract.md:101-107`). The catalog manifest matches that status (`docs/initiative-cross-platform-ui/catalog-coverage.yml:937-961`).

So the reframe is honest. It is not a fix for the original deliverable. If Phase 12.A was required to reproduce V1/V2, this remains not delivered. If Phase 12.A is now explicitly "harness scaffold only", the reframe is acceptable but must not be sold as owner-bug reproduction.

## FINDING [BLOCKER] PARTIALLY CLEARED — BLOCKER 2 executable proof is now only a smoke test

The pending-state honesty is improved. The specs say they are forward-looking and pending until the polish worktree lands (`spec/native_ios/ui_interaction/confirmation_dialog_spec.cr:3-18`, `spec/native_ios/ui_interaction/voyager_toolbar_spec.cr:3-20`).

But the new smoke test is not the same as a regression reproduction. It launches current-main Voyager and waits for `[APIC:VoyagerApp:launched]` and heartbeat markers (`spec/native_ios/ui_interaction/harness_smoke_spec.cr:27-47`). That proves only a narrow launch/log-stream path if it actually runs. It does not prove tap delivery, modal survival, V1, or V2.

There is also a path mismatch: `DEFAULT_APP_BUNDLE_ROOT` resolves from `spec/native_ios/ui_interaction/support` through `../../../tmp`, which lands under `spec/tmp/interaction-contracts/bundles`, not repo-root `tmp/interaction-contracts/bundles` (`spec/native_ios/ui_interaction/support/simulator_harness.cr:45-52`). The smoke spec documentation says `APIC_APP_BUNDLE_ROOT/VoyagerDemo.app` but the broader handoff/runbook language points at repo-root `tmp`. Without overriding `APIC_APP_BUNDLE_ROOT`, this can fail before launch.

## FINDING [BLOCKER] NOT CLEARED — BLOCKER 3 heartbeat fix is broken in both compile and logic

`VoyagerApp.swift` itself likely emits heartbeats correctly. The app delegate emits a launch marker, checks `InteractionContracts.enabled`, and schedules a repeating one-second `Timer` on the main runloop (`samples/initiative-cross-platform-ui-voyager/ios/Sources/VoyagerApp.swift:52-72`). `swift build --disable-sandbox` passes for `AssetPipelineSwiftKit`.

The spec-side fix is not correct:

- It does not compile. `assert_runloop_alive` is declared inside the `describe` macro body (`spec/native_ios/ui_interaction/voyager_toolbar_spec.cr:27-53`), and Crystal rejects that as `can't declare def dynamically`.
- Even after moving the helper, the freshness logic is wrong. The helper takes `since : Time` but never uses it (`spec/native_ios/ui_interaction/voyager_toolbar_spec.cr:38-48`). It clears markers before the tap, then accepts the first heartbeat in the buffer. A heartbeat that arrives after `clear_markers` but before the tap can make a crash-on-tap pass.

Correct shape: record marker count or parsed heartbeat tick before the tap, then require a strictly newer heartbeat after the tap returns. Better: emit an explicit post-tap main-queue marker from the target action path.

## FINDING [CONCERN] NOT CLEARED — CONCERN 4 host-removal dismissal path is still uncovered

The architect acknowledges the limitation but defers it to 12.B. That is not cleared. Binding-write instrumentation catches SwiftUI writing `false`; it still does not catch a host teardown/replacement path where the presentation disappears without the binding setter.

The C1 spec still only asserts no `platform-dismissed` marker in a short window (`spec/native_ios/ui_interaction/confirmation_dialog_spec.cr:69-74`). That misses the exact host-removal class I called out unless the test also proves the sheet remains hittable and its cancel/action button fires from the presented UI.

## FINDING [CONCERN] PARTIALLY CLEARED — CONCERN 5 split is correct in Swift, stale in one spec

The Swift-side split is the right direction. `BoolStorage.binding` now emits `binding-write-false` for every true-to-false transition and emits `dismiss-token-fire` only when `token != 0` (`swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/ValueStorage.swift:78-92`).

Widget walkthrough:

- Sheet: separate `APSKSheetState`, not `BoolStorage`; on dismiss it emits `dismiss-token-fire`, fires the dismiss token, then emits `platform-dismissed` (`swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/SheetFacade.swift:160-178`). For token != 0, expected marker fires, but this remains onDismiss-only.
- Popover: `BoolStorage(initial:, token: dismissToken)` with markerWidget `Popover`; token != 0 means `binding-write-false`, `dismiss-token-fire`, callback fire, then `platform-dismissed` (`PopoverFacade.swift:18-29`, `ValueStorage.swift:78-103`).
- ConfirmationDialog: `BoolStorage(... token: 0)` means `binding-write-false` and `platform-dismissed`, but no `dismiss-token-fire`; button actions use confirm/cancel tokens (`ConfirmationDialogFacade.swift:17-40`, `:50-58`).
- Alert: same token 0 pattern; alert button actions use `buttonTokens`, so no BoolStorage `dismiss-token-fire` should be expected (`AlertFacade.swift:27-57`).

The stale part: the C1 ConfirmationDialog spec still waits for `[APIC:ConfirmationDialog:dismiss-token-fire]` after cancel (`spec/native_ios/ui_interaction/confirmation_dialog_spec.cr:76-82`). That will fail once the pending guard lifts. The C3 example was corrected; C1 was not.

## FINDING [CONCERN] CLEARED — CONCERN 6 NSLog bridge is ABI-correct

The Crystal declaration `fun apsk_apic_log(msg : UInt8*)` matches the C function `void apsk_apic_log(const char *msg)` (`src/ui/native/swiftkit_bridge.cr:20-25`, `src/ui/native/swiftkit_bridge.m:882-885`). `line.to_unsafe` passes Crystal's null-terminated string buffer for the duration of the synchronous call (`src/ui/native/interaction_contracts.cr:39-43`). `NSLog(@"%s", msg)` copies/formats during the call, so pointer lifetime is adequate.

This clears the original STDERR concern for Crystal-side markers.

## FINDING [CONCERN] NOT CLEARED — CONCERN 7 Sheet instrumentation remains partial

Still open. Sheet still uses `APSKSheetState`, not `BoolStorage`, and `apsk_sheet_set_presented` still just assigns `state.isPresented = newValue` with no write-side marker. The response documents/defer this, but does not clear it.

## FINDING [CONCERN] NOT CLEARED — CONCERN 8 V2 positive action assertion is not adequate

The overflow case now waits for `[APIC:Popover:present]`, which is the right kind of positive assertion (`spec/native_ios/ui_interaction/voyager_toolbar_spec.cr:90-105`). But the spec does not compile, so this proof is currently unavailable.

The three sort-button examples still only use the heartbeat helper (`spec/native_ios/ui_interaction/voyager_toolbar_spec.cr:56-87`). That proves neither "tap hit the intended control" nor "controller handled the intended action." A missed coordinate tap plus a live app can still pass.

## FINDING [CONCERN] NOT CLEARED — CONCERN 9 hung/unresponsive coverage depends on the broken helper

The heartbeat concept is acceptable, but the current assertion does not prove a heartbeat after the tap because it ignores the `since` parameter and only searches the whole post-clear buffer. It can false-pass on a heartbeat emitted just before the tap-induced crash/hang.

Also note that the heartbeat is a one-second `Timer` scheduled in the app delegate. That is fine for main-runloop liveness, but it is not a substitute for a target-action marker. Use both.

## FINDING [CONCERN] PARTIALLY CLEARED — CONCERN 10/11 URL-scheme plan is deprecated in response, but not in the durable docs

The architect response says the URL-scheme plan is deprecated. The committed durable docs do not consistently say that.

`interaction-contracts-harness.md` still says "Why not XCTest / XCUITest" and "we're not using it as the MVP" (`docs/initiative-cross-platform-ui/architecture/interaction-contracts-harness.md:19-27`). It still describes a TBD NSLog/accessibilityElement query rather than a concrete XCUITest helper (`docs/initiative-cross-platform-ui/architecture/interaction-contracts-harness.md:102-110`). Its phasing still says Phase 12.A reproduces V1 (`docs/initiative-cross-platform-ui/architecture/interaction-contracts-harness.md:157-162`), contradicting the new lifecycle-contract reframe.

`scripts/capture_tap_coordinates.sh` is also stale: it still says the URL-scheme query mechanism lands in Phase 12.B (`scripts/capture_tap_coordinates.sh:22-25`).

So the URL plan is philosophically deprecated, but the repository still gives future agents conflicting instructions.

## FINDING [CONCERN] PARTIALLY CLEARED — CONCERN 12 XCUITest helper is the right plan, but not a 12.A deliverable yet

It is honest to say "XCUITest helper planned for 12.B" only if Phase 12.A is explicitly rescoped to harness scaffolding. The architect did not ship the helper, and current `tap_accessibility_id` still reads a coordinate map and calls `simctl io ... touch tap` (`spec/native_ios/ui_interaction/support/simulator_harness.cr:257-265`).

That means the V1/V2 specs still need something real before they can run by accessibility id. The response is acceptable as a plan, not as completion of tap-by-id delivery.

## FINDING [NIT] CLEARED — scenario freshness is no longer overstated in the scenario file

`scenarios/voyager.yml` now says coordinate freshness is not enforced by `validate_catalog_coverage.cr` and that `captured_pose_sha` is reserved for a follow-up validator extension (`spec/native_ios/ui_interaction/scenarios/voyager.yml:9-12`). That clears the nit.

## FINDING [BLOCKER] NEW — V2 spec does not compile

This is new in the response commit. The helper declaration inside the spec macro makes `voyager_toolbar_spec.cr` fail under `-Dios`. This must be fixed before any owner sign-off, even if the examples remain pending, because the claimed proof includes no-codegen over all three specs.

## FINDING [CONCERN] NEW — smoke spec overclaims end-to-end coverage

The smoke spec can prove Swift-side `NSLog` marker capture if it runs. It does not prove the Crystal `apsk_apic_log` bridge, because the launch and heartbeat markers are emitted in Swift (`VoyagerApp.swift:52-72`). It also does not prove tap delivery, coordinate freshness, XCUITest lookup, or V1/V2 semantics.

There is a possible launch-marker race: the harness starts `log stream` and immediately launches the app without waiting for the stream process to be ready (`spec/native_ios/ui_interaction/support/simulator_harness.cr:97-101`, `:190-215`). A heartbeat should eventually arrive, but the one-shot launch marker can be missed if the stream subscription is not active yet.

## Validation run

Passed:

- `CRYSTAL_CACHE_DIR=/private/tmp/asset_pipeline_crystal_cache crystal run scripts/validate_catalog_coverage.cr`
- `CRYSTAL_CACHE_DIR=/private/tmp/asset_pipeline_crystal_cache crystal run scripts/lint_conventions.cr`
- `crystal build --no-codegen spec/native_ios/ui_interaction/harness_smoke_spec.cr -Dios`
- `crystal build --no-codegen spec/native_ios/ui_interaction/confirmation_dialog_spec.cr -Dios`
- `CLANG_MODULE_CACHE_PATH=/private/tmp/asset_pipeline_clang_module_cache SWIFTPM_MODULECACHE_PATH=/private/tmp/asset_pipeline_swiftpm_module_cache swift build --disable-sandbox` from `swift/AssetPipelineSwiftKit`
- `git diff --check`

Failed:

- `crystal build --no-codegen spec/native_ios/ui_interaction/voyager_toolbar_spec.cr -Dios` — dynamic method declaration inside spec macro.

Not run:

- Simulator smoke spec end-to-end. This requires a booted matching simulator and a built `VoyagerDemo.app` at the harness bundle root. Static inspection found the default bundle-root mismatch above, so this should be fixed before spending owner time on a live run.

