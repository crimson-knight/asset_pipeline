# swiftkit_bridge.cr — Crystal-side typed wrapper around
# AssetPipelineSwiftKit's `@objc` facade classes.
#
# Every Tier 1 / Tier 2 widget that has a SwiftUI counterpart gets a
# matching `fun` here so call sites in `uikit_renderer.cr` /
# `appkit_renderer.cr` stay readable and typecheckable. The actual
# `objc_msgSend` happens inside C trampolines in
# `src/ui/native/swiftkit_bridge.m`.
#
# Module is gated on `flag?(:macos) || flag?(:ios)` — Web and Android
# builds never touch SwiftKit. The spec environment provides a fake
# wrapper at `spec/support/fake_lib_objc_bridge.cr`.
#
# Phase 3 ships the Button facade end-to-end. The widget coverage list
# in implementation.md §6 (35 widgets) is being migrated incrementally:
# the `fun` declarations for unmigrated widgets are scheduled for the
# follow-up commits documented in the handoff message. Phase 5's glass
# material work extends THIS module — it does not introduce a new lib.

{% if flag?(:macos) || flag?(:ios) %}
  @[Link(framework: "Foundation")]
  lib LibSwiftKitBridge
    # -------------------------------------------------------------------------
    # Runtime initialization. Called once during app startup, after
    # Crystal's `GC.init`, to hand the address of Crystal's
    # `ap_swiftkit_invoke_action` trampoline to the Swift side.
    # -------------------------------------------------------------------------
    fun apsk_runtime_initialize(action_trampoline : Void*)

    # -------------------------------------------------------------------------
    # Overrides constructors. Each returns a +0 retained `APSK*Overrides`
    # instance. The Crystal renderer then sets fields through ObjC setters
    # (see `SwiftKit` helper module in the renderer files) before passing
    # the object pointer into the matching `make_*` call.
    # -------------------------------------------------------------------------
    fun apsk_view_overrides_new : Void*
    fun apsk_button_overrides_new : Void*

    # -------------------------------------------------------------------------
    # Facade entry points. Each returns a +1 retained platform view
    # (`UIView*` on iOS, `NSView*` on macOS); Crystal wraps the returned
    # pointer in a `NativeHandle` immediately.
    #
    # `action_token` is the `UInt64` produced by
    # `UI::CallbackRegistry.register_action`. `0` means "no callback wired."
    # -------------------------------------------------------------------------
    fun apsk_make_button(label : UInt8*, overrides : Void*, action_token : UInt64) : Void*
  end
{% end %}
