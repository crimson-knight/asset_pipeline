require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_basics_fixture"
require "spec"

describe AndroidBasicsFixture do
  it "builds the core basics with stable test ids and Crystal-owned values" do
    AndroidBasicsFixture.reset
    root = AndroidBasicsFixture.build.as(UI::VStack)
    ids = root.children.map(&.test_id)
    ids.should contain("basics-secret")
    ids.should contain("basics-notes")
    ids.should contain("basics-progress")
    ids.should contain("basics-spinner")
    ids.should contain("basics-divider")
    ids.should contain("basics-icon")
    root.children.select(UI::ProgressView).map(&.value).should eq([0.35, nil, 0.5])
    root.children.select(UI::ProgressView).map(&.style).should eq([UI::ProgressStyle::Linear, UI::ProgressStyle::Linear, UI::ProgressStyle::Circular])
    root.children.select(UI::ActivityIndicator).map(&.is_animating).should eq([true, false])
    root.children.select(UI::TextArea).first.text.should eq("Line one\nLine two")
  end

  it "keeps entered values in Crystal across rebuilds" do
    AndroidBasicsFixture.reset
    root = AndroidBasicsFixture.build.as(UI::VStack)
    root.children.select(UI::SecureField).first.on_change.not_nil!.call("1234")
    root.children.select(UI::TextArea).first.on_change.not_nil!.call("a\nb\nc")
    root.children.select(UI::IconButton).first.on_tap.not_nil!.call
    root.children.select(UI::Button).first.on_tap.try &.call
    rebuilt = AndroidBasicsFixture.build.as(UI::VStack)
    rebuilt.children.select(UI::Label).map(&.text).should contain("Secret length: 4")
    rebuilt.children.select(UI::Label).map(&.text).should contain("Lines: 3")
    rebuilt.children.select(UI::Label).map(&.text).should contain("Icon taps: 1")
    rebuilt.children.select(UI::SecureField).first.text.should eq("1234")
  end
end
