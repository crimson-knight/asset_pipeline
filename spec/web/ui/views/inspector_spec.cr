require "../../spec_helper"
require "../../../../src/ui"

# Phase 10B.4 — UI::Inspector web rendering + value semantics.

describe UI::Inspector do
  it "constructs empty with optional primary + inspector content" do
    insp = UI::Inspector.new
    insp.content.should be_nil
    insp.inspector_content.should be_nil
    insp.is_presented.should be_true
    insp.preferred_width.should be_nil
  end

  it "carries primary + inspector content through the constructor" do
    primary = UI::Label.new("Detail")
    pane = UI::Label.new("Metadata")
    insp = UI::Inspector.new(primary, pane)
    insp.content.should be primary
    insp.inspector_content.should be pane
  end

  it "exposes :none as its default accessibility role" do
    UI::Inspector.new.default_accessibility_role.should eq :none
  end

  it "dispatches to the visitor via accept" do
    visitor = TestInspectorVisitor.new
    insp = UI::Inspector.new
    insp.accept(visitor)
    visitor.captured.should be insp
  end

  describe "web renderer" do
    it "renders a 2-column grid when presented with an inspector pane" do
      insp = UI::Inspector.new(
        UI::Label.new("Primary content"),
        UI::Label.new("Inspector pane"),
      )
      insp.is_presented = true
      renderer = UI::Web::Renderer.new
      html = renderer.render(insp)
      html.should contain "data-component=\"inspector\""
      html.should contain "grid-template-columns: 1fr 320.0px"
      html.should contain "Primary content"
      html.should contain "Inspector pane"
      html.should contain "role=\"complementary\""
    end

    it "honors preferred_width when set" do
      insp = UI::Inspector.new(UI::Label.new("a"), UI::Label.new("b"))
      insp.preferred_width = 400.0
      insp.is_presented = true
      renderer = UI::Web::Renderer.new
      html = renderer.render(insp)
      html.should contain "grid-template-columns: 1fr 400.0px"
    end

    it "collapses to a single column when not presented (and omits the pane)" do
      insp = UI::Inspector.new(
        UI::Label.new("Primary"),
        UI::Label.new("Hidden pane"),
      )
      insp.is_presented = false
      renderer = UI::Web::Renderer.new
      html = renderer.render(insp)
      html.should contain "grid-template-columns: 1fr"
      html.should_not contain "grid-template-columns: 1fr 320"
      html.should contain "Primary"
      html.should_not contain "Hidden pane"
    end

    it "reflects is_presented mutations across renders (reactivity contract)" do
      insp = UI::Inspector.new(
        UI::Label.new("Detail"),
        UI::Label.new("Metadata"),
      )
      insp.is_presented = false
      r1 = UI::Web::Renderer.new
      html_before = r1.render(insp)
      html_before.should_not contain "Metadata"

      insp.is_presented = true
      r2 = UI::Web::Renderer.new
      html_after = r2.render(insp)
      html_after.should contain "Metadata"
      html_after.should contain "role=\"complementary\""
    end
  end
end

class TestInspectorVisitor < UI::PlatformVisitor
  property captured : UI::Inspector? = nil

  def visit(view : UI::Inspector)
    @captured = view
  end

  {% for klass in %w(Label Button VStack HStack ZStack Image TextField ScrollView Spacer Toggle Checkbox RadioGroup Slider NavigationStack NavigationLink TabView ProgressView ActivityIndicator Alert Picker IconButton ListView OutlineView SecureField Stepper SegmentedControl DatePicker TimePicker SearchField TextArea Grid Form NavigationSplitView Toolbar Sheet Popover ConfirmationDialog Snackbar Card Surface Divider GlassBackground AsyncImage RichText LinkButton MenuButton ToggleButton TextEditor Circle Rectangle RoundedRectangle Capsule Canvas PathView MapView ChartView WebViewComponent ColorPicker VideoPlayer Tooltip ActivityView DisclosureGroup PageControl ComboBox RatingIndicator ActionSheetWithWebFallback ContextMenuWithWebFallback PathControlWithWebFallback SwipeActionRow InlineActionRow AndroidSwipeActionRow FullScreenCover ToolbarItemGroup ToolbarSpacer) %}
    def visit(view : UI::{{klass.id}})
    end
  {% end %}
end
