# Interaction-contracts harness

**Status:** Authoritative design for the harness that mechanically enforces the [presentation-lifecycle contract](presentation-lifecycle-contract.md) and the per-widget behavior contracts named in each usage doc.

**Owner directive (2026-05-28):** "You have not addressed the automated testing that would verify this behavior is stable, such as like when you click a to-do the action sheet opens and then stays open until I do something to trigger it to close."

This doc closes that gap. The harness is gate item F in the [merge-readiness gate](../merge-readiness-gate.md).

## What the harness is

A Crystal spec runner under `spec/native_ios/ui_interaction/` that:

1. Builds + installs the relevant demo app on the iOS simulator.
2. Launches it with a known entry route (`SIMCTL_CHILD_VOYAGER_ROOT_SLUG=<screen>`).
3. Drives the running app via `cliclick c:<x>,<y>` (host-pixel taps into the Simulator window) and `xcrun simctl spawn ... log stream` (assertion source).
4. Asserts on **unique-grep-token NSLog markers** that the renderer + facades emit at lifecycle points.
5. Records video to `tmp/interaction-contracts/<spec>.mp4` for human review on failure.

## Architecture: coordinate-map taps + APIC markers

**Reframed 2026-05-28 — see `handoff/2026-05-28-phase-12b-worktree-merge-plan.md` step 1 discovery.**

The harness splits responsibilities:

- **Tap delivery** → `cliclick c:<x>,<y>` (host-pixel click into the Simulator window) with coordinates resolved from `spec/native_ios/ui_interaction/scenarios/<app>.yml`. Coordinates are recaptured manually via `scripts/capture_tap_coordinates.sh` whenever screen layouts change.
- **Semantic assertions** → Crystal harness + APIC markers. The `[APIC:...]` marker convention lets the Crystal spec assert on lifecycle invariants (present, dismiss, binding-write, heartbeat) without inspecting the SwiftUI view tree.

**Why not XCUITest taps:** Phase 6.10 Rem 3 documented (handoff/phase-06.10-remediation-3-codex-blocker.md) and Phase 8 collective review confirmed (handoff/phase-08-collective-review-2026-05-25.md) that **XCUITest tap synthesis does NOT fire `CallbackBridge.fire` on Crystal-rendered buttons in this codebase.** XCUITest finds elements correctly via the accessibility tree, but synthesized taps reach `_UIHostingView.hitTest` and stop there — the SwiftUI Button's action closure does not fire. This is a multi-iteration deep bug that was not resolved through Phase 6.10 Rem 3's three remediation iterations and survives in current main.

`cliclick c:<x>,<y>` by contrast generates a host-level mouse click; when the point lies inside the Simulator viewport, Simulator converts it through its normal touch synthesizer and fires the SwiftUI Button action closures as expected. (The earlier draft of this doc proposed `xcrun simctl io touch tap` — that command does NOT exist; `simctl io` only supports enumerate/poll/recordVideo. Codex Phase 12.B partial review caught the hallucination; the harness has used cliclick since commit `7271464d`.)

**XCUITest IS used elsewhere** — `VoyagerVisualTests.swift` uses XCUITest for accessibility-tree DISCOVERABILITY assertions (find element by ID, screenshot it), which works fine. Only the TAP SYNTHESIS path is broken on this codebase.

Phase 12.A delivers the Crystal harness, marker emission, harness smoke test. Phase 12.B ships the polish-worktree merge + coordinate capture + V1+V2 reproduction.

## Marker convention

Every renderer and facade emits NSLog markers with a unique-grep-token prefix `[APIC:<widget>:<event>]` (APIC = Asset Pipeline Interaction Contracts).

Examples:

```
[APIC:ConfirmationDialog:present] view=todo-share-action-sheet trigger=user-tap-row tick=42
[APIC:ConfirmationDialog:binding-read] view=todo-share-action-sheet during-rerender=true value=false
[APIC:ConfirmationDialog:dismiss-token-fire] view=todo-share-action-sheet token=0xABCDEF
[APIC:ConfirmationDialog:platform-dismissed] view=todo-share-action-sheet
[APIC:ConfirmationDialog:action-handler-fire] view=todo-share-action-sheet action=copy timestamp=1779991000
```

The marker schema is documented per widget in its usage doc's "Behavior contract" section. Tests assert on marker presence / absence / order — not on UI tree inspection.

## Per-spec structure

