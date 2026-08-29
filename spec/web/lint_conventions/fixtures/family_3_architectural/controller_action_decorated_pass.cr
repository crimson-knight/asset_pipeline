# fixture_for: family_3/controller_action_returns_action_result
# expected: pass
# synthetic_path: src/controllers/decorated_good_controller.cr
#
# A controller handler decorated with `action_handler :submit` (no
# explicit `: UI::ActionResult` annotation) that ends with a
# controller helper. Must pass — the rule recognises decorated
# handlers and accepts the helper as the terminal.

class DecoratedGoodController < UI::Controller
  action_handler :submit

  def submit(context : UI::ScreenContext::Native)
    Voyager.state.set_email(context.params["email"])
    navigate_to(:todos)
  end
end
