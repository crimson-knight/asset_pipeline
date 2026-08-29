# Phase 10B.2b — Specs for focus management on UI::View
# (focused / focusable / tab_index).

require "spec"
require "../../../src/ui"
require "../../../src/ui/renderers/web_renderer"

private def render(view : UI::View) : String
  renderer = UI::Web::Renderer.new
  view.accept(renderer)
  renderer.output
end

describe "UI::View focus management (Phase 10B.2b)" do
  describe "property surface" do
    it "focused defaults to false" do
      UI::Button.new("X").focused.should be_false
    end

    it "focusable defaults to nil (use widget default)" do
      UI::Button.new("X").focusable.should be_nil
    end

    it "tab_index defaults to nil" do
      UI::Button.new("X").tab_index.should be_nil
    end

    it "interactive widgets default to focusable=true via default_focusable" do
      UI::Button.new("X").default_focusable.should be_true
      UI::TextField.new.default_focusable.should be_true
      UI::Toggle.new.default_focusable.should be_true
    end

    it "layout primitives default to focusable=false" do
      UI::VStack.new(spacing: 8.0).default_focusable.should be_false
      UI::Label.new("Hi").default_focusable.should be_false
    end

    it "effective_focusable applies the override-or-default precedence" do
      btn = UI::Button.new("X")
      btn.effective_focusable.should be_true
      btn.focusable = false
      btn.effective_focusable.should be_false

      lbl = UI::Label.new("Section")
      lbl.effective_focusable.should be_false
      lbl.focusable = true
      lbl.effective_focusable.should be_true
    end

    it "effective_tab_index honors explicit tab_index over inferred value" do
      btn = UI::Button.new("X")
      btn.effective_tab_index.should be_nil # no override — let HTML's implicit order win
      btn.tab_index = 3
      btn.effective_tab_index.should eq(3)
    end

    it "effective_tab_index returns -1 for a focusable widget opted out" do
      btn = UI::Button.new("X")
      btn.focusable = false
      btn.effective_tab_index.should eq(-1)
    end

    it "effective_tab_index returns 0 for a non-focusable widget opted in" do
      lbl = UI::Label.new("X")
      lbl.focusable = true
      lbl.effective_tab_index.should eq(0)
    end
  end

  describe "web renderer threading" do
    it "emits autofocus on form controls when focused = true" do
      btn = UI::Button.new("Save")
      btn.focused = true
      html = render(btn)
      html.should contain(%(autofocus="autofocus"))
      html.should contain(%(data-focused="true"))
    end

    it "emits only data-focused on non-form elements when focused = true" do
      lbl = UI::Label.new("Hi")
      lbl.focused = true
      html = render(lbl)
      html.should contain(%(data-focused="true"))
      html.should_not contain("autofocus")
    end

    it "emits tabindex from explicit tab_index" do
      btn = UI::Button.new("X")
      btn.tab_index = 5
      html = render(btn)
      html.should contain(%(tabindex="5"))
    end

    it "emits tabindex=-1 when focusable=false on a focusable-by-default widget" do
      btn = UI::Button.new("X")
      btn.focusable = false
      html = render(btn)
      html.should contain(%(tabindex="-1"))
    end

    it "emits tabindex=0 when focusable=true on a non-focusable-by-default widget" do
      lbl = UI::Label.new("X")
      lbl.focusable = true
      html = render(lbl)
      html.should contain(%(tabindex="0"))
    end

    it "skips tabindex entirely on a focusable widget with no override" do
      btn = UI::Button.new("X")
      html = render(btn)
      html.should_not contain("tabindex=")
    end
  end
end
