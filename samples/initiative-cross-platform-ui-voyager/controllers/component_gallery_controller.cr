module Voyager
  # Controller for the Component Gallery screen.
  #
  # `:back` Pops back to Settings. The `:gallery_*` actions drive the
  # live-interaction section: each mutates GalleryState and returns
  # Rerender so the readout reflects the new value — this is what proves
  # the demo widgets actually FUNCTION (interaction → action → re-render
  # with updated state), not merely render.
  class ComponentGalleryController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :back            then UI::ActionResult::Pop.new
      when :gallery_tap     then bump_tap
      when :gallery_toggle  then set_toggle(context)
      when :gallery_segment then set_segment(context)
      when :gallery_stepper then set_stepper(context)
      when :gallery_event   then record_event(context)
      else
        raise UI::Controller::UnknownActionError.new(
          "ComponentGalleryController has no action :#{name}"
        )
      end
    end

    private def bump_tap : UI::ActionResult
      GalleryState.bump_tap
      UI::ActionResult::Rerender.new
    end

    private def set_toggle(context : UI::ScreenContext::Native) : UI::ActionResult
      GalleryState.toggle_on = (context.action_params["on"]? == "true")
      UI::ActionResult::Rerender.new
    end

    private def set_segment(context : UI::ScreenContext::Native) : UI::ActionResult
      GalleryState.segment_index = (context.action_params["index"]? || "0").to_i? || 0
      UI::ActionResult::Rerender.new
    end

    private def set_stepper(context : UI::ScreenContext::Native) : UI::ActionResult
      GalleryState.stepper_value = (context.action_params["value"]? || "0").to_i? || 0
      UI::ActionResult::Rerender.new
    end

    private def record_event(context : UI::ScreenContext::Native) : UI::ActionResult
      GalleryState.last_event = context.action_params["text"]? || "(event)"
      UI::ActionResult::Rerender.new
    end
  end
end