```crystal
# spec/native_ios/ui_interaction/confirmation_dialog_spec.cr
require "spec"
require "../../src/asset_pipeline/ui"
require "./support/simulator_harness"

describe "UI::ConfirmationDialog interaction contracts" do
  it "C1 — survives Rerender (stays open until explicit dismiss)" do
    Harness.with_voyager(route: "todos") do |sim|
      sim.tap_accessibility_id("ap-test-share-trigger-todo-1")
      sim.wait_for_marker("[APIC:ConfirmationDialog:present]", timeout: 2.seconds)

      # Trigger N unrelated Rerenders by tapping reload / hitting a state-changing button
      5.times do
        sim.tap_accessibility_id("ap-test-noop-rerender-button")
      end

      sim.markers_during_rerender_for("ConfirmationDialog", count: 5).each do |markers|
        markers.should_not include("[APIC:ConfirmationDialog:binding-read]")
      end

      sim.assert_no_marker("[APIC:ConfirmationDialog:platform-dismissed]")
    end
  end

  it "C3 — dismiss flows through dismissToken" do
    Harness.with_voyager(route: "todos") do |sim|
      sim.tap_accessibility_id("ap-test-share-trigger-todo-1")
      sim.wait_for_marker("[APIC:ConfirmationDialog:present]", timeout: 2.seconds)
      sim.tap_accessibility_id("ap-test-action-sheet-cancel")

      sim.wait_for_marker("[APIC:ConfirmationDialog:dismiss-token-fire]", timeout: 1.second)
      sim.wait_for_marker("[APIC:ConfirmationDialog:platform-dismissed]", timeout: 1.second)
      sim.assert_marker_order(
        "[APIC:ConfirmationDialog:dismiss-token-fire]",
        "[APIC:ConfirmationDialog:platform-dismissed]"
      )
    end
  end

  # C2, C4, C5 specs follow the same shape.
end
```

## Harness support layer

`spec/native_ios/ui_interaction/support/simulator_harness.cr` provides:

- `Harness.with_voyager(route: String, &block : Simulator -> Nil)` — boots simulator, installs Voyager, launches with route env var, starts log-stream subscription, yields, terminates and cleans up.
- `Simulator#tap_accessibility_id(id)` — invokes `cliclick c:<x>,<y>` at the host pixel coordinate resolved from the scenario YAML for the accessibility identifier.
- `Simulator#wait_for_marker(token, timeout)` — tails log stream, fails the example if the marker doesn't appear in time.
- `Simulator#assert_no_marker(token)` — checks the marker buffer doesn't contain the token over the next 500ms.
- `Simulator#assert_marker_order(a, b)` — asserts marker a appeared in the buffer before marker b.
- `Simulator#markers_during_rerender_for(widget, count)` — returns an array of marker arrays, one per Rerender pass, scoped to markers emitted by the named widget.

## Driver: tap delivery (coordinate-map via cliclick)

The harness resolves interactive elements by accessibility_identifier mapped to (x, y) coordinates in a per-app scenario YAML:

- Every screen MUST set `accessibility_identifier` on every interactive element under test, using the convention `<app>-<screen>-<purpose>-<id>` (e.g. `voyager-todos-row-1-share`).
- `accessibility_identifier` is already on `UI::View` (`src/ui/view.cr:327`) and threaded through UIKit (`src/ui/renderers/uikit_renderer.cr:4754`), AppKit (`src/ui/renderers/appkit_renderer.cr:4546`), and Web (`src/ui/renderers/web_renderer.cr:2684`) renderers.
- `Simulator#tap_accessibility_id(id)` looks up the (x, y) host pixel from `spec/native_ios/ui_interaction/scenarios/<app>.yml` and invokes `cliclick c:<x>,<y>`. cliclick generates a host mouse click; Simulator converts it via its normal touch synthesizer and Crystal action closures fire correctly.
- Coordinates are RECAPTURED whenever screen layouts change. `scripts/capture_tap_coordinates.sh` walks the operator through capture (uses `cliclick` for cursor position).

The coordinate map is the long-term tap-delivery mechanism per the step 1 reframe — XCUITest tap synthesis is broken on this codebase and a frame-lookup-via-XCUITest workaround was not pursued (would require a parallel XCUITest process kept alive between queries, which the harness's spec-per-process model doesn't support).

A future XCUITest-FRAME-LOOKUP helper that resolves accessibility IDs to host-pixel frames without synthesizing taps (then `cliclick c` delivers the host click) is queued as a Phase 12.D follow-up if scenario YAML maintenance becomes painful. XCUITest rejection is scoped to tap synthesis only — XCUITest is still acceptable for AX discoverability assertions (the existing `VoyagerVisualTests.swift` precedent) and for frame lookup.

## Marker instrumentation: where it lives

The renderer + facades emit markers via a single `InteractionContractInstrumentation` module:

- `src/ui/native/interaction_contracts.cr` — Crystal-side `InteractionContracts.emit(widget, event, **kv)` that writes NSLog with the `[APIC:...]` prefix when `ENV["APIC_ENABLED"] == "1"`.
- `swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/InteractionContracts.swift` — Swift mirror for facade-side emission.
- Markers are only emitted when the env var is set, so production / regular dev runs are unaffected.

