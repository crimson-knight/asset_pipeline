require "spec"
require "../../../../src/ui/renderers/stack_bake"

# Regression gate for the macOS VStack background bake. The native renderer
# (appkit_renderer.cr) is `{% if flag?(:macos) %}`-gated and cannot be exercised
# headlessly, so the bake-color DECISION lives in the pure UI::StackBake helper
# and is verified here. See UI::StackBake for the full rationale.
describe UI::StackBake do
  describe ".capturing? (offscreen-capture detection)" do
    it "is false for a live app (no screenshot-path env set)" do
      UI::StackBake.capturing?([nil, nil] of String?).should be_false
    end

    it "is true when HIG_SCREENSHOT_PATH is set" do
      UI::StackBake.capturing?(["/tmp/out.png", nil] of String?).should be_true
    end

    it "is true when VOYAGER_SCREENSHOT_PATH is set" do
      UI::StackBake.capturing?([nil, "/tmp/voyager.png"] of String?).should be_true
    end

    it "treats empty strings as absent (not capturing)" do
      UI::StackBake.capturing?(["", ""] of String?).should be_false
    end
  end

  describe ".fallback_rgba (container VStack with no explicit background)" do
    it "is TRANSPARENT in the live app so the parent shows through" do
      # THE ORIGINAL BUG: the live app baked opaque white here, turning every
      # nested background-less container (e.g. My Affirmations' list_container)
      # into a solid white block that hid its children.
      UI::StackBake.fallback_rgba(nil, nil, false).should eq({0.0, 0.0, 0.0, 0.0})
    end

    it "stays TRANSPARENT in a live app even when HIG_APPEARANCE is set" do
      # COUNTEREXAMPLE 1 (review): hosts (e.g. Voyager) set HIG_APPEARANCE for
      # live windows too — appearance must NOT be mistaken for capture mode.
      UI::StackBake.fallback_rgba(nil, "light", false).should eq({0.0, 0.0, 0.0, 0.0})
      UI::StackBake.fallback_rgba(nil, "dark", false).should eq({0.0, 0.0, 0.0, 0.0})
    end

    it "bakes an opaque LIGHT fill when capturing with no appearance pinned" do
      # COUNTEREXAMPLE 2 (review): capture paths that omit HIG_APPEARANCE default
      # to light — they must still get the opaque legibility fill, not transparent.
      UI::StackBake.fallback_rgba(nil, nil, true).should eq({1.0, 1.0, 1.0, 1.0})
    end

    it "bakes an opaque LIGHT fill when capturing in light appearance" do
      UI::StackBake.fallback_rgba(nil, "light", true).should eq({1.0, 1.0, 1.0, 1.0})
    end

    it "bakes an opaque DARK fill when capturing in dark appearance" do
      UI::StackBake.fallback_rgba(nil, "dark", true).should eq({0.12, 0.12, 0.12, 1.0})
    end

    it "stays TRANSPARENT for glass-backdrop captures, even while capturing" do
      UI::StackBake.fallback_rgba("/tmp/backdrop.png", "light", true).should eq({0.0, 0.0, 0.0, 0.0})
      UI::StackBake.fallback_rgba("/tmp/backdrop.png", "dark", true).should eq({0.0, 0.0, 0.0, 0.0})
    end

    it "ignores an empty backdrop-path string (falls through to capture/live)" do
      UI::StackBake.fallback_rgba("", "light", true).should eq({1.0, 1.0, 1.0, 1.0})
      UI::StackBake.fallback_rgba("", nil, false).should eq({0.0, 0.0, 0.0, 0.0})
    end
  end
end
