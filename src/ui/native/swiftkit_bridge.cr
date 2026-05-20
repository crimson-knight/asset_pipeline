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

    # Convenience init for the default case where the renderer just wants
    # the Crystal `ap_swiftkit_invoke_action` symbol installed. The C
    # side resolves the address (avoiding Crystal-level
    # `@convention(c)`-pointer gymnastics that don't survive every
    # optimisation level).
    fun apsk_runtime_install_default_action_trampoline

    # -------------------------------------------------------------------------
    # Brand-tint cascade. Drives "SwiftUI Default Supremacy" (Option B):
    # the active brand identity propagates into every SwiftUI facade via
    # the `.tint()` accent-colour cascade instead of per-widget colour
    # injection. The renderer calls `apsk_runtime_set_brand_tint(...)` on
    # every `render(...)` entry with the active
    # `design_tokens.colors_light.brand_primary` RGBA so a brand swap
    # (`Tokens.default.with_brand(SentinelBrand.new)`) takes effect on
    # the next render. Calling `apsk_runtime_clear_brand_tint` returns
    # the package to SwiftUI's automatic accent-colour default.
    # -------------------------------------------------------------------------
    fun apsk_runtime_set_brand_tint(r : Float64, g : Float64, b : Float64, a : Float64)
    fun apsk_runtime_clear_brand_tint

    # -------------------------------------------------------------------------
    # Overrides constructors. Each returns a +0 retained `APSK*Overrides`
    # instance. The Crystal renderer then sets fields through the
    # `apsk_overrides_set_*` trampolines below before passing the object
    # pointer into the matching `make_*` call.
    # -------------------------------------------------------------------------
    fun apsk_view_overrides_new : Void*
    fun apsk_button_overrides_new : Void*

    # -------------------------------------------------------------------------
    # Overrides field setters. Each takes the `APSK*Overrides` pointer,
    # the ObjC setter selector NAME (e.g. "setBackgroundColor:") as a
    # nul-terminated C string, and a typed value. The C trampoline boxes
    # the value (UIColor/NSColor for `_set_color`, NSNumber for the
    # numeric variants, NSString for `_set_string`) and dispatches
    # `objc_msgSend(target, sel_registerName(setter_name), boxed)`.
    #
    # `nil` / NULL inputs are silently no-ops so the Populator can pass
    # `nil` for "leave at SwiftUI default" cases without conditional
    # branching at every call site.
    # -------------------------------------------------------------------------
    fun apsk_overrides_set_color(target : Void*, setter_name : UInt8*,
                                 r : Float64, g : Float64, b : Float64, a : Float64)
    fun apsk_overrides_set_number(target : Void*, setter_name : UInt8*, value : Float64)
    fun apsk_overrides_set_bool(target : Void*, setter_name : UInt8*, value : Int32)
    fun apsk_overrides_set_string(target : Void*, setter_name : UInt8*, value : UInt8*)

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
