# Phase 10B.2a — Specs for the static AX metadata properties added to
# UI::View (accessibility_hint, accessibility_role, accessibility_traits,
# accessibility_value, accessibility_identifier) and their threading
# through the web renderer.

require "spec"
require "../../../src/ui"
require "../../../src/ui/renderers/web_renderer"

private def render(view : UI::View) : String
  renderer = UI::Web::Renderer.new
  view.accept(renderer)
  renderer.output
end

describe "UI::View static AX metadata (Phase 10B.2a)" do
  describe "property surface" do
    it "exposes accessibility_hint as a nullable string property" do
      view = UI::Label.new("Hi")
      view.accessibility_hint.should be_nil
      view.accessibility_hint = "Read aloud after the label"
      view.accessibility_hint.should eq("Read aloud after the label")
    end

    it "exposes accessibility_role as an overridable symbol" do
      view = UI::Label.new("Hi")
      # Explicit role wins over default.
      view.accessibility_role = :header
      view.accessibility_role.should eq(:header)
      view.effective_accessibility_role.should eq(:header)
    end

    it "exposes accessibility_traits as an array of symbols" do
      view = UI::Button.new("Save")
      view.accessibility_traits.should eq([] of Symbol)
      view.accessibility_traits = [:selected, :plays_sound]
      view.accessibility_traits.should eq([:selected, :plays_sound])
    end

    it "exposes accessibility_value as a nullable string property" do
      view = UI::Slider.new
      view.accessibility_value.should be_nil
      view.accessibility_value = "75%"
      view.accessibility_value.should eq("75%")
    end

    it "exposes accessibility_identifier as a nullable string property" do
      view = UI::Button.new("Save")
      view.accessibility_identifier.should be_nil
      view.accessibility_identifier = "save-button"
      view.accessibility_identifier.should eq("save-button")
    end
  end

  describe "default_accessibility_role inference" do
    it "UI::Button defaults to :button" do
      UI::Button.new("Click").effective_accessibility_role.should eq(:button)
    end

    it "UI::Label defaults to :text" do
      UI::Label.new("Hello").effective_accessibility_role.should eq(:text)
    end

    it "UI::Toggle defaults to :switch" do
      UI::Toggle.new.effective_accessibility_role.should eq(:switch)
    end

    it "UI::Checkbox defaults to :checkbox" do
      UI::Checkbox.new.effective_accessibility_role.should eq(:checkbox)
    end

    it "UI::Slider defaults to :slider" do
      UI::Slider.new.effective_accessibility_role.should eq(:slider)
    end

    it "UI::ProgressView defaults to :progress_bar" do
      UI::ProgressView.new.effective_accessibility_role.should eq(:progress_bar)
    end

    it "UI::Image defaults to :image" do
      UI::Image.new(source: "x.png").effective_accessibility_role.should eq(:image)
    end

    it "UI::TextField defaults to :text_field" do
      UI::TextField.new.effective_accessibility_role.should eq(:text_field)
    end

    it "UI::LinkButton defaults to :link" do
      UI::LinkButton.new(label: "open", url: "/").effective_accessibility_role.should eq(:link)
    end

    it "UI::Alert defaults to :alert" do
      UI::Alert.new(title: "Warning").effective_accessibility_role.should eq(:alert)
    end

    it "an explicit accessibility_role override beats the default" do
      view = UI::Label.new("Heading")
      view.accessibility_role = :header
      view.effective_accessibility_role.should eq(:header)
    end

    it "a layout primitive returns nil so the HTML tag's intrinsic role wins" do
      # VStack / HStack / ZStack are layout primitives, not semantic
      # widgets. Without a default the web renderer emits no role=
      # attribute and the underlying `<div>`'s intrinsic role wins
      # (no role, which is what AT expects for a generic container).
      UI::VStack.new(spacing: 8.0).effective_accessibility_role.should be_nil
    end
  end

  describe "web renderer threading" do
    it "emits aria-description from accessibility_hint" do
      btn = UI::Button.new("Settings")
      btn.accessibility_hint = "Opens the settings screen"
      html = render(btn)
      html.should contain(%(aria-description="Opens the settings screen"))
    end

    it "emits role= from the explicit accessibility_role override" do
      lbl = UI::Label.new("Section")
      lbl.accessibility_role = :header
      html = render(lbl)
      html.should contain(%(role="heading"))
    end

    it "emits role= from the widget-class default when no override is set" do
      btn = UI::Button.new("Save")
      html = render(btn)
      html.should contain(%(role="button"))
    end

    it "emits aria-valuetext from accessibility_value" do
      slider = UI::Slider.new
      slider.accessibility_value = "75%"
      html = render(slider)
      html.should contain(%(aria-valuetext="75%"))
    end

    it "emits aria-selected for the :selected trait" do
      btn = UI::Button.new("Tab")
      btn.accessibility_traits = [:selected]
      html = render(btn)
      html.should contain(%(aria-selected="true"))
    end

    it "emits aria-disabled for the :not_enabled trait" do
      btn = UI::Button.new("Disabled")
      btn.accessibility_traits = [:not_enabled]
      html = render(btn)
      html.should contain(%(aria-disabled="true"))
    end

    it "emits aria-required and aria-invalid for the matching traits" do
      tf = UI::TextField.new
      tf.accessibility_traits = [:is_required, :is_invalid]
      html = render(tf)
      html.should contain(%(aria-required="true"))
      html.should contain(%(aria-invalid="true"))
    end

    it "emits data-accessibility-id from accessibility_identifier" do
      btn = UI::Button.new("Save")
      btn.accessibility_identifier = "save-button"
      html = render(btn)
      html.should contain(%(data-accessibility-id="save-button"))
    end

    it "preserves the legacy data-testid emission from test_id" do
      btn = UI::Button.new("Save")
      btn.test_id = "save-btn"
      html = render(btn)
      html.should contain(%(data-testid="save-btn"))
    end

    it "emits aria-label and aria-description together when both are set" do
      btn = UI::Button.new("X")
      btn.accessibility_label = "Close"
      btn.accessibility_hint = "Dismisses the sheet"
      html = render(btn)
      html.should contain(%(aria-label="Close"))
      html.should contain(%(aria-description="Dismisses the sheet"))
    end
  end
end
