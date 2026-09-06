module AndroidNavigationFixture
  # Retain navigation, not generated native views. Each screen rebuilds from
  # the same Crystal application state when mounted or Activity-recreated.
  class Screen < UI::View
    def initialize(@screen_id : Symbol)
    end

    def accept(visitor : UI::PlatformVisitor)
      AndroidNavigationFixture.content(@screen_id).accept(visitor)
    end
  end

  @@navigation = UI::NavigationStack.new(Screen.new(:home), "Navigation 雪 😀")
  @@inner = UI::NavigationStack.new(Screen.new(:nested), "Nested stack")
  @@draft = "Retained draft"
  @@count = 0

  def self.build : UI::View
    @@navigation
  end

  def self.content(id : Symbol) : UI::View
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    case id
    when :home
      root << UI::Label.new("Navigation home")
      root << UI::NavigationLink.new("Open details", Screen.new(:details))
      disabled = UI::NavigationLink.new("Disabled navigation", Screen.new(:settings))
      disabled.accessibility_traits << :not_enabled
      root << disabled
    when :details
      root << UI::Label.new("Navigation details")
      root << UI::TextField.new("Draft", text: @@draft) { |value| @@draft = value }
      root << UI::NavigationLink.new("Open settings", Screen.new(:settings))
    when :settings
      root << UI::Label.new("Navigation settings")
      root << UI::Label.new("Navigation count: #{@@count}")
      root << UI::Button.new("Change shared state") { @@count += 1; nil }
      root << UI::Button.new("Return to home") { @@inner.pop_to_root; @@navigation.pop_to_root }
      root << @@inner
    when :nested
      root << UI::Label.new("Nested root")
      root << UI::NavigationLink.new("Open nested detail", Screen.new(:nested_detail))
    when :nested_detail
      root << UI::Label.new("Nested detail")
    end
    root
  end
end
