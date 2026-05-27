# fixture_for: family_3/widget_route_resolve_capability_arg
# expected: pass
# synthetic_path: src/screens/intent_caller_screen.cr
#
# `UI::WidgetRoute.resolve` called with two positional args and an
# optional `capabilities_required:` kwarg. Must pass.

class IntentCallerScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    klass = UI::WidgetRoute.resolve(:swipe_actions, context)
    klass2 = UI::WidgetRoute.resolve(:swipe_actions, context, capabilities_required: {:supports_edge_trailing => true})
    UI::Label.new("ok")
  end
end
