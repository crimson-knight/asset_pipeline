# Phase 10B.2b — Verify the SwiftKit Populator forwards the new action /
# focus / keyboard slots to the ViewOverrides carrier with the matching
# `apsk*` selectors. Mirrors the 10B.2a pattern: a recording sender
# captures `(setter, args)` tuples that we then assert against.

require "../../../spec_helper"
require "../../../../../src/ui"

private class RecordingAXSender < UI::Native::Populator::Sender
  def set_color(target : String, setter : Symbol, color : UI::Color?)
    return if color.nil?
    FakeLibObjCBridge.record(setter, [target, "color"], "")
  end

  def set_number(target : String, setter : Symbol, value : Float64?)
    return if value.nil?
    FakeLibObjCBridge.record(setter, [target, value.to_s], "")
  end

  def set_bool(target : String, setter : Symbol, value : Bool?)
    return if value.nil?
    FakeLibObjCBridge.record(setter, [target, value.to_s], "")
  end

  def set_string(target : String, setter : Symbol, value : String?)
    return if value.nil?
    FakeLibObjCBridge.record(setter, [target, value], "")
  end

  def set_uint64(target : String, setter : Symbol, value : UInt64?)
    return if value.nil?
    FakeLibObjCBridge.record(setter, [target, value.to_s], "")
  end

  def set_int(target : String, setter : Symbol, value : Int32?)
    return if value.nil?
    FakeLibObjCBridge.record(setter, [target, value.to_s], "")
  end
end

describe UI::Native::Populator, "action + focus + keyboard forwarding (Phase 10B.2b)" do
  describe "accessibility_actions" do
    it "forwards comma-joined names via setApskAccessibilityActions:" do
      view = UI::Button.new("Save")
      view.accessibility_actions = [
        UI::AccessibilityAction.new("Save and close") { },
        UI::AccessibilityAction.new("Discard") { },
      ]
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      FakeLibObjCBridge.assert_sent(:setApskAccessibilityActions,
        args: [target, "Save and close,Discard"])
      FakeLibObjCBridge.assert_sent(:setApskAccessibilityActionCount,
        args: [target, "2"])
    end

    it "URL-encodes commas in action names" do
      view = UI::Button.new("X")
      view.accessibility_actions = [
        UI::AccessibilityAction.new("Save, then close") { },
      ]
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      FakeLibObjCBridge.assert_sent(:setApskAccessibilityActions,
        args: [target, "Save%2C then close"])
    end

    it "skips emission when actions array is empty" do
      view = UI::Button.new("X")
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      FakeLibObjCBridge.refute_sent(:setApskAccessibilityActions)
      FakeLibObjCBridge.refute_sent(:setApskAccessibilityActionCount)
    end
  end

  describe "focused" do
    it "forwards a true value via setApskFocused:" do
      view = UI::Button.new("X")
      view.focused = true
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      FakeLibObjCBridge.assert_sent(:setApskFocused, args: [target, "true"])
    end

    it "skips emission when focused is false (the default)" do
      view = UI::Button.new("X")
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      FakeLibObjCBridge.refute_sent(:setApskFocused)
    end
  end

  describe "keyboard_shortcut" do
    it "forwards key + modifier mask separately" do
      view = UI::Button.new("Save").with_keyboard_shortcut("S", modifiers: [:command, :shift])
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      FakeLibObjCBridge.assert_sent(:setApskKeyboardShortcutKey, args: [target, "S"])
      # Command (1<<20=0x100000) | Shift (1<<17=0x20000) = 0x120000 = 1179648
      FakeLibObjCBridge.assert_sent(:setApskKeyboardShortcutModifiers,
        args: [target, "1179648"])
    end

    it "skips emission when no shortcut is set" do
      view = UI::Button.new("X")
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      FakeLibObjCBridge.refute_sent(:setApskKeyboardShortcutKey)
      FakeLibObjCBridge.refute_sent(:setApskKeyboardShortcutModifiers)
    end
  end
end
