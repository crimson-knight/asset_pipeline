module AndroidLayoutContractFixture
  @@clicks = 0
  @@equal_clicks = 0

  def self.pin(view : UI::View, id : String, width : Float64?, height : Float64?)
    view.test_id = id
    view.minimum_width = view.maximum_width = width
    view.minimum_height = view.maximum_height = height
    view
  end

  def self.label(id : String, width : Float64? = nil, height : Float64? = nil)
    pin(UI::Label.new(id), id, width, height)
  end

  def self.matrix : UI::View
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.test_id = "layout-matrix"
    bounded = UI::Label.new("A deliberately long line that must obey maximum width and height")
    bounded.test_id = "bounds-label"
    bounded.minimum_width = 40.5
    bounded.maximum_width = 90.5
    bounded.maximum_height = 45.5
    root << bounded
    root << label("zero-size", 0.0, 0.0)
    bounded_fill = UI::VStack.new(0.0, UI::Alignment::Fill)
    pin(bounded_fill, "bounded-fill-parent", 200.0, 80.0)
    bounded = UI::Label.new("Long bounded native content in an exactly allocated parent slot")
    bounded.test_id = "bounded-fill"
    bounded.maximum_width = 90.5
    bounded.maximum_height = 45.5
    bounded_fill << bounded
    root << bounded_fill

    {"leading" => UI::Alignment::Leading, "center" => UI::Alignment::Center,
     "trailing" => UI::Alignment::Trailing, "fill" => UI::Alignment::Fill}.each do |name, alignment|
      stack = UI::VStack.new(0.0, alignment)
      pin(stack, "vertical-#{name}", 200.0, 70.0)
      stack << label("vertical-#{name}-child", name == "fill" ? nil : 40.0, 20.0)
      root << stack
    end
    {"top" => UI::Alignment::Top, "center" => UI::Alignment::Center,
     "bottom" => UI::Alignment::Bottom, "fill" => UI::Alignment::Fill}.each do |name, alignment|
      stack = UI::HStack.new(0.0, alignment)
      pin(stack, "horizontal-#{name}", 200.0, 80.0)
      stack << label("horizontal-#{name}-child", 40.0, name == "fill" ? nil : 20.0)
      root << stack
    end
    UI::Alignment.each do |alignment|
      name = alignment.to_s.downcase
      stack = UI::ZStack.new(alignment)
      pin(stack, "overlay-#{name}", 200.0, 80.0)
      stack << label("overlay-#{name}-first", 40.0, 20.0)
      stack << label("overlay-#{name}-last", alignment.fill? ? nil : 20.0, alignment.fill? ? nil : 10.0)
      root << stack
    end
    horizontal = UI::HStack.new(2.5, UI::Alignment::Center)
    pin(horizontal, "horizontal-spacer-row", 240.0, 30.0)
    horizontal << label("spacer-left", 40.0, 20.0)
    hidden = UI::Label.new("Hidden bounded content")
    hidden.maximum_width = 90.5
    hidden.hidden = true
    horizontal << hidden
    spacer = UI::Spacer.new(15.5)
    spacer.test_id = "horizontal-spacer"
    horizontal << spacer
    horizontal << label("spacer-right", 40.0, 20.0)
    root << horizontal

    vertical = UI::VStack.new(3.5, UI::Alignment::Center)
    pin(vertical, "vertical-spacer-column", 80.0, 160.0)
    vertical << label("spacer-top", 40.0, 20.0)
    spacer = UI::Spacer.new(12.5)
    spacer.test_id = "vertical-spacer"
    vertical << spacer
    vertical << label("spacer-bottom", 40.0, 20.0)
    root << vertical

    minimum = UI::HStack.new(0.0, UI::Alignment::Top)
    minimum.test_id = "intrinsic-spacer-row"
    spacer = UI::Spacer.new(15.5)
    spacer.test_id = "intrinsic-spacer"
    minimum << spacer
    minimum << label("intrinsic-spacer-label", 20.0, 20.0)
    root << minimum

    grow = UI::HStack.new(4.5, UI::Alignment::Fill)
    pin(grow, "grow-row", 240.0, 80.0)
    grow << label("grow-pinned", 40.0, 20.0)
    field = UI::TextField.new("Grow") { |_value| nil }
    field.test_id = "grow-field"
    field.grow!
    grow << field
    root << grow

    {"vertical" => {false, true}, "horizontal" => {true, false},
     "both" => {true, true}, "none" => {false, false}}.each do |name, axes|
      content = label("scroll-#{name}-content", 600.0, 400.0)
      scroll = UI::ScrollView.new(content)
      scroll.test_id = "scroll-#{name}"
      scroll.scroll_horizontal, scroll.scroll_vertical = axes
      scroll.frame_width = 180.5
      scroll.frame_height = 100.5
      scroll.shows_indicators = false
      root << scroll
    end
    flexible = UI::VStack.new(0.0, UI::Alignment::Leading)
    pin(flexible, "flexible-scroll-parent", 200.0, 220.0)
    flexible << label("flexible-scroll-title", 180.0, 20.0)
    scroll = UI::ScrollView.new(label("flexible-scroll-content", 180.0, 400.0))
    scroll.test_id = "flexible-scroll"
    scroll.frame_height = 17.0 # Ignored when the vertical axis is flexible.
    scroll.fill_vertical = true
    flexible << scroll
    root << flexible
    root
  end

  def self.equal_width : UI::View
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.state_key = "equal-width-screen"
    row = UI::HStack.new(2.5, UI::Alignment::Center)
    row.fill_equally = true
    row.padding = UI::EdgeInsets.new(top: 3.5, trailing: 4.5, bottom: 3.5, leading: 7.5)
    pin(row, "equal-pinned", 241.5, 80.5)
    row << label("equal-first", 20.5, 20.5)
    hidden = label("equal-hidden", 1000.0, 1000.0)
    hidden.hidden = true
    row << hidden
    row << label("equal-second", 30.5, 20.5)
    row << label("equal-third", 40.5, 20.5)
    spacer = UI::Spacer.new(15.5)
    spacer.test_id = "equal-spacer"
    row << spacer
    root << row

    {"equal-natural" => true, "unequal-natural" => false}.each do |id, equal|
      natural = UI::HStack.new(3.5, UI::Alignment::Top)
      natural.test_id = id
      natural.fill_equally = equal
      natural << pin(UI::Label.new("A"), "#{id}-short", nil, 20.5)
      natural << pin(UI::Label.new("A much longer label 雪"), "#{id}-long", nil, 20.5)
      bounded = pin(UI::Label.new("A bounded label with long content"), "#{id}-bounded", nil, 20.5)
      bounded.maximum_width = 90.5
      natural << bounded
      root << natural
    end

    actions = UI::HStack.new(4.5, UI::Alignment::Fill)
    actions.fill_equally = true
    pin(actions, "equal-actions", 241.5, 70.5)
    actions << UI::Button.new("Equal A") { @@equal_clicks += 1; nil }.tap { |view| view.test_id = "equal-action-a" }
    actions << UI::Button.new("Equal longer B") { @@equal_clicks += 1; nil }.tap { |view| view.test_id = "equal-action-b" }
    root << actions
    root << pin(UI::Label.new("Equal callbacks: #{@@equal_clicks}"), "equal-result", nil, nil)
    root
  end

  def self.interaction : UI::View
    content = UI::VStack.new(0.0, UI::Alignment::Leading)
    pin(content, "scroll-grid", 600.0, 400.0)
    content << label("Scroll across and down", 200.0, 20.0)
    content << UI::Spacer.new
    row = UI::HStack.new(0.0, UI::Alignment::Bottom)
    pin(row, "scroll-action-row", 600.0, 60.0)
    row << UI::Spacer.new
    button = UI::Button.new("Far corner action") { @@clicks += 1; nil }
    pin(button, "far-corner-action", 140.0, 60.0)
    row << button
    content << row
    scroll = UI::ScrollView.new(content)
    scroll.scroll_horizontal = true
    scroll.test_id = "layout-both-scroll"
    scroll.frame_width = 200.0
    scroll.frame_height = 120.0
    root = UI::VStack.new(12.0, UI::Alignment::Leading)
    root << UI::Label.new("Two-axis native scrolling")
    root << scroll
    root << UI::Label.new("Scroll callbacks: #{@@clicks}")
    root
  end
end
