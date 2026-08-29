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
      when :set_speech_rate        then set_speech_rate(context)
      when :preview_voice          then preview_voice(context)
      when :back                   then back(context)
      when :open_phase_10_hub      then open_phase_10_hub(context)
      when :open_check_in          then UI::ActionResult::Navigate.new(:check_in)
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

    # Voice speed slider → state.speech_rate (clamped to the slider's range),
    # persisted via UI::Preferences so it survives relaunch. Rerender so the
    # "Voice speed: NN%" readout reflects the new value.
    def set_speech_rate(context : UI::ScreenContext::Native) : UI::ActionResult
      # Value arrives as an integer percent (see the slider's on_change): String#to_f?
      # crashes on iOS/watchOS (FastFloat class-init gap), so we parse an Int and
      # divide. Int division by a Float literal is plain math — no float parsing.
      if pct = context.action_params["value"]?.try(&.to_i?)
        rate = (pct / 100.0).clamp(0.35, 0.65)
        Voyager.state.speech_rate = rate
        UI::Preferences.set_double("voyager.speech_rate", rate)
      end
      UI::ActionResult::Rerender.new
    end

    # "Preview voice" — speak a sample at the current rate so the user hears the
    # setting immediately (the same UI::Speech path the agent's replies use).
    def preview_voice(context : UI::ScreenContext::Native) : UI::ActionResult
      UI::Speech.speak("This is how I'll sound when I read your messages.",
        rate: Voyager.state.speech_rate)
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
