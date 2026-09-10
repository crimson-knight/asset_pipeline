module AndroidCompoundFocusFixture
  @@reverse = false
  @@request = false

  def self.mark(view : UI::View, id : String)
    view.test_id = view.state_key = id
    view
  end

  def self.build : UI::View
    requested = @@request
    @@request = false
    root = UI::VStack.new(4.0, UI::Alignment::Leading)
    root.state_key = "compound-focus-root"
    root << UI::Label.new("Compound focus")
    root << mark(UI::Button.new("Request selected focus") { @@request = true; nil }, "compound-request")
    root << mark(UI::Button.new("Change catalog") { @@reverse = !@@reverse; nil }, "compound-change")
    options = ["Choice one", "Choice 雪 two", "Choice three"]
    options.reverse! if @@reverse
    radio = UI::RadioGroup.new(options, 0)
    radio.focused = requested
    root << mark(radio, "compound-radio")
    root << mark(UI::SegmentedControl.new(["First", "Second", "Third"], 0), "compound-segments")
    root << mark(UI::RadioGroup.new(["Disabled A", "Disabled B"], 0).tap { |v| v.accessibility_traits = [:not_enabled]; v.focused = true }, "compound-disabled")
    root << mark(UI::RadioGroup.new(["Skip A", "Skip B"], 0).tap { |v| v.focusable = false; v.focused = true }, "compound-skip")
    root
  end
end
