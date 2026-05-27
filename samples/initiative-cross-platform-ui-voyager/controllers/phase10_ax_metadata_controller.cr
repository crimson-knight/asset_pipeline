module Voyager
  # Phase 10D — controller for the AX metadata exerciser.
  class Phase10AxMetadataController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :phase_10_ax_action then UI::ActionResult::Rerender.new
      when :back               then UI::ActionResult::Pop.new
      else
        raise UI::Controller::UnknownActionError.new(
          "Phase10AxMetadataController has no action :#{name}"
        )
      end
    end
  end
end
