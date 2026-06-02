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
      when :set_focus       then set_focus(context)
      when :toggle_reminder then toggle_reminder(context)
      when :save_checkin    then save_checkin(context)
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

    def set_focus(context : UI::ScreenContext::Native) : UI::ActionResult
      if v = context.action_params["value"]?.try(&.to_i?)
        Voyager.state.checkin_focus_index = v.clamp(0, Voyager::State.checkin_focuses.size - 1)
      end
      UI::ActionResult::Rerender.new
    end

    def toggle_reminder(context : UI::ScreenContext::Native) : UI::ActionResult
      Voyager.state.checkin_reminder = !Voyager.state.checkin_reminder
      UI::ActionResult::Rerender.new
    end

    # Stable identifier for the recurring daily check-in notification, so a
    # re-save updates (rather than duplicates) the request and a toggle-off can
    # remove exactly this one. A method, not a class constant (the iOS class-init
    # gap can skip constant initializers — see State.checkin_focuses).
    private def reminder_identifier : String
      "voyager-daily-checkin"
    end

    # Save the check-in. This is where the Happy Coach vision starts: the agent
    # can actually REACH you. If the reminder is on we schedule a real recurring
    # local notification through the kit's UI::Notifications facade (the host
    # already requested notification authorization at first launch); if it's off
    # we cancel it. We then record the REAL outcome (queried back from the
    # system's pending queue) into state.checkin_status — an honest functional
    # signal (the request genuinely landed), not a synthetic "saved" flag. The
    # screen rebuilds (Rerender) and shows the confirmation; Back navigates away.
    def save_checkin(context : UI::ScreenContext::Native) : UI::ActionResult
      state = Voyager.state
      focuses = Voyager::State.checkin_focuses
      focus = focuses[state.checkin_focus_index]? || focuses.first

      # Persist the check-in settings so they survive relaunch (UI::Preferences).
      UI::Preferences.set_int("voyager.checkin_mood", state.checkin_mood)
      UI::Preferences.set_int("voyager.checkin_goal", state.checkin_goal)
      UI::Preferences.set_bool("voyager.checkin_reminder", state.checkin_reminder)
      UI::Preferences.set_int("voyager.checkin_focus_index", state.checkin_focus_index)

      if state.checkin_reminder
        # Quiet, no-nag authorization: provisional grants immediately with no
        # permission dialog (ideal for a coach that should be able to reach you
        # without interrupting on first run). Required on watchOS, where a
        # request is NOT tracked in the pending queue until authorized (unlike
        # iOS, which tracks pending even while NotDetermined). Idempotent — it
        # never downgrades an existing full grant.
        UI::Notifications.request_authorization(provisional: true)
        request = UI::NotificationRequest.new(
          title: "Daily Check-in",
          body: "Time for your check-in with your agent. How's your #{focus.downcase} today?",
          identifier: reminder_identifier,
          subtitle: "Mood goal: feel a little better than yesterday",
          delay_seconds: 60.0, # min cadence for a repeating trigger
          repeats: true,
          sound: true,
          thread_id: "voyager-coach",
        )
        scheduled = UI::Notifications.schedule(request)
        landed = UI::Notifications.has_pending?(reminder_identifier)
        pending = UI::Notifications.pending_count
        state.checkin_status =
          if scheduled && landed
            "✓ Reminder scheduled — your agent will check in (#{pending} pending)"
          else
            "Reminder could not be scheduled on this device"
          end
      else
        UI::Notifications.remove_pending(reminder_identifier)
        still = UI::Notifications.has_pending?(reminder_identifier)
        state.checkin_status =
          still ? "Reminder could not be cleared" : "Reminder off — no check-in scheduled"
      end

      UI::ActionResult::Rerender.new
    end
  end
end
