require "../../spec_helper"
require "../../../../src/ui"

# Phase 10B.4 — UI::FullScreenCover web rendering + value semantics.

describe UI::FullScreenCover do
  it "constructs empty with no content" do
    cover = UI::FullScreenCover.new
    cover.content.should be_nil
    cover.is_presented.should be_false
    cover.on_dismiss.should be_nil
  end

  it "carries content through the constructor" do
    label = UI::Label.new("Modal body")
    cover = UI::FullScreenCover.new(label)
    cover.content.should be label
  end

  it "exposes :dialog as its default accessibility role" do
    UI::FullScreenCover.new.default_accessibility_role.should eq :dialog
  end

  it "is focusable by default (so keyboards can land on the overlay)" do
    UI::FullScreenCover.new.default_focusable.should be_true
  end

  it "dispatches to the visitor via accept" do
    visitor = TestFullScreenCoverVisitor.new
    cover = UI::FullScreenCover.new
    cover.accept(visitor)
    visitor.captured.should be cover
  end

  describe "web renderer" do
    it "emits a hidden container when not presented" do
      cover = UI::FullScreenCover.new(UI::Label.new("Hidden body"))
      cover.is_presented = false
      renderer = UI::Web::Renderer.new
      html = renderer.render(cover)
      html.should contain "data-component=\"full-screen-cover\""
      html.should contain "display: none"
      # Content is rendered into the DOM but kept hidden so reactive
      # flips of `is_presented` don't require re-instantiating the
      # subtree. The wrapper carries `display: none` instead.
      html.should contain "Hidden body"
    end

    it "emits a fixed-inset overlay with content when presented" do
      cover = UI::FullScreenCover.new(UI::Label.new("Welcome aboard"))
      cover.is_presented = true
      renderer = UI::Web::Renderer.new
      html = renderer.render(cover)
      html.should contain "data-component=\"full-screen-cover\""
      html.should contain "position: fixed"
      html.should contain "inset: 0"
      html.should contain "Welcome aboard"
      html.should contain "ap-full-screen-cover__content"
    end

    it "carries dialog semantics via default_accessibility_role" do
      cover = UI::FullScreenCover.new
      cover.is_presented = true
      renderer = UI::Web::Renderer.new
      html = renderer.render(cover)
      # The web renderer's apply_common_styles emits role= from
      # effective_accessibility_role.
      html.should contain "role=\"dialog\""
    end

    it "reflects is_presented mutations across renders (reactivity contract)" do
      cover = UI::FullScreenCover.new(UI::Label.new("Reactive body"))
      r1 = UI::Web::Renderer.new
      before = r1.render(cover)
      before.should contain "display: none"
      before.should_not contain "position: fixed"

      cover.is_presented = true
      r2 = UI::Web::Renderer.new
      after = r2.render(cover)
      after.should contain "position: fixed"
      after.should_not contain "display: none"
      after.should contain "Reactive body"
    end
  end
end

# Spec-only visitor that captures the dispatched FullScreenCover. All
# other abstract visit methods are stubbed.
class TestFullScreenCoverVisitor < UI::PlatformVisitor
  property captured : UI::FullScreenCover? = nil

  def visit(view : UI::FullScreenCover)
    @captured = view
  end

  # Stub every other abstract method.
  {% for klass in %w(Label Button VStack HStack ZStack Image TextField ScrollView Spacer Toggle Checkbox RadioGroup Slider NavigationStack NavigationLink TabView ProgressView ActivityIndicator Alert Picker IconButton ListView OutlineView SecureField Stepper SegmentedControl DatePicker TimePicker SearchField TextArea Grid Form NavigationSplitView Toolbar Sheet Popover ConfirmationDialog Snackbar Card Surface Divider GlassBackground AsyncImage RichText LinkButton MenuButton ToggleButton TextEditor Circle Rectangle RoundedRectangle Capsule Canvas PathView MapView ChartView WebViewComponent ColorPicker VideoPlayer Tooltip ActivityView DisclosureGroup PageControl ComboBox RatingIndicator ActionSheetWithWebFallback ContextMenuWithWebFallback PathControlWithWebFallback SwipeActionRow InlineActionRow AndroidSwipeActionRow Inspector ToolbarItemGroup ToolbarSpacer) %}
    def visit(view : UI::{{klass.id}})
    end
  {% end %}
end
