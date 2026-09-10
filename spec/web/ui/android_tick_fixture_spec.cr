require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_tick_fixture"
require "spec"

private def tick_labels(view : UI::View) : Hash(String, String)
  labels = {} of String => String
  view.as(UI::VStack).children.each do |child|
    if (label = child.as?(UI::Label)) && (id = label.test_id)
      labels[id] = label.text
    end
  end
  labels
end

describe AndroidTickFixture do
  it "counts ticks and builds separately so a device test can relate them" do
    AndroidTickFixture.reset!
    AndroidTickFixture.ticks.should eq(0)
    AndroidTickFixture.renders.should eq(0)
    AndroidTickFixture.tick!.should eq(1)
    AndroidTickFixture.tick!.should eq(2)
    labels = tick_labels(AndroidTickFixture.build)
    labels["tick-heading"].should eq("Native tick")
    labels["tick-count"].should eq("Ticks 2")
    labels["tick-renders"].should eq("Renders 1")
    AndroidTickFixture.renders.should eq(1)
    tick_labels(AndroidTickFixture.build)["tick-renders"].should eq("Renders 2")
  end

  it "keeps every identifier unique so native assertions cannot select a different view" do
    ids = AndroidTickFixture.build.as(UI::VStack).children.compact_map(&.test_id)
    ids.size.should eq(ids.uniq.size)
  end
end
