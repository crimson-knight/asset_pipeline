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
# Crash detection (Codex Phase 12.A BLOCKER 3 fix): replaces the original
# `simctl listapps` check (which reports installed apps, not process
# liveness — false negative factory) with a heartbeat-marker assertion.
# Voyager emits `[APIC:VoyagerApp:heartbeat]` once per second from the
# main runloop. A crash kills heartbeats; a hung runloop also kills
# heartbeats. The spec asserts at least one fresh heartbeat arrives
# AFTER the tap.

require "./support/simulator_harness"

{% if flag?(:ios) %}
  include UI::InteractionContracts::Spec

  describe "Voyager todos toolbar — interaction contracts" do
    scenario_path = File.join(__DIR__, "scenarios/voyager.yml")
    scenario_yaml = File.exists?(scenario_path) ? File.read(scenario_path) : ""
    coordinates_captured = scenario_yaml.includes?("captured: true")

    pending_reason = "V2 target code lives in phase-10-d-polish worktree and is not " \
                     "present in main; tap coordinates are also placeholders. Spec " \
                     "becomes executable when both prerequisites are resolved."

    # Helper — fails if a fresh heartbeat doesn't arrive within `window`
    # of `since`. Honest crash + hang detection.
    def self.assert_runloop_alive(sim, since : Time, window : Time::Span = 2.seconds)
      deadline = Time.utc + window
      while Time.utc < deadline
        snap = sim.snapshot_markers
        fresh_heartbeat = snap.find do |m|
          m.includes?("[APIC:VoyagerApp:heartbeat]")
        end
        # We can't compare timestamps without parsing the marker tick field;
        # the test relies on a per-test cleared buffer + a window large
        # enough to catch the next heartbeat after the tap.
        return if fresh_heartbeat
        sleep 100.milliseconds
      end
      raise "V2 violation: no heartbeat marker arrived within #{window} after tap " \
            "(suspected crash or main-runloop hang)"
    end

    describe "V2 — header sort buttons must not crash or hang" do
      it "tapping sort-newest leaves the runloop alive (fresh heartbeat arrives)" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          # Clear the heartbeat buffer so we only see post-tap heartbeats.
          sim.clear_markers
          tap_time = Time.utc
          sim.tap_accessibility_id("voyager-todos-header-sort-newest")
          assert_runloop_alive(sim, tap_time)
        end
      end

      it "tapping sort-oldest leaves the runloop alive" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          sim.clear_markers
          tap_time = Time.utc
          sim.tap_accessibility_id("voyager-todos-header-sort-oldest")
          assert_runloop_alive(sim, tap_time)
        end
      end

      it "tapping sort-deadline leaves the runloop alive" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          sim.clear_markers
          tap_time = Time.utc
          sim.tap_accessibility_id("voyager-todos-header-sort-deadline")
          assert_runloop_alive(sim, tap_time)
        end
      end

      it "tapping overflow trigger leaves the runloop alive and presents Popover" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          sim.clear_markers
          tap_time = Time.utc
          sim.tap_accessibility_id("voyager-todos-overflow-trigger")

          # The Popover present marker must fire (positive assertion that
          # the tap reached the intended action — Codex CONCERN 8 fix).
          sim.wait_for_marker(
            "[APIC:Popover:present]",
            timeout: 2.seconds
          )

          assert_runloop_alive(sim, tap_time)
        end
      end
    end
  end
{% end %}
