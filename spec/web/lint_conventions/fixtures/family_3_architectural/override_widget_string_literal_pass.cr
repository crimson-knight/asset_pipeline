# fixture_for: family_3/override_widget_subclass
# expected: pass
# synthetic_path: src/screens/string_literal_screen.cr
#
# False-positive guard #4 — a string literal containing the literal
# text `override_widget :foo, :bogus` (a SHAPE that would otherwise
# flag if the rule scanned inside strings). The rule must scrub
# string-literal interiors before regex-matching.

class StringLiteralScreen < UI::Screen
  ERROR_MESSAGE = "use override_widget :swipe_actions, :bogus_widget — and yes a class constant is required"

  def build(context : UI::ScreenContext) : UI::View
    UI::Label.new(ERROR_MESSAGE)
  end
end
