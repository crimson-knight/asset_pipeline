require "spec"
require "../../../src/ui"

# Phase B — UI::Fluid native (points) resolution. These feed the native
# renderers' existing min/max width constraint pins (additive; see
# foundational-output-and-layout-model.md Principle 2).
describe UI::Fluid do
  describe "native px resolution" do
    it "resolves px min/ideal/max to points" do
      f = UI::Fluid.px(320, 400, 480)
      f.native_min_px.should eq 320.0
      f.native_ideal_px.should eq 400.0
      f.native_max_px.should eq 480.0
    end

    it "resolves rem to points at 1rem = 16px" do
      f = UI::Fluid.new(min: "20rem", ideal: "30rem", max: "40rem")
      f.native_min_px.should eq 320.0
      f.native_ideal_px.should eq 480.0
      f.native_max_px.should eq 640.0
    end

    it "returns nil for viewport-relative ideal (native uses the min/max range)" do
      f = UI::Fluid.vw(320, 60, 480) # ideal = 60vw
      f.native_min_px.should eq 320.0
      f.native_max_px.should eq 480.0
      f.native_ideal_px.should be_nil
    end

    it "returns nil for non-fixed units / junk" do
      UI::Fluid.parse_native_px("60vw").should be_nil
      UI::Fluid.parse_native_px("100%").should be_nil
      UI::Fluid.parse_native_px("calc(100% - 20px)").should be_nil
      UI::Fluid.parse_native_px("auto").should be_nil
    end

    it "tolerates whitespace and case" do
      UI::Fluid.parse_native_px("  480PX ").should eq 480.0
      UI::Fluid.parse_native_px("12.5px").should eq 12.5
    end

    it "still renders clamp() on web (unchanged)" do
      UI::Fluid.px(320, 400, 480).to_css.should eq "clamp(320px, 400px, 480px)"
    end
  end
end
