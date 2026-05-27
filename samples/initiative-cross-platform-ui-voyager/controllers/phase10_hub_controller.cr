module Voyager
  # Phase 10D — controller for the Phase 10 exerciser hub.
  #
  # Each navigation action maps to one of the 5 exerciser routes. The
  # `:back` action returns Pop so the hub itself is dismissable from
  # whichever screen routed in.
  class Phase10HubController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :open_phase_10_intent_resolver  then UI::ActionResult::Navigate.new(:phase_10_intent_resolver)
      when :open_phase_10_class_c_dispatch then UI::ActionResult::Navigate.new(:phase_10_class_c_dispatch)
      when :open_phase_10_ax_metadata      then UI::ActionResult::Navigate.new(:phase_10_ax_metadata)
      when :open_phase_10_environment      then UI::ActionResult::Navigate.new(:phase_10_environment)
      when :open_phase_10_new_widgets      then UI::ActionResult::Navigate.new(:phase_10_new_widgets)
      when :back                           then UI::ActionResult::Pop.new
      else
        raise UI::Controller::UnknownActionError.new(
          "Phase10HubController has no action :#{name}"
        )
      end
    end
  end
end
