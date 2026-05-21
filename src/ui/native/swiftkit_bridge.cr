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
    fun apsk_label_overrides_new : Void*
    fun apsk_image_overrides_new : Void*
    fun apsk_text_field_overrides_new : Void*
    fun apsk_secure_field_overrides_new : Void*
    fun apsk_search_field_overrides_new : Void*
    fun apsk_text_area_overrides_new : Void*
    fun apsk_text_editor_overrides_new : Void*
    fun apsk_link_button_overrides_new : Void*
    fun apsk_icon_button_overrides_new : Void*
    fun apsk_divider_overrides_new : Void*
    fun apsk_spacer_overrides_new : Void*
    fun apsk_toggle_overrides_new : Void*
    fun apsk_checkbox_overrides_new : Void*
    fun apsk_radio_group_overrides_new : Void*
    fun apsk_slider_overrides_new : Void*
    fun apsk_stepper_overrides_new : Void*
    fun apsk_segmented_control_overrides_new : Void*
    fun apsk_picker_overrides_new : Void*
    fun apsk_date_picker_overrides_new : Void*
    fun apsk_time_picker_overrides_new : Void*
    fun apsk_color_picker_overrides_new : Void*

    # ---- Group 3 overrides allocators (container widgets) -------------
    fun apsk_navigation_stack_overrides_new : Void*
    fun apsk_navigation_link_overrides_new : Void*
    fun apsk_navigation_split_view_overrides_new : Void*
    fun apsk_tab_view_overrides_new : Void*
    fun apsk_sheet_overrides_new : Void*
    fun apsk_popover_overrides_new : Void*
    fun apsk_alert_overrides_new : Void*
    fun apsk_confirmation_dialog_overrides_new : Void*
    fun apsk_toolbar_overrides_new : Void*
    fun apsk_form_overrides_new : Void*
    fun apsk_grid_overrides_new : Void*
    fun apsk_card_overrides_new : Void*
    fun apsk_surface_overrides_new : Void*
    fun apsk_menu_button_overrides_new : Void*
    fun apsk_toggle_button_overrides_new : Void*

    # ---- Glass (P1 — the Phase 3 "headline visual differentiator") -----
    fun apsk_glass_background_overrides_new : Void*

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

    # Group 3 array-field setters. Container widgets often need to set
    # ObjC array properties (e.g. `tabLabels`, `itemTokens`, `rowCellCounts`)
    # whose elements are NSStrings, NSNumbers (Int64), or NSNumber (Bool).
    # The C trampolines box each element into an NSArray and call the
    # named setter.
    #
    # `setter_name` is the ObjC setter selector NAME with trailing colon
    # ("setTabLabels:"). `values_ptr` is a contiguous block of UTF-8
    # `const char *` pointers for strings; an array of Int64 / Float64
    # for numeric variants; an array of Int32 (0 / non-zero) for bools.
    fun apsk_overrides_set_string_array(target : Void*, setter_name : UInt8*,
                                        values_ptr : Void*, count : Int32)
    fun apsk_overrides_set_int_array(target : Void*, setter_name : UInt8*,
                                     values_ptr : Int64*, count : Int32)
    fun apsk_overrides_set_uint64_array(target : Void*, setter_name : UInt8*,
                                        values_ptr : UInt64*, count : Int32)
    fun apsk_overrides_set_bool_array(target : Void*, setter_name : UInt8*,
                                      values_ptr : Int32*, count : Int32)
    # Setter for an `Int`-typed scalar property (used by selectedIndex on
    # TabView / MenuButton facades).
    fun apsk_overrides_set_int(target : Void*, setter_name : UInt8*, value : Int64)

    # -------------------------------------------------------------------------
    # Facade entry points. Each returns a +1 retained platform view
    # (`UIView*` on iOS, `NSView*` on macOS); Crystal wraps the returned
    # pointer in a `NativeHandle` immediately.
    #
    # `action_token` is the `UInt64` produced by
    # `UI::CallbackRegistry.register_action`. `0` means "no callback wired."
    # -------------------------------------------------------------------------
    fun apsk_make_button(label : UInt8*, overrides : Void*, action_token : UInt64) : Void*

    # ---- Group 1 facades (value display + simple input) ---------------
    fun apsk_make_label(text : UInt8*, overrides : Void*) : Void*
    fun apsk_make_image(source : UInt8*, overrides : Void*) : Void*
    fun apsk_make_text_field(placeholder : UInt8*, initial_text : UInt8*,
                             overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_secure_field(placeholder : UInt8*, initial_text : UInt8*,
                               overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_search_field(placeholder : UInt8*, initial_text : UInt8*,
                               overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_text_area(placeholder : UInt8*, initial_text : UInt8*,
                            overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_text_editor(placeholder : UInt8*, initial_text : UInt8*,
                              overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_link_button(label : UInt8*, url : UInt8*,
                              overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_icon_button(icon : UInt8*, overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_divider(overrides : Void*) : Void*
    fun apsk_make_spacer(overrides : Void*) : Void*

    # ---- Group 2 facades (selection + form controls) ------------------
    fun apsk_make_toggle(label : UInt8*, is_on : Int32, overrides : Void*,
                         action_token : UInt64) : Void*
    fun apsk_make_checkbox(label : UInt8*, is_on : Int32, overrides : Void*,
                           action_token : UInt64) : Void*
    fun apsk_make_radio_group(options : Void*, option_count : Int32,
                              selected_index : Int32,
                              overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_slider(value : Float64, minimum : Float64, maximum : Float64,
                         overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_stepper(label : UInt8*, value : Float64,
                          minimum : Float64, maximum : Float64,
                          overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_segmented_control(segments : Void*, segment_count : Int32,
                                    selected_index : Int32,
                                    overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_picker(label : UInt8*, options : Void*, option_count : Int32,
                         selected_index : Int32,
                         overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_date_picker(label : UInt8*, initial_epoch : Float64,
                              overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_time_picker(label : UInt8*, initial_epoch : Float64,
                              overrides : Void*, action_token : UInt64) : Void*
    fun apsk_make_color_picker(label : UInt8*, r : Float64, g : Float64,
                               b : Float64, a : Float64,
                               overrides : Void*, action_token : UInt64) : Void*

    # ---- Group 3 facades (container widgets) -------------------------
    # Each facade takes a `child_views` Void* (NULL when no children)
    # pointing to a contiguous block of `Void*` platform-view pointers
    # the Crystal renderer obtained from `render_detached`. The Swift
    # facade wraps each pointer with `APSKHostedChild` and embeds them
    # in the SwiftUI parent.
    fun apsk_make_navigation_stack(child_views : Void*, child_count : Int32,
                                   overrides : Void*) : Void*
    fun apsk_make_navigation_link(label : UInt8*, child_views : Void*,
                                  child_count : Int32, overrides : Void*) : Void*
    fun apsk_make_navigation_split_view(child_views : Void*, child_count : Int32,
                                        overrides : Void*) : Void*
    fun apsk_make_tab_view(child_views : Void*, child_count : Int32,
                           overrides : Void*) : Void*
    fun apsk_make_sheet(child_views : Void*, child_count : Int32,
                        overrides : Void*, dismiss_token : UInt64) : Void*
    fun apsk_make_popover(child_views : Void*, child_count : Int32,
                          overrides : Void*, dismiss_token : UInt64) : Void*
    fun apsk_make_alert(title : UInt8*, message : UInt8*, overrides : Void*) : Void*
    fun apsk_make_confirmation_dialog(title : UInt8*, message : UInt8*,
                                      overrides : Void*) : Void*
    fun apsk_make_toolbar(child_views : Void*, child_count : Int32,
                          overrides : Void*) : Void*
    fun apsk_make_form(child_views : Void*, child_count : Int32,
                       overrides : Void*) : Void*
    fun apsk_make_grid(child_views : Void*, child_count : Int32,
                       overrides : Void*) : Void*
    fun apsk_make_card(child_views : Void*, child_count : Int32,
                       overrides : Void*) : Void*
    fun apsk_make_surface(child_views : Void*, child_count : Int32,
                          overrides : Void*) : Void*
    fun apsk_make_menu_button(label : UInt8*, overrides : Void*) : Void*
    fun apsk_make_toggle_button(label : UInt8*, overrides : Void*,
                                action_token : UInt64) : Void*

    # ---- Glass facade (P1) --------------------------------------------
    # `child_view` is a single platform-view pointer (the content the
    # glass material backs) or NULL for an empty glass card. Unlike the
    # Group-3 container facades (which take a Void* + count), Glass takes
    # a single child because the SwiftUI `.glassEffect()` modifier
    # composes onto a single content view.
    fun apsk_make_glass_background(overrides : Void*, child_view : Void*) : Void*
  end
{% end %}
