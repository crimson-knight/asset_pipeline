# fixture_for: family_3/no_app_domain_mutation_in_screen_build
# expected: pass
# synthetic_path: src/screens/clean_screen.cr
#
# A UI::Screen subclass that READS Voyager.state into a local but
# never mutates it inside build. Must pass.

class CleanScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    state = Voyager.state
    label = UI::Label.new("Todos: #{state.todos.size}")
    label
  end
end
