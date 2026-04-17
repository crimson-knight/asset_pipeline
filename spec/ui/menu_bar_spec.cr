require "spec"
require "../../src/ui"

describe UI::MenuBar do
  it "collects top-level menus" do
    bar = UI::MenuBar.new
    file_menu = bar.add_menu("File") do |menu|
      menu.add_item("New", icon: "doc")
      menu.add_item("Open...", icon: "folder")
    end

    bar.menus.size.should eq(1)
    bar.menus.first.title.should eq("File")
    file_menu.items.size.should eq(2)
    file_menu.items.first.as(UI::ContextMenu::Item).label.should eq("New")
  end

  it "removes menus by title" do
    bar = UI::MenuBar.new
    bar.add_menu("File")
    bar.add_menu("Edit")

    bar.remove_menu("File").should be_true
    bar.menus.map(&.title).should eq(["Edit"])
  end
end
