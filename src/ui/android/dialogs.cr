require "json"
require "../views/alert"
require "../views/confirmation_dialog"

module UI::Android::Dialogs
  # Android's native AlertDialog supports positive/negative/neutral actions.
  # Larger action menus require a separate presentation, never silently dropped.
  def self.validate(title : String, message : String, actions : Array(UI::Alert::AlertButton)) : Nil
    unless title.valid_encoding? && !title.strip.empty? && title.bytesize <= 1024 &&
           message.valid_encoding? && message.bytesize <= 8192 && 1 <= actions.size <= 3 &&
           actions.all? { |action| action.label.valid_encoding? && !action.label.strip.empty? && action.label.bytesize <= 512 && {:default, :cancel, :destructive}.includes?(action.style) } &&
           actions.count(&.style.==(:cancel)) <= 1
      raise ArgumentError.new("Android alerts require a bounded title/message and one to three supported actions with at most one cancel action")
    end
  end

  def self.encode(title : String, message : String, actions : Array(UI::Alert::AlertButton), tokens : Array(UInt64), cancel : UInt64) : String
    validate(title, message, actions)
    raise ArgumentError.new("Android dialog callback mismatch") unless tokens.size == actions.size &&
                                                                       tokens.all? { |token| 0 < token <= Int64::MAX } && 0 < cancel <= Int64::MAX && (tokens + [cancel]).uniq.size == tokens.size + 1
    packet = JSON.build do |json|
      json.object do
        json.field "version", 1
        json.field "title", title
        json.field "message", message
        json.field "cancel", cancel
        json.field "actions" do
          json.array do
            actions.each_with_index do |action, index|
              json.object do
                json.field "label", action.label
                json.field "style", action.style.to_s
                json.field "token", tokens[index]
              end
            end
          end
        end
      end
    end
    raise ArgumentError.new("Android dialog descriptor exceeds its bound") if packet.bytesize > 16_384
    packet
  end
end
