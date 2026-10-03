{% if flag?(:macos) %}
  require "spec"
  require "../../src/ui"

  # Writes the integer-valued SwiftKit override properties through the real
  # production sender and reads them back from the Swift objects. Every
  # override property is `NSNumber?`; a raw integer sent to one of those
  # setters is retained as an object pointer, so before the boxed setter
  # existed each example here crashed the process with SIGSEGV at the
  # integer's value (an accessibility action count of 1 faulted at 0x1).
  lib SwiftKitBoxedSetterProbe
    fun sel_registerName(name : UInt8*) : Void*
    # Same signature as the binding in surface_craft_primitives_spec.cr: a
    # program may declare `objc_msgSend` only once.
    fun objc_msgSend(receiver : Void*, selector : Void*) : UInt8*
  end

  private def boxed_integer(overrides : Void*, getter_name : String) : Int64?
    number = SwiftKitBoxedSetterProbe.objc_msgSend(overrides, SwiftKitBoxedSetterProbe.sel_registerName(getter_name))
    return nil if number.null?

    # One binding serves both reads: on arm64 a `long long`
    # comes back in the same register as an object pointer.
    SwiftKitBoxedSetterProbe.objc_msgSend(number, SwiftKitBoxedSetterProbe.sel_registerName("longLongValue")).address.to_i64!
  end

  describe "SwiftKit integer override setters on macOS" do
    it "boxes the accessibility action count a view with an action carries" do
      overrides = LibSwiftKitBridge.apsk_button_overrides_new
      view = UI::Checkbox.new("Remove correction")
      view.accessibility_actions = [UI::AccessibilityAction.new("Delete") { }]

      UI::Native::Populator.populate_view_common("probe", view, UI::Native::SwiftKitObjCSender.new(overrides))

      boxed_integer(overrides, "apskAccessibilityActionCount").should eq(1)
    end

    it "boxes a menu button's selected index" do
      overrides = LibSwiftKitBridge.apsk_menu_button_overrides_new
      view = UI::MenuButton.new("Mode")
      view.selected_index = 2

      UI::Native::Populator.populate_menu_button("probe", view, UI::Native::SwiftKitObjCSender.new(overrides))

      boxed_integer(overrides, "selectedIndex").should eq(2)
    end

    it "boxes a tab view's selected index" do
      overrides = LibSwiftKitBridge.apsk_tab_view_overrides_new
      tabs = [UI::TabView::Tab.new(label: "One"), UI::TabView::Tab.new(label: "Two")]
      view = UI::TabView.new(tabs, selected_index: 1)

      UI::Native::Populator.populate_tab_view("probe", view, UI::Native::SwiftKitObjCSender.new(overrides))

      boxed_integer(overrides, "selectedIndex").should eq(1)
    end

    it "boxes the confirmation dialog callback tokens" do
      overrides = LibSwiftKitBridge.apsk_confirmation_dialog_overrides_new
      LibSwiftKitBridge.apsk_overrides_set_uint64_boxed(overrides, "setConfirmToken:".to_unsafe, 7_u64)

      boxed_integer(overrides, "confirmToken").should eq(7)
    end

    it "renders a checkbox that carries an accessibility action" do
      view = UI::Checkbox.new("Remove correction")
      view.accessibility_actions = [UI::AccessibilityAction.new("Delete") { }]

      native = UI::AppKit::Renderer.new.render(view)

      native.handle.ptr!.null?.should be_false
    end
  end
{% end %}
