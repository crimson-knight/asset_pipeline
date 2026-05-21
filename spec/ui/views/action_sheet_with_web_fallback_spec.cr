require "../../spec_helper"
require "../../../src/ui"

describe UI::ActionSheetWithWebFallback do
  it "constructs and accepts actions identically to ActionSheet" do
    sheet = UI::ActionSheetWithWebFallback.new("Share", "Pick a destination")
    sheet.title.should eq("Share")
    sheet.message.should eq("Pick a destination")
    sheet.actions.should be_empty

    captured = ""
    sheet.add_action("Copy link", style: :default) { captured = "copied" }
    sheet.add_action("Cancel", style: :cancel)
    sheet.actions.size.should eq(2)
    sheet.actions[0].action.try(&.call)
    captured.should eq("copied")
  end

  it "toggles is_presented property" do
    sheet = UI::ActionSheetWithWebFallback.new
    sheet.is_presented.should be_false
    sheet.is_presented = true
    sheet.is_presented.should be_true
  end
end
