require "../../spec_helper"
require "../../../src/ui/design_tokens"

# Phase 5 probe placeholder — slug `macos.glass.material.default`.
#
# Mirror of `ios_glass_default_spec.cr` for macOS via the AppKit renderer +
# AXTest harness. Same `pending` semantics; Phase 6.5 harness work runs the
# bodies.
#
# AX identifier convention: `ap.glass.<step>.intensity_<intensity_x100>`.
describe "Phase 5 probe: macos.glass.material.default" do
  [:ultra_thin, :thin, :regular, :thick, :chrome].each do |step|
    pending "renders SwiftUI Material `#{step}` at the per-step default blur on macOS" do
      # Expected shape (Phase 6.5 will implement):
      #   tokens = UI::DesignTokens::Tokens.default
      #   app = UI::AXTest::App.launch(MACOS_GLASS_FIXTURE_APP)
      #   screen = app.window("Glass Material Default — #{step}")
      #   elem = screen.find(identifier: "ap.glass.#{step}.intensity_100")
      #   elem.should_not be_nil
      #   visual = app.capture_glass_material(elem)
      #   visual.material_enum.should eq(tokens.material.apple_step(:#{step}))
      #   app.screenshot("/tmp/p5-macos-#{step}.png")
      #   visual_diff("/tmp/p5-macos-#{step}.png", "fixtures/p5-macos-#{step}-baseline.png").should be_within_tolerance
    end
  end
end
