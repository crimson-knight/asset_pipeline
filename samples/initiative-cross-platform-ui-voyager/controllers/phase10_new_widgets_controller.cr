module Voyager
  # Phase 10D — controller for the new-widgets exerciser.
  class Phase10NewWidgetsController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :phase_10_widget_action then UI::ActionResult::Rerender.new
      when :back                   then UI::ActionResult::Pop.new
      else
        raise UI::Controller::UnknownActionError.new(
          "Phase10NewWidgetsController has no action :#{name}"
        )
      end
    end
  end
end
