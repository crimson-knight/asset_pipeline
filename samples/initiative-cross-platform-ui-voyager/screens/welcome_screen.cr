module Voyager
  # Voyager — Welcome / About. Phase C: an intentionally-designed demo screen.
  #
  # The "readable column" pattern: a fixed, size-class-adaptive content width
  # capped at a comfortable measure, centered by the root so it reads as an
  # article. Every dimension — column width, spacing, padding, AND type scale —
  # is authored through DeviceMetrics#responsive, so the WHOLE composition
  # reflows when the size class changes (live, via the host's windowDidResize →
  # rebuild hook on macOS). See foundational-output-and-layout-model.md §"Track 2"
  # — the earlier "fluid collapses / stretches" worry was a measurement misread;
  # a capped centered column IS authoritative and is the right pattern here.
  class WelcomeScreen < UI::Screen
    SLUG = "voyager-welcome"

    def build(context : UI::ScreenContext) : UI::View
      metrics = UI::DesignTokens::DeviceMetrics.current
      w = metrics.responsive(compact: 340.0, regular: 600.0)

      # Vertical rhythm (inter-element spacing, top/bottom padding) keys off the
      # VERTICAL size class so the column tightens in landscape / short windows;
      # width + side padding key off the horizontal class.
      root = UI::VStack.new(spacing: metrics.responsive_vertical(compact: 12.0, regular: 20.0))
      root.root_fill = true
      root.alignment = UI::Alignment::Center
      root.padding = UI::EdgeInsets.new(
        top: metrics.responsive_vertical(compact: 28.0, regular: 64.0) + metrics.safe_area_top_pt,
        trailing: metrics.responsive(compact: 18.0, regular: 28.0) + metrics.safe_area_trailing_pt,
        bottom: metrics.responsive_vertical(compact: 20.0, regular: 48.0) + metrics.safe_area_bottom_pt,
        leading: metrics.responsive(compact: 18.0, regular: 28.0) + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Voyager welcome screen"
      root.test_id = "voyager-welcome-root"

      root << pinned(heading("Voyager", metrics.responsive(compact: 32.0, regular: 44.0), :bold, UI::LabelRole::Primary, "voyager-welcome-wordmark"), w)
      root << pinned(heading(
        "One Crystal source. Native on iPhone, iPad, and Mac — and soon your wrist.",
        metrics.responsive(compact: 16.0, regular: 19.0), :regular, UI::LabelRole::Secondary), w)
      root << pinned(UI::Divider.new(:horizontal).as(UI::View), w)
      root << pinned(heading(
        "Voyager is a sample built on asset_pipeline: a single declarative UI tree " \
        "that the compiler walks into AppKit, UIKit, and the web — no per-platform " \
        "forks. The layout reads as a centered column, capped at a comfortable " \
        "measure, and adapts its width to the device size class.",
        14.0, :regular, UI::LabelRole::Primary, "voyager-welcome-lede"), w)

      [
        {"square.stack.3d.up.fill", "Write once", "Compose UI::View once; the platform renderer produces the idiomatic native control on each target."},
        {"slider.horizontal.3", "Adaptive layout", "Columns adapt to the device size class, capped at a readable measure so lines never sprawl."},
        {"checkmark.seal.fill", "Proven, not assumed", "Every interactive surface is driven through the accessibility API and verified — not eyeballed."},
      ].each do |sym, title, desc|
        root << pinned(feature_row(sym, title, desc, w), w)
      end

      back = UI::Button.new("Back to hub", style: UI::ButtonStyle::Prominent)
      back.accessibility_label = "Back to hub"
      back.test_id = "voyager-welcome-back"
      back.minimum_width = w
      back.maximum_width = w
      back.on_tap = -> { Voyager.dispatch(:back) }
      root << back.as(UI::View)

      root.as(UI::View)
    end

    private def heading(text : String, size : Float64, weight : Symbol, role : UI::LabelRole, tid : String? = nil) : UI::View
      l = UI::Label.new(text)
      l.font = UI::Font.new(size: size, weight: weight)
      l.text_color_role = role
      l.test_id = tid if tid
      l.as(UI::View)
    end

    # A feature row: SF Symbol + a title/description text column, the text column
    # pinned so its labels wrap at the available width.
    private def feature_row(symbol : String, title : String, desc : String, w : Float64) : UI::View
      icon = UI::Image.new(symbol)
      icon.accessibility_label = "#{title} icon"

      text_w = w - 40.0
      text = UI::VStack.new(spacing: 3.0)
      text.alignment = UI::Alignment::Leading
      text.minimum_width = text_w
      text.maximum_width = text_w

      t = UI::Label.new(title)
      t.font = UI::Font.new(size: 16.0, weight: :semibold)
      t.text_color_role = UI::LabelRole::Primary
      t.minimum_width = text_w
      t.maximum_width = text_w
      d = UI::Label.new(desc)
      d.font = UI::Font.new(size: 13.0, weight: :regular)
      d.text_color_role = UI::LabelRole::Secondary
      d.minimum_width = text_w
      d.maximum_width = text_w
      text << t.as(UI::View)
      text << d.as(UI::View)

      row = UI::HStack.new(spacing: 14.0)
      row.alignment = UI::Alignment::Leading
      row << icon.as(UI::View)
      row << text.as(UI::View)
      UI::Card.new(row.as(UI::View)).as(UI::View)
    end

    private def pinned(view : UI::View, w : Float64) : UI::View
      view.minimum_width = w
      view.maximum_width = w
      view
    end
  end
end
