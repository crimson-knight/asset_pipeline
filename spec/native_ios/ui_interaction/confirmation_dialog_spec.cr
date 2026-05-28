# spec/native_ios/ui_interaction/confirmation_dialog_spec.cr
#
# Interaction contracts for UI::ConfirmationDialog. Reproduces V1 from
# docs/initiative-cross-platform-ui/architecture/presentation-lifecycle-contract.md
# ("UI::ConfirmationDialog auto-closes on Voyager todo row tap") as a
# failing regression test, then asserts the C3 dismissal-token flow.
#
# Both specs run against the iOS simulator via the harness defined at
# spec/native_ios/ui_interaction/support/simulator_harness.cr.
#
# Prerequisite — Voyager .app bundle must be at
#   APIC_APP_BUNDLE_ROOT/Voyager.app
# (default: tmp/interaction-contracts/bundles/Voyager.app).
#
# A simulator matching APIC_DEVICE / APIC_RUNTIME must be booted.
#
# The first time these run, the scenario coordinates in
# spec/native_ios/ui_interaction/scenarios/voyager.yml are PLACEHOLDERS —
# examples pend until coordinates are captured. See
# scripts/capture_tap_coordinates.sh (Phase 12.A follow-up).

require "./support/simulator_harness"

{% if flag?(:ios) %}
  include UI::InteractionContracts::Spec

  describe "UI::ConfirmationDialog — interaction contracts" do
    # Guard: skip until tap coordinates are captured. The harness can't
    # honestly assert anything when taps land at placeholder pixels.
    scenario_path = File.join(__DIR__, "scenarios/voyager.yml")
    scenario_yaml = File.exists?(scenario_path) ? File.read(scenario_path) : ""
    coordinates_captured = scenario_yaml.includes?("captured: true")

    pending_reason = "Voyager tap-coordinate scenario contains only placeholders. " \
                     "Run scripts/capture_tap_coordinates.sh to record real coordinates."

    describe "C1 — stays presented across Rerenders until explicit dismiss" do
      it "stays open when an unrelated Rerender fires" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          # Trigger the V1 path: tap a todo row, which dispatches the
          # row-tap controller action that opens the editor's action sheet.
          sim.tap_accessibility_id("voyager-todos-row-1")

          sim.wait_for_marker(
            "[APIC:ConfirmationDialog:present]",
            timeout: 2.seconds
          )

          # Trigger an unrelated Rerender by toggling something on the
          # settings screen that doesn't touch action-sheet state.
          # Note: this requires routing to settings without dismissing the
          # action sheet — V1's behavior under test.
          sim.tap_accessibility_id("voyager-settings-noop-rerender")

          # C1 invariant: no platform-dismissed marker between
          # present and our dismissal trigger.
          sim.assert_no_marker(
            "[APIC:ConfirmationDialog:platform-dismissed]",
            window: 500.milliseconds
          )

          # Explicit dismissal via cancel.
          sim.tap_accessibility_id("voyager-action-sheet-cancel")

          sim.wait_for_marker(
            "[APIC:ConfirmationDialog:dismiss-token-fire]",
            timeout: 1.second
          )
        end
      end
    end

    describe "C3 — dismissal flows through dismissToken, not binding-read" do
      it "fires dismissToken before platform-dismissed; no binding-read during Rerender" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          sim.tap_accessibility_id("voyager-todos-row-1-share")

          sim.wait_for_marker(
            "[APIC:ConfirmationDialog:present]",
            timeout: 2.seconds
          )

          sim.tap_accessibility_id("voyager-action-sheet-cancel")

          sim.wait_for_marker(
            "[APIC:ConfirmationDialog:dismiss-token-fire]",
            timeout: 1.second
          )
          sim.wait_for_marker(
            "[APIC:ConfirmationDialog:platform-dismissed]",
            timeout: 1.second
          )

          sim.assert_marker_order(
            "[APIC:ConfirmationDialog:dismiss-token-fire]",
            "[APIC:ConfirmationDialog:platform-dismissed]"
          )

          # C2 corollary: no binding-read marker emitted during a Rerender pass.
          sim.snapshot_markers.each do |marker|
            if marker.includes?("[APIC:ConfirmationDialog:binding-read]") &&
               marker.includes?("during-rerender=true")
              fail "C2 violation: binding-read during Rerender pass: #{marker}"
            end
          end
        end
      end
    end
  end
{% end %}
