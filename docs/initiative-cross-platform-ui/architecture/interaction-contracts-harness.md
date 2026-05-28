# Interaction-contracts harness

**Status:** Authoritative design for the harness that mechanically enforces the [presentation-lifecycle contract](presentation-lifecycle-contract.md) and the per-widget behavior contracts named in each usage doc.

**Owner directive (2026-05-28):** "You have not addressed the automated testing that would verify this behavior is stable, such as like when you click a to-do the action sheet opens and then stays open until I do something to trigger it to close."

This doc closes that gap. The harness is gate item F in the [merge-readiness gate](../merge-readiness-gate.md).

## What the harness is

A Crystal spec runner under `spec/native_ios/ui_interaction/` that:

1. Builds + installs the relevant demo app on the iOS simulator.
2. Launches it with a known entry route (`SIMCTL_CHILD_VOYAGER_ROOT_SLUG=<screen>`).
3. Drives the running app via `xcrun simctl io` (taps), `cliclick` (fallback), and `xcrun simctl spawn ... log stream` (assertion source).
4. Asserts on **unique-grep-token NSLog markers** that the renderer + facades emit at lifecycle points.
5. Records video to `tmp/interaction-contracts/<spec>.mp4` for human review on failure.

## Why not XCTest / XCUITest

XCUITest is the iOS-native UI testing framework and is more robust. We're not using it as the MVP because:

- It requires a separate Swift test target with a Apple-signed bundle ID, which complicates the toolchain.
- It runs as a separate process attached via accessibility, which loses access to the Crystal-side state we need to assert on.
- The harness owner (the architect) controls the in-app NSLog instrumentation, which gives us tighter assertion semantics than XCUITest's external view of the UI tree.

The decision is: ship the Crystal-driven harness first, migrate to XCUITest only if/when we hit a wall. The marker-based assertion design is XCUITest-compatible if we want to migrate later.

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
- `Simulator#tap_accessibility_id(id)` — invokes `xcrun simctl io <udid> touch tap` at the resolved point for the accessibility identifier (resolves via a small JS helper injected into the WebKit view OR via a hardcoded coordinate map for the demo screen).
- `Simulator#wait_for_marker(token, timeout)` — tails log stream, fails the example if the marker doesn't appear in time.
- `Simulator#assert_no_marker(token)` — checks the marker buffer doesn't contain the token over the next 500ms.
- `Simulator#assert_marker_order(a, b)` — asserts marker a appeared in the buffer before marker b.
- `Simulator#markers_during_rerender_for(widget, count)` — returns an array of marker arrays, one per Rerender pass, scoped to markers emitted by the named widget.

## Driver: tap delivery

The simulator harness MUST resolve interactive elements by stable accessibility identifier, not by coordinate. To make this reliable:

- Every Voyager screen (and every demo-app screen) MUST set `accessibility_identifier` (NOT `accessibility_label` — that's user-facing) on every interactive element under test, using the convention `ap-test-<widget>-<purpose>-<id>`.
- The renderer's `accessibility_identifier` property maps to UIView.accessibilityIdentifier on iOS, NSAccessibility identifier on macOS.
- The harness queries the running app for the element's frame via a small NSLog round-trip OR via accessibilityElement API call — TBD by the implementer.

This is a NEW property on `UI::View`. Acceptance for the harness phase MUST include adding `accessibility_identifier : String?` to `UI::View` and threading it through the renderers.

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

## Phasing

The harness ships in three sub-phases under what should be a new top-level phase (let's call it Phase 12 for now — owner to confirm naming):

- **Phase 12.A** — Build the harness support layer (`simulator_harness.cr`), the `InteractionContracts` instrumentation module, and the `accessibility_identifier` property on `UI::View`. Ship C1 + C3 specs for `UI::ConfirmationDialog` as the worked example. Reproduces V1 from the lifecycle contract.
- **Phase 12.B** — Fix V1 (action-sheet auto-close) and V2 (header-button crash) using the C1/C3 specs as regression tests. Both bugs MUST be reproducible by a failing spec before the fix lands.
- **Phase 12.C** — Roll out the full marker matrix above to all six presented-state widgets. Update each widget's usage doc with its marker schema. Update the merge-readiness scoreboard.

## Cross-references

- [merge-readiness-gate.md](../merge-readiness-gate.md) — gate item F is this harness
- [presentation-lifecycle-contract.md](presentation-lifecycle-contract.md) — the invariants this harness enforces
- [widget-demonstration-criteria.md](../rubric/widget-demonstration-criteria.md) — usage doc's "Behavior contract" section now includes marker schema per widget
- `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr` — first instrumentation target

— Architect (Claude Opus 4.7), interaction-contracts-harness v1, 2026-05-28
