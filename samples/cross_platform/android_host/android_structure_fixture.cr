# Structure Tier A candidates: shapes with intrinsic sizes, a grid of rows, a
# form with a section, and a disclosure group whose header toggles Crystal state.
module AndroidStructureFixture
  @@expanded = false
  @@toggles = 0

  def self.reset
    @@expanded = false; @@toggles = 0
  end

  def self.mark(view : UI::View, id : String) : UI::View
    view.test_id = id
    view.state_key = id
    view
  end

  def self.build : UI::View
    root = UI::VStack.new(6.0, UI::Alignment::Leading)
    root.state_key = "structure-screen"
    root << mark(UI::Label.new("Native structure").tap { |v| v.accessibility_role = :header }, "structure-heading")

    circle = UI::Circle.new(48.0)
    circle.fill_color = UI::Color.new(r: 0.2, g: 0.4, b: 0.9)
    root << mark(circle, "structure-circle")

    capsule = UI::Capsule.new(120.0, 36.0)
    capsule.fill_color = UI::Color.new(r: 0.9, g: 0.5, b: 0.1)
    capsule.stroke_width = 2.0
    capsule.stroke_color = UI::Color.new(r: 0.1, g: 0.1, b: 0.1)
    root << mark(capsule, "structure-capsule")

    rectangle = UI::Rectangle.new(90.0, 30.0)
    rectangle.fill_color = UI::Color.new(r: 0.1, g: 0.6, b: 0.3)
    root << mark(rectangle, "structure-rectangle")

    rounded = UI::RoundedRectangle.new(12.0, 100.0, 40.0)
    rounded.fill_color = UI::Color.new(r: 0.5, g: 0.2, b: 0.7)
    root << mark(rounded, "structure-rounded")

    grid = UI::Grid.new
    grid.add_row([UI::Label.new("A1"), UI::Label.new("A2")] of UI::View)
    grid.add_row([UI::Label.new("B1"), UI::Label.new("B2")] of UI::View)
    root << mark(grid, "structure-grid")

    form = UI::Form.new
    section = form.add_section("Contact", "Footer note")
    section.fields << UI::Form::Field.new(label: "Name", content: UI::Label.new("Ada"))
    section.fields << UI::Form::Field.new(label: "Email", content: UI::Label.new("ada@example.invalid"))
    root << mark(form, "structure-form")

    detail = mark(UI::Label.new("Hidden detail"), "structure-detail")
    disclosure = UI::DisclosureGroup.new("Details", @@expanded, [detail] of UI::View) do |requested|
      @@expanded = requested
      @@toggles += 1
      nil
    end
    root << mark(disclosure, "structure-disclosure")
    root << mark(UI::Label.new("Expanded: #{@@expanded}; toggles: #{@@toggles}"), "structure-disclosure-echo")
    root
  end
end
