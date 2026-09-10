module AndroidSemanticsFixture
  @@actions = 0
  @@clicks = 0
  @@plain = 0
  @@text = "Native 雪 😀 text"

  def self.mark(view : UI::View, id : String)
    view.test_id = id
    view.state_key = id
    view
  end

  def self.build(request_focus = false) : UI::View
    root = UI::VStack.new(4.0, UI::Alignment::Leading)
    root.state_key = "semantics-screen"
    root << mark(UI::Label.new("Native semantics").tap { |v| v.accessibility_role = :header }, "semantics-heading")
    root << mark(UI::Label.new("Actions: #{@@actions}; clicks: #{@@clicks}; plain: #{@@plain}"), "semantics-status")
    button = UI::Button.new("Activate") { @@clicks += 1; nil }
    mark(button, "automation-雪-button")
    button.accessibility_identifier = "accessible-button-id"
    button.accessibility_label = "Save item"
    button.accessibility_hint = "Saves the selected item"
    button.accessibility_value = "Ready"
    button.accessibility_traits = [:selected]
    button.accessibility_actions << UI::AccessibilityAction.new("Archive 雪") { @@actions += 1; nil }
    button.keyboard_shortcut = UI::KeyboardShortcut.new("k", [:control])
    button.tab_index = 7
    button.maximum_width = 230.0
    root << button
    field = UI::TextField.new("Visual placeholder", text: @@text) { |text| @@text = text; nil }
    mark(field, "semantics-editor")
    field.accessibility_label = "Account name"
    field.accessibility_hint = "Use your preferred name"
    field.focused = request_focus
    field.maximum_width = 260.0
    root << field
    root << mark(UI::Button.new("Skip keyboard") { nil }.tap { |v| v.focusable = false; v.focused = true }, "semantics-skip")
    root << mark(UI::Button.new("Plain shortcut") { @@plain += 1; nil }.tap { |v| v.keyboard_shortcut = UI::KeyboardShortcut.new("p") }, "semantics-plain")
    disabled = UI::Button.new("Disabled action") { @@clicks += 1; nil }
    disabled.accessibility_traits = [:not_enabled]
    disabled.focused = true
    disabled.accessibility_actions << UI::AccessibilityAction.new("Disabled archive") { @@actions += 1; nil }
    root << mark(disabled, "semantics-disabled")
    root << mark(UI::Button.new("Hidden focus").tap { |v| v.hidden = true; v.focused = true }, "semantics-hidden")
    root << mark(UI::Checkbox.new("Remember choice", true), "semantics-checkbox")
    root << mark(UI::Toggle.new("Enabled feature", true), "semantics-toggle")
    root << mark(UI::Slider.new(0.0, 100.0, 25.0), "semantics-slider")
    root << mark(UI::Picker.new(["One", "Two"], 1), "semantics-picker")
    root << mark(UI::RadioGroup.new(["First", "Second"], 1), "semantics-radio")
    root
  end

  def self.invalid : UI::View
    # Fails inside checked JNI after registering a callback, before adopting
    # that view. Also unwinds already-adopted callback-owning siblings.
    root = UI::VStack.new
    root << UI::Button.new("Allocated first") { nil }.tap { |v| v.accessibility_actions << UI::AccessibilityAction.new("Valid") { nil } }
    root << UI::Label.new("Invalid action").tap { |v| v.accessibility_actions << UI::AccessibilityAction.new("") { nil } }
    root
  end
end

{% if flag?(:android) %}
  fun crystal_android_semantics_render_probe(env : Void*, context : Void*) : Int32
    UI::Android::Renderer.new(env, context).render(AndroidSemanticsFixture.invalid)
    0
  rescue error : UI::Android::PendingJavaException
    1
  rescue
    -1
  end
{% end %}
