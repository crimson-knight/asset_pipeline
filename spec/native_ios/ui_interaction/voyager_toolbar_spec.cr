# spec/native_ios/ui_interaction/voyager_toolbar_spec.cr
#
# Forward-looking V2 reproduction spec.
#
# Per `docs/initiative-cross-platform-ui/architecture/presentation-lifecycle-contract.md`
# §"V1/V2 source-of-truth location", V2 manifested against the
# `phase-10-d-polish` worktree's todos screen (which has sort filters in
# the header + an overflow popover). The main checkout of
# `phase-10-d-refocus` does NOT contain that code — `todos_screen.cr`
# header has only Print + Settings buttons.
#
# This spec is pre-staged for the polish-worktree merge.
#
# Crash + hang detection (Codex Phase 12.A BLOCKER 3 + CONCERN 9 fix):
# replaces the original `simctl listapps` check with a heartbeat-marker
# assertion. Voyager emits `[APIC:VoyagerApp:heartbeat]` once per second
# from the main runloop. A crash kills heartbeats; a hung runloop also
# kills heartbeats. The spec asserts a STRICTLY NEWER heartbeat arrives
# after the tap by counting markers before/after.
#
# Codex verification pass BLOCKER NEW fix: the assert_runloop_alive
# helper is a top-level function (NOT inside describe — Crystal rejects
# def-inside-describe as "can't declare def dynamically").

require "./support/simulator_harness"

{% if flag?(:ios) %}
  include UI::InteractionContracts::Spec

  # Helper — fail if no new heartbeat arrives after `prior_heartbeat_count`
  # within `window`. Codex verification CONCERN 9 fix: requires a STRICTLY
  # NEW heartbeat (count increased), not just any heartbeat in the buffer.
  private def assert_new_heartbeat(sim, prior_heartbeat_count : Int32, window : Time::Span = 2.seconds)
    deadline = Time.utc + window
    while Time.utc < deadline
      now_count = sim.snapshot_markers.count do |m|
        m.includes?("[APIC:VoyagerApp:heartbeat]")
      end
      return if now_count > prior_heartbeat_count
      sleep 100.milliseconds
    end
    raise "V2 violation: no new heartbeat marker arrived within #{window} after tap " \
          "(prior count=#{prior_heartbeat_count}). Suspected crash or main-runloop hang."
  end

  # Helper — current heartbeat count.
  private def heartbeat_count(sim) : Int32
    sim.snapshot_markers.count { |m| m.includes?("[APIC:VoyagerApp:heartbeat]") }
  end

  describe "Voyager todos toolbar — interaction contracts" do
    scenario_path = File.join(__DIR__, "scenarios/voyager.yml")
    scenario_yaml = File.exists?(scenario_path) ? File.read(scenario_path) : ""
    coordinates_captured = scenario_yaml.includes?("captured: true")

    pending_reason = "V2 target code lives in phase-10-d-polish worktree and is not " \
                     "present in main; tap coordinates are also placeholders. Spec " \
                     "becomes executable when both prerequisites are resolved."

    describe "V2 — header sort buttons must not crash or hang" do
      it "tapping sort-newest leaves the runloop alive (strictly new heartbeat arrives)" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          prior = heartbeat_count(sim)
          sim.tap_accessibility_id("voyager-todos-header-sort-newest")
          assert_new_heartbeat(sim, prior)
        end
      end

      it "tapping sort-oldest leaves the runloop alive" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          prior = heartbeat_count(sim)
          sim.tap_accessibility_id("voyager-todos-header-sort-oldest")
          assert_new_heartbeat(sim, prior)
        end
      end

      it "tapping sort-deadline leaves the runloop alive" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          prior = heartbeat_count(sim)
          sim.tap_accessibility_id("voyager-todos-header-sort-deadline")
          assert_new_heartbeat(sim, prior)
        end
      end

      it "tapping overflow trigger presents Popover and leaves runloop alive" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          prior = heartbeat_count(sim)
          sim.tap_accessibility_id("voyager-todos-overflow-trigger")

          # Positive assertion: tap reached the popover (CONCERN 8 fix).
          sim.wait_for_marker(
            "[APIC:Popover:present]",
            timeout: 2.seconds
          )

          assert_new_heartbeat(sim, prior)
        end
      end
    end
  end
{% end %}
