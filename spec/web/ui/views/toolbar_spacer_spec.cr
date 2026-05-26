require "../../spec_helper"
require "../../../../src/ui"

# Phase 10B.4 — UI::ToolbarSpacer web rendering + value semantics.

describe UI::ToolbarSpacer do
  it "defaults to flexible (no fixed_size)" do
    s = UI::ToolbarSpacer.new
    s.fixed_size.should be_nil
    s.flexible?.should be_true
  end

  it "accepts a fixed size in the constructor" do
    s = UI::ToolbarSpacer.new(16.0)
    s.fixed_size.should eq 16.0
    s.flexible?.should be_false
  end

  it "exposes :none as its default accessibility role (spacers are silent)" do
    UI::ToolbarSpacer.new.default_accessibility_role.should eq :none
  end

  it "is non-focusable by default (decorative chrome stays out of tab order)" do
    # Phase 10B.4 iter 2 — a spacer is aria-hidden chrome; it must
    # never enter the keyboard tab order. The default-focusable
    # override keeps the resolver in agreement with the rendered ARIA.
    UI::ToolbarSpacer.new.default_focusable.should be_false
  end

  it "dispatches to the visitor via accept" do
    visitor = TestToolbarSpacerVisitor.new
    s = UI::ToolbarSpacer.new
    s.accept(visitor)
    visitor.captured.should be s
  end

  describe "web renderer" do
    it "emits a flexible flex spacer by default" do
      s = UI::ToolbarSpacer.new
      renderer = UI::Web::Renderer.new
      html = renderer.render(s)
      html.should contain "data-component=\"toolbar-spacer\""
      html.should contain "data-spacer-mode=\"flexible\""
      html.should contain "flex: 1 1 auto"
      html.should contain "aria-hidden=\"true\""
    end

    it "emits a fixed-width spacer when fixed_size is set" do
      s = UI::ToolbarSpacer.new(24.0)
      renderer = UI::Web::Renderer.new
      html = renderer.render(s)
      html.should contain "data-spacer-mode=\"fixed\""
      html.should contain "flex: 0 0 24.0px"
    end

    it "reflects fixed_size mutations across renders (reactivity contract)" do
      s = UI::ToolbarSpacer.new
      r1 = UI::Web::Renderer.new
      before = r1.render(s)
      before.should contain "flexible"

      s.fixed_size = 8.0
      r2 = UI::Web::Renderer.new
      after = r2.render(s)
      after.should contain "fixed"
      after.should contain "8.0px"
    end
  end
end

class TestToolbarSpacerVisitor < UI::PlatformVisitor
  property captured : UI::ToolbarSpacer? = nil

  def visit(view : UI::ToolbarSpacer)
    @captured = view
  end

  {% for klass in %w(Label Button VStack HStack ZStack Image TextField ScrollView Spacer Toggle Checkbox RadioGroup Slider NavigationStack NavigationLink TabView ProgressView ActivityIndicator Alert Picker IconButton ListView OutlineView SecureField Stepper SegmentedControl DatePicker TimePicker SearchField TextArea Grid Form NavigationSplitView Toolbar Sheet Popover ConfirmationDialog Snackbar Card Surface Divider GlassBackground AsyncImage RichText LinkButton MenuButton ToggleButton TextEditor Circle Rectangle RoundedRectangle Capsule Canvas PathView MapView ChartView WebViewComponent ColorPicker VideoPlayer Tooltip ActivityView DisclosureGroup PageControl ComboBox RatingIndicator ActionSheetWithWebFallback ContextMenuWithWebFallback PathControlWithWebFallback SwipeActionRow InlineActionRow AndroidSwipeActionRow FullScreenCover Inspector ToolbarItemGroup) %}
    def visit(view : UI::{{klass.id}})
    end
  {% end %}
end
