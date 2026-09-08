# Text field styles. A brand kit paints its form fields from its own container
# and asks the platform control for no chrome of its own (`Plain`, after the
# unreadable system fields of an earlier build) and sets the placeholder color
# it wants; the SwiftUI facade honors both, and the Android renderer kept the
# Material filled box and hint color for every field. The fixture shows the
# three styles; a device test reads each layout's box mode, box color and
# hint color.
module AndroidTextFieldStyleFixture
  PLACEHOLDER_INK = UI::Color.new(r: 0.2, g: 0.4, b: 0.6)

  def self.build : UI::View
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.test_id = "field-page"
    root.padding = UI::EdgeInsets.new(top: 12.0, trailing: 18.0, bottom: 12.0, leading: 18.0)
    heading = UI::Label.new("Native field styles")
    heading.accessibility_role = :header
    heading.test_id = "field-heading"
    root << heading
    root << field("field-rounded", "Rounded border", UI::TextFieldStyle::RoundedBorder, nil)
    root << field("field-underline", "Underline", UI::TextFieldStyle::Underline, nil)
    root << field("field-plain", "Plain, brand placeholder", UI::TextFieldStyle::Plain, PLACEHOLDER_INK)
    root
  end

  private def self.field(id : String, placeholder : String, style : UI::TextFieldStyle, color : UI::Color?) : UI::TextField
    field = UI::TextField.new(placeholder: placeholder)
    field.test_id = id
    field.style = style
    field.placeholder_color = color
    field.fill_horizontal = true
    field.accessibility_label = placeholder
    field
  end
end
