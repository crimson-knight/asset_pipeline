require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_view_state_fixture"
require "spec"

describe AndroidViewStateFixture do
  it "uses non-recycled process identities rather than native heap addresses" do
    first = UI::Label.new("one")
    value = first.native_state_identity
    first.native_state_identity.should eq(value)
    UI::TextField.new("two").native_state_identity.should be > value
    values = [] of UInt64
    mutex = Mutex.new
    threads = Array.new(4) { Thread.new { 50.times { id = first.native_state_identity; mutex.synchronize { values << id } } } }
    threads.each(&.join)
    values.uniq.should eq([value])
  end
  it "keeps state identity independent of testing and accessibility content" do
    field = UI::TextField.new("Name")
    field.test_id = "test-only"
    field.accessibility_label = "Spoken label"
    field.state_key = "state-only"
    field.test_id.should eq("test-only")
    field.accessibility_label.should eq("Spoken label")
    field.state_key.should eq("state-only")
  end
  it "provides different stable screen scopes for identically keyed editors" do
    AndroidViewStateFixture::Page.new("a").state_key.should_not eq(AndroidViewStateFixture::Page.new("b").state_key)
    one = AndroidViewStateFixture.screen("a").as(UI::VStack).children.select(UI::TextField).first
    two = AndroidViewStateFixture.screen("b").as(UI::VStack).children.select(UI::TextField).first
    one.state_key.should eq(two.state_key)
    one.text.should_not eq(two.text)
    one.state_key.should eq("editor:雪\0key")
  end
  it "retains controlled text in Crystal and supplies a bounded native editor" do
    field = AndroidViewStateFixture.screen("a").as(UI::VStack).children.select(UI::TextField).first
    field.maximum_width.should eq(250.5)
    field.fill_horizontal.should be_true
    field.on_change.not_nil!.call("Updated 雪 😀")
    AndroidViewStateFixture.screen("a").as(UI::VStack).children.select(UI::TextField).first.text.should eq("Updated 雪 😀")
  end
  it "supplies a keyed real two-axis viewport" do
    scroll = AndroidViewStateFixture.screen("a").as(UI::VStack).children.select(UI::ScrollView).first
    scroll.state_key.should eq("viewport")
    scroll.scroll_horizontal.should be_true
    scroll.scroll_vertical.should be_true
    scroll.content.not_nil!.minimum_width.not_nil!.should be > scroll.frame_width
    scroll.content.not_nil!.minimum_height.not_nil!.should be > scroll.frame_height
  end
end
