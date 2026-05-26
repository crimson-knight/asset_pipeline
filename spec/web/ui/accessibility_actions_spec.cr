# Phase 10B.2b — Specs for custom accessibility actions on UI::View.
#
# Covers the Crystal property surface, the Web renderer's data-attribute
# emission, and (via the SwiftKit Populator) the forwarding to the
# `apskAccessibilityActions` slot on the SwiftKit override carrier.

require "spec"
require "../../../src/ui"
require "../../../src/ui/renderers/web_renderer"

private def render(view : UI::View) : String
  renderer = UI::Web::Renderer.new
  view.accept(renderer)
  renderer.output
end

describe "UI::View accessibility actions (Phase 10B.2b)" do
  describe "property surface" do
    it "defaults to an empty array" do
      view = UI::Button.new("X")
      view.accessibility_actions.should eq([] of UI::AccessibilityAction)
    end

    it "round-trips an array of actions" do
      view = UI::Button.new("Save")
      view.accessibility_actions = [
        UI::AccessibilityAction.new("Save and close") { },
        UI::AccessibilityAction.new("Discard changes") { },
      ]
      view.accessibility_actions.size.should eq(2)
      view.accessibility_actions[0].name.should eq("Save and close")
    end

    it "AccessibilityAction#call invokes the callback" do
      hits = [] of String
      action = UI::AccessibilityAction.new("Test") { hits << "called" }
      action.call
      hits.should eq(["called"])
    end
  end

  describe "web renderer threading" do
    it "emits data-ax-actions with comma-joined names" do
      btn = UI::Button.new("Save")
      btn.accessibility_actions = [
        UI::AccessibilityAction.new("Save") { },
        UI::AccessibilityAction.new("Save as draft") { },
      ]
      html = render(btn)
      html.should contain(%(data-ax-actions="Save,Save as draft"))
      html.should contain(%(data-ax-action-count="2"))
    end

    it "URL-encodes commas in action names" do
      btn = UI::Button.new("X")
      btn.accessibility_actions = [
        UI::AccessibilityAction.new("Save, then close") { },
      ]
      html = render(btn)
      html.should contain(%(data-ax-actions="Save%2C then close"))
    end

    it "skips data-ax-actions when no actions are configured" do
      btn = UI::Button.new("X")
      html = render(btn)
      html.should_not contain("data-ax-actions")
    end
  end

  # Phase 10B.2b iter 2 — A view that exposes custom accessibility
  # actions to AT users MUST be keyboard-reachable. Otherwise a
  # keyboard-only user (including switch / sip-and-puff users routed
  # through their AT to keyboard events) cannot focus the element and
  # therefore cannot invoke the actions. The web renderer promotes
  # any view with non-empty `accessibility_actions` to `tabindex="0"`
  # when the focus resolver did not already produce a tabindex.
  describe "keyboard reachability for custom actions" do
    it "promotes a Label with accessibility_actions to tabindex=0" do
      lbl = UI::Label.new("Status")
      lbl.accessibility_actions = [
        UI::AccessibilityAction.new("Refresh") { },
      ]
      html = render(lbl)
      html.should contain(%(tabindex="0"))
    end

    it "does not promote a Label without accessibility_actions" do
      lbl = UI::Label.new("Status")
      html = render(lbl)
      html.should_not contain("tabindex=")
    end

    it "preserves an explicit tab_index even with accessibility_actions" do
      lbl = UI::Label.new("Status")
      lbl.tab_index = 4
      lbl.accessibility_actions = [
        UI::AccessibilityAction.new("Refresh") { },
      ]
      html = render(lbl)
      html.should contain(%(tabindex="4"))
      html.should_not contain(%(tabindex="0"))
    end

    it "preserves tabindex=-1 opt-out on a focusable widget with actions" do
      btn = UI::Button.new("X")
      btn.focusable = false
      btn.accessibility_actions = [
        UI::AccessibilityAction.new("Refresh") { },
      ]
      html = render(btn)
      html.should contain(%(tabindex="-1"))
    end

    it "does not emit a redundant tabindex on an intrinsically focusable widget with actions" do
      btn = UI::Button.new("Save")
      btn.accessibility_actions = [
        UI::AccessibilityAction.new("Save as draft") { },
      ]
      html = render(btn)
      # Button is intrinsically focusable via <button>; the keyboard
      # reachability invariant is already satisfied without a
      # `tabindex` attribute, so the promotion rule deliberately
      # skips it to avoid noise in the rendered HTML.
      html.should_not contain("tabindex=")
    end
  end
end
