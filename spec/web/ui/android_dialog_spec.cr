require "../../../src/ui"
require "../../../src/ui/android/dialogs"
require "../../../samples/cross_platform/android_host/android_dialog_fixture"
require "spec"

describe UI::Android::Dialogs do
  it "encodes Unicode and actions without serializing application closures" do
    actions = [UI::Alert::AlertButton.new("Cancel", :cancel), UI::Alert::AlertButton.new("Delete 雪", :destructive)]
    data = JSON.parse(UI::Android::Dialogs.encode("Title 😀", "Body", actions, [1_u64, 2_u64], 3_u64))
    data["version"].as_i.should eq 1
    data["title"].as_s.should eq "Title 😀"
    data["actions"].as_a.size.should eq 2
    data["actions"][1]["token"].as_i.should eq 2
  end
  it "rejects unsupported counts, styles, repeated cancellation and invalid callback bindings" do
    action = UI::Alert::AlertButton.new("A")
    [([] of UI::Alert::AlertButton), [action] * 4, [UI::Alert::AlertButton.new("A", :other)],
     [UI::Alert::AlertButton.new("A", :cancel), UI::Alert::AlertButton.new("B", :cancel)]].each do |actions|
      expect_raises(ArgumentError) { UI::Android::Dialogs.validate("Title", "", actions) }
    end
    expect_raises(ArgumentError) { UI::Android::Dialogs.encode("Title", "", [action], [1_u64], 1_u64) }
    expect_raises(ArgumentError) { UI::Android::Dialogs.encode("Title", "", [action], [0_u64], 2_u64) }
    expect_raises(ArgumentError) { UI::Android::Dialogs.validate("Title", "x" * 8193, [action]) }
  end
  it "keeps the fixture's modal declarations keyed and presents one at a time" do
    root = AndroidDialogFixture.build.as(UI::VStack)
    buttons = root.children.select(UI::Button)
    buttons.find { |button| button.test_id == "dialog-open-alert" }.not_nil!.on_tap.not_nil!.call
    AndroidDialogFixture.alert.is_presented.should be_true
    AndroidDialogFixture.confirmation.is_presented.should be_false
    buttons.find { |button| button.test_id == "dialog-open-confirmation" }.not_nil!.on_tap.not_nil!.call
    AndroidDialogFixture.alert.is_presented.should be_false
    AndroidDialogFixture.confirmation.is_presented.should be_true
    AndroidDialogFixture.close_all
    AndroidDialogFixture.confirmation.is_presented.should be_false
    AndroidDialogFixture.alert.state_key.should eq "dialog-alert"
  end
end
