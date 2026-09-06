require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_layout_contract_fixture"
require "spec"

private def layout_fixture_views(view : UI::View) : Array(UI::View)
  children = case view
             when UI::VStack, UI::HStack, UI::ZStack then view.children
             when UI::ScrollView                     then view.content.try { |child| [child] } || [] of UI::View
             else                                         [] of UI::View
             end
  [view] + children.flat_map { |child| layout_fixture_views(child) }
end

describe AndroidLayoutContractFixture do
  it "distinguishes equal outer slots from default intrinsic widths, pins and hidden children" do
    views = layout_fixture_views(AndroidLayoutContractFixture.equal_width)
    ids = views.compact_map(&.test_id)
    ids.size.should eq(ids.uniq.size)
    rows = views.select(UI::HStack)
    rows.select(&.fill_equally).map(&.test_id).should eq(["equal-pinned", "equal-natural", "equal-actions"])
    rows.find { |row| row.test_id == "unequal-natural" }.not_nil!.fill_equally.should be_false
    pinned = rows.find { |row| row.test_id == "equal-pinned" }.not_nil!
    pinned.children[1].hidden.should be_true
    pinned.children.select(UI::Spacer).first.min_length.should eq(15.5)
    pinned.spacing.should eq(2.5)
    pinned.minimum_width.should eq(241.5)
    pinned.children.reject(&.hidden).first(3).map(&.minimum_width).should eq([20.5, 30.5, 40.5])
  end

  it "keeps every matrix identifier unique so native assertions cannot select a different view" do
    ids = layout_fixture_views(AndroidLayoutContractFixture.matrix).compact_map(&.test_id)
    ids.size.should eq(ids.uniq.size)
  end

  it "exercises distinct bounds and fractional spacer minima" do
    views = layout_fixture_views(AndroidLayoutContractFixture.matrix)
    bounded = views.find { |view| view.test_id == "bounds-label" }.not_nil!
    bounded.minimum_width.should eq(40.5)
    bounded.maximum_width.should eq(90.5)
    bounded.maximum_height.should eq(45.5)
    views.select(UI::Spacer).map(&.min_length).sort.should eq([12.5, 15.5, 15.5])
  end

  it "exercises every scroll-axis combination with fractional viewport sizes" do
    scrolls = layout_fixture_views(AndroidLayoutContractFixture.matrix).select(UI::ScrollView).reject(&.fill_vertical)
    scrolls.map { |scroll| {scroll.scroll_horizontal, scroll.scroll_vertical} }.sort_by { |horizontal, vertical| (horizontal ? 2 : 0) + (vertical ? 1 : 0) }.should eq(
      [{false, false}, {false, true}, {true, false}, {true, true}])
    scrolls.each do |scroll|
      scroll.frame_width.should eq(180.5)
      scroll.frame_height.should eq(100.5)
      scroll.shows_indicators.should be_false
    end
  end

  it "provides an actual Crystal action beyond both viewport edges" do
    root = AndroidLayoutContractFixture.interaction
    views = layout_fixture_views(root)
    scroll = views.select(UI::ScrollView).first
    scroll.scroll_horizontal.should be_true
    scroll.scroll_vertical.should be_true
    scroll.content.not_nil!.minimum_width.not_nil!.should be > scroll.frame_width
    scroll.content.not_nil!.minimum_height.not_nil!.should be > scroll.frame_height
    before = views.select(UI::Label).map(&.text)
    views.select(UI::Button).first.on_tap.not_nil!.call
    after = layout_fixture_views(AndroidLayoutContractFixture.interaction).select(UI::Label).map(&.text)
    before.should_not eq(after)
  end
end
