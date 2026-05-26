# fixture_for: family_3/controller_action_returns_action_result
# expected: fail
# synthetic_path: src/controllers/leaky_controller.cr
#
# A controller action that declares `: UI::ActionResult` but ends in
# a `puts` (returning Nil) — the dispatcher silently no-ops.

class LeakyController < UI::Controller
  def submit(context : UI::ScreenContext::Native) : UI::ActionResult
    Voyager.state.set_email(context.params["email"])
    puts "submitted"
  end
end
