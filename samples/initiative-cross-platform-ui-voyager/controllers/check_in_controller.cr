module Voyager
  # CheckInController — the Daily Check-in surface. Demonstrates value-carrying control
  # actions (Slider / Stepper pass their new value via action_params; the Toggle flips
  # shared state), each mutating Voyager.state and returning Rerender so the screen
  # rebuilds with the new value — the same reactive pattern the rest of the app uses
  # (and proven on the watch via the reactive re-render loop).
  class CheckInController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :set_mood        then set_mood(context)
      when :set_goal        then set_goal(context)
      when :toggle_reminder then toggle_reminder(context)
      when :save_checkin    then UI::ActionResult::Pop.new
      when :back            then UI::ActionResult::Pop.new
      else
        raise UI::Controller::UnknownActionError.new(
          "CheckInController has no action :#{name}"
        )
      end
    end

    def set_mood(context : UI::ScreenContext::Native) : UI::ActionResult
      if v = context.action_params["value"]?.try(&.to_i?)
        Voyager.state.checkin_mood = v.clamp(0, 10)
      end
      UI::ActionResult::Rerender.new
    end

    def set_goal(context : UI::ScreenContext::Native) : UI::ActionResult
      if v = context.action_params["value"]?.try(&.to_i?)
        Voyager.state.checkin_goal = v.clamp(1, 20)
      end
      UI::ActionResult::Rerender.new
    end

    def toggle_reminder(context : UI::ScreenContext::Native) : UI::ActionResult
      Voyager.state.checkin_reminder = !Voyager.state.checkin_reminder
      UI::ActionResult::Rerender.new
    end
  end
end
