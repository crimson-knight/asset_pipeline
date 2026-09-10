module AndroidFocusFixture
  @@request = false
  @@requests = 0
  @@text = "Focusable 雪 😀"

  def self.mark(view : UI::View, id : String)
    view.test_id = view.state_key = id
    view
  end

  def self.build : UI::View
    requested = @@request
    @@request = false
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.state_key = "focus-visibility-root"
    root << mark(UI::Label.new("Focus visibility"), "focus-heading")
    root << mark(UI::Label.new("Requests: #{@@requests}"), "focus-status")
    root << mark(UI::Button.new("Focus distant field") { @@request = true; @@requests += 1; nil }, "focus-request")
    content = UI::VStack.new(0.0, UI::Alignment::Leading)
    content.minimum_width = content.maximum_width = 800.0
    content << UI::Label.new("Before target").tap { |v| v.minimum_height = v.maximum_height = 400.0 }
    row = UI::HStack.new(0.0, UI::Alignment::Top)
    row << UI::Label.new("Beside target").tap { |v| v.minimum_width = v.maximum_width = 420.0 }
    field = UI::TextField.new("Distant editor", text: @@text) { |text| @@text = text; nil }
    field.minimum_width = field.maximum_width = 200.0
    field.focused = requested
    row << mark(field, "focus-distant-editor")
    content << row
    content << UI::Label.new("After target").tap { |v| v.minimum_height = v.maximum_height = 200.0 }
    scroll = UI::ScrollView.new(content)
    scroll.scroll_horizontal = true
    scroll.frame_width = 260.0
    scroll.frame_height = 160.0
    root << mark(scroll, "focus-nested-scroll")
    root
  end
end
