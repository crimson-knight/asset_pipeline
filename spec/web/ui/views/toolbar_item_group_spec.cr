require "../../spec_helper"
require "../../../../src/ui"

# Phase 10B.4 — UI::ToolbarItemGroup web rendering + value semantics.

describe UI::ToolbarItemGroup do
  it "starts empty with no label" do
    g = UI::ToolbarItemGroup.new
    g.items.should be_empty
    g.label.should be_nil
    g.with_divider.should be_true
  end

  it "carries a label through the constructor" do
    g = UI::ToolbarItemGroup.new("Formatting")
    g.label.should eq "Formatting"
  end

  it "appends items via add_item" do
    g = UI::ToolbarItemGroup.new("Edit")
    g.add_item("cut", "Cut")
    g.add_item("copy", "Copy")
    g.add_item("paste", "Paste")
    g.items.size.should eq 3
    g.items[0].id.should eq "cut"
    g.items[2].label.should eq "Paste"
  end

  it "shares the Toolbar::ToolbarItem value type with UI::Toolbar" do
    g = UI::ToolbarItemGroup.new
    g.items << UI::Toolbar::ToolbarItem.new(id: "save", label: "Save")
    g.items.first.label.should eq "Save"
  end

  it "carries an action block to add_item" do
    fired = false
    g = UI::ToolbarItemGroup.new
    g.add_item("fire", "Fire") { fired = true }
    g.items.first.action.try(&.call)
    fired.should be_true
  end

  it "exposes :group as its default accessibility role" do
    UI::ToolbarItemGroup.new.default_accessibility_role.should eq :group
  end

  it "is non-focusable by default (items inside carry the tab stops)" do
    # Phase 10B.4 iter 2 — the group wrapper is a clustering surface;
    # the individual `<button>` items inside it own the tab order.
    UI::ToolbarItemGroup.new.default_focusable.should be_false
  end

  it "dispatches to the visitor via accept" do
    visitor = TestToolbarItemGroupVisitor.new
    g = UI::ToolbarItemGroup.new
    g.accept(visitor)
    visitor.captured.should be g
  end

  describe "web renderer" do
    it "emits a role=group div with item buttons" do
      g = UI::ToolbarItemGroup.new("Formatting")
      g.add_item("bold", "Bold")
      g.add_item("italic", "Italic")
      renderer = UI::Web::Renderer.new
      html = renderer.render(g)
      html.should contain "data-component=\"toolbar-item-group\""
      html.should contain "role=\"group\""
      html.should contain "aria-label=\"Formatting\""
      html.should contain "Bold"
      html.should contain "Italic"
      html.should contain "aria-label=\"Bold\""
      html.should contain "data-item-id=\"bold\""
    end

    it "appends a divider when with_divider is true and items exist" do
      g = UI::ToolbarItemGroup.new
      g.add_item("one", "One")
      renderer = UI::Web::Renderer.new
      html = renderer.render(g)
      html.should contain "aria-hidden=\"true\""
    end

    it "omits the divider when with_divider is false" do
      g = UI::ToolbarItemGroup.new
      g.add_item("one", "One")
      g.with_divider = false
      renderer = UI::Web::Renderer.new
      html = renderer.render(g)
      html.should_not contain "aria-hidden=\"true\""
    end

    it "reflects item-list mutations across renders (reactivity contract)" do
      g = UI::ToolbarItemGroup.new("Edit")
      r1 = UI::Web::Renderer.new
      before = r1.render(g)
      before.should_not contain "Copy"

      g.add_item("copy", "Copy")
      r2 = UI::Web::Renderer.new
      after = r2.render(g)
      after.should contain "Copy"
    end
  end
end

class TestToolbarItemGroupVisitor < UI::PlatformVisitor
  property captured : UI::ToolbarItemGroup? = nil

  def visit(view : UI::ToolbarItemGroup)
    @captured = view
  end

  {% for klass in %w(Label Button VStack HStack ZStack Image TextField ScrollView Spacer Toggle Checkbox RadioGroup Slider NavigationStack NavigationLink TabView ProgressView ActivityIndicator Alert Picker IconButton ListView OutlineView SecureField Stepper SegmentedControl DatePicker TimePicker SearchField TextArea Grid Form NavigationSplitView Toolbar Sheet Popover ConfirmationDialog Snackbar Card Surface Divider GlassBackground AsyncImage RichText LinkButton MenuButton ToggleButton TextEditor Circle Rectangle RoundedRectangle Capsule Canvas PathView MapView ChartView WebViewComponent ColorPicker VideoPlayer Tooltip ActivityView DisclosureGroup PageControl ComboBox RatingIndicator ActionSheetWithWebFallback ContextMenuWithWebFallback PathControlWithWebFallback SwipeActionRow InlineActionRow AndroidSwipeActionRow FullScreenCover Inspector ToolbarSpacer) %}
    def visit(view : UI::{{klass.id}})
    end
  {% end %}
end
