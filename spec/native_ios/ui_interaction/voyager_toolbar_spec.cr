# spec/native_ios/ui_interaction/voyager_toolbar_spec.cr
#
# V2 reproduction spec — Voyager overflow popover buttons.
#
# Reproduction path (post-merge surface):
#   1. Tap voyager-todos-overflow → opens UI::Popover anchored to button
#      (renders via PopoverFacade.AnchoredPopoverHost, NOT SwiftUI.popover)
#   2. Popover content has 3 buttons: voyager-overflow-sort,
#      voyager-overflow-hide-completed, voyager-overflow-clear-completed
#   3. Owner-reported V2: tapping any of these crashes app
#
# Codex review-v2 BLOCKER 2 fix: AnchoredPopoverHost now emits
# [APIC:Popover:present] markers (with path=anchored-uikit kv) so the
# V2 spec assertion lands on the correct code path.
#
# Crash + hang detection: heartbeat marker pattern. Strictly-newer
# heartbeat required after each tap.
#
# Per-id coordinate gating (Codex BLOCKER 3 fix).

require "./support/simulator_harness"

{% if flag?(:ios) %}
  include UI::InteractionContracts::Spec

  # Helpers (top-level — Crystal rejects def-inside-describe).
  private def heartbeat_count(sim) : Int32
    sim.snapshot_markers.count { |m| m.includes?("[APIC:VoyagerApp:heartbeat]") }
  end

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
    describe "V2 — overflow popover buttons must not crash or hang" do
      it "opening the overflow popover does not crash and emits present marker" do
        Harness.with_voyager(route: "voyager-todos") do |sim|
          unless sim.coords_captured?("voyager-todos-overflow")
            pending!("Required coordinate 'voyager-todos-overflow' not yet captured.")
          end

          prior = heartbeat_count(sim)
          sim.tap_accessibility_id("voyager-todos-overflow")

          # AnchoredPopoverHost now emits the present marker
          # (path=anchored-uikit) per Codex BLOCKER 2 fix.
          sim.wait_for_marker(
            "[APIC:Popover:present]",
            timeout: 2.seconds
          )

          assert_new_heartbeat(sim, prior)
        end
      end

      it "tapping sort INSIDE overflow popover does not crash" do
        Harness.with_voyager(route: "voyager-todos") do |sim|
          required = ["voyager-todos-overflow", "voyager-overflow-sort"]
          unless sim.coords_captured?(required)
            pending!("Required coordinates not yet captured: #{required.join(", ")}.")
          end

          sim.tap_accessibility_id("voyager-todos-overflow")
          sim.wait_for_marker("[APIC:Popover:present]", timeout: 2.seconds)

          prior = heartbeat_count(sim)
          sim.tap_accessibility_id("voyager-overflow-sort")
          assert_new_heartbeat(sim, prior)
        end
      end

      it "tapping hide-completed INSIDE overflow popover does not crash" do
        Harness.with_voyager(route: "voyager-todos") do |sim|
          required = ["voyager-todos-overflow", "voyager-overflow-hide-completed"]
          unless sim.coords_captured?(required)
            pending!("Required coordinates not yet captured: #{required.join(", ")}.")
          end

          sim.tap_accessibility_id("voyager-todos-overflow")
          sim.wait_for_marker("[APIC:Popover:present]", timeout: 2.seconds)

          prior = heartbeat_count(sim)
          sim.tap_accessibility_id("voyager-overflow-hide-completed")
          assert_new_heartbeat(sim, prior)
        end
      end

      it "tapping clear-completed INSIDE overflow popover does not crash" do
        Harness.with_voyager(route: "voyager-todos") do |sim|
          required = ["voyager-todos-overflow", "voyager-overflow-clear-completed"]
          unless sim.coords_captured?(required)
            pending!("Required coordinates not yet captured: #{required.join(", ")}.")
          end

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
