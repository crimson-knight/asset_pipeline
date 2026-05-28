# fixture_for: family_3/widget_route_resolve_capability_arg
# expected: pass
# synthetic_path: src/screens/multiline_caller_screen.cr
#
# False-positive guard #1 — multi-line call where positional args
# and the kwarg span multiple lines. The rule concatenates
# continuation lines until parens balance.

class MultilineCallerScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    klass = UI::WidgetRoute.resolve(
      :swipe_actions,
      context,
      capabilities_required: {
        :supports_edge_trailing => true,
        :supports_role_default  => true,
      },
    )
    UI::Label.new("ok")
  end
end
