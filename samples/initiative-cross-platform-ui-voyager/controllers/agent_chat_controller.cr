module Voyager
  # Controller for the cross-platform Agent Chat demo screen.
  class AgentChatController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :back         then UI::ActionResult::Pop.new
      when :send_message then UI::ActionResult::Rerender.new
      else
        raise UI::Controller::UnknownActionError.new(
          "AgentChatController has no action :#{name}"
        )
      end
    end
  end
end
