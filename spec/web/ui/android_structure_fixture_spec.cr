require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_structure_fixture"
require "spec"

describe AndroidStructureFixture do
  it "builds shapes, a grid, a form and a disclosure group with stable test ids" do
    AndroidStructureFixture.reset
    root = AndroidStructureFixture.build.as(UI::VStack)
    ids = root.children.map(&.test_id)
    %w[structure-circle structure-capsule structure-rectangle structure-rounded structure-grid structure-form structure-disclosure].each do |id|
      ids.should contain(id)
    end
    root.children.select(UI::Circle).first.size.should eq(48.0)
    root.children.select(UI::Capsule).first.stroke_width.should eq(2.0)
    root.children.select(UI::Rectangle).map { |r| {r.width, r.height} }.should eq([{90.0, 30.0}])
    root.children.select(UI::RoundedRectangle).first.corner_radius.should eq(12.0)
    root.children.select(UI::Grid).first.children.map(&.size).should eq([2, 2])
    form = root.children.select(UI::Form).first
    form.sections.map(&.header).should eq(["Contact"])
    form.sections.first.fields.map(&.label).should eq(["Name", "Email"])
    disclosure = root.children.select(UI::DisclosureGroup).first
    disclosure.expanded.should be_false
    disclosure.content.map(&.test_id).should eq(["structure-detail"])
    root.children.select(UI::Label).map(&.text).should contain("Expanded: false; toggles: 0")
  end

  it "keeps the disclosure state in Crystal across rebuilds" do
    AndroidStructureFixture.reset
    root = AndroidStructureFixture.build.as(UI::VStack)
    root.children.select(UI::DisclosureGroup).first.on_toggle.not_nil!.call(true)
    rebuilt = AndroidStructureFixture.build.as(UI::VStack)
    rebuilt.children.select(UI::DisclosureGroup).first.expanded.should be_true
    rebuilt.children.select(UI::Label).map(&.text).should contain("Expanded: true; toggles: 1")
    rebuilt.children.select(UI::DisclosureGroup).first.on_toggle.not_nil!.call(false)
    AndroidStructureFixture.build.as(UI::VStack).children.select(UI::DisclosureGroup).first.expanded.should be_false
  end
end
