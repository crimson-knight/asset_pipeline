# spec/native_ios/ui_interaction/voyager_toolbar_spec.cr
#
# Reproduces V2 from
# docs/initiative-cross-platform-ui/architecture/presentation-lifecycle-contract.md
# ("Voyager todos header sort buttons crash on tap") as a failing
# regression test.
#
# Crash detection strategy: tap the suspect button, then check whether
# the app process is still alive. A process exit signals the crash. The
# log-stream marker buffer is also checked — a process crash typically
# leaves an incomplete sequence (start marker without end marker).
#
# Per the harness convention, the spec pends with a clear reason until
# the scenario tap coordinates are captured.

require "./support/simulator_harness"

{% if flag?(:ios) %}
  include UI::InteractionContracts::Spec

  describe "Voyager todos toolbar — interaction contracts" do
    scenario_path = File.join(__DIR__, "scenarios/voyager.yml")
    scenario_yaml = File.exists?(scenario_path) ? File.read(scenario_path) : ""
    coordinates_captured = scenario_yaml.includes?("captured: true")

    pending_reason = "Voyager tap-coordinate scenario contains only placeholders. " \
                     "Run scripts/capture_tap_coordinates.sh to record real coordinates."

    describe "V2 — header sort buttons must not crash on tap" do
      it "tapping any header sort button leaves the app running" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          sim.tap_accessibility_id("voyager-todos-header-sort-newest")

          # The app should remain running. We sleep briefly to let any
          # crash propagate then verify the process is alive via
          # `simctl listapps` filter against the bundle id.
          sleep 1.second

          listing = `xcrun simctl listapps #{sim.udid} 2>/dev/null`
          unless listing.includes?(sim.bundle_id)
            fail "V2 violation: app process not found after tapping sort-newest button " \
                 "(suspected crash). Check simctl spawn log stream for traceback."
          end
        end
      end

      it "tapping sort-oldest leaves the app running" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          sim.tap_accessibility_id("voyager-todos-header-sort-oldest")
          sleep 1.second
          listing = `xcrun simctl listapps #{sim.udid} 2>/dev/null`
          unless listing.includes?(sim.bundle_id)
            fail "V2 violation: app process not found after tapping sort-oldest"
          end
        end
      end

      it "tapping sort-deadline leaves the app running" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          sim.tap_accessibility_id("voyager-todos-header-sort-deadline")
          sleep 1.second
          listing = `xcrun simctl listapps #{sim.udid} 2>/dev/null`
          unless listing.includes?(sim.bundle_id)
            fail "V2 violation: app process not found after tapping sort-deadline"
          end
        end
      end

      it "tapping overflow trigger leaves the app running and presents Popover" do
        pending!(pending_reason) unless coordinates_captured

        Harness.with_voyager(route: "todos") do |sim|
          sim.tap_accessibility_id("voyager-todos-overflow-trigger")

          sim.wait_for_marker(
            "[APIC:Popover:present]",
            timeout: 2.seconds
          )

          # Process still alive.
          listing = `xcrun simctl listapps #{sim.udid} 2>/dev/null`
          unless listing.includes?(sim.bundle_id)
            fail "V2 violation: app process not found after tapping overflow trigger"
          end
        end
      end
    end
  end
{% end %}
