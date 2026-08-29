# fixture_for: family_3/no_app_domain_mutation_in_screen_build
# expected: fail
# synthetic_path: src/screens/leaky_screen.cr
#
# A UI::Screen subclass that mutates Voyager.state inside build —
# the canonical anti-pattern Rule 1 traps.

class LeakyScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    Voyager.state.hide_completed = true
    UI::Label.new("oops")
  end
end
