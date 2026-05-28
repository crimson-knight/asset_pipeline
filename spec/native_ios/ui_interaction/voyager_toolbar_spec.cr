# spec/native_ios/ui_interaction/voyager_toolbar_spec.cr
#
# V2 reproduction spec — Voyager overflow popover buttons.
#
# Per `presentation-lifecycle-contract.md` §"Today's known violations",
# V2 was reported by the owner as "tapping the three buttons at the top
# crashed the app." Investigation of the polish branch (post-merge)
# reveals: the three buttons live INSIDE the overflow popover, not in
# the toolbar header. The reproduction path is:
#
#   1. Tap voyager-todos-overflow → opens UI::Popover anchored to button
#   2. Popover content: voyager-overflow-sort, voyager-overflow-hide-completed,
#      voyager-overflow-clear-completed
#   3. Tap any of those three → owner reported crash
#
# Crash + hang detection: heartbeat marker. Voyager emits
# `[APIC:VoyagerApp:heartbeat]` once per second from the main runloop.
# Spec asserts a strictly-newer heartbeat after each tap. Crashes stop
# heartbeats; hung runloops also stop heartbeats.
#
# Positive tap-reached assertion: the overflow trigger emits
# `[APIC:Popover:present]` when tapped successfully (Codex CONCERN 8 fix).

require "./support/simulator_harness"

{% if flag?(:ios) %}
  include UI::InteractionContracts::Spec

  # Helper — heartbeat counter (free function, NOT inside describe).
  private def heartbeat_count(sim) : Int32
    sim.snapshot_markers.count { |m| m.includes?("[APIC:VoyagerApp:heartbeat]") }
  end

  # Helper — fail if no STRICTLY NEW heartbeat after `prior_count`
  # within `window`. Detects crash + hung runloop in one assertion.
  private def assert_new_heartbeat(sim, prior_count : Int32, window : Time::Span = 2.seconds)
    deadline = Time.utc + window
    while Time.utc < deadline
      return if heartbeat_count(sim) > prior_count
      sleep 100.milliseconds
    end
    raise "V2 violation: no new heartbeat marker within #{window} after tap " \
          "(prior_count=#{prior_count}). Suspected crash or main-runloop hang."
  end

  describe "Voyager overflow popover — V2 interaction contracts" do
    scenario_path = File.join(__DIR__, "scenarios/voyager.yml")
    scenario_yaml = File.exists?(scenario_path) ? File.read(scenario_path) : ""
    coordinates_captured = scenario_yaml.includes?("captured: true")

    pending_reason = "Tap coordinates in scenarios/voyager.yml are placeholders. " \
                     "Run scripts/capture_tap_coordinates.sh to record real coordinates."

    describe "V2 — overflow popover buttons must not crash or hang" do
      it "opening the overflow popover does not crash" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "voyager-todos") do |sim|
          prior = heartbeat_count(sim)
          sim.tap_accessibility_id("voyager-todos-overflow")

          # Positive: tap reached the popover trigger.
          sim.wait_for_marker(
            "[APIC:Popover:present]",
            timeout: 2.seconds
          )

          assert_new_heartbeat(sim, prior)
        end
      end

      it "tapping sort INSIDE overflow popover does not crash" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "voyager-todos") do |sim|
          sim.tap_accessibility_id("voyager-todos-overflow")
          sim.wait_for_marker("[APIC:Popover:present]", timeout: 2.seconds)

          prior = heartbeat_count(sim)
          sim.tap_accessibility_id("voyager-overflow-sort")
          assert_new_heartbeat(sim, prior)
        end
      end

      it "tapping hide-completed INSIDE overflow popover does not crash" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "voyager-todos") do |sim|
          sim.tap_accessibility_id("voyager-todos-overflow")
          sim.wait_for_marker("[APIC:Popover:present]", timeout: 2.seconds)

          prior = heartbeat_count(sim)
          sim.tap_accessibility_id("voyager-overflow-hide-completed")
          assert_new_heartbeat(sim, prior)
        end
      end

      it "tapping clear-completed INSIDE overflow popover does not crash" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "voyager-todos") do |sim|
          sim.tap_accessibility_id("voyager-todos-overflow")
          sim.wait_for_marker("[APIC:Popover:present]", timeout: 2.seconds)

          prior = heartbeat_count(sim)
          sim.tap_accessibility_id("voyager-overflow-clear-completed")
          assert_new_heartbeat(sim, prior)
        end
      end
    end
  end
{% end %}
