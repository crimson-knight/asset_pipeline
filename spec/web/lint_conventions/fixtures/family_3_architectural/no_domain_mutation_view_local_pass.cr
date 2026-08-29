# fixture_for: family_3/no_app_domain_mutation_in_screen_build
# expected: pass
# synthetic_path: src/screens/view_local_screen.cr
#
# False-positive guard #1 — view-local mutation. Building up a view
# tree by appending child views to a local VStack is legitimate and
# must NOT be flagged. Only domain-singleton mutations are flagged.

class ViewLocalScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    root = UI::VStack.new(spacing: 8.0)
    root << UI::Label.new("Item A")
    root << UI::Label.new("Item B")
    save = UI::Button.new("Save")
    save.disabled = true
    root << save
    root.as(UI::View)
  end
end
