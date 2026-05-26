require "../../spec_helper"
require "../../../../src/asset_pipeline/native_app"
require "../../../../src/asset_pipeline/native_context"
require "../../../../src/asset_pipeline/native_controller"
require "../../../../src/ui"
require "../../../../src/ui/intent_bootstrap"

# Phase 10B.1c — UI::AndroidSwipeActionRow web rendering + value semantics.
#
# `UI::AndroidSwipeActionRow` is the `:android` default for the
# `:swipe_actions` intent. The spec covers:
#
#   * Construction + value-type sharing with `UI::SwipeActionRow` /
#     `UI::InlineActionRow`.
#   * Visitor dispatch.
#   * Web fallback emission (content + buttons + aria-labels + roles).
#   * Capability declaration / resolver interop is covered by
#     `spec/web/ui/intent_spec.cr`.
#   * Reactivity contract — runtime mutation surfaces in re-render.

describe UI::AndroidSwipeActionRow do
  it "wraps a content view with empty action lists by default" do
    content = UI::Label.new("Inbox row")
    row = UI::AndroidSwipeActionRow.new(content)
    row.content.should be content
    row.leading_actions.should be_empty
    row.trailing_actions.should be_empty
  end

  it "shares the UI::SwipeAction value type with sibling widgets" do
    # An action authored against SwipeActionRow / InlineActionRow must
    # mount unchanged on AndroidSwipeActionRow. That sibling-contract
    # is what lets app authors swap widgets via an intent override
    # without rewriting their action lists.
    action = UI::SwipeAction.new("Edit", on_tap: -> { nil })
    row = UI::AndroidSwipeActionRow.new(UI::Label.new("x"))
    row.trailing_actions << action
    row.trailing_actions.first.should be action
  end

  it "accepts both leading and trailing actions" do
    row = UI::AndroidSwipeActionRow.new(UI::Label.new("Buy milk"))
    row.leading_actions << UI::SwipeAction.new("Archive")
    row.trailing_actions << UI::SwipeAction.new("Edit")
    row.trailing_actions << UI::SwipeAction.new("Delete", role: :destructive)

    row.leading_actions.size.should eq 1
    row.trailing_actions.size.should eq 2
    row.trailing_actions[1].role.should eq :destructive
  end

  it "dispatches to the visitor via accept" do
    visitor = TestAndroidSwipeActionRowVisitor.new
    row = UI::AndroidSwipeActionRow.new(UI::Label.new("x"))
    row.accept(visitor)
    visitor.captured.should be row
  end

  describe "web fallback renderer" do
    it "emits the row chrome with content + trailing actions" do
      content = UI::Label.new("Buy milk")
      row = UI::AndroidSwipeActionRow.new(content)
      row.trailing_actions << UI::SwipeAction.new("Edit")
      row.trailing_actions << UI::SwipeAction.new("Delete", role: :destructive)

      renderer = UI::Web::Renderer.new
      html = renderer.render(row)

      # The web fallback emits the same inline-row chrome class as
      # InlineActionRow (shared `.ap-inline-action-row`) but with a
      # distinguishing `data-component` marker so E2E / introspection
      # specs can tell the two widgets apart.
      html.should contain "ap-inline-action-row"
      html.should contain "data-component=\"android-swipe-action-row\""
      html.should contain "Buy milk"
      html.should contain "Edit"
      html.should contain "Delete"
      html.should contain "aria-label=\"Edit\""
      html.should contain "aria-label=\"Delete\""
      html.should contain "ap-inline-action-row__action--destructive"
      html.should contain "data-action-edge=\"trailing\""
    end

    it "honors leading actions when present" do
      row = UI::AndroidSwipeActionRow.new(UI::Label.new("Inbox"))
      row.leading_actions << UI::SwipeAction.new("Archive")
      renderer = UI::Web::Renderer.new
      html = renderer.render(row)
      html.should contain "Archive"
      html.should contain "data-action-edge=\"leading\""
    end

    it "surfaces on_tap_route as a data-on-tap-route attribute" do
      row = UI::AndroidSwipeActionRow.new(UI::Label.new("Hello"))
      row.trailing_actions << UI::SwipeAction.new(
        "Open",
        on_tap_route: "/items/42/edit",
      )

      renderer = UI::Web::Renderer.new
      html = renderer.render(row)
      html.should contain "data-on-tap-route=\"/items/42/edit\""
    end

    it "renders content + actions on a row that mutates after construction (reactivity contract)" do
      # `[[reactivity-is-table-stakes]]`: runtime state mutation MUST
      # surface in the next render pass. Build a row, mutate
      # `trailing_actions`, re-render — the new action must appear.
      content = UI::Label.new("Reactive row")
      row = UI::AndroidSwipeActionRow.new(content)
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

  describe "intent resolution" do
    it "is the `:swipe_actions` default for `:android`" do
      # Mirrors the assertion in `spec/web/ui/intent_spec.cr`; restated
      # here so the widget's spec file documents its own intent role
      # without forcing the reader to chase the resolver test.
      ctx = UI::ScreenContext::Native.new(
        form_state: UI::FormState.new(mount_token: 0_i64),
        session: UI::Session::InProcess.new,
        flash: UI::Flash::InProcess.new,
        design_tokens: UI::DesignTokens::Tokens.default,
        navigation: UI::NavigationCoordinator.new(UI::NavigationCoordinator::Route.new(:test)),
        platform: :android,
      )
      UI::Intent.resolve(:swipe_actions, ctx).should eq(UI::AndroidSwipeActionRow)
    end
  end
end

# Spec-only visitor that captures the dispatched AndroidSwipeActionRow.
# All other abstract visit methods are stubbed.
class TestAndroidSwipeActionRowVisitor < UI::PlatformVisitor
  property captured : UI::AndroidSwipeActionRow? = nil

  def visit(view : UI::AndroidSwipeActionRow)
    @captured = view
  end

  # Stub every other abstract method.
  {% for klass in %w(Label Button VStack HStack ZStack Image TextField ScrollView Spacer Toggle Checkbox RadioGroup Slider NavigationStack NavigationLink TabView ProgressView ActivityIndicator Alert Picker IconButton ListView OutlineView SecureField Stepper SegmentedControl DatePicker TimePicker SearchField TextArea Grid Form NavigationSplitView Toolbar Sheet Popover ConfirmationDialog Snackbar Card Surface Divider GlassBackground AsyncImage RichText LinkButton MenuButton ToggleButton TextEditor Circle Rectangle RoundedRectangle Capsule Canvas PathView MapView ChartView WebViewComponent ColorPicker VideoPlayer Tooltip ActivityView DisclosureGroup PageControl ComboBox RatingIndicator ActionSheetWithWebFallback ContextMenuWithWebFallback PathControlWithWebFallback SwipeActionRow InlineActionRow) %}
    def visit(view : UI::{{klass.id}})
    end
  {% end %}
end
