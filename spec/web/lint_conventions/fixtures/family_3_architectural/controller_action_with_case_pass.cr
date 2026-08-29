# fixture_for: family_3/controller_action_returns_action_result
# expected: pass
# synthetic_path: src/controllers/case_controller.cr
#
# False-positive guard #1 — controller action whose final expression
# is a multi-line `case ... end` block. The rule accepts the trailing
# `end` line as a plausible return (the branches each return an
# ActionResult).

class CaseController < UI::Controller
  def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
    case name
    when :submit then navigate_to(:todos)
    when :cancel then pop_navigation
    else              render_current_screen
    end
  end
end
