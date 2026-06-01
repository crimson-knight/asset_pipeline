module Voyager
  # Controller for the ComboBox Probe. `:combo_reveal` just rerenders so the
  # readout surfaces the captured value (combo on_change stores it without
  # rerendering, mirroring the gallery's capture-without-rerender pattern).
  class ComboProbeController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :combo_reveal then UI::ActionResult::Rerender.new
      else
        raise UI::Controller::UnknownActionError.new(
          "ComboProbeController has no action :#{name}"
        )
      end
    end
  end
end
