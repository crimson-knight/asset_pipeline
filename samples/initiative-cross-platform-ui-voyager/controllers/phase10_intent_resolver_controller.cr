module Voyager
  # Phase 10D — controller for the Phase 10 intent-resolver exerciser.
  # `:phase_10_intent_action` re-renders so the "Last action" label
  # picks up the swipe-action mutation written to
  # `Phase10ExerciserState.last_action`.
  class Phase10IntentResolverController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :phase_10_intent_action then UI::ActionResult::Rerender.new
      when :back                   then UI::ActionResult::Pop.new
      else
        raise UI::Controller::UnknownActionError.new(
          "Phase10IntentResolverController has no action :#{name}"
        )
      end
    end
  end
end
