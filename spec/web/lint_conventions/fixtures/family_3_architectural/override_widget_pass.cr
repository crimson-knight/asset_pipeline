# fixture_for: family_3/override_widget_subclass
# expected: pass
# synthetic_path: src/screens/override_screen.cr
#
# `override_widget :foo, MyWidget` with a proper class constant.
# Must pass.

class OverrideScreen < UI::Screen
  override_widget :swipe_actions, AcmeFancySwipeRow

  def build(context : UI::ScreenContext) : UI::View
    UI::Label.new("ok")
  end
end
