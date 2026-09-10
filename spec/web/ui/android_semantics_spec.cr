require "../../../src/ui"
require "../../../src/ui/android/semantics"
require "../../../samples/cross_platform/android_host/android_semantics_fixture"
require "spec"

describe UI::Android::Semantics do
  it "keeps automation, spoken metadata and native state identities separate" do
    view = UI::Label.new("Visible content")
    view.test_id = "test-雪\0😀"
    view.accessibility_identifier = "explicit-id"
    view.state_key = "private-state-key"
    data = JSON.parse(UI::Android::Semantics.encode(view, [] of UInt64))
    data["test_id"].as_s.should eq(view.test_id)
    data["identifier"].as_s.should eq("explicit-id")
    data["label"].should eq(nil)
    data.to_json.should_not contain("private-state-key")
    data.to_json.should_not contain("Visible content")
  end
  it "encodes effective role and explicit focus opt-out without losing their precedence" do
    view = UI::Button.new("Button")
    view.focusable = false
    view.focused = true
    data = JSON.parse(UI::Android::Semantics.encode(view, [] of UInt64))
    data["role"].as_s.should eq("button")
    data["explicit_role"].as_bool.should be_false
    data["focusable"].as_bool.should be_false
    data["focused"].as_bool.should be_true
    view.accessibility_role = :header
    JSON.parse(UI::Android::Semantics.encode(view, [] of UInt64))["explicit_role"].as_bool.should be_true
  end
  it "encodes actions and keyboard shortcuts without invoking callbacks" do
    called = 0
    view = UI::Button.new("Command")
    view.accessibility_actions << UI::AccessibilityAction.new("Archive 雪") { called += 1; nil }
    view.keyboard_shortcut = UI::KeyboardShortcut.new(:return, [:control, :shift])
    data = JSON.parse(UI::Android::Semantics.encode(view, [123_u64]))
    data["actions"][0]["token"].as_i.should eq(123)
    data["actions"][0]["name"].as_s.should eq("Archive 雪")
    data["shortcut"]["modifiers"].as_a.map(&.as_s).should eq(["control", "shift"])
    called.should eq(0)
  end
  it "rejects mismatched ownership and excess action packets" do
    view = UI::Label.new("Bounded")
    expect_raises(ArgumentError, "callback count mismatch") { UI::Android::Semantics.encode(view, [1_u64]) }
    17.times { view.accessibility_actions << UI::AccessibilityAction.new("Action") { nil } }
    expect_raises(ArgumentError, "at most 16") { UI::Android::Semantics.encode(view, (1_u64..17_u64).to_a) }
  end
  it "keeps entered text out of accessibility metadata" do
    view = UI::TextField.new("Placeholder", text: "Private entered value")
    view.accessibility_label = "Account name"
    data = UI::Android::Semantics.encode(view, [] of UInt64)
    data.should contain("Account name")
    data.should_not contain("Private entered value")
    data.should_not contain("Placeholder")
  end
  it "provides real controls and checked-JNI partial ownership failure fixtures" do
    root = AndroidSemanticsFixture.build(true).as(UI::VStack)
    root.children.select(UI::TextField).first.focused.should be_true
    root.children.select(UI::Checkbox).size.should eq(1)
    root.children.select(UI::Slider).size.should eq(1)
    button = root.children.select(UI::Button).first
    button.maximum_width.should eq(230.0)
    button.accessibility_actions.size.should eq(1)
    AndroidSemanticsFixture.invalid.as(UI::VStack).children.last.accessibility_actions.first.name.should be_empty
  end
end