The harness sets `SIMCTL_CHILD_APIC_ENABLED=1` when launching.

## CI integration

A new make target `make test-interaction-contracts`:

```makefile
test-interaction-contracts:
	@./scripts/boot-simulator.sh "iPhone 17 Pro" "iOS 26.5"
	@xcodebuild -workspace ... build-for-testing
	@crystal-alpha spec spec/native_ios/ui_interaction/ -Dios \
	  --link-flags="-framework ApplicationServices -framework CoreFoundation"
```

A new GitHub Actions job `interaction-contracts` in `.github/workflows/initiative-cross-platform-ui.yml`:

- Runs on `macos-latest` runners only (simulator requirement).
- Boots the simulator, installs the demo apps, runs `make test-interaction-contracts`.
- Uploads `tmp/interaction-contracts/*.mp4` as artifacts on failure for human triage.

The job is **required** to pass for merge-readiness gate item F.

## Coverage matrix

The harness ships with at least one C1 + C3 spec per presented-state widget, before that widget can satisfy [merge-readiness gate](../merge-readiness-gate.md) item 4:

| Widget | C1 (survives Rerender) | C2 (binding one-direction) | C3 (dismiss via token) | C4 (anchor survives) | C5 (action after dismiss) |
|---|---|---|---|---|---|
| `Sheet` | REQUIRED | REQUIRED | REQUIRED | n/a | REQUIRED |
| `Popover` | REQUIRED | REQUIRED | REQUIRED | REQUIRED | REQUIRED |
| `Alert` | REQUIRED | REQUIRED | REQUIRED | n/a | REQUIRED |
| `ConfirmationDialog` | REQUIRED | REQUIRED | REQUIRED | n/a | REQUIRED |
| `FullScreenCover` | REQUIRED | REQUIRED | REQUIRED | n/a | REQUIRED |
| `Inspector` | REQUIRED | REQUIRED | n/a | n/a | n/a |

For widgets WITHOUT presented state (Button, Slider, TextField, etc.), interaction contracts are still required but are simpler — typically just "tap fires exactly one action callback" and "value change fires exactly one binding update." Those specs follow the same harness pattern with widget-specific markers documented in their usage doc.

## Phasing (revised per Codex Phase 12.A verification pass)

The harness ships in four sub-phases under Phase 12:

- **Phase 12.A** — Harness scaffold. Builds `simulator_harness.cr` (Crystal-driven simctl + log-stream tail), the `InteractionContracts` Crystal/Swift marker emitter, the `apsk_apic_log` NSLog C bridge, and the heartbeat-marker scaffold in Voyager. Ships `harness_smoke_spec.cr` (executable end-to-end smoke test against current main). Pre-stages the V1+V2 reproduction specs at `spec/native_ios/ui_interaction/{confirmation_dialog,voyager_toolbar}_spec.cr` with `pre-staged-pending-worktree-merge` status. DOES NOT reproduce V1 or V2 (their target code lives in `phase-10-d-polish` worktree; see `presentation-lifecycle-contract.md` §"V1/V2 source-of-truth location").
- **Phase 12.B** — Polish worktree merge + V1+V2 reproduction prerequisites. Merges the `phase-10-d-polish` worktree's todos extensions (action sheet on row tap, sort filters, overflow popover) into main so V1+V2 target code paths exist. Captures real tap coordinates for the V1+V2 specs via `capture_tap_coordinates.sh`. Adds host-teardown probe markers (Codex CONCERN 4 — shipped early as part of step 2) and Sheet write-side markers (Codex CONCERN 7 — shipped early as part of step 2). At end of 12.B, V1+V2 specs become executable. XCUITest tap-by-id helper REJECTED per Phase 6.10 Rem 3 tap synthesis bug.
- **Phase 12.C** — V1 + V2 fixes. Uses the now-executable V1+V2 specs as regression tests. C1/C3 specs flip from failing-on-V1 to passing-with-fix; V2 spec flips from failing-on-crash to passing-with-fix.
- **Phase 12.D** — Roll out the full marker matrix to all six presented-state widgets (FullScreenCover, Inspector). Update each widget's usage doc with its marker schema. Extend the catalog manifest validator to enforce scenario coordinate freshness (Codex NIT 13).

## Cross-references

- [merge-readiness-gate.md](../merge-readiness-gate.md) — gate item F is this harness
- [presentation-lifecycle-contract.md](presentation-lifecycle-contract.md) — the invariants this harness enforces
- [widget-demonstration-criteria.md](../rubric/widget-demonstration-criteria.md) — usage doc's "Behavior contract" section now includes marker schema per widget
- `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr` — first instrumentation target

— Architect (Claude Opus 4.7), interaction-contracts-harness v1, 2026-05-28
