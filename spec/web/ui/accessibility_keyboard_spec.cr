# Phase 10B.2b — Specs for keyboard shortcuts on UI::View
# (`keyboard_shortcut`, `UI::KeyboardShortcut` value type).

require "spec"
require "../../../src/ui"
require "../../../src/ui/renderers/web_renderer"

private def render(view : UI::View) : String
  renderer = UI::Web::Renderer.new
  view.accept(renderer)
  renderer.output
end

describe UI::KeyboardShortcut, "(Phase 10B.2b)" do
  describe "value type" do
    it "constructs with a string key" do
      ks = UI::KeyboardShortcut.new("S", modifiers: [:command])
      ks.key.should eq("S")
      ks.modifiers.should eq([:command])
    end

    it "accepts symbol keys" do
      ks = UI::KeyboardShortcut.new(:return)
      ks.key.should eq("return")
    end

    it "canonical orders modifiers Control / Option / Shift / Command" do
      ks = UI::KeyboardShortcut.new("P", modifiers: [:command, :shift, :control])
      ks.canonical.should eq("Control+Shift+Command+P")
    end

    it "accesskey_char returns single-character keys" do
      UI::KeyboardShortcut.new("S").accesskey_char.should eq("S")
      UI::KeyboardShortcut.new(:return).accesskey_char.should be_nil
    end

    it "uikit_modifier_mask matches UIKeyModifierFlags bits" do
      # Command = 1 << 20 = 0x100000
      UI::KeyboardShortcut.new("S", modifiers: [:command]).uikit_modifier_mask
        .should eq(1_u64 << 20)
      # Command + Shift
      UI::KeyboardShortcut.new("S", modifiers: [:command, :shift]).uikit_modifier_mask
        .should eq((1_u64 << 20) | (1_u64 << 17))
      # Option == Alt alias
      UI::KeyboardShortcut.new("X", modifiers: [:alt]).uikit_modifier_mask
        .should eq(1_u64 << 19)
    end

    it "appkit_modifier_mask matches NSEventModifierFlags bits (same as UIKit)" do
      UI::KeyboardShortcut.new("S", modifiers: [:command]).appkit_modifier_mask
        .should eq(1_u64 << 20)
    end
  end
end

describe "UI::View keyboard_shortcut (Phase 10B.2b)" do
  describe "property surface" do
    it "defaults to nil" do
      UI::Button.new("X").keyboard_shortcut.should be_nil
    end

    it "round-trips a shortcut value" do
      btn = UI::Button.new("Save")
      btn.keyboard_shortcut = UI::KeyboardShortcut.new("S", modifiers: [:command])
      btn.keyboard_shortcut.not_nil!.key.should eq("S")
    end

    it "with_keyboard_shortcut is chainable" do
      btn = UI::Button.new("Save")
      result = btn.with_keyboard_shortcut("S", modifiers: [:command])
      result.should be(btn)
      btn.keyboard_shortcut.not_nil!.key.should eq("S")
    end
  end

  describe "web renderer threading" do
    it "emits accesskey for a single-character key" do
      btn = UI::Button.new("Save").with_keyboard_shortcut("S", modifiers: [:command])
      html = render(btn)
      html.should contain(%(accesskey="S"))
    end

    it "emits canonical data-keyboard-shortcut" do
      btn = UI::Button.new("Save").with_keyboard_shortcut("S", modifiers: [:command, :shift])
      html = render(btn)
      html.should contain(%(data-keyboard-shortcut="Shift+Command+S"))
    end

    it "omits accesskey but emits data-keyboard-shortcut for named keys" do
      btn = UI::Button.new("OK").with_keyboard_shortcut(:return)
      html = render(btn)
      html.should_not contain("accesskey=")
      html.should contain(%(data-keyboard-shortcut="return"))
    end

    it "skips both attributes when no shortcut is set" do
      btn = UI::Button.new("X")
      html = render(btn)
      html.should_not contain("accesskey=")
      html.should_not contain("data-keyboard-shortcut")
    end
  end
end
