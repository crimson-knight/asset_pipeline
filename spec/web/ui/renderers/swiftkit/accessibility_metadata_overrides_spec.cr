require "../../../spec_helper"
require "../../../../../src/ui"

# Phase 10B.2a iter 2 (Codex Finding 1) — verify the Populator
# forwards all 5 new static accessibility metadata properties to the
# SwiftKit ViewOverrides slots.
#
# This spec covers the Crystal-side wiring: that
# `populate_view_common` invokes the matching `set_*` sender method
# with the expected setter symbol. The Swift-side application of
# those slots (via `CommonModifiers.apply`) is exercised by the
# Apple-host SnapshotTests in
# `swift/AssetPipelineSwiftKit/Tests/AssetPipelineSwiftKitTests/`
# which require a macOS / iOS build to run.

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
end

describe UI::Native::Populator, "accessibility metadata forwarding" do
  describe "populate_view_common" do
    it "forwards accessibility_hint via setApskAccessibilityHint:" do
      view = UI::Button.new("Save")
      view.accessibility_hint = "Double-tap to save the document"
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      FakeLibObjCBridge.assert_sent(:setApskAccessibilityHint, args: [target, "Double-tap to save the document"])
    end

    it "forwards accessibility_value via setApskAccessibilityValue:" do
      view = UI::Slider.new(value: 0.75)
      view.accessibility_value = "75 percent"
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      FakeLibObjCBridge.assert_sent(:setApskAccessibilityValue, args: [target, "75 percent"])
    end

    it "forwards accessibility_identifier via setAccessibilityIdentifier: (wins over test_id)" do
      view = UI::Button.new("X")
      view.accessibility_identifier = "explicit-id"
      view.test_id = "legacy-test-id"
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      FakeLibObjCBridge.assert_sent(:setAccessibilityIdentifier, args: [target, "explicit-id"])
    end

    it "falls back to test_id when accessibility_identifier is unset" do
      view = UI::Button.new("X")
      view.test_id = "legacy-test-id"
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      FakeLibObjCBridge.assert_sent(:setAccessibilityIdentifier, args: [target, "legacy-test-id"])
    end

    it "forwards accessibility_role via setApskAccessibilityRole: (string)" do
      view = UI::Button.new("X")
      view.accessibility_role = :header
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      # UI::Button's default_accessibility_role is :button; explicit :header wins
      FakeLibObjCBridge.assert_sent(:setApskAccessibilityRole, args: [target, "header"])
    end

    it "forwards composed trait + role bitmask via setApskAccessibilityTraitsMask:" do
      view = UI::Button.new("X")
      view.accessibility_traits = [:selected, :not_enabled]
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      # Expected mask:
      #   :button (default role)  = 0x0001
      #   :selected               = 0x0010
      #   :not_enabled            = 0x0200
      # OR'd                      = 0x0211 = 529 (decimal)
      FakeLibObjCBridge.assert_sent(:setApskAccessibilityTraitsMask, args: [target, "529"])
    end

    it "skips traits mask emission when no traits and no role-trait bit" do
      view = UI::VStack.new # layout primitive: no default role, no traits
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      FakeLibObjCBridge.refute_sent(:setApskAccessibilityTraitsMask)
    end

    it "emits role-only mask when role trait bit is set but no explicit traits" do
      view = UI::Label.new("Title")
      view.accessibility_role = :header
      target = FakeLibObjCBridge.next_sentinel_pointer
      UI::Native::Populator.populate_view_common(target, view, RecordingAXSender.new)
      # :header role-trait = 0x10000 = 65536
      FakeLibObjCBridge.assert_sent(:setApskAccessibilityTraitsMask, args: [target, "65536"])
    end
  end

  describe "populator_trait_bit" do
    it "returns canonical UIKit bit positions" do
      UI::Native::Populator.populator_trait_bit(:selected).should eq(0x0010_u64)
      UI::Native::Populator.populator_trait_bit(:not_enabled).should eq(0x0200_u64)
      UI::Native::Populator.populator_trait_bit(:plays_sound).should eq(0x0020_u64)
      UI::Native::Populator.populator_trait_bit(:starts_media).should eq(0x0800_u64)
      UI::Native::Populator.populator_trait_bit(:updates_frequently).should eq(0x0400_u64)
      UI::Native::Populator.populator_trait_bit(:adjustable).should eq(0x1000_u64)
      UI::Native::Populator.populator_trait_bit(:allows_direct_interaction).should eq(0x2000_u64)
      UI::Native::Populator.populator_trait_bit(:causes_page_turn).should eq(0x4000_u64)
    end

    it "returns 0 for unmapped traits" do
      UI::Native::Populator.populator_trait_bit(:is_required).should eq(0_u64)
      UI::Native::Populator.populator_trait_bit(:is_invalid).should eq(0_u64)
      UI::Native::Populator.populator_trait_bit(:is_busy).should eq(0_u64)
    end
  end

  describe "populator_role_trait_bit" do
    it "returns canonical UIKit role bit positions" do
      UI::Native::Populator.populator_role_trait_bit(:button).should eq(0x0001_u64)
      UI::Native::Populator.populator_role_trait_bit(:link).should eq(0x0002_u64)
      UI::Native::Populator.populator_role_trait_bit(:header).should eq(0x10000_u64)
      UI::Native::Populator.populator_role_trait_bit(:image).should eq(0x0008_u64)
      UI::Native::Populator.populator_role_trait_bit(:search).should eq(0x0004_u64)
      UI::Native::Populator.populator_role_trait_bit(:text).should eq(0x0080_u64)
      UI::Native::Populator.populator_role_trait_bit(:tab).should eq(0x8000_u64)
    end

    it "returns 0 for roles UIKit has no trait analog for" do
      UI::Native::Populator.populator_role_trait_bit(:dialog).should eq(0_u64)
      UI::Native::Populator.populator_role_trait_bit(:list).should eq(0_u64)
    end
  end
end
