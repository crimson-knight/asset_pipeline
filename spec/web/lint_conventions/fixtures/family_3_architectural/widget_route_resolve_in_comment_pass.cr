# fixture_for: family_3/widget_route_resolve_capability_arg
# expected: pass
# synthetic_path: src/screens/comment_caller_screen.cr
#
# False-positive guard #2 — a doc-comment line that mentions the
# retired `UI::WidgetRoute.resolve(:foo, ctx, MyClass)` signature must
# NOT trip the rule. The runner skips comment-only lines at entry.
#
# Reference shape (retired):
#   UI::WidgetRoute.resolve(:swipe_actions, context, screen_class: self.class)

class CommentCallerScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    # Historical: the old shape used a positional third arg.
    # UI::WidgetRoute.resolve(:swipe_actions, context, MyExtra)
    klass = UI::WidgetRoute.resolve(:swipe_actions, context)
    UI::Label.new("#{klass}")
  end
end
