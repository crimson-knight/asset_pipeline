module Voyager
  # Voyager — Welcome / About. Phase C: an intentionally-designed demo screen.
  #
  # Uses the PROVEN fixed-width "readable column" pattern (size-class content
  # width, like sign-in), NOT native fluid_width: NSStackView fluid containers
  # collapse to their content minimum (a confirmed dead-end parked for a
  # wrapper-NSView redo — see foundational-output-and-layout-model.md §"Phase B").
  # Each text element is pinned to the column width so it wraps at a comfortable
  # measure; the root centers the column, so it reads as a centered article.
  class WelcomeScreen < UI::Screen
    SLUG = "voyager-welcome"

    def build(context : UI::ScreenContext) : UI::View
      metrics = UI::DesignTokens::DeviceMetrics.current
      w = metrics.compact_horizontal? ? 340.0 : 600.0

      root = UI::VStack.new(spacing: 16.0)
      root.root_fill = true
      root.alignment = UI::Alignment::Center
      root.padding = UI::EdgeInsets.new(
        top: 56.0 + metrics.safe_area_top_pt,
        trailing: 24.0 + metrics.safe_area_trailing_pt,
        bottom: 40.0 + metrics.safe_area_bottom_pt,
        leading: 24.0 + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Voyager welcome screen"
      root.test_id = "voyager-welcome-root"

      root << pinned(heading("Voyager", 40.0, :bold, UI::LabelRole::Primary, "voyager-welcome-wordmark"), w)
      root << pinned(heading(
        "One Crystal source. Native on iPhone, iPad, and Mac — and soon your wrist.",
        17.0, :regular, UI::LabelRole::Secondary), w)
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
