module Voyager
  # Phase 10D — controller for the Class C dispatch exerciser.
  # `:phase_10_class_c_dispatched` re-renders so the result labels
  # reflect the latest `Phase10ExerciserState.last_dispatch_result`.
  class Phase10ClassCDispatchController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :phase_10_class_c_dispatched then UI::ActionResult::Rerender.new
      when :back                        then UI::ActionResult::Pop.new
      else
        raise UI::Controller::UnknownActionError.new(
          "Phase10ClassCDispatchController has no action :#{name}"
        )
      end
    end
  end
end
