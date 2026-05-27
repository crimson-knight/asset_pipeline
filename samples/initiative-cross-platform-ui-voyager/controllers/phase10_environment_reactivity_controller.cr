module Voyager
  # Phase 10D — controller for the environment-reactivity exerciser.
  # The environment readouts are static-per-render so the only action
  # is `:back`.
  class Phase10EnvironmentReactivityController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :back then UI::ActionResult::Pop.new
      else
        raise UI::Controller::UnknownActionError.new(
          "Phase10EnvironmentReactivityController has no action :#{name}"
        )
      end
    end
  end
end
