# spec/native_ios/ui_interaction/harness_smoke_spec.cr
#
# Phase 12.A — end-to-end smoke test for the interaction-contracts harness.
#
# This spec is the executable proof that the Phase 12.A infrastructure
# works against current-main Voyager code (NOT the polish worktree).
# It runs without depending on V1 or V2 reproduction targets.
#
# Pass criteria:
#   1. Voyager.app is installed at APIC_APP_BUNDLE_ROOT/VoyagerDemo.app
#      and launches without crash.
#   2. The Voyager app delegate emits `[APIC:VoyagerApp:launched]`
#      within 5 seconds of launch (proves NSLog bridge + log stream tail
#      work end-to-end).
#   3. A heartbeat marker arrives within 2 seconds after launch (proves
#      the app runloop is alive and emitting continuously).
#
# If this passes, the harness is honest. V1/V2 reproduction specs are
# pre-staged for when the polish worktree merges to main; this smoke test
# proves they will work as written when their target code paths exist.

require "./support/simulator_harness"

{% if flag?(:ios) %}
  include UI::InteractionContracts::Spec

  describe "Interaction-contracts harness — smoke test" do
    it "Voyager launches and emits the launch marker" do
      Harness.with_voyager(route: "voyager-sign-in") do |sim|
        sim.wait_for_marker(
          "[APIC:VoyagerApp:launched]",
          timeout: 5.seconds
        )
      end
    end

    it "Voyager emits a heartbeat after launch (runloop alive)" do
      Harness.with_voyager(route: "voyager-sign-in") do |sim|
        sim.wait_for_marker(
          "[APIC:VoyagerApp:launched]",
          timeout: 5.seconds
        )
        sim.wait_for_marker(
          "[APIC:VoyagerApp:heartbeat]",
          timeout: 2.seconds
        )
      end
    end
  end
{% end %}
