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

  it "tracks install state locally" do
    bar = UI::MenuBar.new
    bar.install
    {% if flag?(:darwin) %}
      bar.is_installed.should be_true
    {% else %}
      bar.is_installed.should be_false
    {% end %}
    bar.uninstall
    bar.is_installed.should be_false
  end
end
