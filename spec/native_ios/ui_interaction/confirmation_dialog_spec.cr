# spec/native_ios/ui_interaction/confirmation_dialog_spec.cr
#
# V1 reproduction spec — UI::ConfirmationDialog (share action sheet).
#
# Per `presentation-lifecycle-contract.md` §"Today's known violations",
# V1 is: tapping the swipe-Share tile on a Voyager todo row opens the
# ConfirmationDialog share sheet, but the sheet immediately dismisses
# before the user can interact.
#
# Reproduction path (post-merge surface from polish):
#   1. Left-swipe row 1 → reveals trailing-edge action tiles
#   2. Tap Share tile (voyager-todo-row-1-share-tile)
#   3. :request_share controller sets state.pending_share_todo_id
#   4. Rerender wires UI::ConfirmationDialog (voyager-todos-share-sheet)
#      containing Copy/Print/Cancel actions
#   5. V1 symptom: sheet appears then immediately closes
#
# Codex review-v2 BLOCKER 1 fix: spec previously tapped row 1 directly
# which dispatches :edit_row (editor sheet path), not :request_share.
# Now uses the swipe-then-tap-share path via Harness's swipe_left helper.
#
# Per-id coordinate gating (Codex BLOCKER 3 fix): each example pends only
# if the SPECIFIC ids it needs are unrecorded. Other examples in the
# describe block still run with their own captured coords.

require "./support/simulator_harness"

{% if flag?(:ios) %}
  include UI::InteractionContracts::Spec

  describe "UI::ConfirmationDialog — interaction contracts" do
    describe "C1 — stays presented across Rerenders until explicit dismiss" do
      it "stays open when an unrelated Rerender fires" do
        Harness.with_voyager(route: "voyager-todos") do |sim|
          required = ["voyager-todo-row-1-swipe-start", "voyager-todo-row-1-swipe-end",
                      "voyager-todo-row-1-share-tile", "voyager-todo-row-1-check",
                      "voyager-todos-share-sheet-cancel"]
          unless sim.coords_captured?(required)
            pending!("Required coordinates not yet captured: #{required.join(", ")}. " \
                     "Run scripts/capture_tap_coordinates.sh.")
          end

          # Swipe-reveal trailing actions, then tap Share tile.
          sim.swipe_left("voyager-todo-row-1-swipe-start", "voyager-todo-row-1-swipe-end")
          sleep 300.milliseconds # allow swipe animation
          sim.tap_accessibility_id("voyager-todo-row-1-share-tile")

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
        Harness.with_voyager(route: "voyager-todos") do |sim|
          required = ["voyager-todo-row-1-swipe-start", "voyager-todo-row-1-swipe-end",
                      "voyager-todo-row-1-share-tile", "voyager-todos-share-sheet-cancel"]
          unless sim.coords_captured?(required)
            pending!("Required coordinates not yet captured: #{required.join(", ")}.")
          end

          sim.swipe_left("voyager-todo-row-1-swipe-start", "voyager-todo-row-1-swipe-end")
          sleep 300.milliseconds
          sim.tap_accessibility_id("voyager-todo-row-1-share-tile")

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
