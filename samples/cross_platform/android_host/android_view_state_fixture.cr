module AndroidViewStateFixture
  @@values = {"a" => "Alpha 雪 😀 text", "b" => "Other screen text"}
  @@extra = false
  @@navigation : UI::NavigationStack? = nil

  class Page < UI::View
    def initialize(@name : String)
      self.state_key = "page:#{@name}"
    end

    def accept(visitor : UI::PlatformVisitor)
      AndroidViewStateFixture.screen(@name).accept(visitor)
    end
  end

  def self.navigation : UI::View
    @@navigation ||= UI::NavigationStack.new(Page.new("a"), "View state").tap { |view| view.state_key = "state-navigation" }
  end

  def self.label(text : String, id : String)
    UI::Label.new(text).tap { |view| view.test_id = id }
  end

  def self.screen(name : String) : UI::View
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.state_key = "page-layout"
    root << label("Page #{name}", "state-page")
    root << label("Echo: #{@@values[name]}", "state-echo")
    root << label("Structure: #{@@extra}", "state-structure")
    root << label("Inserted sibling", "state-inserted") if @@extra
    field = UI::TextField.new("State editor", text: @@values[name]) { |value| @@values[name] = value; nil }
    field.test_id = "state-editor"
    field.state_key = "editor:雪\0key"
    field.maximum_width = 250.5
    field.grow!
    root << field
    root << UI::Button.new("Insert sibling") { @@extra = !@@extra; nil }
    root << UI::NavigationLink.new("Open B", Page.new("b")) if name == "a"
    content = UI::VStack.new(0.0, UI::Alignment::Leading)
    content.minimum_width = content.maximum_width = 600.0
    content.minimum_height = content.maximum_height = 500.0
    content << label("Scrollable #{name}", "state-scroll-heading")
    content << UI::Spacer.new
    content << label("Bottom #{name}", "state-scroll-bottom")
    scroll = UI::ScrollView.new(content)
    scroll.test_id = "state-scroll"
    scroll.state_key = "viewport"
    scroll.scroll_horizontal = true
    scroll.frame_width = 200.0
    scroll.frame_height = 120.0
    root << scroll
    root
  end
end
