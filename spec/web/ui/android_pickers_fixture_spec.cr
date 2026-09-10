require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_pickers_fixture"
require "spec"

describe AndroidPickersFixture do
  it "builds a bounded date picker and a 24-hour time picker with Crystal-owned values" do
    AndroidPickersFixture.reset
    root = AndroidPickersFixture.build.as(UI::VStack)
    root.children.map(&.test_id).should contain("pickers-date")
    root.children.map(&.test_id).should contain("pickers-time")
    date = root.children.select(UI::DatePicker).first
    date.selected_date.should eq(Time.utc(2026, 9, 6, 12, 0, 0))
    date.minimum_date.should eq(Time.utc(2026, 1, 1))
    date.maximum_date.should eq(Time.utc(2026, 12, 31))
    time = root.children.select(UI::TimePicker).first
    time.shows_24_hour.should be_true
    time.selected_time.should eq(Time.utc(2000, 1, 1, 9, 30, 0))
    root.children.select(UI::Label).map(&.text).should contain("Date: 2026-09-06; changes: 0")
    root.children.select(UI::Label).map(&.text).should contain("Time: 09:30; changes: 0")
  end

  it "keeps reported values in Crystal and counts only real changes" do
    AndroidPickersFixture.reset
    root = AndroidPickersFixture.build.as(UI::VStack)
    root.children.select(UI::DatePicker).first.on_change.not_nil!.call(Time.utc(2026, 12, 25, 12, 0, 0))
    picker = root.children.select(UI::TimePicker).first
    picker.on_change.not_nil!.call(Time.utc(2000, 1, 1, 14, 45, 0))
    picker.on_change.not_nil!.call(Time.utc(2000, 1, 1, 14, 45, 0))
    rebuilt = AndroidPickersFixture.build.as(UI::VStack)
    rebuilt.children.select(UI::DatePicker).first.selected_date.should eq(Time.utc(2026, 12, 25, 12, 0, 0))
    rebuilt.children.select(UI::Label).map(&.text).should contain("Date: 2026-12-25; changes: 1")
    rebuilt.children.select(UI::Label).map(&.text).should contain("Time: 14:45; changes: 1")
  end
end
