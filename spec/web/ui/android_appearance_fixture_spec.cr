require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_appearance_fixture"
require "spec"

private def answer(dark : Bool) : String
  AndroidAppearanceFixture.build(dark).as(UI::VStack).children.find { |child| child.test_id == "appearance-answer" }.not_nil!.as(UI::Label).text
end

describe AndroidAppearanceFixture do
  it "prints the appearance the host reported" do
    answer(true).should eq("Appearance dark")
    answer(false).should eq("Appearance light")
  end

  it "keeps every identifier unique so native assertions cannot select a different view" do
    ids = AndroidAppearanceFixture.build(false).as(UI::VStack).children.compact_map(&.test_id)
    ids.size.should eq(ids.uniq.size)
    ids.size.should eq(2)
  end
end
