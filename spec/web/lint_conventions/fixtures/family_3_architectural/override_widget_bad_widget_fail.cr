# fixture_for: family_3/override_widget_subclass
# expected: fail
# synthetic_path: src/screens/bad_override_screen.cr
#
# `override_widget` passed a symbol literal as the widget. Must be
# flagged — the widget must be a class constant.

class BadOverrideScreen < UI::Screen
  override_widget :swipe_actions, :missing_widget

  def build(context : UI::ScreenContext) : UI::View
    UI::Label.new("oops")
  end
end
