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

describe "UI::Label trailing link on the web" do
  it "draws no link by default" do
    render_tracking_label(UI::Label.new("Plain")).should_not contain("<a")
  end

  it "ends the paragraph with an underlined anchor when a URL is set" do
    label = UI::Label.new("Choose where results are saved.")
    label.trailing_link_text = "How saving works"
    label.trailing_link_url = "https://example.com/saving"

    html = render_tracking_label(label)
    html.should contain("Choose where results are saved. <a")
    html.should contain(%(href="https://example.com/saving"))
    html.should contain(">How saving works</a>")
    html.should contain("text-decoration: underline")
  end

  it "underlines the link text in a span when no URL is set" do
    label = UI::Label.new("Choose where results are saved.")
    label.trailing_link_text = "How saving works"

    html = render_tracking_label(label)
    html.should_not contain("<a")
    html.should contain(">How saving works</span>")
  end
end
