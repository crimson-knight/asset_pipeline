# fixture_for: family_3/override_intent_widget_subclass
# expected: pass
# synthetic_path: src/screens/inline_comment_screen.cr
#
# False-positive guard #3 — an inline trailing comment that contains
# the literal text `override_intent :foo, BarClass` on a NON-macro
# line. The rule must scrub inline comments before regex-matching so
# the comment text is invisible to the entry pattern.

class InlineCommentScreen < UI::Screen
  some_setting :enabled # override_intent :swipe_actions, BogusWidget

  def build(context : UI::ScreenContext) : UI::View
    UI::Label.new("inline comment guard")
  end
end
