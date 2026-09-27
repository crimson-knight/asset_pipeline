{% if flag?(:macos) %}
  require "spec"
  require "../../src/ui"
  require "../../src/ui/ax_test"

  # Proves `UI::View#accessibility_hidden` through this process's own
  # accessibility tree, the tree VoiceOver reads. The scenario is the one
  # that exposed the gap: a checkbox built from a native Toggle whose visible
  # caption is a separate Label. Without hiding, VoiceOver reaches the
  # caption twice (once as the checkbox name, once as static text).
  #
  # The window comes from the offscreen, non-activating Label window helper
  # in `support/appkit_focus_test_bridge.m`; it never activates the app or
  # becomes key.
  lib AppKitAccessibilityHiddenBridge
    fun ap_spec_create_label_window(content_view_ptr : Void*) : Void*
    fun ap_spec_pump_label_run_loop : Void
    fun ap_spec_application_is_active : Int32
    fun ap_spec_window_is_key(window_ptr : Void*) : Int32
    fun ap_spec_close_label_window(window_ptr : Void*) : Void
  end

  private CHECKBOX_CAPTION         = "Sync drafts to iCloud"
  private VISIBLE_CONTROL_CAPTION  = "Accessibility hidden probe control caption"
  private HIDDEN_STACK_CAPTION     = "Caption inside a hidden stack"
  private PROBE_WINDOW_TITLE       = "Selectable Label Probe"
  private HIDDEN_READINESS_TIMEOUT = 5.seconds
  private MAX_AX_DEPTH             = 24

  private def collect_ax_elements(element : UI::AXTest::Element, into list_of_elements : Array(UI::AXTest::Element), depth : Int32 = 0) : Nil
    return if depth > MAX_AX_DEPTH

    element.children.each do |child|
      list_of_elements << child
      collect_ax_elements(child, list_of_elements, depth + 1)
    end
  end

  private def probe_window_elements : Array(UI::AXTest::Element)
    app = UI::AXTest::App.connect(Process.pid.to_i32)
    list_of_elements = [] of UI::AXTest::Element
    app.root.windows.each do |window|
      next unless window.title == PROBE_WINDOW_TITLE
      collect_ax_elements(window, list_of_elements)
    end
    list_of_elements
  end

  private def static_texts_reading(list_of_elements : Array(UI::AXTest::Element), text : String) : Array(UI::AXTest::Element)
    list_of_elements.select { |element| element.role == "AXStaticText" && element.value == text }
  end

  # Pumps the main run loop until the visible control caption is in the
  # accessibility tree. It is rendered in the same window and pass as the
  # views under test, so once it is readable they have been through the
  # same SwiftUI updates.
  private def wait_for_probe_elements : Array(UI::AXTest::Element)
    deadline = Time.instant + HIDDEN_READINESS_TIMEOUT
    loop do
      AppKitAccessibilityHiddenBridge.ap_spec_pump_label_run_loop
      list_of_elements = probe_window_elements
      return list_of_elements unless static_texts_reading(list_of_elements, VISIBLE_CONTROL_CAPTION).empty?

      if Time.instant >= deadline
        raise "The visible control caption was not in the accessibility tree within #{HIDDEN_READINESS_TIMEOUT}"
      end
    end
  end

  private def with_probe_window(root : UI::View, &block : Array(UI::AXTest::Element) ->) : Nil
    native = UI::AppKit::Renderer.new.render(root)
    window_ptr = Pointer(Void).null
    begin
      window_ptr = AppKitAccessibilityHiddenBridge.ap_spec_create_label_window(native.handle.ptr!)
      raise "AppKit test window could not be created" if window_ptr.null?

      yield wait_for_probe_elements

      AppKitAccessibilityHiddenBridge.ap_spec_application_is_active.should eq(0)
      AppKitAccessibilityHiddenBridge.ap_spec_window_is_key(window_ptr).should eq(0)
    ensure
      AppKitAccessibilityHiddenBridge.ap_spec_close_label_window(window_ptr) unless window_ptr.null?
      native.teardown!
    end
  end

  # A native checkbox Toggle with no built-in title, named for assistive
  # tech by `accessibility_label`, followed by its visible caption Label.
  private def checkbox_row(caption : UI::Label) : UI::HStack
    toggle = UI::Toggle.new
    toggle.style = UI::ToggleStyle::Checkbox
    toggle.accessibility_label = CHECKBOX_CAPTION

    row = UI::HStack.new
    row << toggle
    row << caption
    row
  end

  private def probe_root(*list_of_views : UI::View) : UI::VStack
    stack = UI::VStack.new
    list_of_views.each { |view| stack << view }
    stack << UI::Label.new(VISIBLE_CONTROL_CAPTION)
    stack
  end

  describe "UI::View#accessibility_hidden on macOS" do
    it "exposes a visible checkbox caption Label as static text by default" do
      caption = UI::Label.new(CHECKBOX_CAPTION)

      with_probe_window(probe_root(checkbox_row(caption))) do |list_of_elements|
        static_texts_reading(list_of_elements, CHECKBOX_CAPTION).size.should eq(1)
        list_of_elements.count { |element| element.role == "AXCheckBox" }.should eq(1)
      end
    end

    it "removes a hidden caption Label while the sibling Toggle keeps its checkbox" do
      caption = UI::Label.new(CHECKBOX_CAPTION)
      caption.accessibility_hidden = true

      with_probe_window(probe_root(checkbox_row(caption))) do |list_of_elements|
        static_texts_reading(list_of_elements, CHECKBOX_CAPTION).should be_empty

        list_of_checkboxes = list_of_elements.select { |element| element.role == "AXCheckBox" }
        list_of_checkboxes.size.should eq(1)
        list_of_checkboxes.first.label.should eq(CHECKBOX_CAPTION)
      end
    end

    it "removes every descendant of a hidden AppKit stack" do
      hidden_stack = UI::VStack.new
      hidden_stack << UI::Label.new(HIDDEN_STACK_CAPTION)
      hidden_stack.accessibility_hidden = true

      with_probe_window(probe_root(hidden_stack)) do |list_of_elements|
        static_texts_reading(list_of_elements, HIDDEN_STACK_CAPTION).should be_empty
        static_texts_reading(list_of_elements, VISIBLE_CONTROL_CAPTION).size.should eq(1)
      end
    end
  end
{% end %}
