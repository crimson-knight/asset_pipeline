# Tabs and menus Tier A candidates: a Material tab bar over Crystal-owned
# content, a pull-down menu button of actions and a pop-up menu button whose
# face shows the Crystal selection. Every value lives in Crystal; the host
# reports the tab position or the picked item index and re-renders.
module AndroidTabsFixture
  SIZES = ["Small", "Medium", "Large"]
  @@tab = 0
  @@tab_changes = 0
  @@picked = "none"
  @@picks = 0
  @@choice = 1

  def self.reset
    @@tab = 0; @@tab_changes = 0; @@picked = "none"; @@picks = 0; @@choice = 1
  end

  def self.mark(view : UI::View, id : String) : UI::View
    view.test_id = id
    view.state_key = id
    view
  end

  def self.build : UI::View
    root = UI::VStack.new(6.0, UI::Alignment::Leading)
    root.state_key = "tabs-screen"
    root << mark(UI::Label.new("Tabs and menus").tap { |v| v.accessibility_role = :header }, "tabs-heading")

    tabs = [
      UI::TabView::Tab.new(label: "Home", content: mark(UI::Label.new("Home content"), "tabs-home")),
      UI::TabView::Tab.new(label: "Search", content: mark(UI::Label.new("Search content"), "tabs-search")),
      UI::TabView::Tab.new(label: "Profile", content: mark(UI::Label.new("Profile content"), "tabs-profile")),
    ]
    tab_view = UI::TabView.new(tabs, @@tab) do |index|
      @@tab_changes += 1 if index != @@tab
      @@tab = index
      nil
    end
    tab_view.bar_position = :top
    root << mark(tab_view, "tabs-view")
    root << mark(UI::Label.new("Tab: #{@@tab}; changes: #{@@tab_changes}"), "tabs-echo")

    actions = UI::MenuButton.new("Actions")
    actions.is_pull_down = true
    ["Share", "Duplicate", "Delete"].each do |label|
      actions.add_item(label, is_destructive: label == "Delete") { @@picked = label; @@picks += 1; nil }
    end
    root << mark(actions, "tabs-menu")
    root << mark(UI::Label.new("Picked: #{@@picked}; picks: #{@@picks}"), "tabs-menu-echo")

    choice = UI::MenuButton.new("Size")
    choice.selected_index = @@choice
    SIZES.each_with_index do |label, index|
      choice.add_item(label) { @@choice = index; nil }
    end
    root << mark(choice, "tabs-choice")
    root << mark(UI::Label.new("Choice: #{SIZES[@@choice]}"), "tabs-choice-echo")
    root
  end
end
