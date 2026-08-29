module Voyager
  # Controller for the Phase C Welcome / About designed demo screen.
  class WelcomeController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :back then UI::ActionResult::Pop.new
      else
        raise UI::Controller::UnknownActionError.new(
          "WelcomeController has no action :#{name}"
        )
      end
    end
  end
end
