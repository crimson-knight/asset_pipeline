# fixture_for: family_3/controller_action_returns_action_result
# expected: pass
# synthetic_path: src/controllers/early_return_controller.cr
#
# False-positive guard #2 — controller action with an early return
# of an ActionResult constructor. The terminal line is the matching
# helper, which the rule accepts.

class EarlyReturnController < UI::Controller
  def submit(context : UI::ScreenContext::Native) : UI::ActionResult
    if context.params["email"].empty?
      return UI::ActionResult::Pop.new
    end
    Voyager.state.set_email(context.params["email"])
    navigate_to(:todos)
  end
end
