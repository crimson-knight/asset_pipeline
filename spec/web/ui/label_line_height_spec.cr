require "spec"
require "../../../src/ui"
require "../../../src/ui/renderers/web_renderer"

private def render_label(label : UI::Label) : String
  renderer = UI::Web::Renderer.new
  label.accept(renderer)
  renderer.output
end

describe "UI::Label line height on the web" do
  it "leaves the line height to the stylesheet by default" do
    UI::Label.new("Caption").line_height.should be_nil
    render_label(UI::Label.new("Caption")).should_not contain("line-height")
  end

  it "emits the line height in CSS pixels" do
    label = UI::Label.new("Caption")
    label.line_height = 16.0

    render_label(label).should contain("line-height: 16.0px")
  end
end
