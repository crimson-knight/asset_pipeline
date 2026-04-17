require "spec"
require "../../src/ui"

describe UI::StatusBar do
  it "captures a status item with an attached menu" do
    item = UI::StatusBar.new(
      identifier: "sync",
      title: "Sync",
      icon: "arrow.triangle.2.circlepath",
      tooltip: "Sync status"
    )

    menu = item.with_menu do |m|
      m.add_item("Pause Sync")
      m.add_item("Open Activity")
      m.add_item("Quit", icon: "xmark")
    end

    item.identifier.should eq("sync")
    item.title.should eq("Sync")
    item.icon.should eq("arrow.triangle.2.circlepath")
    item.tooltip.should eq("Sync status")
    item.menu.should eq(menu)
    menu.items.size.should eq(3)
  end

  it "tracks install state locally" do
    item = UI::StatusBar.new
    item.install
    {% if flag?(:darwin) %}
      item.is_installed.should be_true
    {% else %}
      item.is_installed.should be_false
    {% end %}
    item.uninstall
    item.is_installed.should be_false
  end
end
