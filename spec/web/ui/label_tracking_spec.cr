require "spec"
require "../../../src/ui"
require "../../../src/ui/renderers/web_renderer"

private def render_tracking_label(view : UI::View) : String
  renderer = UI::Web::Renderer.new
  view.accept(renderer)
  renderer.output
end

describe "UI::Label tracking on the web" do
  it "defaults to no tracking" do
    UI::Label.new("STANDING BY").tracking.should eq(0.0)
  end

  it "emits letter-spacing in px, one px per point" do
    label = UI::Label.new("STANDING BY")
    label.font = UI::Font.new(family: "monospace", size: 11.0)
    label.tracking = 1.32

    html = render_tracking_label(label)
    html.should contain("letter-spacing: 1.32px")
    html.should contain(">STANDING BY<")
  end

  it "emits negative tracking for tightened display text" do
    label = UI::Label.new("Display")
    label.tracking = -0.5

    render_tracking_label(label).should contain("letter-spacing: -0.5px")
  end

  it "keeps an untracked label free of letter-spacing" do
    render_tracking_label(UI::Label.new("Plain")).should_not contain("letter-spacing")
  end
end
