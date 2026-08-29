# fixture_for: family_3/no_app_domain_mutation_in_screen_build
# expected: pass
# synthetic_path: src/screens/state_read_screen.cr
#
# False-positive guard #2 — comparing `Voyager.state.foo == bar`
# inside an `if` is a READ, not a mutation. The assignment regex
# requires a single `=` not followed by `=`; verify the `==` path is
# allowed.

class StateReadScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    state = Voyager.state
    if Voyager.state.hide_completed == true
      UI::Label.new("hidden")
    else
      UI::Label.new("shown: #{state.todos.size}")
    end
  end
end
