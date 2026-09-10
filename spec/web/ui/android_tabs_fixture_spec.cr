require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_tabs_fixture"
require "spec"

describe AndroidTabsFixture do
  it "builds a top tab bar over Crystal-owned content and two menu buttons" do
    AndroidTabsFixture.reset
    root = AndroidTabsFixture.build.as(UI::VStack)
    tabs = root.children.select(UI::TabView).first
    tabs.tabs.map(&.label).should eq(["Home", "Search", "Profile"])
    tabs.selected_index.should eq(0)
    tabs.bar_position.should eq(:top)
    tabs.current_content.not_nil!.test_id.should eq("tabs-home")
    menus = root.children.select(UI::MenuButton)
    menus.map(&.test_id).should eq(["tabs-menu", "tabs-choice"])
    menus[0].is_pull_down.should be_true
    menus[0].items.map(&.label).should eq(["Share", "Duplicate", "Delete"])
    menus[0].items.last.is_destructive.should be_true
    menus[1].is_pull_down.should be_false
    menus[1].selected_index.should eq(1)
    labels = root.children.select(UI::Label).map(&.text)
    labels.should contain("Tab: 0; changes: 0")
    labels.should contain("Picked: none; picks: 0")
    labels.should contain("Choice: Medium")
  end

  it "keeps the tab selection and menu picks in Crystal" do
    AndroidTabsFixture.reset
    root = AndroidTabsFixture.build.as(UI::VStack)
    root.children.select(UI::TabView).first.on_change.not_nil!.call(1)
    root.children.select(UI::MenuButton)[0].items[1].action.not_nil!.call
    root.children.select(UI::MenuButton)[1].items[2].action.not_nil!.call
    rebuilt = AndroidTabsFixture.build.as(UI::VStack)
    rebuilt_tabs = rebuilt.children.select(UI::TabView).first
    rebuilt_tabs.selected_index.should eq(1)
    rebuilt_tabs.current_content.not_nil!.test_id.should eq("tabs-search")
    rebuilt.children.select(UI::MenuButton)[1].selected_index.should eq(2)
    labels = rebuilt.children.select(UI::Label).map(&.text)
    labels.should contain("Tab: 1; changes: 1")
    labels.should contain("Picked: Duplicate; picks: 1")
    labels.should contain("Choice: Large")
  end
end
