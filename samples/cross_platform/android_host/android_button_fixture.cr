# Button contract. A customer's brand kit paints its call-to-action with an
# explicit background and foreground (the QuiltPerfect one is BERNINA red under
# white), rules its secondary buttons with a border in the brand's ink, wraps a
# content button's label, and the SwiftUI facade honors all of that on iOS,
# where the Android renderer kept the Material role colors for every button.
# The fixture shows a brand button, a default button, an outlined one, a
# wrapping one, a capped one and two aligned ones; a device test reads the
# MaterialButtons' tint, text color, stroke, line cap and gravity.
module AndroidButtonFixture
  BRAND_RED  = UI::Color.new(r: 0.78, g: 0.09, b: 0.16)
  INK        = UI::Color.new(r: 0.12, g: 0.20, b: 0.24)
  WHITE      = UI::Color.new(r: 1.0, g: 1.0, b: 1.0)
  LONG_LABEL = "Request these items from the shop and have them held at the counter"

  def self.build : UI::View
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.test_id = "button-page"
    root.padding = UI::EdgeInsets.new(top: 12.0, trailing: 18.0, bottom: 12.0, leading: 18.0)
    heading = UI::Label.new("Native button reads")
    heading.accessibility_role = :header
    heading.test_id = "button-heading"
    root << heading

    brand = button("button-brand", "Identify my machine", UI::ButtonStyle::Prominent)
    brand.background = BRAND_RED
    brand.foreground_color = WHITE
    brand.fill_horizontal = true
    root << brand

    root << button("button-default", "Keep the Material colors", UI::ButtonStyle::Default)

    outlined = button("button-outlined", "See all parts", UI::ButtonStyle::Bordered)
    outlined.background = WHITE
    outlined.foreground_color = INK
    outlined.border_width = 1.0
    outlined.border_color = INK
    root << outlined

    wrap = button("button-wrap", LONG_LABEL, UI::ButtonStyle::Borderless)
    wrap.number_of_lines = 0
    wrap.maximum_width = 200.0
    root << wrap

    capped = button("button-capped", LONG_LABEL, UI::ButtonStyle::Borderless)
    capped.number_of_lines = 2
    capped.maximum_width = 200.0
    root << capped

    leading = button("button-leading", "Leading", UI::ButtonStyle::Default)
    leading.text_alignment = UI::Alignment::Leading
    leading.minimum_width = 240.0
    root << leading

    trailing = button("button-trailing", "Trailing", UI::ButtonStyle::Default)
    trailing.text_alignment = UI::Alignment::Trailing
    trailing.minimum_width = 240.0
    root << trailing
    root
  end

  private def self.button(id : String, label : String, style : UI::ButtonStyle) : UI::Button
    button = UI::Button.new(label, style: style) { }
    button.test_id = id
    button.accessibility_label = label
    button
  end
end
