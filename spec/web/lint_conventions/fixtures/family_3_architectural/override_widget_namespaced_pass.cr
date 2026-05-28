# fixture_for: family_3/override_widget_subclass
# expected: pass
# synthetic_path: src/screens/namespaced_override_screen.cr
#
# False-positive guard #1 — `override_widget` with a module-qualified
# class constant `Module::ClassName`. Must pass.

class NamespacedOverrideScreen < UI::Screen
  override_widget :swipe_actions, UI::InlineActionRow

  def build(context : UI::ScreenContext) : UI::View
    UI::Label.new("ok")
  end
end
