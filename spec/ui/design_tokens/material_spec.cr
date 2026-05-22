require "../../spec_helper"
require "../../../src/ui/design_tokens"

describe UI::DesignTokens::Material do
  describe "#step" do
    it "returns the matching MaterialStep for each declared symbol" do
      m = UI::DesignTokens::Defaults.material
      m.step(:ultra_thin).blur_radius.should eq(10.0)
      m.step(:thin).blur_radius.should eq(20.0)
      m.step(:regular).blur_radius.should eq(30.0)
      m.step(:thick).blur_radius.should eq(40.0)
      m.step(:chrome).blur_radius.should eq(50.0)
    end

    it "falls back to :regular for unknown symbols" do
      m = UI::DesignTokens::Defaults.material
      m.step(:nonexistent_step).should eq(m.step(:regular))
    end
  end

  describe "#resolve" do
    it "scales blur_radius by intensity at the default 1.0" do
      m = UI::DesignTokens::Defaults.material
      resolved = m.resolve(:regular)
      resolved.blur_radius.should eq(30.0)
      resolved.opacity.should eq(0.60)
      resolved.saturation.should eq(1.15)
      resolved.name.should eq(:regular)
    end

    it "scales blur_radius by intensity at 1.3" do
      m = UI::DesignTokens::Defaults.material.copy_with(intensity: 1.3)
      m.resolve(:regular).blur_radius.should be_close(39.0, 1e-9)
      m.resolve(:thick).blur_radius.should be_close(52.0, 1e-9)
    end

    it "scales blur_radius by intensity at 0.5" do
      m = UI::DesignTokens::Defaults.material.copy_with(intensity: 0.5)
      m.resolve(:regular).blur_radius.should eq(15.0)
    end

    it "clamps intensity to [0.1, 3.0]" do
      m_low = UI::DesignTokens::Defaults.material.copy_with(intensity: 0.0)
      m_low.resolve(:regular).blur_radius.should eq(3.0)
      m_high = UI::DesignTokens::Defaults.material.copy_with(intensity: 10.0)
      m_high.resolve(:regular).blur_radius.should eq(90.0)
    end

    it "does NOT scale opacity, saturation, or luminance" do
      m = UI::DesignTokens::Defaults.material.copy_with(intensity: 2.0)
      m.resolve(:regular).opacity.should eq(0.60)
      m.resolve(:regular).saturation.should eq(1.15)
      m.resolve(:regular).luminance.should eq(0.0)
    end
  end

  describe "#apple_step (Apple quantization contract)" do
    it "honors the declared step at default intensity 1.0" do
      m = UI::DesignTokens::Defaults.material
      m.apple_step(:ultra_thin).should eq(:ultra_thin)
      m.apple_step(:thin).should eq(:thin)
      m.apple_step(:regular).should eq(:regular)
      m.apple_step(:thick).should eq(:thick)
      m.apple_step(:chrome).should eq(:chrome)
    end

    it "honors a non-:regular declared step regardless of intensity" do
      m = UI::DesignTokens::Defaults.material.copy_with(intensity: 1.5)
      m.apple_step(:thick).should eq(:thick)
      m.apple_step(:ultra_thin).should eq(:ultra_thin)
    end

    it "quantizes :regular declared step through the documented table" do
      # Per Phase 5 brief.yml adapter_cardinality row 1.
      base = UI::DesignTokens::Defaults.material
      base.copy_with(intensity: 0.2).apple_step(:regular).should eq(:ultra_thin)
      base.copy_with(intensity: 0.5).apple_step(:regular).should eq(:thin)
      base.copy_with(intensity: 1.0).apple_step(:regular).should eq(:regular)
      base.copy_with(intensity: 1.3).apple_step(:regular).should eq(:regular)
      base.copy_with(intensity: 1.5).apple_step(:regular).should eq(:thick)
      base.copy_with(intensity: 2.0).apple_step(:regular).should eq(:chrome)
    end
  end

  describe "brand override cascade" do
    it "exposes intensity via Tokens.with_brand without runtime mutation" do
      brand = TestGlassBrand.new
      tokens = UI::DesignTokens::Tokens.default.with_brand(brand)
      tokens.material.intensity.should eq(1.3)
      # Original Tokens.default is unchanged — copy_with returns a new instance.
      UI::DesignTokens::Tokens.default.material.intensity.should eq(1.0)
    end
  end
end

private class TestGlassBrand < UI::DesignTokens::Brand
  protected def override_material(material : UI::DesignTokens::Material) : UI::DesignTokens::Material
    material.copy_with(intensity: 1.3)
  end
end
