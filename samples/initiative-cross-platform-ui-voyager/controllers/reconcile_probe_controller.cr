module Voyager
  # Controller for the Reconcile Probe screen.
  #
  # `:probe_text` stores the typed value and returns Rerender on EVERY
  # keystroke — the controlled-reactive path that the in-place reconciler
  # must handle without losing the field's keyboard focus. `:back` pops.
  class ReconcileProbeController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :back       then UI::ActionResult::Pop.new
      when :probe_text then set_text(context)
      else
        raise UI::Controller::UnknownActionError.new(
          "ReconcileProbeController has no action :#{name}"
        )
      end
    end

    private def set_text(context : UI::ScreenContext::Native) : UI::ActionResult
      ReconcileProbeState.text = context.action_params["text"]? || ""
      UI::ActionResult::Rerender.new
    end
  end
end
