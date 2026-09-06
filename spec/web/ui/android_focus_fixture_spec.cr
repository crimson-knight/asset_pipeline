require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_focus_fixture"
require "../../../samples/cross_platform/android_host/android_compound_focus_fixture"
require "spec"

describe AndroidFocusFixture do
  it "keeps a real editor outside both axes of the initial bounded viewport" do
    root = AndroidFocusFixture.build.as(UI::VStack)
    scroll = root.children.select(UI::ScrollView).first
    scroll.scroll_horizontal.should be_true
    scroll.scroll_vertical.should be_true
    scroll.content.not_nil!.maximum_width.not_nil!.should be > scroll.frame_width
    content = scroll.content.as(UI::VStack)
    content.children.first.minimum_height.not_nil!.should be > scroll.frame_height
    row = content.children.select(UI::HStack).first
    row.children.first.minimum_width.not_nil!.should be > scroll.frame_width
    row.children.select(UI::TextField).first.maximum_width.not_nil!.should be < scroll.frame_width
  end
  it "issues a one-shot focus request without changing native state identities" do
    root = AndroidFocusFixture.build.as(UI::VStack)
    root.children.select(UI::Button).first.on_tap.not_nil!.call
    scroll = AndroidFocusFixture.build.as(UI::VStack).children.select(UI::ScrollView).first
    field = scroll.content.as(UI::VStack).children.select(UI::HStack).first.children.select(UI::TextField).first
    field.focused.should be_true
    again = AndroidFocusFixture.build.as(UI::VStack).children.select(UI::ScrollView).first.content.as(UI::VStack).children.select(UI::HStack).first.children.select(UI::TextField).first
    again.focused.should be_false
    again.state_key.should eq(field.state_key)
  end
end

describe AndroidCompoundFocusFixture do
  it "provides keyed native option groups and separate focus/disabled contracts" do
    root = AndroidCompoundFocusFixture.build.as(UI::VStack)
    groups = root.children.select(UI::RadioGroup)
    groups.size.should eq(3)
    groups.first.state_key.should eq("compound-radio")
    groups.first.options.size.should eq(3)
    groups[1].accessibility_traits.should contain(:not_enabled)
    groups[2].focusable.should eq(false)
    root.children.select(UI::SegmentedControl).first.segments.size.should eq(3)
  end
  it "changes the option catalog without pretending its ordinal is a stable identity" do
    first = AndroidCompoundFocusFixture.build.as(UI::VStack)
    before = first.children.select(UI::RadioGroup).first.options
    first.children.select(UI::Button).last.on_tap.not_nil!.call
    after = AndroidCompoundFocusFixture.build.as(UI::VStack).children.select(UI::RadioGroup).first
    after.options.should eq(before.reverse)
    after.selected_index.should eq(0)
    after.state_key.should eq("compound-radio")
  end
end
