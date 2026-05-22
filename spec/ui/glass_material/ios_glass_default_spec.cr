require "../../spec_helper"
require "../../../src/ui/design_tokens"

# Phase 5 probe placeholder — slug `ios.glass.material.default`.
#
# Verifies per-material-step visual baseline on iOS. The body is `pending`
# until Phase 6.5 ships the audit harness (visual diff + screenshot capture)
# referenced from this slug. The AX identifier convention captured here is
# the contract Phase 6.5 will hook into:
#
#   ap.glass.<step>.intensity_<intensity_x100>
#
# At default intensity 1.0 each step's identifier therefore reads
# `ap.glass.ultra_thin.intensity_100`, `ap.glass.thin.intensity_100`, etc.
#
# The pending assertion shape below documents what the Phase 6.5 harness
# will verify once it runs.
describe "Phase 5 probe: ios.glass.material.default" do
  [:ultra_thin, :thin, :regular, :thick, :chrome].each do |step|
    pending "renders SwiftUI Material `#{step}` at the per-step default blur" do
      # Expected shape (Phase 6.5 will implement):
      #   tokens = UI::DesignTokens::Tokens.default
      #   app = UI::AXTest::App.launch(IOS_GLASS_FIXTURE_APP)
      #   screen = app.window("Glass Material Default — #{step}")
      #   elem = screen.find(identifier: "ap.glass.#{step}.intensity_100")
      #   elem.should_not be_nil
      #   captured = capture_render(elem)
      #   captured.blur_radius.should be_close(
      #     tokens.material.resolve(:#{step}).blur_radius, 0.5)
      #   captured.material_enum.should eq("#{step}".to_apple_material_case)
      #   app.screenshot("/tmp/p5-#{step}.png")
      #   visual_diff("/tmp/p5-#{step}.png", "fixtures/p5-#{step}-baseline.png").should be_within_tolerance
    end
  end
end
