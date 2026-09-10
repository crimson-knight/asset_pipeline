# A small real UI tree whose measured Android dimensions form the native
# layout contract. Fractions intentionally catch rounding before dp conversion.
module AndroidLayoutFixture
  def self.fixed_label(text : String, id : String, width : Float64, height : Float64) : UI::Label
    label = UI::Label.new(text)
    label.test_id = id
    label.minimum_width = label.maximum_width = width
    label.minimum_height = label.maximum_height = height
    label
  end

  def self.build : UI::View
    root = UI::VStack.new(12.5, UI::Alignment::Leading)
    root.test_id = "density-root"
    root.padding = UI::EdgeInsets.new(top: 7.5, trailing: 11.5, bottom: 9.5, leading: 10.5)

    label = fixed_label("Scaled text", "density-label", 128.5, 48.5)
    label.font = UI::Font.new(size: 18.0)
    label.corner_radius = 8.5
    label.shadow_radius = 3.5
    label.border_width = 1.5
    label.background = UI::Color.new(r: 0.6, g: 0.6, b: 0.6)
    root << label

    hidden = fixed_label("Hidden", "density-hidden", 20.0, 20.0)
    hidden.hidden = true
    root << hidden

    row = UI::HStack.new(7.5, UI::Alignment::Top)
    row.test_id = "density-row"
    row << fixed_label("A", "density-a", 28.5, 20.5)
    row << fixed_label("B", "density-b", 32.5, 20.5)
    root << row

    button = UI::Button.new("Sized button", style: UI::ButtonStyle::Bordered)
    button.test_id = "density-button"
    button.corner_radius = 9.5
    root << button

    content = UI::Label.new("Card content")
    content.test_id = "density-card-label"
    card = UI::Card.new(content)
    card.test_id = "density-card"
    card.corner_radius = 6.5
    card.elevation = 2.5
    card.is_outlined = true
    card.content_padding = UI::EdgeInsets.new(top: 5.5, trailing: 5.5, bottom: 5.5, leading: 5.5)
    root << card
    root
  end
end
