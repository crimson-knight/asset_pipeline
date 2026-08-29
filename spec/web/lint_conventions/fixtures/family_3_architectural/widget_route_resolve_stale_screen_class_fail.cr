# fixture_for: family_3/widget_route_resolve_capability_arg
# expected: fail
# synthetic_path: src/screens/stale_caller_screen.cr
#
# Stale `screen_class:` kwarg — retired in 10B.0 iter-9. Must be
# flagged.

class StaleCallerScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    klass = UI::WidgetRoute.resolve(:swipe_actions, context, screen_class: self.class)
    UI::Label.new("oops")
  end
end
