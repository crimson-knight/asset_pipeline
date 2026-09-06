require "../../../src/ui"
require "../../../src/ui/android/sheets"
require "../../../samples/cross_platform/android_host/android_sheet_fixture"
require "spec"

describe UI::Android::Sheets do
  it "serializes native presentation policy without persisting content or closures" do
    sheet = UI::Sheet.new(UI::Label.new("Private content"))
    sheet.accessibility_label = "Edit 雪 😀"
    data = JSON.parse(UI::Android::Sheets.encode(sheet, 1_u64, 2_u64))
    data["title"].as_s.should eq "Edit 雪 😀"
    data["detents"].as_a.map(&.as_i).should eq [1, 2]
    data["selected"].as_i.should eq 1
    data.to_json.should_not contain("Private content")
  end

  it "rejects undeclared and custom detents instead of drawing placeholder text" do
    sheet = UI::Sheet.new(UI::Label.new("Content"))
    sheet.detents = [:small]
    expect_raises(ArgumentError) { UI::Android::Sheets.encode(sheet, 1_u64, 2_u64) }
    sheet.selected_detent = :small
    expect_raises(ArgumentError) { UI::Android::Sheets.encode(sheet, 1_u64, 1_u64) }
    sheet.detents = [:custom]
    expect_raises(ArgumentError) { UI::Android::Sheets.encode(sheet, 1_u64, 2_u64) }
  end

  it "schedules managed programmatic dismissal once and lets the retired window report completion" do
    requests = 0
    completions = 0
    sheet = UI::Sheet.new
    sheet.on_dismiss = -> { completions += 1; nil }
    sheet.__android_bind_dismiss(-> { requests += 1; nil })
    presenter = UI::SheetPresenter.new(sheet)
    presenter.present
    presenter.dismiss
    presenter.dismiss
    sheet.dismiss!
    requests.should eq 1
    completions.should eq 0
    sheet.__android_did_dismiss
    completions.should eq 1
    sheet.is_presented.should be_false
  end

  it "retires subtree callbacks without prematurely releasing owned native handles" do
    root = UI::NativeView.new(UI::NativeHandle.new(Pointer(Void).new(0x1234_u64), UI::ReleaseStrategy::Unowned))
    child = UI::NativeView.new(UI::NativeHandle.new(Pointer(Void).new(0x2345_u64), UI::ReleaseStrategy::Unowned))
    root.add_child(child)
    fired = 0
    callback = child.register_callback(-> { fired += 1; nil })
    begin
      UI::CallbackRegistry.call(callback)
      root.retire_callbacks!
      root.retire_callbacks!
      UI::CallbackRegistry.call(callback)
      fired.should eq 1
      child.handle.released?.should be_false
      root.children.should eq [child]
    ensure
      root.teardown!
    end
    child.handle.released?.should be_true
  end

  it "keeps real editor content keyed and explicitly supports locked programmatic closure" do
    root = AndroidSheetFixture.build.as(UI::VStack)
    buttons = root.children.select(UI::Button)
    buttons.find { |button| button.test_id == "sheet-open-locked" }.not_nil!.on_tap.not_nil!.call
    sheet = AndroidSheetFixture.sheet
    begin
      sheet.is_presented.should be_true
      sheet.interactive_dismiss_disabled.should be_true
      sheet.state_key.should eq "sheet-editor"
      content = sheet.content.not_nil!.as(UI::VStack)
      content.children.select(UI::TextField).first.state_key.should eq "sheet-draft"
      buttons.find { |button| button.test_id == "sheet-close-outside" }.not_nil!.on_tap.not_nil!.call
      sheet.is_presented.should be_false
    ensure
      sheet.dismiss!
    end
  end

  it "reconciles structural removal once while ordinary replacement and teardown stay silent" do
    completions = 0
    sheet = UI::Sheet.new
    sheet.is_presented = true
    sheet.on_dismiss = -> { completions += 1; nil }
    begin
      UI::Android::Sheets.stage_retirement(sheet)
      UI::Android::Sheets.finish_retirement(false).should be_false
      sheet.is_presented.should be_true
      UI::Android::Sheets.stage_retirement(sheet)
      UI::Android::Sheets.finish_retirement(true).should be_true
      UI::Android::Sheets.finish_retirement(true).should be_false
      sheet.is_presented.should be_false
      completions.should eq 1
      UI::Android::Sheets.stage_retirement(sheet)
      UI::Android::Sheets.discard_retirement
      UI::Android::Sheets.finish_retirement(true).should be_false
      completions.should eq 1
    ensure
      UI::Android::Sheets.discard_retirement
    end
  end

  it "declares every native height combination with a valid selected detent" do
    buttons = AndroidSheetFixture.build.as(UI::VStack).children.select(UI::Button)
    cases = {
      "small-only" => {[:small], :small},
      "medium-only" => {[:medium], :medium},
      "large-only" => {[:large], :large},
      "small-medium" => {[:small, :medium], :small},
      "small-large" => {[:small, :large], :small},
      "medium-large" => {[:medium, :large], :medium},
      "three-small" => {[:small, :medium, :large], :small},
    }
    sheet = AndroidSheetFixture.sheet
    begin
      cases.each do |suffix, policy|
        buttons.find { |button| button.test_id == "sheet-open-#{suffix}" }.not_nil!.on_tap.not_nil!.call
        sheet.detents.should eq policy[0]
        sheet.selected_detent.should eq policy[1]
        sheet.interactive_dismiss_disabled.should be_false
        JSON.parse(UI::Android::Sheets.encode(sheet, 1_u64, 2_u64))["detents"].as_a.size.should eq policy[0].size
        sheet.dismiss!
      end
      buttons.find { |button| button.test_id == "sheet-open-locked-small" }.not_nil!.on_tap.not_nil!.call
      sheet.detents.should eq [:small]
      sheet.interactive_dismiss_disabled.should be_true
    ensure
      sheet.dismiss!
    end
  end

  it "releases the structural handoff before a failing application dismissal" do
    sheet = UI::Sheet.new
    sheet.on_dismiss = -> { raise "fixture-only dismissal failure" }
    begin
      UI::Android::Sheets.stage_retirement(sheet)
      expect_raises(Exception, "fixture-only dismissal failure") { UI::Android::Sheets.finish_retirement(true) }
      UI::Android::Sheets.finish_retirement(true).should be_false
    ensure
      UI::Android::Sheets.discard_retirement
    end
  end
end
