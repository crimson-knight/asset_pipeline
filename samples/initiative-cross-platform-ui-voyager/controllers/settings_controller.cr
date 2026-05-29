module Voyager
  # Phase 8D.1 — SettingsController.
  #
  # :toggle_filter flips Voyager.state.hide_completed and returns
  # Rerender. The host's render path on Rerender rebuilds the current
  # screen (Settings) with the new toggle state, AND the next time the
  # user pops back to Todos, that screen's build reads the same
  # singleton state so the filter is honored — the state-propagation
  # litmus path the original Voyager brief locked in.
  #
  # :back returns Pop. (The toggle's filter change has already taken
  # effect via Rerender; popping returns to Todos which reads the
  # new state.)
  class SettingsController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :toggle_filter          then toggle_filter(context)
      when :back                   then back(context)
      when :open_phase_10_hub      then open_phase_10_hub(context)
      when :open_component_gallery then UI::ActionResult::Navigate.new(:component_gallery)
      else
        raise UI::Controller::UnknownActionError.new(
          "SettingsController has no action :#{name}"
        )
      end
    end

    def toggle_filter(context : UI::ScreenContext::Native) : UI::ActionResult
      Voyager.state.hide_completed = !Voyager.state.hide_completed
      UI::ActionResult::Rerender.new
    end

    def back(context : UI::ScreenContext::Native) : UI::ActionResult
      UI::ActionResult::Pop.new
    end

    # Phase 10D — open the Phase 10 exerciser hub screen.
    def open_phase_10_hub(context : UI::ScreenContext::Native) : UI::ActionResult
      UI::ActionResult::Navigate.new(:phase_10_hub)
    end
  end
end
