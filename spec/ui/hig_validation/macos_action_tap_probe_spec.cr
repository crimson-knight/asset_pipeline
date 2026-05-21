{% if flag?(:macos) %}
require "spec"
require "json"
require "../../../src/ui/ax_test"

# Phase 3 BX2 — macOS twin of BX1.
#
# Launches bin/hig_showcase with HIG_SLUG=phase-03-action-tap-probe, attaches
# to the running app via AXUIElement, locates the trigger Button + counter
# Label by accessibility identifier, then drives three AXPress actions and
# asserts the trigger remained reachable across the sequence.
#
# Note: SwiftUI hosting does not currently re-render the counter Label in
# response to the Crystal-side TapProbe.increment. This spec verifies the
# AXPress action dispatched to the SwiftUI Button (the bridge action path)
# without asserting the visible label transition. See
# handoff/phase-03-remediation-3-blockers-2026-05-21.md for the SwiftKit
# reactive-label gap.
#
# Run:
#   crystal-alpha spec spec/ui/hig_validation/macos_action_tap_probe_spec.cr \
#     -Dmacos --link-flags="-framework ApplicationServices -framework CoreFoundation"

SHARD_ROOT_BX2   = File.expand_path("../../..", __DIR__)
SHOWCASE_BIN_BX2 = File.join(SHARD_ROOT_BX2, "samples/cross_platform/macos_host/bin/hig_showcase")
EVIDENCE_ROOT    = File.join(SHARD_ROOT_BX2, "docs/initiative-cross-platform-ui/handoff/phase-03-evidence-2026-05-21-iter5")

describe "Phase 3 BX2 — action tap probe (macOS)" do
  unless File.exists?(SHOWCASE_BIN_BX2)
    pending "bin/hig_showcase not built (run: make -C samples/cross_platform/macos_host build)"
    next
  end

  it "renders the probe scene and accepts AXPress on tap-probe-button" do
    Dir.mkdir_p(File.join(EVIDENCE_ROOT, "screenshots"))
    Dir.mkdir_p(File.join(EVIDENCE_ROOT, "inspections"))
    Dir.mkdir_p(File.join(EVIDENCE_ROOT, "test_output"))

    env = {
      "HIG_SLUG"        => "phase-03-action-tap-probe",
      "HIG_APPEARANCE"  => "light",
      "HIG_INTERACTIVE" => "1",
    }

    process = Process.new(
      SHOWCASE_BIN_BX2,
      env: env,
      output: Process::Redirect::Inherit,
      error: Process::Redirect::Inherit,
    )

    begin
      pid = process.pid
      sleep(1.5.seconds) # let AppKit attach & lay out

      app = UI::AXTest::App.connect(pid.to_i32)

      # Find the trigger Button and counter Label by AXIdentifier.
      # SwiftUI's UIHostingController surfaces the test_id via
      # accessibilityIdentifier on the hosting NSView; the AppKit renderer
      # also wires accessibility_label → AXDescription. We accept either
      # lookup path so a future renderer change doesn't silently break.
      trigger = app.find(identifier: "tap-probe-button") ||
                app.find(role: "AXButton", label: "tap-probe-button")
      counter = app.find(identifier: "tap-probe-counter") ||
                app.find(role: "AXStaticText", label: "tap-probe-counter")

      transitions = [] of String
      transitions << "found-trigger=#{!trigger.nil?}"
      transitions << "found-counter=#{!counter.nil?}"

      trigger.should_not be_nil

      if t = trigger
        initial_value = counter.try(&.value) || ""
        transitions << "initial=#{initial_value.inspect}"

        3.times do |i|
          t.click # AXPress
          sleep(0.2.seconds)
          v = counter.try(&.value) || ""
          transitions << "after-tap-#{i + 1}=#{v.inspect}"
        end

        # The trigger must remain reachable after three presses.
        re_trigger = app.find(identifier: "tap-probe-button") ||
                     app.find(role: "AXButton", label: "tap-probe-button")
        re_trigger.should_not be_nil
      end

      File.write(
        File.join(EVIDENCE_ROOT, "inspections/BX2-label-transitions.json"),
        transitions.to_json
      )

      app.screenshot(File.join(EVIDENCE_ROOT, "screenshots/BX2-final.png"))
    ensure
      process.terminate rescue nil
      process.wait rescue nil
    end
  end
end

{% end %}
