# spec/native_ios/ui_interaction/confirmation_dialog_spec.cr
#
# V1 reproduction spec — UI::ConfirmationDialog (share action sheet).
#
# Per `presentation-lifecycle-contract.md` §"Today's known violations",
# V1 is: tapping a Voyager todo row's Share swipe-action opens the
# ConfirmationDialog share sheet, but the sheet immediately dismisses
# before the user can interact.
#
# Post-Phase-12.B-merge surface (from polish):
#   - Share is a swipe-action on each todo row
#   - Tapping Share fires `:request_share` which sets
#     state.pending_share_todo_id
#   - The screen rerenders and wires a UI::ConfirmationDialog
#     (test_id: voyager-todos-share-sheet) containing Copy/Print/Cancel
#   - V1 symptom: sheet appears then immediately closes
#
# The spec uses the heartbeat-marker pattern to detect a crash/hang
# during the test (Codex Phase 12.A BLOCKER 3 + CONCERN 9 fix), and
# asserts:
#   C1 — once present, sheet stays presented across an unrelated Rerender
#        until an explicit dismissal action.
#   C3 — explicit cancel fires `binding-write-false` (ConfirmationDialog
#        uses BoolStorage token=0; dismiss flows via confirm/cancel tokens
#        not BoolStorage token, so we assert binding-write-false NOT
#        dismiss-token-fire).
#
# Spec pends until tap coordinates are captured. Without coordinates the
# placeholder pixels would tap nowhere meaningful.

require "./support/simulator_harness"

{% if flag?(:ios) %}
  include UI::InteractionContracts::Spec

  describe "UI::ConfirmationDialog — interaction contracts" do
    scenario_path = File.join(__DIR__, "scenarios/voyager.yml")
    scenario_yaml = File.exists?(scenario_path) ? File.read(scenario_path) : ""
    coordinates_captured = scenario_yaml.includes?("captured: true")

    pending_reason = "Tap coordinates in scenarios/voyager.yml are placeholders. " \
                     "Run scripts/capture_tap_coordinates.sh to record real coordinates."

    describe "C1 — stays presented across Rerenders until explicit dismiss" do
      it "stays open when an unrelated Rerender fires" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "voyager-todos") do |sim|
          # Trigger V1's hypothetical failure path. The Share swipe tile
          # fires :request_share → sets pending_share_todo_id → screen
          # rerenders with the share_sheet ConfirmationDialog present.
          sim.tap_accessibility_id("voyager-todo-row-1-tap")

          # Note: capturing the swipe→Share gesture requires multi-step
          # coordinate capture. Until then the spec is recorded as a
          # placeholder for the future expanded capture.
          sim.wait_for_marker(
            "[APIC:ConfirmationDialog:present]",
            timeout: 2.seconds
          )

          # Trigger an unrelated Rerender by toggling the
          # mark-completed checkbox on a different row.
          sim.tap_accessibility_id("voyager-todo-row-1-check")

          # C1 invariant: no platform-dismissed marker between present
          # and our explicit dismissal trigger.
          sim.assert_no_marker(
            "[APIC:ConfirmationDialog:platform-dismissed]",
            window: 500.milliseconds
          )

          # Explicit dismissal via Cancel.
          sim.tap_accessibility_id("voyager-todos-share-sheet-cancel")

          # ConfirmationDialog token=0 → binding-write-false, NOT
          # dismiss-token-fire.
          sim.wait_for_marker(
            "[APIC:ConfirmationDialog:binding-write-false]",
            timeout: 1.second
          )
        end
      end
    end

    describe "C3 — dismissal flows through the binding write path" do
      it "fires binding-write-false before platform-dismissed" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "voyager-todos") do |sim|
          sim.tap_accessibility_id("voyager-todo-row-1-tap")

          sim.wait_for_marker(
            "[APIC:ConfirmationDialog:present]",
            timeout: 2.seconds
          )

          sim.tap_accessibility_id("voyager-todos-share-sheet-cancel")

          sim.wait_for_marker(
            "[APIC:ConfirmationDialog:binding-write-false]",
            timeout: 1.second
          )
          sim.wait_for_marker(
            "[APIC:ConfirmationDialog:platform-dismissed]",
            timeout: 1.second
          )

          sim.assert_marker_order(
            "[APIC:ConfirmationDialog:binding-write-false]",
            "[APIC:ConfirmationDialog:platform-dismissed]"
          )
        end
      end
    end
  end
{% end %}
