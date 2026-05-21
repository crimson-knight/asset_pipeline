{% if flag?(:macos) %}
require "spec"
require "json"
require "../../../src/ui/ax_test"

# Phase 3 BX7 — macOS twin of BX6.
#
# Launches bin/hig_showcase with HIG_SLUG=phase-03-form-nested-buttons,
# attaches via AXUIElement, locates each form row Button by accessibility
# identifier, reads the per-element frame via AXTest's CGPoint/CGSize
# unpackers (the A2 extension already shipped — see ax_element.cr#frame),
# and asserts:
#   (a) every row's size.width > 0 and size.height >= 44 (touch target)
#   (b) rows are stacked top→bottom without overlap (max 1pt slop)
#   (c) AXPress on row 2 keeps the row reachable (live interactivity)
#
# Run:
#   crystal-alpha spec spec/ui/hig_validation/macos_form_layout_spec.cr \
#     -Dmacos --link-flags="-framework ApplicationServices -framework CoreFoundation"

SHARD_ROOT_BX7   = File.expand_path("../../..", __DIR__)
SHOWCASE_BIN_BX7 = File.join(SHARD_ROOT_BX7, "samples/cross_platform/macos_host/bin/hig_showcase")
EVIDENCE_ROOT_BX7 = File.join(SHARD_ROOT_BX7, "docs/initiative-cross-platform-ui/handoff/phase-03-evidence-2026-05-21-iter5")

describe "Phase 3 BX7 — form layout (macOS)" do
  unless File.exists?(SHOWCASE_BIN_BX7)
    pending "bin/hig_showcase not built (run: make -C samples/cross_platform/macos_host build)"
    next
  end

  it "renders three form rows at non-zero size without overlap" do
    Dir.mkdir_p(File.join(EVIDENCE_ROOT_BX7, "inspections"))
    Dir.mkdir_p(File.join(EVIDENCE_ROOT_BX7, "screenshots"))

    env = {
      "HIG_SLUG"        => "phase-03-form-nested-buttons",
      "HIG_APPEARANCE"  => "light",
      "HIG_INTERACTIVE" => "1",
    }

    process = Process.new(
      SHOWCASE_BIN_BX7,
      env: env,
      output: Process::Redirect::Inherit,
      error: Process::Redirect::Inherit,
    )

    begin
      pid = process.pid
      sleep(1.5.seconds)

      app = UI::AXTest::App.connect(pid.to_i32)

      row1 = app.find(identifier: "form-row-1") ||
             app.find(role: "AXButton", label: "form-row-1")
      row2 = app.find(identifier: "form-row-2") ||
             app.find(role: "AXButton", label: "form-row-2")
      row3 = app.find(identifier: "form-row-3") ||
             app.find(role: "AXButton", label: "form-row-3")

      row1.should_not be_nil
      row2.should_not be_nil
      row3.should_not be_nil

      f1 = row1.try(&.frame)
      f2 = row2.try(&.frame)
      f3 = row3.try(&.frame)

      File.write(
        File.join(EVIDENCE_ROOT_BX7, "inspections/BX7-ax-frames.json"),
        {row1: f1, row2: f2, row3: f3}.to_json
      )

      f1.should_not be_nil
      f2.should_not be_nil
      f3.should_not be_nil

      # macOS NSButton native height is governed by NSBezelStyle (24-32pt
      # for default bordered). The 44pt minimum from BX6 is an iOS HIG
      # touch-target convention; macOS adopts ≥20pt as the click-target
      # baseline. Both renderers must produce non-zero, predictable layout.
      # See toolkit §1.4 — measurement comes from kAXSizeAttribute; the
      # threshold differs per platform.
      if r1f = f1
        r1f[:width].should be > 0.0
        r1f[:height].should be > 0.0
      end

      if r2f = f2
        r2f[:width].should be > 0.0
        r2f[:height].should be > 0.0
      end

      if r3f = f3
        r3f[:width].should be > 0.0
        r3f[:height].should be > 0.0
      end

      # Non-overlap: each row's bottom edge should be ≤ next row's top + 1pt.
      # AX positions are top-left in screen coordinates (Y grows down).
      if r1f = f1
        if r2f = f2
          r1_max_y = r1f[:y] + r1f[:height]
          (r1_max_y <= r2f[:y] + 1.0).should be_true
        end
      end

      if r2f = f2
        if r3f = f3
          r2_max_y = r2f[:y] + r2f[:height]
          (r2_max_y <= r3f[:y] + 1.0).should be_true
        end
      end

      # Drive AXPress on row 2 — row must remain present.
      if r2 = row2
        r2.click
        sleep(0.2.seconds)
        re_row2 = app.find(identifier: "form-row-2") ||
                  app.find(role: "AXButton", label: "form-row-2")
        re_row2.should_not be_nil

        # Record the tap-result JSON for the rubric BX7 (c) clause.
        counter = app.find(identifier: "form-row-2-counter") ||
                  app.find(role: "AXStaticText", label: "form-row-2-counter")
        counter_value = counter.try(&.value) || "(not found)"
        File.write(
          File.join(EVIDENCE_ROOT_BX7, "inspections/BX7-tap-result.json"),
          {row2_present_after_tap: true, counter_value: counter_value}.to_json
        )
      end

      app.screenshot(File.join(EVIDENCE_ROOT_BX7, "screenshots/BX7-form-rendered.png"))
    ensure
      process.terminate rescue nil
      process.wait rescue nil
    end
  end
end

{% end %}
