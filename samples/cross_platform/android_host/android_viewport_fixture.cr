# Host viewport contract. The host reports the rectangle it lays the tree out
# in and the system-bar insets it left for the application, in dp, before
# every render and on every change. The fixture prints the last report and
# sizes two views from it the way an application does: a bar exactly as wide
# as the content column and a label that wraps at it. A device test compares
# the printed numbers with the mount it measures itself, checks that the bar
# and the wrap width follow the screen, and reads the numbers again after a
# rotation. The render count is cumulative for the process, so a test can
# tell how many refreshes a report took to settle.
module AndroidViewportFixture
  WRAP_INSET = 36.0
  WRAP_TEXT  = "The quick brown fox jumps over the lazy dog and keeps going until the line is full, " \
               "then the next line starts where the viewport says it must and not one dp later."

  @@renders = 0

  def self.reset! : Nil
    @@renders = 0
  end

  def self.build(viewport : UI::Android::Viewport?) : UI::View
    @@renders += 1
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.test_id = "viewport-page"
    root.padding = UI::EdgeInsets.new(top: 12.0, trailing: 18.0, bottom: 12.0, leading: 18.0)
    heading = UI::Label.new("Native viewport")
    heading.accessibility_role = :header
    heading.test_id = "viewport-heading"
    root << heading
    if viewport
      root << metric("viewport-width", "Width", viewport.width)
      root << metric("viewport-height", "Height", viewport.height)
      root << metric("viewport-top", "Top", viewport.top_inset)
      root << metric("viewport-bottom", "Bottom", viewport.bottom_inset)
      root << metric("viewport-left", "Left", viewport.left_inset)
      root << metric("viewport-right", "Right", viewport.right_inset)
      root << metric("viewport-density", "Density", viewport.density)
      column = viewport.width - WRAP_INSET
      root << bar(column)
      root << wrap(column)
    else
      missing = UI::Label.new("No viewport reported")
      missing.test_id = "viewport-missing"
      root << missing
    end
    renders = UI::Label.new("Renders #{@@renders}")
    renders.test_id = "viewport-renders"
    root << renders
    root
  end

  private def self.metric(id : String, name : String, value : Float64) : UI::Label
    label = UI::Label.new("#{name} #{value.round(1)}")
    label.test_id = id
    label
  end

  # A bar exactly as wide as the content column: the fixed size an
  # application gives a full-width surface from the viewport.
  private def self.bar(column : Float64) : UI::View
    bar = UI::VStack.new(0.0, UI::Alignment::Leading)
    bar.test_id = "viewport-bar"
    bar.background = UI::Color.new(r: 0.40, g: 0.31, b: 0.89)
    bar.minimum_width = bar.maximum_width = column
    bar.minimum_height = bar.maximum_height = 6.0
    bar
  end

  # A label told to wrap at the column, the way an application wraps its copy.
  private def self.wrap(column : Float64) : UI::Label
    label = UI::Label.new(WRAP_TEXT)
    label.test_id = "viewport-wrap"
    label.preferred_max_layout_width = column
    label
  end
end
