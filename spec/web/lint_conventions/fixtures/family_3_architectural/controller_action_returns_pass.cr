# fixture_for: family_3/controller_action_returns_action_result
# expected: pass
# synthetic_path: src/controllers/good_controller.cr
#
# A controller action that declares `: UI::ActionResult` and ends
# with a controller helper. Must pass.

class GoodController < UI::Controller
  def submit(context : UI::ScreenContext::Native) : UI::ActionResult
    Voyager.state.set_email(context.params["email"])
    navigate_to(:todos)
  end
end
