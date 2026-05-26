# fixture_for: family_3/controller_action_returns_action_result
# expected: fail
# synthetic_path: src/controllers/decorated_leaky_controller.cr
#
# A controller handler decorated with `action_handler :submit` (no
# explicit `: UI::ActionResult` annotation) whose terminal expression
# is a `puts` — returns Nil. The dispatcher silently no-ops; the
# rule must flag this even though the method has no return-type
# annotation.

class DecoratedLeakyController < UI::Controller
  action_handler :submit

  def submit(context : UI::ScreenContext::Native)
    Voyager.state.set_email(context.params["email"])
    puts "submitted"
  end
end
