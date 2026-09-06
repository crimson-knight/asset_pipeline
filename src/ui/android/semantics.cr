require "json"
require "../view"

module UI::Android::Semantics
  MAX_ACTIONS = 16

  # Identifiers stay separate from spoken labels. Callback tokens are owned by
  # the rendered NativeView, never by this temporary serialization buffer.
  def self.encode(view : UI::View, tokens : Array(UInt64)) : String
    raise ArgumentError.new("Android supports at most 16 custom accessibility actions per view") if tokens.size > MAX_ACTIONS
    raise ArgumentError.new("Android accessibility callback count mismatch") unless tokens.size == view.accessibility_actions.size
    JSON.build do |json|
      json.object do
        json.field "version", 1
        json.field "label", view.accessibility_label
        json.field "hint", view.accessibility_hint
        json.field "value", view.accessibility_value
        json.field "role", view.effective_accessibility_role.try(&.to_s)
        json.field "explicit_role", !view.accessibility_role.nil?
        json.field "identifier", view.accessibility_identifier
        json.field "test_id", view.test_id
        json.field "focusable", view.focusable
        json.field "default_focusable", view.effective_focusable
        json.field "focused", view.focused
        json.field "tab_index", view.tab_index
        json.field "traits", view.accessibility_traits.map(&.to_s)
        json.field "actions" do
          json.array do
            view.accessibility_actions.each_with_index do |action, index|
              json.object do
                json.field "name", action.name
                json.field "token", tokens[index]
              end
            end
          end
        end
        json.field "shortcut" do
          if shortcut = view.keyboard_shortcut
            json.object do
              json.field "key", shortcut.key
              json.field "modifiers", shortcut.modifiers.map(&.to_s)
            end
          else
            json.null
          end
        end
      end
    end
  end
end
