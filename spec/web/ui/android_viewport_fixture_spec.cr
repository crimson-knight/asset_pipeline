require "../../../src/ui"
require "../../../src/ui/android/viewport"
require "../../../samples/cross_platform/android_host/android_viewport_fixture"
require "spec"

private def views_by_id(view : UI::View) : Hash(String, UI::View)
  views = {} of String => UI::View
  view.as(UI::VStack).children.each do |child|
    if id = child.test_id
      views[id] = child
    end
  end
  views
end

private def text(views : Hash(String, UI::View), id : String) : String
  views[id].as(UI::Label).text
end

describe AndroidViewportFixture do
  it "prints the report to one decimal and sizes the bar and the wrap width from it" do
    AndroidViewportFixture.reset!
    viewport = UI::Android::Viewport.new(411.4285, 800.0, 24.0, 48.0, 0.0, 0.0, 2.625)
    views = views_by_id(AndroidViewportFixture.build(viewport))
    text(views, "viewport-heading").should eq("Native viewport")
    text(views, "viewport-width").should eq("Width 411.4")
    text(views, "viewport-height").should eq("Height 800.0")
    text(views, "viewport-top").should eq("Top 24.0")
    text(views, "viewport-bottom").should eq("Bottom 48.0")
    text(views, "viewport-left").should eq("Left 0.0")
    text(views, "viewport-right").should eq("Right 0.0")
    text(views, "viewport-density").should eq("Density 2.6")
    text(views, "viewport-renders").should eq("Renders 1")
    bar = views["viewport-bar"]
    bar.minimum_width.not_nil!.should be_close(375.4285, 1e-9)
    bar.maximum_width.should eq(bar.minimum_width)
    views["viewport-wrap"].as(UI::Label).preferred_max_layout_width.should eq(bar.maximum_width)
    views_by_id(AndroidViewportFixture.build(viewport))["viewport-renders"].as(UI::Label).text.should eq("Renders 2")
  end

  it "says so when the host has not reported" do
    views = views_by_id(AndroidViewportFixture.build(nil))
    text(views, "viewport-missing").should eq("No viewport reported")
    views.has_key?("viewport-bar").should be_false
  end

  it "keeps every identifier unique so native assertions cannot select a different view" do
    viewport = UI::Android::Viewport.new(360.0, 640.0)
    ids = AndroidViewportFixture.build(viewport).as(UI::VStack).children.compact_map(&.test_id)
    ids.size.should eq(ids.uniq.size)
  end
end

describe UI::Android::Viewport do
  it "spends the insets on the content size" do
    viewport = UI::Android::Viewport.new(393.0, 852.0, 59.0, 34.0, 0.0, 0.0, 3.0)
    viewport.content_width.should eq(393.0)
    viewport.content_height.should eq(759.0)
  end

  it "compares by value so an unchanged report is not a change" do
    UI::Android::Viewport.new(360.0, 640.0, 24.0, 0.0, 0.0, 0.0, 2.0).should eq(UI::Android::Viewport.new(360.0, 640.0, 24.0, 0.0, 0.0, 0.0, 2.0))
    UI::Android::Viewport.new(360.0, 640.0).should_not eq(UI::Android::Viewport.new(360.0, 641.0))
  end

  it "rejects geometry that leaves no area" do
    expect_raises(ArgumentError) { UI::Android::Viewport.new(0.0, 640.0) }
    expect_raises(ArgumentError) { UI::Android::Viewport.new(360.0, 640.0, -1.0) }
    expect_raises(ArgumentError) { UI::Android::Viewport.new(360.0, 640.0, 0.0, 0.0, 0.0, 0.0, 0.0) }
    expect_raises(ArgumentError) { UI::Android::Viewport.new(360.0, 640.0, 320.0, 320.0) }
    expect_raises(ArgumentError) { UI::Android::Viewport.new(Float64::NAN, 640.0) }
  end
end
