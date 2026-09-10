# Host tick contract. The host runs the application's registered tick on its
# main looper while the surface is in the foreground, first right after the
# first render and then once per interval, and stops it while the surface is
# in the background. The fixture counts the ticks the bridge handed it and the
# times it was built, so a device test can prove that the count advances
# without a touch, that each tick's `invalidate` lands one render, and that a
# backgrounded surface receives none. Both counters are cumulative for the
# process; assertions compare differences.
module AndroidTickFixture
  @@ticks = 0
  @@renders = 0

  def self.ticks : Int32
    @@ticks
  end

  def self.renders : Int32
    @@renders
  end

  def self.tick! : Int32
    @@ticks += 1
  end

  def self.reset! : Nil
    @@ticks = 0
    @@renders = 0
  end

  def self.build : UI::View
    @@renders += 1
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.test_id = "tick-page"
    root.padding = UI::EdgeInsets.new(top: 12.0, trailing: 18.0, bottom: 12.0, leading: 18.0)
    heading = UI::Label.new("Native tick")
    heading.accessibility_role = :header
    heading.test_id = "tick-heading"
    root << heading
    root << counter("tick-count", "Ticks #{@@ticks}")
    root << counter("tick-renders", "Renders #{@@renders}")
    note = UI::Label.new("The host advances the counts without a touch and stops them in the background.")
    note.test_id = "tick-note"
    root << note
    root
  end

  private def self.counter(id : String, text : String) : UI::Label
    label = UI::Label.new(text)
    label.test_id = id
    label
  end
end
