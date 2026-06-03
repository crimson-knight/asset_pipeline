require "spec"
require "../../../../src/ui/renderers/stack_bake"

# Regression gate for the macOS VStack background bake. The native renderer
# (appkit_renderer.cr) is `{% if flag?(:macos) %}`-gated and cannot be exercised
# headlessly, so the bake-color DECISION lives in the pure UI::StackBake helper
# and is verified here. See UI::StackBake for the full rationale.
describe UI::StackBake do
  describe ".fallback_rgba (container VStack with no explicit background)" do
    it "is TRANSPARENT in the live app (no capture env) so the parent shows through" do
      # THE BUG: the live app previously baked opaque white here, turning every
      # nested background-less container (e.g. My Affirmations' list_container)
      # into a solid white block that hid its children.
      UI::StackBake.fallback_rgba(nil, nil).should eq({0.0, 0.0, 0.0, 0.0})
    end

    it "bakes an opaque LIGHT fill in the light-appearance capture path" do
      UI::StackBake.fallback_rgba(nil, "light").should eq({1.0, 1.0, 1.0, 1.0})
    end

    it "bakes an opaque DARK fill in the dark-appearance capture path" do
      UI::StackBake.fallback_rgba(nil, "dark").should eq({0.12, 0.12, 0.12, 1.0})
    end

    it "stays TRANSPARENT for glass-backdrop captures, even with an appearance set" do
      UI::StackBake.fallback_rgba("/tmp/backdrop.png", "light").should eq({0.0, 0.0, 0.0, 0.0})
      UI::StackBake.fallback_rgba("/tmp/backdrop.png", "dark").should eq({0.0, 0.0, 0.0, 0.0})
    end

    it "treats empty env strings as absent (live app), not as capture mode" do
      UI::StackBake.fallback_rgba("", "").should eq({0.0, 0.0, 0.0, 0.0})
    end
  end
end
