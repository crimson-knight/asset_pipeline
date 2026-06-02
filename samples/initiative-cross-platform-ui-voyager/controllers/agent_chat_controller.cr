module Voyager
  # Controller for the cross-platform Agent Chat demo screen.
  class AgentChatController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :back         then UI::ActionResult::Pop.new
      when :send_message then send_message(context)
      else
        raise UI::Controller::UnknownActionError.new(
          "AgentChatController has no action :#{name}"
        )
      end
    end

    # Read the typed reply from the compose TextField (wired via name:
    # "chat_message"), append it (+ a canned agent reply) to the transcript, clear
    # the input, and Rerender so the screen rebuilds from the grown transcript.
    def send_message(context : UI::ScreenContext::Native) : UI::ActionResult
      text = (context.form_state.values["chat_message"]? || "").strip
      return UI::ActionResult::Rerender.new if text.empty?
      Voyager.state.send_chat_message(text)
      context.form_state.update("chat_message", "")
      # Voice: the agent reads its reply aloud via UI::Speech (AVSpeechSynthesizer),
      # cohesively on macOS / iOS / watchOS — the OUTPUT half of a wrist voice
      # conversation (dictation input is native to the compose TextField). The
      # last appended message is the agent's reply. No-op on web.
      if reply = Voyager.state.chat_messages.last?
        UI::Speech.speak(reply.text) if reply.is_agent
      end
      UI::ActionResult::Rerender.new
    end
  end
end
