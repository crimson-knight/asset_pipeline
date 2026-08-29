require "../../spec_helper"
require "../../../../src/ui"

# Phase 10B.1a — UI::InlineActionRow web rendering + value semantics.
#
# `UI::InlineActionRow` is the macOS + web_wide default for the
# `:swipe_actions` intent. The spec covers:
#
#   * Construction + value-type sharing with `UI::SwipeActionRow`.
#   * Visitor dispatch.
#   * Web renderer emission (content + buttons + aria-labels + roles).
#   * Capability declaration is interchangeable with `UI::SwipeActionRow`
#     (covered transitively by `spec/web/ui/intent_spec.cr` — the
#     resolver returns this class for macOS / web_wide).

describe UI::InlineActionRow do
  it "wraps a content view with empty action lists by default" do
    content = UI::Label.new("Inbox row")
    row = UI::InlineActionRow.new(content)
    row.content.should be content
    row.leading_actions.should be_empty
    row.trailing_actions.should be_empty
  end

  it "shares the UI::SwipeAction value type with UI::SwipeActionRow" do
    # The sibling widget contract: an action authored against
    # SwipeActionRow must mount unchanged on InlineActionRow.
    action = UI::SwipeAction.new("Edit", on_tap: -> { nil })
    row = UI::InlineActionRow.new(UI::Label.new("x"))
    row.trailing_actions << action
    row.trailing_actions.first.should be action
  end

  it "accepts both leading and trailing actions" do
    row = UI::InlineActionRow.new(UI::Label.new("Buy milk"))
    row.leading_actions << UI::SwipeAction.new("Archive")
    row.trailing_actions << UI::SwipeAction.new("Edit")
    row.trailing_actions << UI::SwipeAction.new("Delete", role: :destructive)

    row.leading_actions.size.should eq 1
    row.trailing_actions.size.should eq 2
    row.trailing_actions[1].role.should eq :destructive
  end

  it "dispatches to the visitor via accept" do
    visitor = TestInlineActionRowVisitor.new
    row = UI::InlineActionRow.new(UI::Label.new("x"))
    row.accept(visitor)
    visitor.captured.should be row
  end

  describe "web renderer" do
    it "emits the row chrome with content + trailing actions" do
      content = UI::Label.new("Buy milk")
      row = UI::InlineActionRow.new(content)
      row.trailing_actions << UI::SwipeAction.new("Edit")
      row.trailing_actions << UI::SwipeAction.new("Delete", role: :destructive)

      renderer = UI::Web::Renderer.new
      html = renderer.render(row)

      html.should contain "ap-inline-action-row"
      html.should contain "data-component=\"inline-action-row\""
      html.should contain "Buy milk"
      html.should contain "Edit"
      html.should contain "Delete"
      # Both action button labels surface as aria-labels for assistive tech.
      html.should contain "aria-label=\"Edit\""
      html.should contain "aria-label=\"Delete\""
      # Destructive role surfaces as a discriminating CSS class.
      html.should contain "ap-inline-action-row__action--destructive"
      html.should contain "data-action-edge=\"trailing\""
    end

    it "honors leading actions when present" do
      row = UI::InlineActionRow.new(UI::Label.new("Inbox"))
      row.leading_actions << UI::SwipeAction.new("Archive")
      renderer = UI::Web::Renderer.new
      html = renderer.render(row)
      html.should contain "Archive"
      html.should contain "data-action-edge=\"leading\""
    end

    it "emits the inline-action chrome exactly once per renderer instance" do
      row1 = UI::InlineActionRow.new(UI::Label.new("Row 1"))
      row1.trailing_actions << UI::SwipeAction.new("Edit")
      row2 = UI::InlineActionRow.new(UI::Label.new("Row 2"))
      row2.trailing_actions << UI::SwipeAction.new("Delete")

      renderer = UI::Web::Renderer.new
      stack = UI::VStack.new
      stack << row1.as(UI::View)
      stack << row2.as(UI::View)
      html = renderer.render(stack)

      html.should contain "data-component=\"inline-action-row-chrome\""
      html.should contain "Row 1"
      html.should contain "Row 2"
      html.scan("data-component=\"inline-action-row-chrome\"").size.should eq 1
    end

    it "surfaces on_tap_route as a data-on-tap-route attribute" do
      row = UI::InlineActionRow.new(UI::Label.new("Hello"))
      row.trailing_actions << UI::SwipeAction.new(
        "Open",
        on_tap_route: "/items/42/edit",
      )

      renderer = UI::Web::Renderer.new
      html = renderer.render(row)
      html.should contain "data-on-tap-route=\"/items/42/edit\""
    end

    it "renders content + actions on a row that mutates after construction (reactivity contract)" do
      # The view tree is a mutable Crystal object graph; runtime state
      # changes (e.g. a controller toggling an action list before
      # re-render) MUST surface in the next render pass. This spec
      # builds a row, mutates `trailing_actions`, and re-renders.
      content = UI::Label.new("Reactive row")
      row = UI::InlineActionRow.new(content)
      renderer1 = UI::Web::Renderer.new
      html_before = renderer1.render(row)
      html_before.should_not contain "Delete"

      row.trailing_actions << UI::SwipeAction.new("Delete", role: :destructive)
      renderer2 = UI::Web::Renderer.new
      html_after = renderer2.render(row)
      html_after.should contain "Delete"
      html_after.should contain "ap-inline-action-row__action--destructive"
    end
  end
end

# Spec-only visitor that captures the dispatched InlineActionRow. All
# other abstract visit methods are stubbed.
class TestInlineActionRowVisitor < UI::PlatformVisitor
  property captured : UI::InlineActionRow? = nil

  def visit(view : UI::InlineActionRow)
    @captured = view
  end

  # Stub every other abstract method.
  {% for klass in %w(Label Button VStack HStack ZStack Image TextField ScrollView Spacer Toggle Checkbox RadioGroup Slider NavigationStack NavigationLink TabView ProgressView ActivityIndicator Alert Picker IconButton ListView OutlineView SecureField Stepper SegmentedControl DatePicker TimePicker SearchField TextArea Grid Form NavigationSplitView Toolbar Sheet Popover ConfirmationDialog Snackbar Card Surface Divider GlassBackground AsyncImage RichText LinkButton MenuButton ToggleButton TextEditor Circle Rectangle RoundedRectangle Capsule Canvas PathView MapView ChartView WebViewComponent ColorPicker VideoPlayer Tooltip ActivityView DisclosureGroup PageControl ComboBox RatingIndicator ActionSheetWithWebFallback ContextMenuWithWebFallback PathControlWithWebFallback SwipeActionRow AndroidSwipeActionRow FullScreenCover Inspector ToolbarItemGroup ToolbarSpacer) %}
    def visit(view : UI::{{klass.id}})
    end
  {% end %}
end
