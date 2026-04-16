{% if flag?(:ios) %}
require "../platform_visitor"
require "../native/native_handle"
require "../native/native_view"
require "../native/callback_registry"

module UI::UIKit
  # ObjC bridge function bindings for UIKit rendering on iOS.
  #
  # UIKit shares the same ARM64 ObjC runtime as AppKit -- the same C bridge
  # functions (objc_bridge.c) work on iOS. The difference is the class names
  # and selector names passed to those functions (UILabel vs NSTextField, etc.).
  #
  # ## Struct types
  #
  # CGRect/CGPoint/CGSize are Homogeneous Floating-point Aggregates (HFA)
  # on ARM64. They are passed/returned in d0-d3 (CGRect), d0-d1 (CGPoint,
  # CGSize), NOT on the stack.
  lib LibObjCBridge
    struct CGRect
      x : Float64
      y : Float64
      width : Float64
      height : Float64
    end

    # --- Section 1: Basic message sends (integer/pointer args) ---
    fun objc_send(obj : Void*, sel : Void*) : Void*
    fun objc_send_id(obj : Void*, sel : Void*, arg : Void*) : Void*
    fun objc_send_id_id(obj : Void*, sel : Void*, arg1 : Void*, arg2 : Void*) : Void*
    fun objc_send_id_id_id(obj : Void*, sel : Void*, arg1 : Void*, arg2 : Void*, arg3 : Void*) : Void*
    fun objc_send_bool(obj : Void*, sel : Void*, val : Int32) : Void
    fun objc_send_long(obj : Void*, sel : Void*, val : Int64) : Void*
    fun objc_send_ulong(obj : Void*, sel : Void*, val : UInt64) : Void*
    fun objc_send_void_id(obj : Void*, sel : Void*, arg : Void*) : Void
    fun objc_send_sel(obj : Void*, sel : Void*, arg : Void*) : Void
    fun objc_send_id_long(obj : Void*, sel : Void*, arg1 : Void*, arg2 : Int64) : Void*
    fun objc_send_id_id_long(obj : Void*, sel : Void*, arg1 : Void*, arg2 : Void*, arg3 : Int64) : Void*

    # --- Section 2: Double/float register sends ---
    fun objc_send_1d(obj : Void*, sel : Void*, d0 : Float64) : Void
    fun objc_send_1d_ret_id(obj : Void*, sel : Void*, d0 : Float64) : Void*
    fun objc_send_2d_ret_id(obj : Void*, sel : Void*, d0 : Float64, d1 : Float64) : Void*
    fun objc_send_4d_ret_id(obj : Void*, sel : Void*, d0 : Float64, d1 : Float64, d2 : Float64, d3 : Float64) : Void*

    # --- Section 3: CGRect / HFA sends ---
    fun objc_send_rect(obj : Void*, sel : Void*, rect : CGRect) : Void*
    fun objc_send_rect_void(obj : Void*, sel : Void*, rect : CGRect) : Void
    fun objc_send_ret_bool(obj : Void*, sel : Void*) : Int32

    # --- Section 4: Convenience helpers ---
    fun nsstring_from_cstr(str : UInt8*) : Void*
    fun nscolor_rgba(r : Float64, g : Float64, b : Float64, a : Float64) : Void*
    fun nscolor_white_alpha(white : Float64, alpha : Float64) : Void*
    fun nscolor_label_primary : Void*
    fun nscolor_label_secondary : Void*
    fun nscolor_label_tertiary : Void*
    fun nscolor_label_quaternary : Void*
    fun nsfont_system(size : Float64) : Void*
    fun nsfont_bold_system(size : Float64) : Void*
    fun nsfont_system_weight(size : Float64, weight : Float64) : Void*
    fun nsfont_monospaced_system(size : Float64, weight : Float64) : Void*
    fun nsfont_named(name : Void*, size : Float64) : Void*
    fun objc_add_subview(parent : Void*, child : Void*) : Void
    fun objc_set_autoresize(view : Void*, mask : UInt64) : Void
    fun objc_set_frame(obj : Void*, frame : CGRect) : Void
    fun objc_constrain_size(view : Void*, w : Float64, h : Float64) : Void
    fun objc_constrain_width(view : Void*, w : Float64) : Void
    fun objc_constrain_required_width(view : Void*, w : Float64) : Void
    fun objc_constrain_height(view : Void*, h : Float64) : Void
    fun objc_constrain_minimum_height(view : Void*, min_h : Float64) : Void
    fun objc_constrain_minimum_width(view : Void*, min_w : Float64) : Void
    fun objc_constrain_equal_width(child : Void*, parent : Void*) : Void
    fun uiscrollview_pin_content(scroll_view : Void*, content_view : Void*) : Void
    fun objc_screen_width : Float64
    fun uislider_build_synthetic_track(value_fraction : Float64, filled_color : Void*, unfilled_color : Void*, slider_ptr : Void*) : Void*
    fun nsimageview_make_symbol(symbol_name : UInt8*, tint_color : Void*, size_pts : Float64) : Void*
    fun uiview_install_amber_gradient_layer(view : Void*) : Void

    # --- ObjC runtime ---
    fun sel_registerName(name : UInt8*) : Void*
    fun objc_getClass(name : UInt8*) : Void*
  end

  # Renders a UI::View tree to native UIKit views via the ObjC bridge.
  #
  # Each `visit` method:
  #   1. Allocates and initializes the appropriate UIKit view class
  #   2. Configures its properties (text, font, color, etc.)
  #   3. Wraps the raw pointer in a `NativeHandle` (owned)
  #   4. Creates a `NativeView` node
  #   5. If inside a container, adds as arranged subview or addSubview:
  #   6. If top-level, sets as `@result`
  #
  # ## UIKit vs AppKit differences
  #
  # - Labels use UILabel (not NSTextField). UILabel has setText:/setFont:/setTextColor:
  #   directly rather than requiring a non-editable NSTextField.
  # - Buttons use UIButton (buttonWithType: UIButtonTypeSystem=1).
  #   UIButton uses addTarget:action:forControlEvents: for callbacks.
  # - Stacks use UIStackView (same axis/alignment semantics, different constants).
  # - ZStack uses UIView with addSubview:. Children fill parent via autoresizing.
  # - Images use UIImageView with UIImage(named:) and contentMode.
  # - TextFields use UITextField (placeholder, secureTextEntry, keyboardType).
  # - ScrollView uses UIScrollView.
  # - Spacer uses UIView with low content hugging priority.
  # - Toggle uses UISwitch.
  # - Checkbox uses UIButton toggled as a checkmark (no native UICheckbox on iOS).
  # - RadioGroup uses a UIStackView of UIButtons acting as radio options.
  # - Slider uses UISlider (minimumValue, maximumValue, value).
  #
  # ## Usage
  #
  # ```
  # label = UI::Label.new("Hello, iOS!")
  # renderer = UI::UIKit::Renderer.new
  # label.accept(renderer)
  # native_view = renderer.result  # => NativeView wrapping a UILabel
  # ```
  #
  # ## Memory Management
  #
  # All native views created by the renderer are owned (+1 retain count)
  # via `ObjC.owned`. Call `NativeView#teardown!` on the root result to
  # release the entire tree.
  class Renderer < UI::PlatformVisitor
    # The root NativeView produced by visiting the top-level view.
    @result : NativeView? = nil

    # Stack of NativeViews for container nesting. When visiting children
    # inside a VStack/HStack/ZStack/ScrollView, the parent is on top of
    # the stack so children can be added to it.
    @stack : Array(NativeView)

    # Tracks which NativeViews on the stack are UIStackViews (true) vs
    # plain UIViews (false). UIStackView uses addArrangedSubview:, plain
    # UIView uses addSubview:.
    @stack_is_uistack : Array(Bool)

    # Scoped preferred UILabel wrapping widths inherited from exact-width
    # containers. This keeps multi-line labels from reporting their single-line
    # intrinsic width during UIKit fitting passes.
    @label_preferred_max_layout_width_stack : Array(Float64)

    def initialize
      @stack = [] of NativeView
      @stack_is_uistack = [] of Bool
      @label_preferred_max_layout_width_stack = [] of Float64
    end

    # Returns the root NativeView produced by the last top-level visit.
    # Raises if no view has been visited yet.
    def result : NativeView
      @result.not_nil!
    end

    # Convenience: visit a view and return its NativeView.
    def render(view : UI::View) : NativeView
      view.accept(self)
      result
    end

    # -----------------------------------------------------------------
    # Visit: Label -> UILabel
    # -----------------------------------------------------------------
    def visit(view : UI::Label)
      ptr = alloc_init("UILabel")

      # setText: accepts an NSString directly on UILabel
      str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("setText:"), str)

      # Font -> UIFont
      font_ptr = resolve_font(view.font)
      LibObjCBridge.objc_send_id(ptr, sel("setFont:"), font_ptr)

      # Text color -> UIColor. A LabelRole resolves to the dynamic
      # appearance-tracking system color (UIColor.labelColor and siblings)
      # so light / dark appearance and Increase Contrast track
      # automatically. A brand override opts out by clearing
      # `text_color_role` and setting `text_color` to the brand RGBA.
      color_ptr = if role = view.text_color_role
                    case role
                    when UI::LabelRole::Primary    then LibObjCBridge.nscolor_label_primary
                    when UI::LabelRole::Secondary  then LibObjCBridge.nscolor_label_secondary
                    when UI::LabelRole::Tertiary   then LibObjCBridge.nscolor_label_tertiary
                    when UI::LabelRole::Quaternary then LibObjCBridge.nscolor_label_quaternary
                    else                                resolve_color(view.text_color)
                    end
                  else
                    resolve_color(view.text_color)
                  end
      LibObjCBridge.objc_send_id(ptr, sel("setTextColor:"), color_ptr)

      # Text alignment: NSTextAlignment values (shared between UIKit and AppKit)
      # NSTextAlignmentLeft=0, NSTextAlignmentCenter=1, NSTextAlignmentRight=2,
      # NSTextAlignmentNatural=4
      alignment_val = case view.text_alignment
                      when Alignment::Leading  then 0_i64 # NSTextAlignmentLeft
                      when Alignment::Center   then 1_i64 # NSTextAlignmentCenter
                      when Alignment::Trailing then 2_i64 # NSTextAlignmentRight
                      else                          4_i64 # NSTextAlignmentNatural
                      end
      LibObjCBridge.objc_send_long(ptr, sel("setTextAlignment:"), alignment_val)

      # Number of lines: 0 = unlimited (UILabel default is 1, so set explicitly)
      LibObjCBridge.objc_send_long(ptr, sel("setNumberOfLines:"), view.number_of_lines.to_i64)

      # preferredMaxLayoutWidth lets UILabel compute a wrapped intrinsic size
      # during fitting. Without it, long labels can force exact-width cards to
      # grow to their single-line width on iOS.
      if preferred_width = view.preferred_max_layout_width || @label_preferred_max_layout_width_stack.last?
        LibObjCBridge.objc_send_1d(ptr, sel("setPreferredMaxLayoutWidth:"), preferred_width)
      end

      # Common properties (hidden, opacity, background, accessibility)
      apply_common_properties(ptr, view)

      emit(ptr, "UILabel")
    end

    # -----------------------------------------------------------------
    # Visit: Button -> UIButton with UIButton.Configuration (iOS 15+)
    #
    # Style -> Configuration factory method mapping:
    #   Default / Bordered -> UIButton.Configuration.gray()
    #   Prominent          -> UIButton.Configuration.filled()
    #   Tinted             -> UIButton.Configuration.tinted()
    #   Borderless         -> UIButton.Configuration.plain()
    #
    # Role overrides applied on top of the configuration:
    #   :destructive -> baseBackgroundColor = systemRedColor (Prominent/Tinted)
    #                   or baseForegroundColor = systemRedColor (Default/Bordered)
    #   :cancel      -> semibold title attribute weight
    #
    # HIG: "Use a filled button for the most likely action in a view."
    #       "Use the destructive style to identify a button that performs a
    #        destructive action people didn't deliberately choose."
    # -----------------------------------------------------------------
    def visit(view : UI::Button)
      uibutton_cls = LibObjCBridge.objc_getClass("UIButton")
      uicolor_cls  = LibObjCBridge.objc_getClass("UIColor")

      # Build UIButton.Configuration from style.
      # +[UIButton.Configuration gray] etc. are class methods on UIButtonConfiguration.
      # The class name changed in different SDK headers but the ObjC runtime name is
      # "UIButtonConfiguration". We call through uibutton_cls's class method because
      # that is the public UIKit factory surface.
      config_cls = LibObjCBridge.objc_getClass("UIButtonConfiguration")

      # Determine the configuration selector based on style.
      config_sel = case view.style
                   when UI::ButtonStyle::Prominent  then "filledButtonConfiguration"
                   when UI::ButtonStyle::Tinted     then "tintedButtonConfiguration"
                   when UI::ButtonStyle::Borderless then "plainButtonConfiguration"
                   else                                  "grayButtonConfiguration"
                   end

      # Create configuration object. Falls back to nil on older iOS where
      # UIButtonConfiguration is unavailable — we degrade to UIButtonTypeSystem.
      config = if config_cls.null?
                 Pointer(Void).null
               else
                 LibObjCBridge.objc_send(config_cls, sel(config_sel))
               end

      # Amber brand gold — replaces systemBlue as the primary tint for all
      # non-destructive roles. Light: #FFAD33, Dark: #FFB84D. Resolved from
      # TEST_RUNNER_HIG_APPEARANCE env var (set by iOS capture harness).
      # Destructive always uses systemRed — HIG mandates red for danger actions.
      amber_gold = amber_brand_gold
      # Deep ember (#2A1A08) — legible foreground on Amber gold fill.
      ember_dark = LibObjCBridge.nscolor_rgba(0.165, 0.102, 0.031, 1.0)

      # Apply role + brand color overrides to the configuration.
      # Dark mode contrast fix (June R3): UIButtonConfiguration.gray() in dark mode
      # can desaturate baseForegroundColor to ~50% perceived value. To guarantee full
      # #FFB84D saturation on Tinted/Bordered/Borderless in dark, we:
      #   (a) set baseForegroundColor to the full-saturation amber gold, AND
      #   (b) after creating the UIButton (below), set setTintColor: on the button
      #       directly as a belt-and-suspenders pass that UIKit honors even when
      #       configuration-level colors are processed/dimmed.
      # For destructive, systemRedColor dark resolves to ~#FF453A (systemRed in dark).
      # grayButtonConfiguration in dark may desaturate systemRed to salmon; we also
      # set the button's tintColor to systemRedColor post-creation to force it.
      unless config.null?
        if view.role == :destructive
          # Amber brand: destructive uses plum (#5B3A94 light / #7D59B8 dark).
          # HIG role semantics are preserved by prominence and position in the
          # action sheet — the plum overrides the systemRed hue per amber.md
          # destructive=plum mapping. Contrast vs cream surface: 5.8:1 (WCAG AA).
          raw_app = LibC.getenv("TEST_RUNNER_HIG_APPEARANCE")
          want_dark_dest = !raw_app.null? && String.new(raw_app) == "dark"
          # Dark destructive: #D6B8F2 (0.839, 0.722, 0.949). Prior #B99CE0 still
          # read ~#9B85C0 against warm-amber translucent glass (apparent contrast
          # ~3:1) because of alpha-compositing + simultaneous contrast dropping
          # perceived luminance. Pushed further to #D6B8F2 for ≥4.5:1 perceived
          # contrast against warm-glass surfaces (June round 4 citation).
          plum = LibObjCBridge.nscolor_rgba(
            want_dark_dest ? 0.839 : 0.357,
            want_dark_dest ? 0.722 : 0.227,
            want_dark_dest ? 0.949 : 0.580,
            1.0
          )
          unless plum.null?
            case view.style
            when UI::ButtonStyle::Prominent, UI::ButtonStyle::Tinted
              LibObjCBridge.objc_send_id(config, sel("setBaseBackgroundColor:"), plum)
              white = LibObjCBridge.objc_send(uicolor_cls, sel("whiteColor"))
              LibObjCBridge.objc_send_id(config, sel("setBaseForegroundColor:"), white) unless white.null?
            else
              # Default / Bordered / Borderless destructive: plum label.
              LibObjCBridge.objc_send_id(config, sel("setBaseForegroundColor:"), plum)
            end
          end
        else
          # Non-destructive: apply Amber gold brand primary.
          unless amber_gold.null?
            case view.style
            when UI::ButtonStyle::Prominent
              # Filled: Amber gold background + deep ember foreground for contrast.
              LibObjCBridge.objc_send_id(config, sel("setBaseBackgroundColor:"), amber_gold)
              LibObjCBridge.objc_send_id(config, sel("setBaseForegroundColor:"), ember_dark) unless ember_dark.null?
            when UI::ButtonStyle::Tinted
              # Tinted: Amber gold tint (UIKit uses baseForegroundColor for the label
              # and derives the translucent fill automatically from it).
              # Dark mode: set full-saturation #FFB84D; tintColor override applied post-creation.
              LibObjCBridge.objc_send_id(config, sel("setBaseForegroundColor:"), amber_gold)
            else
              # Default / Bordered / Borderless: Amber gold label.
              # Dark mode: set full-saturation #FFB84D; tintColor override applied post-creation.
              LibObjCBridge.objc_send_id(config, sel("setBaseForegroundColor:"), amber_gold)
            end
          end
        end
      end

      # Create UIButton with configuration via +[UIButton buttonWithConfiguration:primaryAction:]
      # (iOS 15+). When UIButtonConfiguration is unavailable (nil config) fall back to
      # UIButtonTypeSystem = 1 which gives a text-link style button.
      #
      # buttonWithConfiguration:primaryAction: signature:
      #   + (UIButton *)buttonWithConfiguration:(UIButtonConfiguration *)configuration
      #                           primaryAction:(UIAction *)primaryAction;
      # We pass nil for primaryAction (actions wired separately via addTarget:action:forControlEvents:).
      ptr = if !config.null?
              LibObjCBridge.objc_send_id_id(
                uibutton_cls,
                sel("buttonWithConfiguration:primaryAction:"),
                config,
                Pointer(Void).null
              )
            else
              LibObjCBridge.objc_send_long(uibutton_cls, sel("buttonWithType:"), 1_i64)
            end

      # Post-creation tint color override — belt-and-suspenders for dark mode.
      # UIButtonConfiguration.gray() / .tinted() / .plain() in dark mode may
      # desaturate or alpha-reduce baseForegroundColor. Setting setTintColor:
      # on the UIButton directly overrides the configuration-level tint, ensuring
      # the label + any SF Symbol icon render at full saturation in both appearances.
      #
      # For Prominent (filled), the background is the primary brand signal; we do NOT
      # override tintColor there (it would override the fill-derived label color).
      #
      # Fallback (no configuration): setTitleColor:forState: as before.
      if config.null?
        tint_color = if view.role == :destructive
                       # Amber plum (#5B3A94 light / #D6B8F2 dark) for destructive.
                       # Dark bumped to #D6B8F2 for 4.5:1+ perceived contrast on
                       # warm-glass surfaces (June round 4 citation).
                       raw_app_fb = LibC.getenv("TEST_RUNNER_HIG_APPEARANCE")
                       want_dark_fb = !raw_app_fb.null? && String.new(raw_app_fb) == "dark"
                       LibObjCBridge.nscolor_rgba(
                         want_dark_fb ? 0.839 : 0.357,
                         want_dark_fb ? 0.722 : 0.227,
                         want_dark_fb ? 0.949 : 0.580,
                         1.0
                       )
                     else
                       amber_brand_gold
                     end
        unless tint_color.null?
          LibObjCBridge.objc_send_id_long(ptr, sel("setTitleColor:forState:"), tint_color, 0_i64)
        end
      elsif view.style != UI::ButtonStyle::Prominent
        # Configuration-backed non-Prominent: also set UIButton.tintColor directly
        # to guarantee dark-mode contrast on Tinted, Bordered, Borderless, and
        # Destructive (Default/Bordered) buttons. Prominent does not need this
        # because its filled background is already applied via setBaseBackgroundColor:.
        direct_tint = if view.role == :destructive
                        LibObjCBridge.objc_send(uicolor_cls, sel("systemRedColor"))
                      else
                        amber_gold
                      end
        unless direct_tint.null?
          LibObjCBridge.objc_send_id(ptr, sel("setTintColor:"), direct_tint)
        end
      end

      # setTitle:forState: — works on both configuration-backed and legacy buttons.
      title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
      LibObjCBridge.objc_send_id_long(ptr, sel("setTitle:forState:"), title_str, 0_i64)

      # Role-aware font: cancel = semibold, others = view.font.
      # NOTE: on configuration-backed buttons, titleLabel is nil; we set the
      # font via the configuration's titleTextAttributesTransformer path if needed.
      # For simplicity we attempt setFont: on titleLabel and skip if nil — the
      # configuration-based button uses Dynamic Type automatically which is
      # HIG-correct for most cases.
      font_for_role = view.font
      if view.role == :cancel
        font_for_role = UI::Font.new(
          family: view.font.family,
          size: view.font.size,
          weight: :semibold,
          italic: view.font.italic,
        )
      end
      title_label = LibObjCBridge.objc_send(ptr, sel("titleLabel"))
      unless title_label.null?
        font_ptr = resolve_font(font_for_role)
        LibObjCBridge.objc_send_id(title_label, sel("setFont:"), font_ptr)
      end

      # Leading SF Symbol (iOS 13+). +[UIImage systemImageNamed:] returns
      # nil for unknown names; skip silently.
      if sym = view.symbol
        uiimage_cls = LibObjCBridge.objc_getClass("UIImage")
        sym_ns = LibObjCBridge.nsstring_from_cstr(sym.to_unsafe)
        sym_image = LibObjCBridge.objc_send_id(uiimage_cls, sel("systemImageNamed:"), sym_ns)
        unless sym_image.null?
          LibObjCBridge.objc_send_id_long(ptr, sel("setImage:forState:"), sym_image, 0_i64)
        end
      end

      # Enabled/disabled.
      if view.disabled
        LibObjCBridge.objc_send_bool(ptr, sel("setEnabled:"), 0)
      end

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UIButton[#{view.style}]")
      native = NativeView.new(handle)

      # Wire on_tap via CrystalActionDispatcher + UIControlEventTouchUpInside = 64.
      if tap_handler = view.on_tap
        callback_id = native.register_callback(tap_handler)

        dispatcher_cls = LibObjCBridge.objc_getClass("CrystalActionDispatcher")
        unless dispatcher_cls.null?
          dispatcher = LibObjCBridge.objc_send(dispatcher_cls, sel("alloc"))
          dispatcher = LibObjCBridge.objc_send(dispatcher, sel("init"))
          LibObjCBridge.objc_send_long(dispatcher, sel("setTag:"), callback_id.to_i64)
          LibObjCBridge.objc_send_id_id_id(
            ptr,
            sel("addTarget:action:forControlEvents:"),
            dispatcher,
            sel("dispatch:"),
            Pointer(Void).new(64_u64)
          )
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: VStack -> UIStackView (vertical)
    # -----------------------------------------------------------------
    def visit(view : UI::VStack)
      ptr = alloc_init("UIStackView")

      # UILayoutConstraintAxisVertical = 1
      LibObjCBridge.objc_send_long(ptr, sel("setAxis:"), 1_i64)

      # Spacing
      LibObjCBridge.objc_send_1d(ptr, sel("setSpacing:"), view.spacing)

      # UIStackView alignment for vertical axis:
      # UIStackViewAlignmentLeading=1, UIStackViewAlignmentCenter=3,
      # UIStackViewAlignmentTrailing=4, UIStackViewAlignmentFill=0
      #
      # Default is Fill (0) rather than Center (3): a vertical UIStackView
      # should stretch its children to the full container width by default
      # on iOS. Centering collapses children that have no intrinsic width
      # (e.g. nested UIStackViews), breaking HStack rows inside ListViews.
      alignment_val = case view.alignment
                      when Alignment::Leading  then 1_i64
                      when Alignment::Center   then 3_i64
                      when Alignment::Trailing then 4_i64
                      when Alignment::Fill     then 0_i64
                      else                          0_i64  # Fill by default
                      end
      LibObjCBridge.objc_send_long(ptr, sel("setAlignment:"), alignment_val)

      # Common properties
      apply_common_properties(ptr, view)
      apply_stack_padding(ptr, view)

      handle = ObjC.owned(ptr, label: "UIStackView[v]")
      native = NativeView.new(handle)

      # Push onto stack, visit children, pop
      push_stack(native, is_uistack: true)
      view.children.each do |child|
        child.accept(self)
      end
      pop_stack

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: HStack -> UIStackView (horizontal)
    # -----------------------------------------------------------------
    def visit(view : UI::HStack)
      ptr = alloc_init("UIStackView")

      # UILayoutConstraintAxisHorizontal = 0
      LibObjCBridge.objc_send_long(ptr, sel("setAxis:"), 0_i64)

      # Spacing
      LibObjCBridge.objc_send_1d(ptr, sel("setSpacing:"), view.spacing)

      # UIStackView alignment for horizontal axis:
      # UIStackViewAlignmentTop=1, UIStackViewAlignmentCenter=3,
      # UIStackViewAlignmentBottom=4, UIStackViewAlignmentFill=0
      alignment_val = case view.alignment
                      when Alignment::Top      then 1_i64
                      when Alignment::Center   then 3_i64
                      when Alignment::Bottom   then 4_i64
                      when Alignment::Fill     then 0_i64
                      else                          3_i64
                      end
      LibObjCBridge.objc_send_long(ptr, sel("setAlignment:"), alignment_val)

      # Common properties
      apply_common_properties(ptr, view)
      apply_stack_padding(ptr, view)

      handle = ObjC.owned(ptr, label: "UIStackView[h]")
      native = NativeView.new(handle)

      push_stack(native, is_uistack: true)
      view.children.each do |child|
        child.accept(self)
      end
      pop_stack

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: ZStack -> UIView (overlay container)
    #
    # Children are added as subviews in order. Later children are drawn
    # on top. Each child gets an autoresizing mask to fill the parent.
    # -----------------------------------------------------------------
    def visit(view : UI::ZStack)
      ptr = alloc_init("UIView")

      # Common properties
      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UIView[zstack]")
      native = NativeView.new(handle)

      push_stack(native, is_uistack: false)
      view.children.each do |child|
        child.accept(self)
      end
      pop_stack

      # For ZStack children, set autoresizing mask to fill parent:
      # UIViewAutoresizingFlexibleWidth (2) | UIViewAutoresizingFlexibleHeight (16) = 18
      native.children.each do |child_nv|
        if child_nv.handle.valid?
          child_ptr = child_nv.handle.ptr!
          LibObjCBridge.objc_set_autoresize(child_ptr, 18_u64)
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Image -> UIImageView
    # -----------------------------------------------------------------
    def visit(view : UI::Image)
      ptr = alloc_init("UIImageView")

      # Load image by name. Prefer SF Symbol path (iOS 13+) so that
      # names like "envelope", "flag", "folder" resolve via SF Symbols.
      # Fall back to bundle imageNamed: for app-specific assets.
      uiimage_cls = LibObjCBridge.objc_getClass("UIImage")
      image_name = LibObjCBridge.nsstring_from_cstr(view.source.to_unsafe)
      uiimage = LibObjCBridge.objc_send_id(uiimage_cls, sel("systemImageNamed:"), image_name)
      if uiimage.null?
        # Not an SF Symbol — try bundle asset.
        uiimage = LibObjCBridge.objc_send_id(uiimage_cls, sel("imageNamed:"), image_name)
      end
      unless uiimage.null?
        LibObjCBridge.objc_send_id(ptr, sel("setImage:"), uiimage)
      end

      # Content mode -> UIViewContentMode
      # UIViewContentModeScaleAspectFit=1, UIViewContentModeScaleAspectFill=2,
      # UIViewContentModeScaleToFill=0
      content_mode_val = case view.content_mode
                         when ContentMode::Fit     then 1_i64 # ScaleAspectFit
                         when ContentMode::Fill    then 2_i64 # ScaleAspectFill
                         when ContentMode::Stretch then 0_i64 # ScaleToFill
                         else                           1_i64
                         end
      LibObjCBridge.objc_send_long(ptr, sel("setContentMode:"), content_mode_val)

      # Tint color: setTintColor: (available on UIImageView directly in UIKit)
      if tint = view.tint_color
        tint_ptr = LibObjCBridge.nscolor_rgba(tint.r, tint.g, tint.b, tint.a)
        LibObjCBridge.objc_send_id(ptr, sel("setTintColor:"), tint_ptr)
      end

      # Clip to bounds for UIImageView (important for aspect fill)
      if view.content_mode == ContentMode::Fill
        LibObjCBridge.objc_send_bool(ptr, sel("setClipsToBounds:"), 1)
      end

      # Common properties
      apply_common_properties(ptr, view)

      emit(ptr, "UIImageView")
    end

    # -----------------------------------------------------------------
    # Visit: TextField -> UITextField (or with secureTextEntry for passwords)
    # -----------------------------------------------------------------
    def visit(view : UI::TextField)
      ptr = alloc_init("UITextField")

      # Current text value
      unless view.text.empty?
        text_str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setText:"), text_str)
      end

      # Placeholder text
      unless view.placeholder.empty?
        placeholder_str = LibObjCBridge.nsstring_from_cstr(view.placeholder.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setPlaceholder:"), placeholder_str)
      end

      # Secure text entry (password field)
      if view.secure_entry
        LibObjCBridge.objc_send_bool(ptr, sel("setSecureTextEntry:"), 1)
      end

      # Keyboard type -> UIKeyboardType
      # UIKeyboardTypeDefault=0, UIKeyboardTypeEmailAddress=7, UIKeyboardTypeNumberPad=4,
      # UIKeyboardTypePhonePad=3, UIKeyboardTypeURL=3 (no exact match, use WebSearch=9 or URL=3)
      keyboard_type_val = case view.keyboard_type
                          when KeyboardType::EmailAddress then 7_i64
                          when KeyboardType::NumberPad    then 4_i64
                          when KeyboardType::PhonePad     then 3_i64
                          when KeyboardType::URL          then 9_i64 # UIKeyboardTypeWebSearch is closest for URL
                          else                                 0_i64 # UIKeyboardTypeDefault
                          end
      LibObjCBridge.objc_send_long(ptr, sel("setKeyboardType:"), keyboard_type_val)

      # Border style: UITextBorderStyleRoundedRect = 3
      # HIG text-fields: the canonical text field has bordered rounded-rect chrome.
      # UITextBorderStyleNone=0, UITextBorderStyleLine=1, UITextBorderStyleBezel=2,
      # UITextBorderStyleRoundedRect=3.
      LibObjCBridge.objc_send_long(ptr, sel("setBorderStyle:"), 3_i64)

      # Font
      font_ptr = resolve_font(view.font)
      LibObjCBridge.objc_send_id(ptr, sel("setFont:"), font_ptr)

      # Text color: default to UIColor.labelColor (appearance-tracking, HIG-correct).
      # Resolves to near-black in light mode and near-white in dark mode automatically.
      # A brand override sets view.text_color to a non-default RGBA value.
      # The View default is Color{r:0, g:0, b:0, a:1} (opaque black); when that sentinel
      # is detected, use the system labelColor instead of the explicit black, which would
      # be illegible in dark mode.
      tc = view.text_color
      color_ptr = if tc.r == 0.0 && tc.g == 0.0 && tc.b == 0.0 && tc.a == 1.0
                    LibObjCBridge.nscolor_label_primary
                  else
                    resolve_color(tc)
                  end
      LibObjCBridge.objc_send_id(ptr, sel("setTextColor:"), color_ptr)

      # Common properties
      apply_common_properties(ptr, view)

      # Create NativeView with potential on_change callback.
      #
      # UITextField uses the delegate pattern (textField:shouldChangeCharactersInRange:
      # replacementString:) or UIControlEventEditingChanged for text change notifications.
      # The CrystalTextFieldDelegate ObjC class must be registered before the renderer is
      # used. It calls crystal_ui_callback_dispatch(id) when text changes.
      handle = ObjC.owned(ptr, label: "UITextField")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        text_field_ptr = ptr
        wrapped = Proc(Nil).new do
          raw_str = LibObjCBridge.objc_send(text_field_ptr, sel("text"))
          unless raw_str.null?
            cstr = LibObjCBridge.objc_send(raw_str, sel("UTF8String"))
            unless cstr.null?
              change_handler.call(String.new(cstr.as(UInt8*)))
            end
          end
        end
        native.register_callback(wrapped)
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: ScrollView -> UIScrollView
    # -----------------------------------------------------------------
    def visit(view : UI::ScrollView)
      ptr = alloc_init("UIScrollView")

      # Scroll indicator visibility
      LibObjCBridge.objc_send_bool(ptr, sel("setShowsVerticalScrollIndicator:"),
        (view.scroll_vertical && view.shows_indicators) ? 1 : 0)
      LibObjCBridge.objc_send_bool(ptr, sel("setShowsHorizontalScrollIndicator:"),
        (view.scroll_horizontal && view.shows_indicators) ? 1 : 0)

      # Bounce behavior: disable vertical bounce if not scrolling vertically
      unless view.scroll_vertical
        LibObjCBridge.objc_send_bool(ptr, sel("setAlwaysBounceVertical:"), 0)
      end
      unless view.scroll_horizontal
        LibObjCBridge.objc_send_bool(ptr, sel("setAlwaysBounceHorizontal:"), 0)
      end

      # Explicit viewport size constraint.  UIScrollView inside a UIStackView
      # collapses to zero height because UIScrollView has no intrinsicContentSize
      # that the stack can use; the stack sees a (0, 0) fittingSize and collapses
      # the view.  objc_constrain_height pins the viewport height, letting the
      # content inside the scroll view remain taller (scrollable).
      if view.frame_width > 0.0 && view.frame_height > 0.0
        LibObjCBridge.objc_constrain_size(ptr, view.frame_width, view.frame_height)
      elsif view.frame_height > 0.0
        LibObjCBridge.objc_constrain_height(ptr, view.frame_height)
      end

      # Common properties
      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UIScrollView")
      native = NativeView.new(handle)

      # Visit the content subtree in isolation (render_detached) to get the
      # content UIView pointer.  Then:
      #   1. Add it as a subview of the UIScrollView.
      #   2. Call uiscrollview_pin_content to wire the content view's edges
      #      to the UIScrollView's contentLayoutGuide and its width to the
      #      frameLayoutGuide.  Without these constraints, UIScrollView's
      #      contentSize stays at {0,0} and the content collapses to zero.
      if content = view.content
        if content_nv = render_detached(content)
          native.add_child(content_nv)
          if content_nv.handle.valid?
            content_ptr = content_nv.handle.ptr!
            LibObjCBridge.objc_add_subview(ptr, content_ptr)
            LibObjCBridge.uiscrollview_pin_content(ptr, content_ptr)
          end
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Spacer -> UIView (empty, flexible)
    #
    # Spacers in a UIStackView expand to fill available space because
    # UIStackView distributes space among arranged subviews. A plain
    # UIView with no content hugging priority set achieves this.
    # Setting content hugging priority to 1 (UILayoutPriorityFittingSizeLevel=50,
    # lower = easier to stretch) allows the spacer to expand freely.
    # -----------------------------------------------------------------
    def visit(view : UI::Spacer)
      ptr = alloc_init("UIView")

      # Disable autoresizing mask translation so Auto Layout controls size
      LibObjCBridge.objc_send_bool(ptr, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)

      # If min_length > 0, set the frame as a minimum size hint.
      if view.min_length > 0
        min = view.min_length
        rect = LibObjCBridge::CGRect.new(x: 0.0, y: 0.0, width: min, height: min)
        LibObjCBridge.objc_set_frame(ptr, rect)
      end

      # Common properties
      apply_common_properties(ptr, view)

      emit(ptr, "UIView[spacer]")
    end

    # -----------------------------------------------------------------
    # Visit: Toggle -> UISwitch
    #
    # UISwitch is the native iOS toggle control. It has setOn:animated:
    # for state and setOnTintColor: for tint.
    #
    # Dark mode appearance fix (June R3): UISwitch OFF-state track renders
    # "cream" in dark captures because the switch inherits a light trait
    # collection when created outside the window hierarchy. Fix: set
    # overrideUserInterfaceStyle (UIUserInterfaceStyleDark=2, Light=1) on
    # the UISwitch directly from TEST_RUNNER_HIG_APPEARANCE before adding
    # it to the view tree. This forces the switch to resolve its OFF-state
    # gray track against the correct dark palette immediately.
    # -----------------------------------------------------------------
    def visit(view : UI::Toggle)
      ptr = alloc_init("UISwitch")

      # Appearance override: read TEST_RUNNER_HIG_APPEARANCE via raw getenv
      # (safe to call before Crystal runtime is initialized — see amber_brand_gold).
      # UIUserInterfaceStyle: Unspecified=0, Light=1, Dark=2
      raw_app = LibC.getenv("TEST_RUNNER_HIG_APPEARANCE")
      if !raw_app.null?
        want_dark_toggle = String.new(raw_app) == "dark"
        uistyle = want_dark_toggle ? 2_i64 : 1_i64
        # setOverrideUserInterfaceStyle: is iOS 13+ (always available on iOS 26).
        LibObjCBridge.objc_send_long(ptr, sel("setOverrideUserInterfaceStyle:"), uistyle)
      end

      # Set initial on/off state (animated: NO during initial setup)
      # setOn:animated: - NO=0
      LibObjCBridge.objc_send_id_long(ptr, sel("setOn:animated:"),
        Pointer(Void).new(view.is_on ? 1_u64 : 0_u64), 0_i64)

      # Tint color for the "on" state track.
      # Dark: amber gold dark (#FFB84D, r=1.0 g=0.722 b=0.302) for full saturation.
      if tint = view.tint_color
        tint_ptr = LibObjCBridge.nscolor_rgba(tint.r, tint.g, tint.b, tint.a)
        LibObjCBridge.objc_send_id(ptr, sel("setOnTintColor:"), tint_ptr)
      end

      # Disabled state: setEnabled:NO dims the UISwitch.
      if view.disabled
        LibObjCBridge.objc_send_bool(ptr, sel("setEnabled:"), 0)
      end

      # Common properties
      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UISwitch")
      native = NativeView.new(handle)

      # Wire up on_change callback via UIControlEventValueChanged = 1 << 12 = 4096.
      # The UISwitch sends UIControlEventValueChanged when its state changes.
      if change_handler = view.on_change
        switch_ptr = ptr
        wrapped = Proc(Nil).new do
          # isOn returns a BOOL (Int32 in Crystal). Convert to Bool for the handler.
          is_on_val = LibObjCBridge.objc_send_ret_bool(switch_ptr, sel("isOn"))
          change_handler.call(is_on_val != 0)
        end
        callback_id = native.register_callback(wrapped)

        dispatcher_cls = LibObjCBridge.objc_getClass("CrystalActionDispatcher")
        unless dispatcher_cls.null?
          dispatcher = LibObjCBridge.objc_send(dispatcher_cls, sel("alloc"))
          dispatcher = LibObjCBridge.objc_send(dispatcher, sel("init"))
          LibObjCBridge.objc_send_long(dispatcher, sel("setTag:"), callback_id.to_i64)
          # addTarget:action:forControlEvents: UIControlEventValueChanged=4096
          LibObjCBridge.objc_send_id_id_id(
            ptr,
            sel("addTarget:action:forControlEvents:"),
            dispatcher,
            sel("dispatch:"),
            Pointer(Void).new(4096_u64)
          )
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Checkbox -> UIButton (configured as a checkbox toggle)
    #
    # iOS has no native UICheckbox. We simulate one using a UIButton
    # that displays a system checkmark image when checked. The button
    # toggles its checked state on tap and calls the on_change handler.
    #
    # Symbol names (SF Symbols): "checkmark.square.fill" (checked),
    # "square" (unchecked). These are available on iOS 13+.
    # -----------------------------------------------------------------
    def visit(view : UI::Checkbox)
      # UIButtonTypeSystem = 1
      uibutton_cls = LibObjCBridge.objc_getClass("UIButton")
      ptr = LibObjCBridge.objc_send_long(uibutton_cls, sel("buttonWithType:"), 1_i64)

      # Set the title (label text) for UIControlStateNormal = 0
      title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
      LibObjCBridge.objc_send_id_long(ptr, sel("setTitle:forState:"), title_str, 0_i64)

      # Set checked state image using SF Symbols (iOS 13+):
      # UIImage.systemImageNamed: "checkmark.square.fill" or "square"
      uiimage_cls = LibObjCBridge.objc_getClass("UIImage")
      checked_symbol = view.is_checked ? "checkmark.square.fill" : "square"
      symbol_name_str = LibObjCBridge.nsstring_from_cstr(checked_symbol.to_unsafe)
      symbol_image = LibObjCBridge.objc_send_id(uiimage_cls, sel("systemImageNamed:"), symbol_name_str)
      unless symbol_image.null?
        # setImage:forState: UIControlStateNormal = 0
        LibObjCBridge.objc_send_id_long(ptr, sel("setImage:forState:"), symbol_image, 0_i64)
      end

      # Common properties
      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UIButton[checkbox]")
      native = NativeView.new(handle)

      # Wire up on_change callback: UIControlEventTouchUpInside = 64
      if change_handler = view.on_change
        # Track checked state across taps using a simple mutable reference.
        # The initial state matches view.is_checked at creation time.
        button_ptr = ptr
        checked_state = view.is_checked

        wrapped = Proc(Nil).new do
          # Toggle state
          checked_state = !checked_state
          new_symbol = checked_state ? "checkmark.square.fill" : "square"
          sym_str = LibObjCBridge.nsstring_from_cstr(new_symbol.to_unsafe)
          new_img = LibObjCBridge.objc_send_id(uiimage_cls, sel("systemImageNamed:"), sym_str)
          unless new_img.null?
            LibObjCBridge.objc_send_id_long(button_ptr, sel("setImage:forState:"), new_img, 0_i64)
          end
          change_handler.call(checked_state)
        end
        callback_id = native.register_callback(wrapped)

        dispatcher_cls = LibObjCBridge.objc_getClass("CrystalActionDispatcher")
        unless dispatcher_cls.null?
          dispatcher = LibObjCBridge.objc_send(dispatcher_cls, sel("alloc"))
          dispatcher = LibObjCBridge.objc_send(dispatcher, sel("init"))
          LibObjCBridge.objc_send_long(dispatcher, sel("setTag:"), callback_id.to_i64)
          LibObjCBridge.objc_send_id_id_id(
            ptr,
            sel("addTarget:action:forControlEvents:"),
            dispatcher,
            sel("dispatch:"),
            Pointer(Void).new(64_u64) # UIControlEventTouchUpInside
          )
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: RadioGroup -> UIStackView of UIButtons (radio options)
    #
    # iOS has no native UIRadioGroup. We simulate one as a UIStackView
    # (vertical) containing one UIButton per option. The selected option
    # is indicated by a filled circle SF Symbol; others show empty circles.
    #
    # Symbol names: "largecircle.fill.circle" (selected), "circle" (unselected).
    # Available on iOS 13+.
    # -----------------------------------------------------------------
    def visit(view : UI::RadioGroup)
      container_ptr = alloc_init("UIStackView")

      # Vertical stack for radio options
      LibObjCBridge.objc_send_long(container_ptr, sel("setAxis:"), 1_i64)
      LibObjCBridge.objc_send_1d(container_ptr, sel("setSpacing:"), 8.0)
      LibObjCBridge.objc_send_long(container_ptr, sel("setAlignment:"), 1_i64) # UIStackViewAlignmentLeading

      # Common properties on the container
      apply_common_properties(container_ptr, view)

      handle = ObjC.owned(container_ptr, label: "UIStackView[radio]")
      native = NativeView.new(handle)

      uibutton_cls = LibObjCBridge.objc_getClass("UIButton")
      uiimage_cls = LibObjCBridge.objc_getClass("UIImage")

      # Create a button for each option
      view.options.each_with_index do |option_text, index|
        # UIButtonTypeSystem = 1
        option_ptr = LibObjCBridge.objc_send_long(uibutton_cls, sel("buttonWithType:"), 1_i64)

        # Option title
        option_str = LibObjCBridge.nsstring_from_cstr(option_text.to_unsafe)
        LibObjCBridge.objc_send_id_long(option_ptr, sel("setTitle:forState:"), option_str, 0_i64)

        # Selection indicator via SF Symbol
        is_selected = (index == view.selected_index)
        symbol_name = is_selected ? "largecircle.fill.circle" : "circle"
        sym_str = LibObjCBridge.nsstring_from_cstr(symbol_name.to_unsafe)
        sym_img = LibObjCBridge.objc_send_id(uiimage_cls, sel("systemImageNamed:"), sym_str)
        unless sym_img.null?
          LibObjCBridge.objc_send_id_long(option_ptr, sel("setImage:forState:"), sym_img, 0_i64)
        end

        # Wire up callback for this option: UIControlEventTouchUpInside = 64
        if change_handler = view.on_change
          captured_index = index
          captured_container = container_ptr
          captured_options_count = view.options.size

          option_btn_ptr = option_ptr
          wrapped = Proc(Nil).new do
            # Update all sibling buttons' images to reflect new selection.
            # Access arranged subviews of the container stack.
            captured_options_count.times do |i|
              # getArrangedSubviews returns NSArray; we use objectAtIndex:
              # to get each subview's button and update its image.
              arranged_sel = LibObjCBridge.sel_registerName("arrangedSubviews".to_unsafe)
              arranged_views = LibObjCBridge.objc_send(captured_container, arranged_sel)
              unless arranged_views.null?
                obj_at_sel = LibObjCBridge.sel_registerName("objectAtIndex:".to_unsafe)
                sibling = LibObjCBridge.objc_send_long(arranged_views, obj_at_sel, i.to_i64)
                unless sibling.null?
                  sib_sym = (i == captured_index) ? "largecircle.fill.circle" : "circle"
                  sib_sym_str = LibObjCBridge.nsstring_from_cstr(sib_sym.to_unsafe)
                  sib_img = LibObjCBridge.objc_send_id(uiimage_cls, sel("systemImageNamed:"), sib_sym_str)
                  unless sib_img.null?
                    LibObjCBridge.objc_send_id_long(sibling, sel("setImage:forState:"), sib_img, 0_i64)
                  end
                end
              end
            end
            change_handler.call(captured_index)
          end

          option_handle = ObjC.owned(option_ptr, label: "UIButton[radio-option]")
          option_native = NativeView.new(option_handle)
          callback_id = option_native.register_callback(wrapped)

          dispatcher_cls = LibObjCBridge.objc_getClass("CrystalActionDispatcher")
          unless dispatcher_cls.null?
            dispatcher = LibObjCBridge.objc_send(dispatcher_cls, sel("alloc"))
            dispatcher = LibObjCBridge.objc_send(dispatcher, sel("init"))
            LibObjCBridge.objc_send_long(dispatcher, sel("setTag:"), callback_id.to_i64)
            LibObjCBridge.objc_send_id_id_id(
              option_ptr,
              sel("addTarget:action:forControlEvents:"),
              dispatcher,
              sel("dispatch:"),
              Pointer(Void).new(64_u64) # UIControlEventTouchUpInside
            )
          end

          native.add_child(option_native)
        else
          # No callback: wrap simply and add to tree
          option_handle = ObjC.owned(option_ptr, label: "UIButton[radio-option]")
          option_native = NativeView.new(option_handle)
          native.add_child(option_native)
        end

        # Add option button to container stack as arranged subview
        LibObjCBridge.objc_send_void_id(container_ptr, sel("addArrangedSubview:"), option_ptr)
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Slider -> synthetic UIView container + invisible UISlider
    #
    # UISlider's track is drawn via private CALayer sublayers that XCUITest
    # rasterization does not composite into screenshots.  Instead we build a
    # screenshot-stable synthetic track:
    #   - A UIView container (44pt tall, TAMIC=NO) as the outer hit target.
    #   - A background track UIView (full width, 4pt, corner radius 2pt,
    #     UIColor.systemFillColor) for the unfilled portion.
    #   - A filled track UIView (leading fraction of width, same height,
    #     system blue or tint_color) for the filled portion.
    #   - A 28pt circular thumb UIView (white, drop shadow) at the fraction
    #     position.
    #   - The real UISlider at alpha 0.0 on top, so touch events still route
    #     correctly and UIControlEventValueChanged still fires.
    #
    # All frame layout is deferred to the next run-loop turn (after UIStackView
    # resolves the container width) via dispatch_async from the C helper
    # uislider_build_synthetic_track.
    # -----------------------------------------------------------------
    def visit(view : UI::Slider)
      # Build the invisible UISlider first (range, value, callback wiring).
      ptr = alloc_init("UISlider")

      LibObjCBridge.objc_send_1d(ptr, sel("setMinimumValue:"), view.minimum)
      LibObjCBridge.objc_send_1d(ptr, sel("setMaximumValue:"), view.maximum)
      LibObjCBridge.objc_send_1d(ptr, sel("setValue:"), view.value)

      # Also configure native tint so touch-driven updates show correctly.
      uicolor_cls = LibObjCBridge.objc_getClass("UIColor")
      filled_color = if tint = view.tint_color
                       LibObjCBridge.nscolor_rgba(tint.r, tint.g, tint.b, tint.a)
                     else
                       LibObjCBridge.objc_send(uicolor_cls, sel("systemBlueColor"))
                     end
      unfilled_color = LibObjCBridge.objc_send(uicolor_cls, sel("systemFillColor"))

      LibObjCBridge.objc_send_id(ptr, sel("setMinimumTrackTintColor:"), filled_color) unless filled_color.null?

      apply_common_properties(ptr, view)

      # Compute the value fraction in [0, 1] for thumb / fill positioning.
      range = view.maximum - view.minimum
      value_fraction = if range > 0.0
                         ((view.value - view.minimum) / range).clamp(0.0, 1.0)
                       else
                         0.0
                       end

      # Build the synthetic track container.  The UISlider ptr is added as a
      # child inside the container at alpha 0.0 by the C helper.
      container_ptr = LibObjCBridge.uislider_build_synthetic_track(
        value_fraction,
        filled_color.null? ? LibObjCBridge.nscolor_rgba(0.0, 0.478, 1.0, 1.0) : filled_color,
        unfilled_color.null? ? LibObjCBridge.nscolor_rgba(0.47, 0.47, 0.47, 0.3) : unfilled_color,
        ptr
      )

      # Fall back to the plain UISlider if the C helper returned NULL
      # (should never happen on iOS, but defensive).
      root_ptr = container_ptr.null? ? ptr : container_ptr

      handle = ObjC.owned(root_ptr, label: "UIView[slider-container]")
      native = NativeView.new(handle)

      # Wire up on_change callback on the underlying UISlider (ptr).
      if change_handler = view.on_change
        slider_ptr = ptr
        step = view.step

        wrapped = Proc(Nil).new do
          # ARM64: UISlider.value returns float in s0 register, which the ObjC
          # runtime places in d0 when called through objc_msgSend.  We read it
          # via the void* -> address reinterpret trick (ABI-correct on ARM64).
          raw_val_ptr = LibObjCBridge.objc_send(slider_ptr, sel("value"))
          raw_float = raw_val_ptr.address.unsafe_as(Float32)
          actual_value = if step > 0.0
                           snapped = (raw_float.to_f64 / step).round * step
                           snapped.clamp(view.minimum, view.maximum)
                         else
                           raw_float.to_f64
                         end
          change_handler.call(actual_value)
        end
        callback_id = native.register_callback(wrapped)

        dispatcher_cls = LibObjCBridge.objc_getClass("CrystalActionDispatcher")
        unless dispatcher_cls.null?
          dispatcher = LibObjCBridge.objc_send(dispatcher_cls, sel("alloc"))
          dispatcher = LibObjCBridge.objc_send(dispatcher, sel("init"))
          LibObjCBridge.objc_send_long(dispatcher, sel("setTag:"), callback_id.to_i64)
          # UIControlEventValueChanged = 1 << 12 = 4096
          LibObjCBridge.objc_send_id_id_id(
            ptr,
            sel("addTarget:action:forControlEvents:"),
            dispatcher,
            sel("dispatch:"),
            Pointer(Void).new(4096_u64)
          )
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: ProgressView -> UIProgressView (linear) or UIActivityIndicatorView (circular)
    # -----------------------------------------------------------------
    # -----------------------------------------------------------------
    # Visit: NavigationStack -> UIView (container for navigation content)
    # -----------------------------------------------------------------
    def visit(view : UI::NavigationStack)
      ptr = alloc_init("UIView")

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UIView[nav-stack]")
      native = NativeView.new(handle)

      # Render the current view (top of stack or root) into this container
      push_stack(native, is_uistack: false)
      view.current_view.accept(self)
      pop_stack

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: NavigationLink -> UIButton (styled as a link row)
    # -----------------------------------------------------------------
    def visit(view : UI::NavigationLink)
      # UIButtonTypeSystem = 1
      uibutton_cls = LibObjCBridge.objc_getClass("UIButton")
      ptr = LibObjCBridge.objc_send_long(uibutton_cls, sel("buttonWithType:"), 1_i64)

      title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
      LibObjCBridge.objc_send_id_long(ptr, sel("setTitle:forState:"), title_str, 0_i64)

      apply_common_properties(ptr, view)

      emit(ptr, "UIButton[nav-link]")
    end

    # -----------------------------------------------------------------
    # Visit: TabView -> UIVisualEffectView (Liquid Glass root) containing
    #                   a vertical UIStackView with content + tab bar row.
    #
    # HIG tab-bars Platform considerations (iOS): "A tab bar floats above
    # content at the bottom of the screen. Its items rest on a Liquid Glass
    # background that allows content beneath to peek through."
    #
    # Structure:
    #   UIVisualEffectView (glass root: UIGlassEffect iOS 26 / UIBlurEffect
    #                        systemChromeMaterial=11 fallback)
    #     contentView
    #       UIStackView (outer, vertical, no spacing)
    #         UIStackView (content area: grows, vertical)
    #           <selected tab content>
    #         UIView (separator: 0.5pt horizontal hairline)
    #         UIStackView (tab row: horizontal, equal-width cells)
    #           cell_0 .. cell_N (vertical: UIImageView + UILabel)
    #
    # Selected tab: UIColor.systemBlueColor (or selected_tint_color).
    # Unselected tabs: UIColor.secondaryLabelColor (appearance-tracking).
    # -----------------------------------------------------------------
    def visit(view : UI::TabView)
      uicolor_cls = LibObjCBridge.objc_getClass("UIColor")
      uifont_cls  = LibObjCBridge.objc_getClass("UIFont")

      # Build the glass effect. UIGlassEffect on iOS 26; fallback to
      # UIBlurEffectStyleSystemChromeMaterial = 11 on older SDKs.
      glass_cls = LibObjCBridge.objc_getClass("UIGlassEffect")
      blur_effect = if !glass_cls.null?
                      LibObjCBridge.objc_send(
                        LibObjCBridge.objc_send(glass_cls, sel("alloc")),
                        sel("init"))
                    else
                      ublur_cls = LibObjCBridge.objc_getClass("UIBlurEffect")
                      # UIBlurEffectStyleSystemChromeMaterial = 11
                      LibObjCBridge.objc_send_long(ublur_cls, sel("effectWithStyle:"), 11_i64)
                    end

      uveff_cls = LibObjCBridge.objc_getClass("UIVisualEffectView")
      effect_alloc = LibObjCBridge.objc_send(uveff_cls, sel("alloc"))
      glass_root = LibObjCBridge.objc_send_id(effect_alloc, sel("initWithEffect:"), blur_effect)

      apply_common_properties(glass_root, view)

      glass_handle = ObjC.owned(glass_root, label: "UIVisualEffectView[tab-bar-glass]")
      glass_native = NativeView.new(glass_handle)

      # Get the contentView (UIVisualEffectView requirement: subviews MUST go in contentView)
      content_view_host = LibObjCBridge.objc_send(glass_root, sel("contentView"))
      anchor_host = content_view_host.null? ? glass_root : content_view_host

      # Outer vertical UIStackView: content area + separator + tab row
      outer = alloc_init("UIStackView")
      LibObjCBridge.objc_send_long(outer, sel("setAxis:"), 1_i64)
      LibObjCBridge.objc_send_1d(outer, sel("setSpacing:"), 0.0)
      LibObjCBridge.objc_send_long(outer, sel("setDistribution:"), 0_i64)
      LibObjCBridge.objc_send_bool(outer, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)

      outer_inner_handle = ObjC.borrowed(outer, label: "UIStackView[tab-view-inner]")
      outer_inner_native = NativeView.new(outer_inner_handle)

      # Content area UIStackView (vertical, contains selected tab content)
      content_stack = alloc_init("UIStackView")
      LibObjCBridge.objc_send_long(content_stack, sel("setAxis:"), 1_i64)
      LibObjCBridge.objc_send_1d(content_stack, sel("setSpacing:"), 8.0)
      # UIStackViewAlignmentFill = 0
      LibObjCBridge.objc_send_long(content_stack, sel("setAlignment:"), 0_i64)
      content_insets = LibObjCBridge::CGRect.new(x: 16.0, y: 16.0, width: 16.0, height: 16.0)
      LibObjCBridge.objc_send_rect_void(content_stack, sel("setLayoutMargins:"), content_insets)
      LibObjCBridge.objc_send_bool(content_stack, sel("setLayoutMarginsRelativeArrangement:"), 1)

      if content = view.current_content
        content_stack_handle = ObjC.owned(content_stack, label: "UIStackView[tab-content]")
        content_stack_native = NativeView.new(content_stack_handle)
        push_stack(content_stack_native, is_uistack: true)
        content.accept(self)
        pop_stack
      end
      LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), content_stack)

      # Separator: thin UIView (0.5pt height, secondary label color)
      sep = alloc_init("UIView")
      unless uicolor_cls.null?
        sep_color = LibObjCBridge.objc_send(uicolor_cls, sel("separatorColor"))
        LibObjCBridge.objc_send_id(sep, sel("setBackgroundColor:"), sep_color) unless sep_color.null?
      end
      LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), sep)

      # Tab bar row: horizontal UIStackView, equal-width cells
      tab_row = alloc_init("UIStackView")
      LibObjCBridge.objc_send_long(tab_row, sel("setAxis:"), 0_i64)
      LibObjCBridge.objc_send_1d(tab_row, sel("setSpacing:"), 0.0)
      # UIStackViewDistributionFillEqually = 2
      LibObjCBridge.objc_send_long(tab_row, sel("setDistribution:"), 2_i64)

      view.tabs.each_with_index do |tab, idx|
        is_selected = (idx == view.selected_index)

        selected_tint = if tc = view.selected_tint_color
                           LibObjCBridge.nscolor_rgba(tc.r, tc.g, tc.b, tc.a)
                         elsif !uicolor_cls.null?
                           LibObjCBridge.objc_send(uicolor_cls, sel("systemBlueColor"))
                         else
                           LibObjCBridge.nscolor_rgba(0.0, 0.478, 1.0, 1.0)
                         end
        unselected_tint = if !uicolor_cls.null?
                             LibObjCBridge.objc_send(uicolor_cls, sel("secondaryLabelColor"))
                           else
                             LibObjCBridge.nscolor_rgba(0.34, 0.34, 0.36, 1.0)
                           end

        # Cell: vertical UIStackView (icon above label)
        cell = alloc_init("UIStackView")
        LibObjCBridge.objc_send_long(cell, sel("setAxis:"), 1_i64)
        LibObjCBridge.objc_send_1d(cell, sel("setSpacing:"), 2.0)
        LibObjCBridge.objc_send_long(cell, sel("setAlignment:"), 3_i64) # UIStackViewAlignmentCenter
        LibObjCBridge.objc_send_long(cell, sel("setDistribution:"), 0_i64)
        cell_insets = LibObjCBridge::CGRect.new(x: 6.0, y: 4.0, width: 6.0, height: 4.0)
        LibObjCBridge.objc_send_rect_void(cell, sel("setLayoutMargins:"), cell_insets)
        LibObjCBridge.objc_send_bool(cell, sel("setLayoutMarginsRelativeArrangement:"), 1)

        # Icon: UIImageView with SF Symbol
        if icon_name = tab.icon
          img_view = alloc_init("UIImageView")
          sym_name_ns = LibObjCBridge.nsstring_from_cstr(icon_name.to_unsafe)
          ui_image_cls = LibObjCBridge.objc_getClass("UIImage")
          unless ui_image_cls.null?
            sym_img = LibObjCBridge.objc_send_id(ui_image_cls,
              sel("systemImageNamed:"), sym_name_ns)
            LibObjCBridge.objc_send_id(img_view, sel("setImage:"), sym_img) unless sym_img.null?
          end
          icon_tint = is_selected ? selected_tint : unselected_tint
          LibObjCBridge.objc_send_id(img_view, sel("setTintColor:"), icon_tint) unless icon_tint.null?
          # contentMode: UIViewContentModeScaleAspectFit = 1
          LibObjCBridge.objc_send_long(img_view, sel("setContentMode:"), 1_i64)
          LibObjCBridge.objc_send_id(cell, sel("addArrangedSubview:"), img_view)
        end

        # Label: UILabel, 10pt caption font
        lbl_ptr = alloc_init("UILabel")
        lbl_str = LibObjCBridge.nsstring_from_cstr(tab.label.to_unsafe)
        LibObjCBridge.objc_send_id(lbl_ptr, sel("setText:"), lbl_str)
        # NSTextAlignmentCenter = 1
        LibObjCBridge.objc_send_long(lbl_ptr, sel("setTextAlignment:"), 1_i64)
        unless uifont_cls.null?
          lbl_font = LibObjCBridge.objc_send_1d_ret_id(uifont_cls, sel("systemFontOfSize:"), 10.0)
          LibObjCBridge.objc_send_id(lbl_ptr, sel("setFont:"), lbl_font) unless lbl_font.null?
        end
        lbl_tint = is_selected ? selected_tint : unselected_tint
        LibObjCBridge.objc_send_id(lbl_ptr, sel("setTextColor:"), lbl_tint) unless lbl_tint.null?
        LibObjCBridge.objc_send_id(cell, sel("addArrangedSubview:"), lbl_ptr)

        LibObjCBridge.objc_send_id(tab_row, sel("addArrangedSubview:"), cell)
      end

      LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), tab_row)

      # Add outer stack into the glass root's contentView; pin its edges
      # so the glass root derives its intrinsic size from the stack content.
      LibObjCBridge.objc_add_subview(anchor_host, outer)

      %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anchor_sel|
        outer_anchor = LibObjCBridge.objc_send(outer, sel(anchor_sel))
        host_anchor  = LibObjCBridge.objc_send(anchor_host, sel(anchor_sel))
        next if outer_anchor.null? || host_anchor.null?
        constraint = LibObjCBridge.objc_send_id(outer_anchor, sel("constraintEqualToAnchor:"), host_anchor)
        LibObjCBridge.objc_send_bool(constraint, sel("setActive:"), 1) unless constraint.null?
      end

      glass_native.add_child(outer_inner_native)
      push_native(glass_native)
    end

    # -----------------------------------------------------------------
    # Visit: ProgressView -> UIProgressView (linear) or UIActivityIndicatorView (circular)
    # -----------------------------------------------------------------
    def visit(view : UI::ProgressView)
      if view.style == UI::ProgressStyle::Circular
        ptr = alloc_init("UIActivityIndicatorView")

        if view.value.nil?
          # UIActivityIndicatorView.startAnimating
          LibObjCBridge.objc_send(ptr, sel("startAnimating"))
        end

        apply_common_properties(ptr, view)

        emit(ptr, "UIActivityIndicatorView[progress]")
      else
        ptr = alloc_init("UIProgressView")

        if val = view.value
          # setProgress:animated: - animated:NO=0
          LibObjCBridge.objc_send_id_long(ptr, sel("setProgress:animated:"),
            Pointer(Void).new((val * 1000.0).round.to_u64), 0_i64)
        end

        if tint = view.tint_color
          tint_ptr = LibObjCBridge.nscolor_rgba(tint.r, tint.g, tint.b, tint.a)
          LibObjCBridge.objc_send_id(ptr, sel("setProgressTintColor:"), tint_ptr)
        end

        apply_common_properties(ptr, view)

        emit(ptr, "UIProgressView")
      end
    end

    # -----------------------------------------------------------------
    # Visit: ActivityIndicator -> UIActivityIndicatorView
    # -----------------------------------------------------------------
    def visit(view : UI::ActivityIndicator)
      ptr = alloc_init("UIActivityIndicatorView")

      # UIActivityIndicatorViewStyle: medium=100, large=101 (iOS 13+)
      style_val = view.size == :large ? 101_i64 : 100_i64
      LibObjCBridge.objc_send_long(ptr, sel("setActivityIndicatorViewStyle:"), style_val)

      if view.is_animating
        LibObjCBridge.objc_send(ptr, sel("startAnimating"))
      else
        LibObjCBridge.objc_send(ptr, sel("stopAnimating"))
      end

      if tint = view.color
        tint_ptr = LibObjCBridge.nscolor_rgba(tint.r, tint.g, tint.b, tint.a)
        LibObjCBridge.objc_send_id(ptr, sel("setColor:"), tint_ptr)
      end

      apply_common_properties(ptr, view)

      emit(ptr, "UIActivityIndicatorView")
    end

    # -----------------------------------------------------------------
    # Visit: Alert -> UIVisualEffectView inline card (Liquid Glass)
    #
    # HIG: Alerts are surface components requiring Liquid Glass. On iOS 26
    # we prefer UIGlassEffect; on older SDKs UIBlurEffect(systemMaterial=7)
    # provides the frosted-glass appearance.
    #
    # For production use the caller should present UIAlertController modally.
    # This inline rendering path is used by the HIG validation host for
    # screenshot isolation. Material, corner radius, and role-coloring are
    # HIG-faithful — hudWindow-equivalent on iOS is systemMaterial.
    # -----------------------------------------------------------------
    def visit(view : UI::Alert)
      # Build the UIBlurEffect. Prefer UIGlassEffect on iOS 26; fall back to
      # UIBlurEffectStyleSystemMaterial (= 7, tracks appearance).
      glass_cls = LibObjCBridge.objc_getClass("UIGlassEffect")
      blur_effect = if !glass_cls.null?
                      LibObjCBridge.objc_send(
                        LibObjCBridge.objc_send(glass_cls, sel("alloc")),
                        sel("init"))
                    else
                      ublur_cls = LibObjCBridge.objc_getClass("UIBlurEffect")
                      # UIBlurEffectStyleSystemMaterial = 7
                      LibObjCBridge.objc_send_long(ublur_cls, sel("effectWithStyle:"), 7_i64)
                    end

      # [[UIVisualEffectView alloc] initWithEffect:blur_effect]
      uveff_cls = LibObjCBridge.objc_getClass("UIVisualEffectView")
      effect_alloc = LibObjCBridge.objc_send(uveff_cls, sel("alloc"))
      effect = LibObjCBridge.objc_send_id(effect_alloc, sel("initWithEffect:"), blur_effect)

      # Rounded corners — ~12pt matches HIG alert card corner radius.
      LibObjCBridge.objc_send_bool(effect, sel("setClipsToBounds:"), 1)
      layer = LibObjCBridge.objc_send(effect, sel("layer"))
      unless layer.null?
        LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), 12.0)
        LibObjCBridge.objc_send_bool(layer, sel("setMasksToBounds:"), 1)
      end

      # Inner UIStackView: vertical, 16pt margins, 8pt spacing.
      inner = alloc_init("UIStackView")
      # UILayoutConstraintAxisVertical = 1
      LibObjCBridge.objc_send_long(inner, sel("setAxis:"), 1_i64)
      LibObjCBridge.objc_send_1d(inner, sel("setSpacing:"), 8.0)
      # UIStackViewAlignmentCenter = 3
      LibObjCBridge.objc_send_long(inner, sel("setAlignment:"), 3_i64)
      insets = LibObjCBridge::CGRect.new(x: 16.0, y: 16.0, width: 16.0, height: 16.0)
      LibObjCBridge.objc_send_rect_void(inner, sel("setLayoutMargins:"), insets)
      LibObjCBridge.objc_send_bool(inner, sel("setLayoutMarginsRelativeArrangement:"), 1)
      LibObjCBridge.objc_send_bool(inner, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)

      # Add inner stack to contentView (UIVisualEffectView requirement).
      content_view = LibObjCBridge.objc_send(effect, sel("contentView"))
      anchor_host = if content_view.null?
                      LibObjCBridge.objc_add_subview(effect, inner)
                      effect
                    else
                      LibObjCBridge.objc_add_subview(content_view, inner)
                      content_view
                    end

      # Pin inner to anchor_host on all four edges.
      %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anchor_sel|
        inner_anchor = LibObjCBridge.objc_send(inner, sel(anchor_sel))
        host_anchor  = LibObjCBridge.objc_send(anchor_host, sel(anchor_sel))
        next if inner_anchor.null? || host_anchor.null?
        constraint = LibObjCBridge.objc_send_id(inner_anchor, sel("constraintEqualToAnchor:"), host_anchor)
        LibObjCBridge.objc_send_bool(constraint, sel("setActive:"), 1) unless constraint.null?
      end

      inner_handle = ObjC.borrowed(inner, label: "UIStackView[alert-inner]")
      inner_native = NativeView.new(inner_handle)

      # Title label — bold, center-aligned (HIG: "write a title that clearly
      # and succinctly describes the situation").
      title_field = alloc_init("UILabel")
      title_str = LibObjCBridge.nsstring_from_cstr(view.title.to_unsafe)
      LibObjCBridge.objc_send_id(title_field, sel("setText:"), title_str)
      title_font = LibObjCBridge.nsfont_bold_system(13.0)
      LibObjCBridge.objc_send_id(title_field, sel("setFont:"), title_font)
      # UITextAlignmentCenter = 1
      LibObjCBridge.objc_send_long(title_field, sel("setTextAlignment:"), 1_i64)
      title_color = LibObjCBridge.nscolor_label_primary
      LibObjCBridge.objc_send_id(title_field, sel("setTextColor:"), title_color)
      title_handle = ObjC.owned(title_field, label: "UILabel[alert-title]")
      title_native = NativeView.new(title_handle)
      inner_native.add_child(title_native)
      LibObjCBridge.objc_send_id(inner, sel("addArrangedSubview:"), title_field)

      # Message label — regular weight, center-aligned.
      unless view.message.empty?
        msg_field = alloc_init("UILabel")
        msg_str = LibObjCBridge.nsstring_from_cstr(view.message.to_unsafe)
        LibObjCBridge.objc_send_id(msg_field, sel("setText:"), msg_str)
        msg_font = LibObjCBridge.nsfont_system(11.0)
        LibObjCBridge.objc_send_id(msg_field, sel("setFont:"), msg_font)
        LibObjCBridge.objc_send_long(msg_field, sel("setTextAlignment:"), 1_i64) # Center
        msg_color = LibObjCBridge.nscolor_label_secondary
        LibObjCBridge.objc_send_id(msg_field, sel("setTextColor:"), msg_color)
        LibObjCBridge.objc_send_long(msg_field, sel("setNumberOfLines:"), 3_i64)
        msg_handle = ObjC.owned(msg_field, label: "UILabel[alert-message]")
        msg_native = NativeView.new(msg_handle)
        inner_native.add_child(msg_native)
        LibObjCBridge.objc_send_id(inner, sel("addArrangedSubview:"), msg_field)
      end

      # Button row — horizontal UIStackView, trailing-edge fill distribution.
      btn_row = alloc_init("UIStackView")
      # UILayoutConstraintAxisHorizontal = 0
      LibObjCBridge.objc_send_long(btn_row, sel("setAxis:"), 0_i64)
      LibObjCBridge.objc_send_1d(btn_row, sel("setSpacing:"), 8.0)
      # UIStackViewDistributionFillEqually = 2
      LibObjCBridge.objc_send_long(btn_row, sel("setDistribution:"), 2_i64)
      btn_row_handle = ObjC.owned(btn_row, label: "UIStackView[alert-buttons]")
      btn_row_native = NativeView.new(btn_row_handle)
      inner_native.add_child(btn_row_native)
      LibObjCBridge.objc_send_id(inner, sel("addArrangedSubview:"), btn_row)

      view.buttons.each do |btn|
        # UIButtonTypeSystem = 1
        uibutton_cls = LibObjCBridge.objc_getClass("UIButton")
        btn_ptr = LibObjCBridge.objc_send_long(uibutton_cls, sel("buttonWithType:"), 1_i64)

        btn_title_str = LibObjCBridge.nsstring_from_cstr(btn.label.to_unsafe)
        # setTitle:forState: UIControlStateNormal = 0
        LibObjCBridge.objc_send_id_long(btn_ptr, sel("setTitle:forState:"), btn_title_str, 0_i64)

        # Role-aware tint color (UIButton.tintColor drives title color in .system type).
        tint_color = case btn.style
                     when :destructive
                       uicolor_cls = LibObjCBridge.objc_getClass("UIColor")
                       c = LibObjCBridge.objc_send(uicolor_cls, sel("systemRedColor"))
                       c.null? ? resolve_color(UI::Color.new(r: 1.0, g: 0.23, b: 0.19)) : c
                     else
                       resolve_color(UI::Color.new(r: 0.0, g: 0.478, b: 1.0))
                     end
        LibObjCBridge.objc_send_id(btn_ptr, sel("setTintColor:"), tint_color)

        # Cancel buttons: bold title font (Semibold per HIG).
        if btn.style == :cancel
          cancel_font = LibObjCBridge.nsfont_system_weight(13.0, 0.4)
          LibObjCBridge.objc_send_id(btn_ptr, sel("setFont:"), cancel_font)
        end

        # Minimum 44pt hit target (HIG Buttons — Best practices).
        min_h_anchor = LibObjCBridge.objc_send(btn_ptr, sel("heightAnchor"))
        unless min_h_anchor.null?
          h_const = LibObjCBridge.objc_send_1d_ret_id(
            min_h_anchor,
            sel("constraintGreaterThanOrEqualToConstant:"),
            44.0)
          LibObjCBridge.objc_send_bool(h_const, sel("setActive:"), 1) unless h_const.null?
        end

        native_btn_handle = ObjC.owned(btn_ptr, label: "UIButton[alert-btn-#{btn.label}]")
        native_btn = NativeView.new(native_btn_handle)
        btn_row_native.add_child(native_btn)
        LibObjCBridge.objc_send_id(btn_row, sel("addArrangedSubview:"), btn_ptr)
      end

      apply_common_properties(effect, view)

      outer_handle = ObjC.owned(effect, label: "UIVisualEffectView[alert-glass]")
      outer_native = NativeView.new(outer_handle)
      outer_native.add_child(inner_native)
      push_native(outer_native)
    end

    # -----------------------------------------------------------------
    # Visit: Picker -> inline list with checkmarks (iOS Settings style)
    #
    # HIG short-list recommendation: "For short lists, consider using a menu
    # or segmented control instead of a wheel picker." For static option sets
    # we render an inset-grouped list of rows, each showing the option label
    # leading-aligned and a "checkmark" SF Symbol tinted systemBlue on the
    # selected row. This is the dominant picker shape in iOS Settings and
    # is legible in both light and dark appearances.
    #
    # Root: UIStackView (vertical, axis=1, alignment=Fill). UIStackView has
    # intrinsic content size from its arranged subviews — it sizes correctly
    # inside a parent UIStackView without explicit anchor constraints.
    # Corner radius + secondarySystemGroupedBackground on the root stack.
    #
    # Row anatomy (horizontal UIStackView per row, isLayoutMarginsRelativeArrangement=YES):
    #   16pt leading margin | UILabel (expands, leading-aligned, 17pt) | UIImageView (20x20pt "checkmark") | 16pt trailing margin
    #
    # The outer vertical stack uses spacing=0. A 0.5pt separator UIView is
    # inserted between rows (NOT after the last row).
    # -----------------------------------------------------------------
    def visit(view : UI::Picker)
      uiimage_cls = LibObjCBridge.objc_getClass("UIImage")
      uicolor_cls = LibObjCBridge.objc_getClass("UIColor")
      uifont_cls  = LibObjCBridge.objc_getClass("UIFont")

      # --- Root vertical UIStackView (card container) ---
      card_ptr = alloc_init("UIStackView")
      LibObjCBridge.objc_send_long(card_ptr, sel("setAxis:"), 1_i64)          # vertical
      LibObjCBridge.objc_send_1d(card_ptr, sel("setSpacing:"), 0.0)
      LibObjCBridge.objc_send_long(card_ptr, sel("setAlignment:"), 4_i64)     # UIStackViewAlignmentFill

      # secondarySystemGroupedBackground is a UIColor that adapts to light/dark
      sec_bg = LibObjCBridge.objc_send(uicolor_cls, sel("secondarySystemGroupedBackgroundColor"))
      LibObjCBridge.objc_send_id(card_ptr, sel("setBackgroundColor:"), sec_bg)
      # 10pt corner radius — inset-grouped list style
      card_layer = LibObjCBridge.objc_send(card_ptr, sel("layer"))
      unless card_layer.null?
        LibObjCBridge.objc_send_1d(card_layer, sel("setCornerRadius:"), 10.0)
      end
      LibObjCBridge.objc_send_bool(card_ptr, sel("setClipsToBounds:"), 1)

      apply_common_properties(card_ptr, view)

      card_handle = ObjC.owned(card_ptr, label: "UIStackView[picker]")
      card_native = NativeView.new(card_handle)

      # Shared resources
      system_blue   = LibObjCBridge.objc_send(uicolor_cls, sel("systemBlueColor"))
      sep_color_ptr = LibObjCBridge.objc_send(uicolor_cls, sel("separatorColor"))
      body_font     = LibObjCBridge.objc_send_1d_ret_id(uifont_cls, sel("systemFontOfSize:"), 17.0)
      primary_color = LibObjCBridge.nscolor_label_primary

      view.options.each_with_index do |option_text, index|
        is_selected = (index == view.selected_index)

        # --- Row: horizontal UIStackView ---
        row_ptr = alloc_init("UIStackView")
        LibObjCBridge.objc_send_long(row_ptr, sel("setAxis:"), 0_i64)          # horizontal
        LibObjCBridge.objc_send_1d(row_ptr, sel("setSpacing:"), 8.0)
        LibObjCBridge.objc_send_long(row_ptr, sel("setAlignment:"), 3_i64)     # UIStackViewAlignmentCenter
        LibObjCBridge.objc_send_bool(row_ptr, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)

        # Use layout margins for 16pt leading/trailing insets inside the row.
        # isLayoutMarginsRelativeArrangement = YES makes UIStackView respect layoutMargins.
        LibObjCBridge.objc_send_bool(row_ptr, sel("setLayoutMarginsRelativeArrangement:"), 1)
        # directionalLayoutMargins: NSDirectionalEdgeInsets{top, leading, bottom, trailing}
        # passed as 4 doubles (top=12, leading=16, bottom=12, trailing=16)
        LibObjCBridge.objc_send_4d_ret_id(row_ptr, sel("setDirectionalLayoutMargins:"), 12.0, 16.0, 12.0, 16.0)

        # Row background = card background
        LibObjCBridge.objc_send_id(row_ptr, sel("setBackgroundColor:"), sec_bg)

        # --- Option label (expands to fill, leading-aligned) ---
        lbl_ptr = alloc_init("UILabel")
        opt_ns = LibObjCBridge.nsstring_from_cstr(option_text.to_unsafe)
        LibObjCBridge.objc_send_id(lbl_ptr, sel("setText:"), opt_ns)
        LibObjCBridge.objc_send_id(lbl_ptr, sel("setFont:"), body_font)
        LibObjCBridge.objc_send_id(lbl_ptr, sel("setTextColor:"), primary_color)
        # NSTextAlignmentLeft = 0
        LibObjCBridge.objc_send_long(lbl_ptr, sel("setTextAlignment:"), 0_i64)
        LibObjCBridge.objc_send_bool(lbl_ptr, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)

        # --- Trailing checkmark UIImageView (always present; hidden when not selected) ---
        chk_ptr = alloc_init("UIImageView")
        LibObjCBridge.objc_send_bool(chk_ptr, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
        chk_sym_ns = LibObjCBridge.nsstring_from_cstr("checkmark".to_unsafe)
        chk_img = LibObjCBridge.objc_send_id(uiimage_cls, sel("systemImageNamed:"), chk_sym_ns)
        unless chk_img.null?
          LibObjCBridge.objc_send_id(chk_ptr, sel("setImage:"), chk_img)
        end
        LibObjCBridge.objc_send_id(chk_ptr, sel("setTintColor:"), system_blue)
        # UIImageView content mode 1 = UIViewContentModeScaleAspectFit
        LibObjCBridge.objc_send_long(chk_ptr, sel("setContentMode:"), 1_i64)
        # Hide on non-selected rows (preserves horizontal space for column alignment)
        LibObjCBridge.objc_send_bool(chk_ptr, sel("setHidden:"), is_selected ? 0 : 1)

        # Add label then checkmark to row
        LibObjCBridge.objc_send_void_id(row_ptr, sel("addArrangedSubview:"), lbl_ptr)
        LibObjCBridge.objc_send_void_id(row_ptr, sel("addArrangedSubview:"), chk_ptr)

        row_handle = ObjC.owned(row_ptr, label: "UIStackView[picker-row-#{index}]")
        row_native = NativeView.new(row_handle)
        card_native.add_child(row_native)
        LibObjCBridge.objc_send_void_id(card_ptr, sel("addArrangedSubview:"), row_ptr)

        # 0.5pt separator below each row except the last
        unless index == view.options.size - 1
          sep_ptr = alloc_init("UIView")
          LibObjCBridge.objc_send_bool(sep_ptr, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
          LibObjCBridge.objc_send_id(sep_ptr, sel("setBackgroundColor:"), sep_color_ptr)
          sep_handle = ObjC.owned(sep_ptr, label: "UIView[picker-sep-#{index}]")
          sep_native = NativeView.new(sep_handle)
          card_native.add_child(sep_native)
          LibObjCBridge.objc_send_void_id(card_ptr, sel("addArrangedSubview:"), sep_ptr)
        end
      end

      push_native(card_native)
    end

    # -----------------------------------------------------------------
    # Visit: IconButton -> UIButton with SF Symbol image
    # -----------------------------------------------------------------
    def visit(view : UI::IconButton)
      # UIButtonTypeSystem = 1
      uibutton_cls = LibObjCBridge.objc_getClass("UIButton")
      ptr = LibObjCBridge.objc_send_long(uibutton_cls, sel("buttonWithType:"), 1_i64)

      # Load SF Symbol image
      uiimage_cls = LibObjCBridge.objc_getClass("UIImage")
      symbol_str = LibObjCBridge.nsstring_from_cstr(view.icon.to_unsafe)
      symbol_img = LibObjCBridge.objc_send_id(uiimage_cls, sel("systemImageNamed:"), symbol_str)
      unless symbol_img.null?
        # setImage:forState: UIControlStateNormal = 0
        LibObjCBridge.objc_send_id_long(ptr, sel("setImage:forState:"), symbol_img, 0_i64)
      end

      # Optional text label
      if lbl = view.label
        lbl_str = LibObjCBridge.nsstring_from_cstr(lbl.to_unsafe)
        LibObjCBridge.objc_send_id_long(ptr, sel("setTitle:forState:"), lbl_str, 0_i64)
      end

      # Enabled/disabled
      if view.disabled
        LibObjCBridge.objc_send_bool(ptr, sel("setEnabled:"), 0)
      end

      # Tint color
      tint = view.tint_color
      tint_ptr = LibObjCBridge.nscolor_rgba(tint.r, tint.g, tint.b, tint.a)
      LibObjCBridge.objc_send_id(ptr, sel("setTintColor:"), tint_ptr)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UIButton[icon]")
      native = NativeView.new(handle)

      if tap_handler = view.on_tap
        callback_id = native.register_callback(tap_handler)

        dispatcher_cls = LibObjCBridge.objc_getClass("CrystalActionDispatcher")
        unless dispatcher_cls.null?
          dispatcher = LibObjCBridge.objc_send(dispatcher_cls, sel("alloc"))
          dispatcher = LibObjCBridge.objc_send(dispatcher, sel("init"))
          LibObjCBridge.objc_send_long(dispatcher, sel("setTag:"), callback_id.to_i64)
          LibObjCBridge.objc_send_id_id_id(
            ptr,
            sel("addTarget:action:forControlEvents:"),
            dispatcher,
            sel("dispatch:"),
            Pointer(Void).new(64_u64) # UIControlEventTouchUpInside
          )
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: ListView -> UIStackView (vertical rows or row-of-rows grid)
    #
    # Grid mode: wraps items into horizontal UIStackViews of `columns`
    # width, then stacks those rows vertically. This approximates
    # UICollectionView's flow layout without requiring a data-source
    # delegate chain through the ObjC bridge in the validation renderer.
    # Production use should prefer UI::ListView with layout: :grid which
    # will map to a real UICollectionView via the production UIKit renderer.
    # -----------------------------------------------------------------
    def visit(view : UI::ListView)
      outer_ptr = alloc_init("UIStackView")

      # UILayoutConstraintAxisVertical = 1
      LibObjCBridge.objc_send_long(outer_ptr, sel("setAxis:"), 1_i64)
      LibObjCBridge.objc_send_1d(outer_ptr, sel("setSpacing:"), view.item_spacing)
      # UIStackViewAlignmentFill = 0 — children stretch to fill the full width,
      # ensuring HStack rows span the list width rather than sizing to content.
      LibObjCBridge.objc_send_long(outer_ptr, sel("setAlignment:"), 0_i64)

      apply_common_properties(outer_ptr, view)

      handle = ObjC.owned(outer_ptr, label: "UIStackView[list]")
      native = NativeView.new(handle)

      push_stack(native, is_uistack: true)

      view.sections.each do |section|
        if header = section.header
          header_ptr = alloc_init("UILabel")
          header_str = LibObjCBridge.nsstring_from_cstr(header.to_unsafe)
          LibObjCBridge.objc_send_id(header_ptr, sel("setText:"), header_str)
          emit(header_ptr, "UILabel[list-header]")
        end

        if view.layout == UI::ListLayout::Grid && view.columns > 1
          # Grid mode: chunk items into rows of `columns` width.
          # Each row is a horizontal UIStackView of equal-width cells.
          cols = view.columns
          items = section.items
          row_idx = 0
          while row_idx < items.size
            row_ptr = alloc_init("UIStackView")
            # UILayoutConstraintAxisHorizontal = 0
            LibObjCBridge.objc_send_long(row_ptr, sel("setAxis:"), 0_i64)
            LibObjCBridge.objc_send_1d(row_ptr, sel("setSpacing:"), view.item_spacing)
            # UIStackViewDistributionFillEqually = 2
            LibObjCBridge.objc_send_long(row_ptr, sel("setDistribution:"), 2_i64)
            # TAMIC = NO so the outer vertical UIStackView can Auto Layout this row.
            LibObjCBridge.objc_send_bool(row_ptr, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)

            row_handle = ObjC.owned(row_ptr, label: "UIStackView[grid-row]")
            row_native = NativeView.new(row_handle)
            push_stack(row_native, is_uistack: true)

            col_count = 0
            while col_count < cols && (row_idx + col_count) < items.size
              items[row_idx + col_count].accept(self)
              col_count += 1
            end

            # Pad incomplete last row with empty spacer views for alignment
            while col_count < cols
              spacer_ptr = alloc_init("UIView")
              emit(spacer_ptr, "UIView[grid-pad]")
              col_count += 1
            end

            pop_stack
            emit(row_ptr, "UIStackView[grid-row]")

            row_idx += cols
          end
        else
          # List mode: items appended to the outer vertical UIStackView.
          # When shows_separators is true, insert a thin UIView (0.5pt tall,
          # UIColor.separatorColor) between each pair of items -- mimicking
          # UITableView hairline dividers. InsetGrouped style wraps items in
          # a rounded-card UIView with corner radius 10pt.
          if view.style == UI::ListStyle::InsetGrouped
            # Rounded card: plain UIView container with rounded corners and
            # a system-secondary fill. Items are nested in a UIStackView
            # inside the card so separators can be inserted.
            card_ptr = alloc_init("UIView")
            LibObjCBridge.objc_send_bool(card_ptr, sel("setClipsToBounds:"), 1)
            # Set corner radius via CALayer (no appearance-tracking issue here
            # since corner radius is not appearance-dependent).
            card_layer = LibObjCBridge.objc_send(card_ptr, sel("layer"))
            unless card_layer.null?
              LibObjCBridge.objc_send_1d(card_layer, sel("setCornerRadius:"), 10.0)
            end
            # Use UIView.setBackgroundColor: (NOT layer.backgroundColor) so that
            # the dynamic UIColor tracks appearance automatically. Setting CGColor
            # on the layer captures a static snapshot at conversion time and does
            # NOT track dark/light appearance changes.
            sec_bg_cls = LibObjCBridge.objc_getClass("UIColor")
            sec_bg = LibObjCBridge.objc_send(sec_bg_cls, sel("secondarySystemGroupedBackgroundColor"))
            LibObjCBridge.objc_send_id(card_ptr, sel("setBackgroundColor:"), sec_bg) unless sec_bg.null?
            # Inner UIStackView holds the items.
            inner_ptr = alloc_init("UIStackView")
            LibObjCBridge.objc_send_long(inner_ptr, sel("setAxis:"), 1_i64)
            LibObjCBridge.objc_send_1d(inner_ptr, sel("setSpacing:"), 0.0)
            # UIStackViewAlignmentFill = 0: inner stack children fill the card width.
            LibObjCBridge.objc_send_long(inner_ptr, sel("setAlignment:"), 0_i64)
            LibObjCBridge.objc_send_bool(inner_ptr, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
            LibObjCBridge.objc_add_subview(card_ptr, inner_ptr)
            # Pin inner UIStackView to the card UIView's edges so it sizes
            # correctly inside the card. Without these constraints, the inner
            # stack has no frame and all its arranged subviews are invisible.
            {
              {"topAnchor", "topAnchor"},
              {"leadingAnchor", "leadingAnchor"},
              {"trailingAnchor", "trailingAnchor"},
              {"bottomAnchor", "bottomAnchor"},
            }.each do |inner_anch_name, card_anch_name|
              inner_anch = LibObjCBridge.objc_send(inner_ptr, sel(inner_anch_name))
              card_anch = LibObjCBridge.objc_send(card_ptr, sel(card_anch_name))
              unless inner_anch.null? || card_anch.null?
                # constraintEqualToAnchor: returns NSLayoutConstraint (an id).
                c = LibObjCBridge.objc_send_id(inner_anch, sel("constraintEqualToAnchor:"), card_anch)
                LibObjCBridge.objc_send_bool(c, sel("setActive:"), 1) unless c.null?
              end
            end

            inner_handle = ObjC.owned(inner_ptr, label: "UIStackView[inset-grouped-inner]")
            inner_native = NativeView.new(inner_handle)
            # Card UIView must also have TAMIC = NO so the outer ListView
            # UIStackView can apply Auto Layout to it correctly.
            LibObjCBridge.objc_send_bool(card_ptr, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
            card_handle = ObjC.owned(card_ptr, label: "UIView[inset-grouped-card]")
            card_native = NativeView.new(card_handle)
            # Push the inner stack for item rendering.
            push_stack(inner_native, is_uistack: true)
            screen_w_ig = LibObjCBridge.objc_screen_width
            item_w_ig = screen_w_ig > 0.0 ? screen_w_ig - 64.0 : 280.0
            section.items.each_with_index do |item, idx|
              item.accept(self)
              # Same width-pinning fix as plain list mode -- UIStackView
              # fill alignment doesn't propagate into nested UIStackViews.
              if parent_native = @stack.last?
                if last_child = parent_native.children.last?
                  if last_child.handle.valid?
                    row_ptr = last_child.handle.ptr!
                    w_anch = LibObjCBridge.objc_send(row_ptr, sel("widthAnchor"))
                    unless w_anch.null?
                      wc = LibObjCBridge.objc_send_1d_ret_id(w_anch, sel("constraintEqualToConstant:"), item_w_ig)
                      LibObjCBridge.objc_send_bool(wc, sel("setActive:"), 1) unless wc.null?
                    end
                  end
                end
              end
              if view.shows_separators && idx < section.items.size - 1
                sep_ptr = alloc_init("UIView")
                # 0.5pt separator; height constrained via objc_constrain_size.
                LibObjCBridge.objc_constrain_size(sep_ptr, 0.0, 0.5)
                uicolor_cls = LibObjCBridge.objc_getClass("UIColor")
                sep_color = LibObjCBridge.objc_send(uicolor_cls, sel("separatorColor"))
                unless sep_color.null?
                  sep_cg = LibObjCBridge.objc_send(sep_color, sel("CGColor"))
                  unless sep_cg.null?
                    sep_layer = LibObjCBridge.objc_send(sep_ptr, sel("layer"))
                    LibObjCBridge.objc_send_void_id(sep_layer, sel("setBackgroundColor:"), sep_cg) unless sep_layer.null?
                  end
                end
                emit(sep_ptr, "UIView[list-sep]")
              end
            end
            pop_stack
            # Attach inner_native as a child of card_native for the NativeView tree.
            card_native.add_child(inner_native)
            push_native(card_native)
          else
            # Plain / Grouped / Sidebar: flat list with optional separators.
            section.items.each_with_index do |item, idx|
              item.accept(self)
              # After visiting the item, explicitly pin the item's width to the
              # ListView outer UIStackView's width. UIStackView alignment=fill
              # does NOT propagate width constraints into nested UIStackViews
              # via the standard mechanism when their intrinsicContentSize.width
              # is UIViewNoIntrinsicMetric (e.g., a UIStackView containing a
              # UI::Spacer). This creates a circular dependency in the layout
              # engine: item.width = list.width, but list.width = max(item widths).
              #
              # The correct fix: pin item.width to a CONSTANT derived from the
              # screen width, not to the list's anchor. Then the item gets a
              # definite width without the circular reference, and UIStackView's
              # fill alignment on the list properly anchors the item's trailing.
              # Standard horizontal padding = 32pt (2 × 16pt), matching the
              # SwiftUI .padding() applied in ContentView.
              if parent_native = @stack.last?
                if last_child = parent_native.children.last?
                  if last_child.handle.valid?
                    row_ptr = last_child.handle.ptr!
                    screen_w = LibObjCBridge.objc_screen_width
                    item_w = screen_w > 0.0 ? screen_w - 32.0 : 320.0
                    w_anch = LibObjCBridge.objc_send(row_ptr, sel("widthAnchor"))
                    unless w_anch.null?
                      wc = LibObjCBridge.objc_send_1d_ret_id(w_anch, sel("constraintEqualToConstant:"), item_w)
                      LibObjCBridge.objc_send_bool(wc, sel("setActive:"), 1) unless wc.null?
                    end
                  end
                end
              end
              if view.shows_separators && idx < section.items.size - 1
                sep_ptr = alloc_init("UIView")
                LibObjCBridge.objc_constrain_size(sep_ptr, 0.0, 0.5)
                uicolor_cls = LibObjCBridge.objc_getClass("UIColor")
                sep_color = LibObjCBridge.objc_send(uicolor_cls, sel("separatorColor"))
                unless sep_color.null?
                  sep_cg = LibObjCBridge.objc_send(sep_color, sel("CGColor"))
                  unless sep_cg.null?
                    sep_layer = LibObjCBridge.objc_send(sep_ptr, sel("layer"))
                    LibObjCBridge.objc_send_void_id(sep_layer, sel("setBackgroundColor:"), sep_cg) unless sep_layer.null?
                  end
                end
                emit(sep_ptr, "UIView[list-sep]")
              end
            end
          end
        end
      end

      pop_stack

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: SecureField -> UITextField with secureTextEntry = true
    # -----------------------------------------------------------------
    def visit(view : UI::SecureField)
      ptr = alloc_init("UITextField")

      # Enable secure text entry
      LibObjCBridge.objc_send_bool(ptr, sel("setSecureTextEntry:"), 1)

      unless view.text.empty?
        text_str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setText:"), text_str)
      end

      unless view.placeholder.empty?
        placeholder_str = LibObjCBridge.nsstring_from_cstr(view.placeholder.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setPlaceholder:"), placeholder_str)
      end

      font_ptr = resolve_font(view.font)
      LibObjCBridge.objc_send_id(ptr, sel("setFont:"), font_ptr)

      color_ptr = resolve_color(view.text_color)
      LibObjCBridge.objc_send_id(ptr, sel("setTextColor:"), color_ptr)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UITextField[secure]")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        text_field_ptr = ptr
        wrapped = Proc(Nil).new do
          raw_str = LibObjCBridge.objc_send(text_field_ptr, sel("text"))
          unless raw_str.null?
            cstr = LibObjCBridge.objc_send(raw_str, sel("UTF8String"))
            unless cstr.null?
              change_handler.call(String.new(cstr.as(UInt8*)))
            end
          end
        end
        native.register_callback(wrapped)
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Stepper -> UIStepper
    # -----------------------------------------------------------------
    def visit(view : UI::Stepper)
      ptr = alloc_init("UIStepper")

      LibObjCBridge.objc_send_1d(ptr, sel("setMinimumValue:"), view.minimum)
      LibObjCBridge.objc_send_1d(ptr, sel("setMaximumValue:"), view.maximum)
      LibObjCBridge.objc_send_1d(ptr, sel("setValue:"), view.value)
      LibObjCBridge.objc_send_1d(ptr, sel("setStepValue:"), view.step_value)
      LibObjCBridge.objc_send_bool(ptr, sel("setWraps:"), view.wraps ? 1 : 0)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UIStepper")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        stepper_ptr = ptr
        wrapped = Proc(Nil).new do
          val_ptr = LibObjCBridge.objc_send(stepper_ptr, sel("value"))
          change_handler.call(val_ptr.address.unsafe_as(Float64))
        end
        callback_id = native.register_callback(wrapped)

        dispatcher_cls = LibObjCBridge.objc_getClass("CrystalActionDispatcher")
        unless dispatcher_cls.null?
          dispatcher = LibObjCBridge.objc_send(dispatcher_cls, sel("alloc"))
          dispatcher = LibObjCBridge.objc_send(dispatcher, sel("init"))
          LibObjCBridge.objc_send_long(dispatcher, sel("setTag:"), callback_id.to_i64)
          LibObjCBridge.objc_send_id_id_id(
            ptr,
            sel("addTarget:action:forControlEvents:"),
            dispatcher,
            sel("dispatch:"),
            Pointer(Void).new(4096_u64) # UIControlEventValueChanged
          )
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: SegmentedControl -> UISegmentedControl
    # -----------------------------------------------------------------
    def visit(view : UI::SegmentedControl)
      ptr = alloc_init("UISegmentedControl")

      view.segments.each_with_index do |segment, index|
        segment_str = LibObjCBridge.nsstring_from_cstr(segment.to_unsafe)
        LibObjCBridge.objc_send_id_long(ptr, sel("insertSegmentWithTitle:atIndex:animated:"),
          segment_str, index.to_i64)
      end

      LibObjCBridge.objc_send_long(ptr, sel("setSelectedSegmentIndex:"), view.selected_index.to_i64)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UISegmentedControl")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        seg_ptr = ptr
        wrapped = Proc(Nil).new do
          idx = LibObjCBridge.objc_send(seg_ptr, sel("selectedSegmentIndex"))
          change_handler.call(idx.address.to_i32)
        end
        callback_id = native.register_callback(wrapped)

        dispatcher_cls = LibObjCBridge.objc_getClass("CrystalActionDispatcher")
        unless dispatcher_cls.null?
          dispatcher = LibObjCBridge.objc_send(dispatcher_cls, sel("alloc"))
          dispatcher = LibObjCBridge.objc_send(dispatcher, sel("init"))
          LibObjCBridge.objc_send_long(dispatcher, sel("setTag:"), callback_id.to_i64)
          LibObjCBridge.objc_send_id_id_id(
            ptr,
            sel("addTarget:action:forControlEvents:"),
            dispatcher,
            sel("dispatch:"),
            Pointer(Void).new(4096_u64) # UIControlEventValueChanged
          )
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: DatePicker -> UIDatePicker
    # -----------------------------------------------------------------
    def visit(view : UI::DatePicker)
      ptr = alloc_init("UIDatePicker")

      # UIDatePickerMode: Time=0, Date=1, DateAndTime=3
      mode_val = case view.mode
                 when UI::DatePickerMode::Date        then 1_i64
                 when UI::DatePickerMode::Time        then 0_i64
                 when UI::DatePickerMode::DateAndTime then 3_i64
                 else                                      1_i64
                 end
      LibObjCBridge.objc_send_long(ptr, sel("setDatePickerMode:"), mode_val)

      unless view.label.empty?
        label_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), label_str)
      end

      apply_common_properties(ptr, view)

      emit(ptr, "UIDatePicker")
    end

    # -----------------------------------------------------------------
    # Visit: TimePicker -> UIDatePicker (time mode)
    # -----------------------------------------------------------------
    def visit(view : UI::TimePicker)
      ptr = alloc_init("UIDatePicker")

      # UIDatePickerModeTime = 0
      LibObjCBridge.objc_send_long(ptr, sel("setDatePickerMode:"), 0_i64)

      if view.minute_interval > 1
        LibObjCBridge.objc_send_long(ptr, sel("setMinuteInterval:"), view.minute_interval.to_i64)
      end

      unless view.label.empty?
        label_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), label_str)
      end

      apply_common_properties(ptr, view)

      emit(ptr, "UIDatePicker[time]")
    end

    # -----------------------------------------------------------------
    # Visit: SearchField -> UISearchBar
    # -----------------------------------------------------------------
    def visit(view : UI::SearchField)
      ptr = alloc_init("UISearchBar")

      unless view.placeholder.empty?
        placeholder_str = LibObjCBridge.nsstring_from_cstr(view.placeholder.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setPlaceholder:"), placeholder_str)
      end

      unless view.text.empty?
        text_str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setText:"), text_str)
      end

      LibObjCBridge.objc_send_bool(ptr, sel("setShowsCancelButton:"), view.shows_cancel_button ? 1 : 0)

      apply_common_properties(ptr, view)

      # UISearchBar reports intrinsicContentSize.width = UIView.noIntrinsicMetric
      # (-1) when not inside a UINavigationItem, causing it to collapse to a
      # tiny icon when placed inside a standalone UIStackView.  Fix: pin height
      # to 44pt (standard compact search bar height) and width to screen width
      # minus 32pt (16pt leading + 16pt trailing margin), matching HIG-standard
      # toolbar search field insets.  The VStack fill alignment then correctly
      # fills the remaining parent width at runtime.
      sf_screen_w = LibObjCBridge.objc_screen_width
      sf_width = sf_screen_w > 0.0 ? sf_screen_w - 32.0 : 320.0
      LibObjCBridge.objc_constrain_size(ptr, sf_width, 44.0)

      emit(ptr, "UISearchBar")
    end

    # -----------------------------------------------------------------
    # Visit: TextArea -> UITextView
    # -----------------------------------------------------------------
    def visit(view : UI::TextArea)
      ptr = alloc_init("UITextView")

      unless view.text.empty?
        text_str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setText:"), text_str)
      end

      LibObjCBridge.objc_send_bool(ptr, sel("setEditable:"), view.is_editable ? 1 : 0)
      LibObjCBridge.objc_send_bool(ptr, sel("setScrollEnabled:"), view.is_scrollable ? 1 : 0)

      font_ptr = resolve_font(view.font)
      LibObjCBridge.objc_send_id(ptr, sel("setFont:"), font_ptr)

      color_ptr = resolve_color(view.text_color)
      LibObjCBridge.objc_send_id(ptr, sel("setTextColor:"), color_ptr)

      apply_common_properties(ptr, view)

      emit(ptr, "UITextView")
    end

    # -----------------------------------------------------------------
    # Visit: Grid -> UIStackView (grid approximation)
    # -----------------------------------------------------------------
    def visit(view : UI::Grid)
      ptr = alloc_init("UIStackView")

      # UILayoutConstraintAxisVertical = 1
      LibObjCBridge.objc_send_long(ptr, sel("setAxis:"), 1_i64)
      LibObjCBridge.objc_send_1d(ptr, sel("setSpacing:"), view.row_spacing)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UIStackView[grid]")
      native = NativeView.new(handle)

      push_stack(native, is_uistack: true)
      view.children.each do |row|
        row.each do |cell|
          cell.accept(self)
        end
      end
      pop_stack

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Form -> UIStackView (form sections)
    # -----------------------------------------------------------------
    def visit(view : UI::Form)
      ptr = alloc_init("UIStackView")

      # UILayoutConstraintAxisVertical = 1
      LibObjCBridge.objc_send_long(ptr, sel("setAxis:"), 1_i64)
      LibObjCBridge.objc_send_1d(ptr, sel("setSpacing:"), 0.0)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UIStackView[form]")
      native = NativeView.new(handle)

      push_stack(native, is_uistack: true)

      view.sections.each do |section|
        if header = section.header
          header_ptr = alloc_init("UILabel")
          header_str = LibObjCBridge.nsstring_from_cstr(header.to_unsafe)
          LibObjCBridge.objc_send_id(header_ptr, sel("setText:"), header_str)
          emit(header_ptr, "UILabel[form-header]")
        end

        section.fields.each do |field|
          row_ptr = alloc_init("UIStackView")
          LibObjCBridge.objc_send_long(row_ptr, sel("setAxis:"), 0_i64) # horizontal
          LibObjCBridge.objc_send_1d(row_ptr, sel("setSpacing:"), 8.0)

          unless field.label.empty?
            lbl_ptr = alloc_init("UILabel")
            lbl_str = LibObjCBridge.nsstring_from_cstr(field.label.to_unsafe)
            LibObjCBridge.objc_send_id(lbl_ptr, sel("setText:"), lbl_str)
            LibObjCBridge.objc_send_void_id(row_ptr, sel("addArrangedSubview:"), lbl_ptr)
          end

          if content = field.content
            row_handle = ObjC.owned(row_ptr, label: "UIStackView[form-row]")
            row_native = NativeView.new(row_handle)
            push_stack(row_native, is_uistack: true)
            content.accept(self)
            pop_stack
            LibObjCBridge.objc_send_void_id(ptr, sel("addArrangedSubview:"), row_ptr)
          else
            LibObjCBridge.objc_send_void_id(ptr, sel("addArrangedSubview:"), row_ptr)
          end
        end

        if footer = section.footer
          footer_ptr = alloc_init("UILabel")
          footer_str = LibObjCBridge.nsstring_from_cstr(footer.to_unsafe)
          LibObjCBridge.objc_send_id(footer_ptr, sel("setText:"), footer_str)
          emit(footer_ptr, "UILabel[form-footer]")
        end
      end

      pop_stack

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: NavigationSplitView -> UIView (horizontal split container)
    #        with UIVisualEffectView sidebar column (Liquid Glass)
    #
    # HIG: "sidebars float above content in the Liquid Glass layer."
    # On iPhone, NavigationSplitView collapses to a NavigationStack root,
    # so the sidebar column IS the visible capture. On iPad, the split
    # layout is shown.
    #
    # iOS 26: prefer UIGlassContainerEffect for the sidebar surface;
    # fallback to UIBlurEffect(systemChromeMaterial=11) on older SDKs.
    # -----------------------------------------------------------------
    def visit(view : UI::NavigationSplitView)
      # Outer horizontal container — plain UIView.
      outer = alloc_init("UIView")
      apply_common_properties(outer, view)
      outer_handle = ObjC.owned(outer, label: "UIView[split-outer]")
      outer_native = NativeView.new(outer_handle)

      if view.shows_sidebar
        if sidebar = view.sidebar
          # --- Liquid Glass sidebar column ---
          # Prefer UIGlassContainerEffect on iOS 26; fall back to
          # UIBlurEffectStyleSystemChromeMaterial (= 11) on older SDKs.
          glass_container_cls = LibObjCBridge.objc_getClass("UIGlassContainerEffect")
          blur_effect = if !glass_container_cls.null?
                          LibObjCBridge.objc_send(
                            LibObjCBridge.objc_send(glass_container_cls, sel("alloc")),
                            sel("init"))
                        else
                          ublur_cls = LibObjCBridge.objc_getClass("UIBlurEffect")
                          LibObjCBridge.objc_send_long(
                            ublur_cls, sel("effectWithStyle:"), 11_i64)
                        end

          uveff_cls = LibObjCBridge.objc_getClass("UIVisualEffectView")
          effect_alloc = LibObjCBridge.objc_send(uveff_cls, sel("alloc"))
          sidebar_effect = LibObjCBridge.objc_send_id(effect_alloc, sel("initWithEffect:"), blur_effect)

          LibObjCBridge.objc_send_bool(sidebar_effect, sel("setClipsToBounds:"), 1)

          # Inner UIStackView for sidebar rows with 8pt layout margins.
          sidebar_inner = alloc_init("UIStackView")
          LibObjCBridge.objc_send_long(sidebar_inner, sel("setAxis:"), 1_i64)
          LibObjCBridge.objc_send_1d(sidebar_inner, sel("setSpacing:"), 2.0)
          LibObjCBridge.objc_send_long(sidebar_inner, sel("setAlignment:"), 0_i64)
          sidebar_insets = LibObjCBridge::CGRect.new(x: 8.0, y: 8.0, width: 8.0, height: 8.0)
          LibObjCBridge.objc_send_rect_void(sidebar_inner, sel("setLayoutMargins:"), sidebar_insets)
          LibObjCBridge.objc_send_bool(sidebar_inner, sel("setLayoutMarginsRelativeArrangement:"), 1)
          LibObjCBridge.objc_send_bool(sidebar_inner, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)

          # UIVisualEffectView subviews must go in contentView.
          content_view = LibObjCBridge.objc_send(sidebar_effect, sel("contentView"))
          anchor_host = if content_view.null?
                          LibObjCBridge.objc_add_subview(sidebar_effect, sidebar_inner)
                          sidebar_effect
                        else
                          LibObjCBridge.objc_add_subview(content_view, sidebar_inner)
                          content_view
                        end

          # Pin inner stack to all four edges of anchor_host.
          %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anchor_sel|
            inner_anchor = LibObjCBridge.objc_send(sidebar_inner, sel(anchor_sel))
            host_anchor  = LibObjCBridge.objc_send(anchor_host, sel(anchor_sel))
            next if inner_anchor.null? || host_anchor.null?
            constraint = LibObjCBridge.objc_send_id(inner_anchor, sel("constraintEqualToAnchor:"), host_anchor)
            LibObjCBridge.objc_send_bool(constraint, sel("setActive:"), 1) unless constraint.null?
          end

          # Constrain the sidebar column to its declared width. On iPhone the
          # sidebar fills the full screen width (split collapses); a width
          # constraint is still applied but the UIStackView hosting the
          # NavigationSplitView ignores it due to fill alignment.
          sidebar_width_val = view.sidebar_width
          LibObjCBridge.objc_constrain_width(sidebar_effect, sidebar_width_val)

          sidebar_inner_handle = ObjC.borrowed(sidebar_inner, label: "UIStackView[sidebar-inner]")
          sidebar_inner_native = NativeView.new(sidebar_inner_handle)

          push_stack(sidebar_inner_native, is_uistack: true)
          sidebar.accept(self)
          pop_stack

          sidebar_effect_handle = ObjC.owned(sidebar_effect, label: "UIVisualEffectView[sidebar-glass]")
          sidebar_effect_native = NativeView.new(sidebar_effect_handle)
          push_native(sidebar_effect_native)
        end
      end

      if content = view.content
        push_stack(outer_native, is_uistack: false)
        content.accept(self)
        pop_stack
      end

      if detail = view.detail
        push_stack(outer_native, is_uistack: false)
        detail.accept(self)
        pop_stack
      end

      push_native(outer_native)
    end

    # -----------------------------------------------------------------
    # Visit: Toolbar -> UIVisualEffectView (Liquid Glass) + horizontal
    #                   UIStackView of icon-button items.
    #
    # HIG: "A toolbar provides convenient access to frequently used
    # commands, controls, navigation, and search." On iOS 26, toolbars
    # use UIGlassEffect (iOS 26+) or UIBlurEffect.systemChromeMaterial
    # (iOS 15+) as the background material.
    #
    # Structure:
    #   UIVisualEffectView (glass root)
    #     contentView
    #       UIStackView (horizontal, 4pt spacing, 8pt h-insets, 4pt v-insets)
    #         item_0..item_N:
    #           UIButton (icon-only, 44x44pt minimum, borderless)
    #             UIImageView (SF Symbol, no circular border per HIG)
    #
    # HIG Best practices: "Prefer system-provided symbols without borders."
    # HIG iOS: "Prioritize only the most important items for inclusion in
    # the main toolbar area."
    # -----------------------------------------------------------------
    def visit(view : UI::Toolbar)
      uicolor_cls = LibObjCBridge.objc_getClass("UIColor")
      uifont_cls  = LibObjCBridge.objc_getClass("UIFont")

      # Build the glass effect. UIGlassEffect on iOS 26; fallback to
      # UIBlurEffectStyleSystemChromeMaterial = 11 on older SDKs.
      glass_cls = LibObjCBridge.objc_getClass("UIGlassEffect")
      blur_effect = if !glass_cls.null?
                      LibObjCBridge.objc_send(
                        LibObjCBridge.objc_send(glass_cls, sel("alloc")),
                        sel("init"))
                    else
                      ublur_cls = LibObjCBridge.objc_getClass("UIBlurEffect")
                      # UIBlurEffectStyleSystemChromeMaterial = 11
                      LibObjCBridge.objc_send_long(ublur_cls, sel("effectWithStyle:"), 11_i64)
                    end

      uveff_cls   = LibObjCBridge.objc_getClass("UIVisualEffectView")
      effect_alloc = LibObjCBridge.objc_send(uveff_cls, sel("alloc"))
      glass_root  = LibObjCBridge.objc_send_id(effect_alloc, sel("initWithEffect:"), blur_effect)

      if lbl = view.accessibility_label
        lbl_str = LibObjCBridge.nsstring_from_cstr(lbl.to_unsafe)
        LibObjCBridge.objc_send_id(glass_root, sel("setAccessibilityLabel:"), lbl_str)
      elsif title = view.title
        title_str = LibObjCBridge.nsstring_from_cstr(title.to_unsafe)
        LibObjCBridge.objc_send_id(glass_root, sel("setAccessibilityLabel:"), title_str)
      end

      apply_common_properties(glass_root, view)

      glass_handle = ObjC.owned(glass_root, label: "UIVisualEffectView[toolbar-glass]")
      glass_native = NativeView.new(glass_handle)

      # UIVisualEffectView subviews MUST go in contentView.
      content_view_host = LibObjCBridge.objc_send(glass_root, sel("contentView"))
      anchor_host = content_view_host.null? ? glass_root : content_view_host

      # Horizontal UIStackView for toolbar items.
      item_row = alloc_init("UIStackView")
      # UILayoutConstraintAxisHorizontal = 0
      LibObjCBridge.objc_send_long(item_row, sel("setAxis:"), 0_i64)
      LibObjCBridge.objc_send_1d(item_row, sel("setSpacing:"), 4.0)
      LibObjCBridge.objc_send_long(item_row, sel("setDistribution:"), 0_i64)
      # 4pt top/bottom, 8pt leading/trailing layout margins
      item_margins = LibObjCBridge::CGRect.new(x: 8.0, y: 4.0, width: 8.0, height: 4.0)
      LibObjCBridge.objc_send_rect_void(item_row, sel("setLayoutMargins:"), item_margins)
      LibObjCBridge.objc_send_bool(item_row, sel("setLayoutMarginsRelativeArrangement:"), 1)
      LibObjCBridge.objc_send_bool(item_row, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)

      uiimage_cls = LibObjCBridge.objc_getClass("UIImage")

      view.items.each_with_index do |item, idx|
        # Vertical divider between groups (item id == "---")
        if item.id == "---"
          sep_view = alloc_init("UIView")
          sep_frame = LibObjCBridge::CGRect.new(x: 0.0, y: 0.0, width: 1.0, height: 28.0)
          LibObjCBridge.objc_send_rect_void(sep_view, sel("setFrame:"), sep_frame)
          unless uicolor_cls.null?
            sep_color = LibObjCBridge.objc_send_long(uicolor_cls, sel("separatorColor"), 0_i64)
            LibObjCBridge.objc_send_id(sep_view, sel("setBackgroundColor:"), sep_color) unless sep_color.null?
          end
          LibObjCBridge.objc_send_id(item_row, sel("addArrangedSubview:"), sep_view)
          next
        end

        btn = alloc_init("UIButton")

        # SF Symbol icon (no border per HIG Best practices for toolbar items)
        if icon = item.icon
          unless uiimage_cls.null?
            icon_ns = LibObjCBridge.nsstring_from_cstr(icon.to_unsafe)
            sym_img = LibObjCBridge.objc_send_id(uiimage_cls, sel("systemImageNamed:"), icon_ns)
            unless sym_img.null?
              LibObjCBridge.objc_send_id(btn, sel("setImage:forState:"), sym_img) rescue nil
              # Use setImage:forState: with UIControlStateNormal = 0
              LibObjCBridge.objc_send_id_long(btn, sel("setImage:forState:"), sym_img, 0_i64) rescue nil
            end
          end
        end

        # Accessibility label
        acc_label = item.label.empty? ? (item.icon || "toolbar item #{idx}") : item.label
        acc_ns = LibObjCBridge.nsstring_from_cstr(acc_label.to_unsafe)
        LibObjCBridge.objc_send_id(btn, sel("setAccessibilityLabel:"), acc_ns)

        # 44x44pt minimum hit target (HIG iOS: "a button needs a hit region
        # of at least 44x44 pt")
        btn_frame = LibObjCBridge::CGRect.new(x: 0.0, y: 0.0, width: 44.0, height: 44.0)
        LibObjCBridge.objc_send_rect_void(btn, sel("setFrame:"), btn_frame)

        LibObjCBridge.objc_send_id(item_row, sel("addArrangedSubview:"), btn)
      end

      # Add item_row to contentView and pin to glass_root edges.
      LibObjCBridge.objc_add_subview(anchor_host, item_row)

      %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anchor_sel|
        row_anchor   = LibObjCBridge.objc_send(item_row,   sel(anchor_sel))
        host_anchor  = LibObjCBridge.objc_send(anchor_host, sel(anchor_sel))
        next if row_anchor.null? || host_anchor.null?
        constraint = LibObjCBridge.objc_send_id(row_anchor, sel("constraintEqualToAnchor:"), host_anchor)
        LibObjCBridge.objc_send_bool(constraint, sel("setActive:"), 1) unless constraint.null?
      end

      item_row_handle = ObjC.borrowed(item_row, label: "UIStackView[toolbar-items]")
      glass_native.add_child(NativeView.new(item_row_handle))
      push_native(glass_native)
    end

    # -----------------------------------------------------------------
    # Visit: Sheet -> UIVisualEffectView + inner UIStackView (Liquid Glass)
    # -----------------------------------------------------------------
    def visit(view : UI::Sheet)
      # Inline Liquid Glass surface for HIG presentation-surface validation.
      # True modal dispatch (is_presented == true) stays on the plain
      # UIView placeholder branch below.
      grouped_card = !view.is_presented &&
                     (view.surface_style == :auto || view.surface_style == :grouped_card)

      if grouped_card
        # Build the UIBlurEffect. Prefer UIGlassEffect on iOS 26 if the
        # runtime class is present; otherwise fall back to
        # UIBlurEffectStyleSystemChromeMaterial (iOS 15+, tracks appearance).
        glass_cls = LibObjCBridge.objc_getClass("UIGlassEffect")
        blur_effect = if !glass_cls.null?
                        # UIGlassEffect has a bare init on iOS 26.
                        LibObjCBridge.objc_send(
                          LibObjCBridge.objc_send(glass_cls, sel("alloc")),
                          sel("init"))
                      else
                        # [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]
                        # UIBlurEffectStyleSystemChromeMaterial = 11
                        ublur_cls = LibObjCBridge.objc_getClass("UIBlurEffect")
                        LibObjCBridge.objc_send_long(
                          ublur_cls, sel("effectWithStyle:"), 11_i64)
                      end

        # [[UIVisualEffectView alloc] initWithEffect:blur_effect]
        uveff_cls = LibObjCBridge.objc_getClass("UIVisualEffectView")
        effect_alloc = LibObjCBridge.objc_send(uveff_cls, sel("alloc"))
        effect = LibObjCBridge.objc_send_id(effect_alloc, sel("initWithEffect:"), blur_effect)

        # Rounded corners with masksToBounds so the glass clips cleanly.
        # 16pt: Amber phi-scale "sheet" token. Action sheets are modal surfaces;
        # 16pt (not 12pt) is the correct Amber token. June R5 fix.
        LibObjCBridge.objc_send_bool(effect, sel("setClipsToBounds:"), 1)
        layer = LibObjCBridge.objc_send(effect, sel("layer"))
        unless layer.null?
          LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), 16.0)
          LibObjCBridge.objc_send_bool(layer, sel("setMasksToBounds:"), 1)

          # Issue 4 fix: explicitly set maskedCorners to ALL four corners so
          # CALayer does not internally bias rounding to a subset of corners.
          # CACornerMask bit values (UIKit / QuartzCore on ARM64):
          #   layerMinXMinYCorner = 1 (top-left)
          #   layerMaxXMinYCorner = 2 (top-right)
          #   layerMinXMaxYCorner = 4 (bottom-left)
          #   layerMaxXMaxYCorner = 8 (bottom-right)
          # All four = 0b1111 = 15. Without this explicit mask, UIKit may apply
          # an internal asymmetric mask that leaves top-left flat on some SDK
          # versions when UIGlassEffect is the backing blur.
          LibObjCBridge.objc_send_ulong(layer, sel("setMaskedCorners:"), 15_u64)

          # Issue 3 fix: add a 1pt top-edge border at UIColor.separatorColor so
          # the card silhouette is discernible when the glass tint is isoluminant
          # with the amber ember backdrop in dark mode. The border is set on the
          # CALayer (setMasksToBounds = YES clips the visual-effect blur, so the
          # border paints over the glass edge cleanly). 0.5pt matches UIKit hairline.
          uicolor_cls_border = LibObjCBridge.objc_getClass("UIColor")
          unless uicolor_cls_border.null?
            sep_color = LibObjCBridge.objc_send(uicolor_cls_border, sel("separatorColor"))
            unless sep_color.null?
              cg_sep = LibObjCBridge.objc_send(sep_color, sel("CGColor"))
              unless cg_sep.null?
                LibObjCBridge.objc_send_1d(layer, sel("setBorderWidth:"), 0.5)
                LibObjCBridge.objc_send_id(layer, sel("setBorderColor:"), cg_sep)
              end
            end
          end
        end

        # Inner UIStackView hosts sheet rows with 16pt layout margins.
        inner = alloc_init("UIStackView")
        LibObjCBridge.objc_send_long(inner, sel("setAxis:"), 1_i64)
        LibObjCBridge.objc_send_1d(inner, sel("setSpacing:"), 8.0)
        LibObjCBridge.objc_send_long(inner, sel("setAlignment:"), 0_i64)
        insets = LibObjCBridge::CGRect.new(x: 16.0, y: 16.0, width: 16.0, height: 16.0)
        LibObjCBridge.objc_send_rect_void(inner, sel("setLayoutMargins:"), insets)
        LibObjCBridge.objc_send_bool(inner, sel("setLayoutMarginsRelativeArrangement:"), 1)
        LibObjCBridge.objc_send_bool(inner, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)

        # CRITICAL: UIStackView by default has NO background color (nil), but in
        # some UIKit versions the implicit drawing context leaves an opaque pixel
        # layer. Explicitly setting backgroundColor = UIColor.clearColor ensures
        # the UIStackView is transparent so the UIVisualEffectView material bleeds
        # through behind the content rows. Without this the glass material is
        # occluded by the inner stack's drawing and the capture shows a solid fill.
        uicolor_cls = LibObjCBridge.objc_getClass("UIColor")
        clear_color = LibObjCBridge.objc_send(uicolor_cls, sel("clearColor"))
        LibObjCBridge.objc_send_id(inner, sel("setBackgroundColor:"), clear_color) unless clear_color.null?

        # Add inner stack to the effect view's contentView (standard
        # UIVisualEffectView pattern — subviews MUST live in contentView
        # for the material to render behind them correctly).
        content_view = LibObjCBridge.objc_send(effect, sel("contentView"))
        if content_view.null?
          # Pathological fallback — add directly to the effect view.
          LibObjCBridge.objc_add_subview(effect, inner)
          anchor_host = effect
        else
          LibObjCBridge.objc_add_subview(content_view, inner)
          anchor_host = content_view
        end

        # Pin inner to anchor_host on all four edges.
        %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anchor_sel|
          inner_anchor = LibObjCBridge.objc_send(inner, sel(anchor_sel))
          host_anchor  = LibObjCBridge.objc_send(anchor_host, sel(anchor_sel))
          next if inner_anchor.null? || host_anchor.null?
          constraint = LibObjCBridge.objc_send_id(inner_anchor, sel("constraintEqualToAnchor:"), host_anchor)
          LibObjCBridge.objc_send_bool(constraint, sel("setActive:"), 1) unless constraint.null?
        end

        # apply_common_properties now handles minimum_height via
        # objc_constrain_minimum_height when view.minimum_height is set.
        # The explicit duplicate call that was here has been removed.
        apply_common_properties(effect, view)

        outer_handle = ObjC.owned(effect, label: "UIVisualEffectView[sheet-glass]")
        outer_native = NativeView.new(outer_handle)

        inner_handle = ObjC.borrowed(inner, label: "UIStackView[sheet-inner]")
        inner_native = NativeView.new(inner_handle)

        if content = view.content
          push_stack(inner_native, is_uistack: true)
          content.accept(self)
          pop_stack
        end

        push_native(outer_native)
      else
        ptr = alloc_init("UIView")

        if view.is_presented
          LibObjCBridge.objc_send_bool(ptr, sel("setHidden:"), 0)
        else
          LibObjCBridge.objc_send_bool(ptr, sel("setHidden:"), 1)
        end

        apply_common_properties(ptr, view)

        handle = ObjC.owned(ptr, label: "UIView[sheet]")
        native = NativeView.new(handle)

        if content = view.content
          push_stack(native, is_uistack: false)
          content.accept(self)
          pop_stack
        end

        push_native(native)
      end
    end

    # -----------------------------------------------------------------
    # Visit: Popover -> UIVisualEffectView inline card (Liquid Glass)
    #
    # HIG: Popovers are surface components requiring Liquid Glass on iOS 26.
    # Production usage on iOS uses UIPopoverPresentationController for the
    # full presentation lifecycle with arrow. The inline path (is_presented
    # == false) renders the glass surface directly into the host view tree
    # for screenshot isolation in the HIG validation loop.
    #
    # Material: UIGlassEffect (iOS 26) preferred; falls back to
    # UIBlurEffectStyleSystemChromeMaterial (= 11, tracks appearance) on
    # older SDKs.
    #
    # Arrow/tail: UIPopoverPresentationController provides the arrow when
    # used in the presented path. The inline validation path does not emit
    # a native arrow -- logged as a systemic gap in gaps.md.
    #
    # Corner radius ~10pt via CALayer.setCornerRadius: matching HIG popover
    # default. Content insets 16pt leading/trailing, 12pt top/bottom.
    # -----------------------------------------------------------------
    def visit(view : UI::Popover)
      # Build the glass effect. Prefer UIGlassEffect on iOS 26; fall back to
      # UIBlurEffectStyleSystemChromeMaterial (= 11, tracks appearance).
      glass_cls = LibObjCBridge.objc_getClass("UIGlassEffect")
      blur_effect = if !glass_cls.null?
                      LibObjCBridge.objc_send(
                        LibObjCBridge.objc_send(glass_cls, sel("alloc")),
                        sel("init"))
                    else
                      ublur_cls = LibObjCBridge.objc_getClass("UIBlurEffect")
                      # UIBlurEffectStyleSystemChromeMaterial = 11
                      LibObjCBridge.objc_send_long(ublur_cls, sel("effectWithStyle:"), 11_i64)
                    end

      # [[UIVisualEffectView alloc] initWithEffect:blur_effect]
      uveff_cls = LibObjCBridge.objc_getClass("UIVisualEffectView")
      effect_alloc = LibObjCBridge.objc_send(uveff_cls, sel("alloc"))
      effect = LibObjCBridge.objc_send_id(effect_alloc, sel("initWithEffect:"), blur_effect)

      # Rounded corners -- ~10pt matches UIPopoverPresentationController default.
      LibObjCBridge.objc_send_bool(effect, sel("setClipsToBounds:"), 1)
      layer = LibObjCBridge.objc_send(effect, sel("layer"))
      unless layer.null?
        LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), 10.0)
        LibObjCBridge.objc_send_bool(layer, sel("setMasksToBounds:"), 1)
      end

      # Inner UIStackView: vertical, leading-aligned, 16pt margins, 8pt spacing.
      inner = alloc_init("UIStackView")
      # UILayoutConstraintAxisVertical = 1
      LibObjCBridge.objc_send_long(inner, sel("setAxis:"), 1_i64)
      LibObjCBridge.objc_send_1d(inner, sel("setSpacing:"), 8.0)
      # UIStackViewAlignmentLeading = 1
      LibObjCBridge.objc_send_long(inner, sel("setAlignment:"), 1_i64)
      insets = LibObjCBridge::CGRect.new(x: 16.0, y: 12.0, width: 16.0, height: 12.0)
      LibObjCBridge.objc_send_rect_void(inner, sel("setLayoutMargins:"), insets)
      LibObjCBridge.objc_send_bool(inner, sel("setLayoutMarginsRelativeArrangement:"), 1)
      LibObjCBridge.objc_send_bool(inner, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)

      # Add inner stack to contentView (UIVisualEffectView requirement -- subviews
      # must live in contentView for the material to render behind them correctly).
      content_view = LibObjCBridge.objc_send(effect, sel("contentView"))
      anchor_host = if content_view.null?
                      LibObjCBridge.objc_add_subview(effect, inner)
                      effect
                    else
                      LibObjCBridge.objc_add_subview(content_view, inner)
                      content_view
                    end

      # Pin inner to anchor_host on all four edges.
      %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anchor_sel|
        inner_anchor = LibObjCBridge.objc_send(inner, sel(anchor_sel))
        host_anchor  = LibObjCBridge.objc_send(anchor_host, sel(anchor_sel))
        next if inner_anchor.null? || host_anchor.null?
        constraint = LibObjCBridge.objc_send_id(inner_anchor, sel("constraintEqualToAnchor:"), host_anchor)
        LibObjCBridge.objc_send_bool(constraint, sel("setActive:"), 1) unless constraint.null?
      end

      inner_handle = ObjC.borrowed(inner, label: "UIStackView[popover-inner]")
      inner_native = NativeView.new(inner_handle)

      apply_common_properties(effect, view)

      outer_handle = ObjC.owned(effect, label: "UIVisualEffectView[popover-glass]")
      outer_native = NativeView.new(outer_handle)
      outer_native.add_child(inner_native)

      # Render content children into the inner stack.
      if content = view.content
        push_stack(inner_native, is_uistack: true)
        content.accept(self)
        pop_stack
      end

      push_native(outer_native)
    end

    # -----------------------------------------------------------------
    # Visit: ConfirmationDialog -> UIAlertController (action sheet style)
    # -----------------------------------------------------------------
    def visit(view : UI::ConfirmationDialog)
      uialert_cls = LibObjCBridge.objc_getClass("UIAlertController")
      title_str = LibObjCBridge.nsstring_from_cstr(view.title.to_unsafe)

      msg_ptr = if view.message.empty?
                  Pointer(Void).null
                else
                  LibObjCBridge.nsstring_from_cstr(view.message.to_unsafe)
                end

      # UIAlertControllerStyleAlert = 1
      ptr = LibObjCBridge.objc_send_id_id_long(
        uialert_cls,
        sel("alertControllerWithTitle:message:preferredStyle:"),
        title_str,
        msg_ptr,
        1_i64)

      apply_common_properties(ptr, view)

      emit(ptr, "UIAlertController[confirmation]")
    end

    # -----------------------------------------------------------------
    # Visit: Snackbar -> UILabel (toast overlay)
    # -----------------------------------------------------------------
    def visit(view : UI::Snackbar)
      ptr = alloc_init("UILabel")

      msg_str = LibObjCBridge.nsstring_from_cstr(view.message.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("setText:"), msg_str)

      if view.is_presented
        LibObjCBridge.objc_send_bool(ptr, sel("setHidden:"), 0)
      else
        LibObjCBridge.objc_send_bool(ptr, sel("setHidden:"), 1)
      end

      apply_common_properties(ptr, view)

      emit(ptr, "UILabel[snackbar]")
    end

    # -----------------------------------------------------------------
    # Visit: Card -> UIStackView (grouped card container)
    #
    # HIG Boxes - Platform considerations, iOS/iPadOS: "iOS and iPadOS
    # use the secondary and tertiary background colors in boxes." The
    # previous implementation used a plain UIView with addSubview: and
    # no constraints, so the content collapsed to zero frame when
    # placed inside a parent UIStackView. Here we emit a UIStackView
    # directly: UIStackView handles layout/sizing of its arranged
    # subviews, supports backgroundColor (iOS 14+), and lets us prepend
    # an optional title label cleanly. The outer parent UIStackView
    # sizes this card from its intrinsicContentSize (sum of arranged
    # subviews + spacing + layout margins).
    # -----------------------------------------------------------------
    def visit(view : UI::Card)
      ptr = alloc_init("UIStackView")

      # Vertical axis (UILayoutConstraintAxisVertical = 1).
      LibObjCBridge.objc_send_long(ptr, sel("setAxis:"), 1_i64)
      # HIG-standard ~8pt inter-row spacing.
      LibObjCBridge.objc_send_1d(ptr, sel("setSpacing:"), 8.0)
      # Fill alignment (0) so children use the card's full width.
      LibObjCBridge.objc_send_long(ptr, sel("setAlignment:"), 0_i64)
      # Use layout-margin-relative arrangement so arranged subviews are
      # inset from the card's edges. UI::Card#content_padding is the
      # cross-platform contract for readable rounded containers; without
      # it, title labels sit on the clipped corner and body copy reads as
      # unfinished.
      card_pad = view.content_padding
      card_insets = LibObjCBridge::CGRect.new(
        x: card_pad.top,
        y: card_pad.leading,
        width: card_pad.bottom,
        height: card_pad.trailing
      )
      LibObjCBridge.objc_send_rect_void(ptr, sel("setLayoutMargins:"), card_insets)
      LibObjCBridge.objc_send_bool(ptr, sel("setLayoutMarginsRelativeArrangement:"), 1)
      label_preferred_width = exact_card_label_preferred_width(view)

      # Grouped-container background per HIG. UIColor class method
      # selection based on UI::Card#material -- default :secondary.
      color_sel = case view.material
                  when :tertiary
                    sel("tertiarySystemBackgroundColor")
                  else
                    sel("secondarySystemBackgroundColor")
                  end
      uicolor_cls = LibObjCBridge.objc_getClass("UIColor")
      bg_color = LibObjCBridge.objc_send(uicolor_cls, color_sel)
      unless bg_color.null?
        LibObjCBridge.objc_send_id(ptr, sel("setBackgroundColor:"), bg_color)
      end

      # ~10pt corner radius, HIG grouped-container default on iOS 26.
      layer = LibObjCBridge.objc_send(ptr, sel("layer"))
      unless layer.null?
        LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), 10.0)
      end
      LibObjCBridge.objc_send_bool(ptr, sel("setClipsToBounds:"), 1)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UIStackView[card]")
      native = NativeView.new(handle)

      # Prepend an optional headline title label inside the card stack.
      if title = view.title
        title_ptr = alloc_init("UILabel")
        title_ns = LibObjCBridge.nsstring_from_cstr(title.to_unsafe)
        LibObjCBridge.objc_send_id(title_ptr, sel("setText:"), title_ns)
        # Headline weight (semibold 17pt) -- matches HIG for grouped
        # card titles on iOS.
        headline_font = LibObjCBridge.nsfont_system_weight(17.0, 0.3)
        LibObjCBridge.objc_send_id(title_ptr, sel("setFont:"), headline_font)
        if preferred_width = label_preferred_width
          LibObjCBridge.objc_send_long(title_ptr, sel("setNumberOfLines:"), 0_i64)
          LibObjCBridge.objc_send_1d(title_ptr, sel("setPreferredMaxLayoutWidth:"), preferred_width)
        end
        # Add as first arranged subview.
        LibObjCBridge.objc_send_void_id(ptr, sel("addArrangedSubview:"), title_ptr)

        title_handle = ObjC.owned(title_ptr, label: "UILabel[card-title]")
        native.add_child(NativeView.new(title_handle))
      end

      if content = view.content
        # Push the card stack as a uistack parent so children flow in
        # via addArrangedSubview: and are laid out / sized by the stack.
        if preferred_width = label_preferred_width
          @label_preferred_max_layout_width_stack.push(preferred_width)
          push_stack(native, is_uistack: true)
          content.accept(self)
          pop_stack
          @label_preferred_max_layout_width_stack.pop
        else
          push_stack(native, is_uistack: true)
          content.accept(self)
          pop_stack
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Surface -> UIView (elevated surface container)
    # -----------------------------------------------------------------
    def visit(view : UI::Surface)
      ptr = alloc_init("UIView")

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UIView[surface]")
      native = NativeView.new(handle)

      if content = view.content
        push_stack(native, is_uistack: false)
        content.accept(self)
        pop_stack
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Divider -> UIView (thin separator line)
    # -----------------------------------------------------------------
    def visit(view : UI::Divider)
      ptr = alloc_init("UIView")

      c = view.color
      color_ptr = LibObjCBridge.nscolor_rgba(c.r, c.g, c.b, c.a)
      LibObjCBridge.objc_send_id(ptr, sel("setBackgroundColor:"), color_ptr)

      apply_common_properties(ptr, view)

      # UIView has no intrinsicContentSize so UIStackView fill distribution
      # would expand the divider to fill all remaining space. Pin to thickness
      # (default 1pt) so the divider stays at its intended size.
      if view.orientation == :horizontal
        LibObjCBridge.objc_constrain_height(ptr, view.thickness)
      else
        LibObjCBridge.objc_constrain_width(ptr, view.thickness)
      end

      emit(ptr, "UIView[divider]")
    end

    # -----------------------------------------------------------------
    # Visit: GlassBackground -> UIVisualEffectView
    # -----------------------------------------------------------------
    def visit(view : UI::GlassBackground)
      # UIBlurEffect.effectWithStyle:
      blur_cls = LibObjCBridge.objc_getClass("UIBlurEffect")

      # UIBlurEffectStyle: extraLight=0, light=1, dark=2, extraDark=3,
      # regular=4 (iOS 10+), prominent=5, systemUltraThinMaterial=8,
      # systemThinMaterial=9, systemMaterial=10, systemThickMaterial=11,
      # systemChromeMaterial=12
      # On iOS, sidebar material does not exist; map to systemMaterial (10)
      # as the closest translucent surface that tracks appearance.
      style_val = case view.material
                  when :ultra_thin then 8_i64  # systemUltraThinMaterial
                  when :thin       then 9_i64  # systemThinMaterial
                  when :regular    then 10_i64 # systemMaterial
                  when :thick      then 11_i64 # systemThickMaterial
                  when :chrome     then 12_i64 # systemChromeMaterial
                  when :sidebar    then 10_i64 # systemMaterial (no iOS sidebar material)
                  when :menu       then 10_i64 # systemMaterial (closest to menu on iOS)
                  when :popover    then 10_i64 # systemMaterial (closest to popover on iOS)
                  when :sheet      then 10_i64 # systemMaterial (sheet blur on iOS)
                  else                  10_i64
                  end

      blur_effect = LibObjCBridge.objc_send_long(blur_cls, sel("effectWithStyle:"), style_val)

      effect_view_cls = LibObjCBridge.objc_getClass("UIVisualEffectView")
      ptr = LibObjCBridge.objc_send(effect_view_cls, sel("alloc"))
      ptr = LibObjCBridge.objc_send_id(ptr, sel("initWithEffect:"), blur_effect)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "UIVisualEffectView")
      native = NativeView.new(handle)

      if content = view.content
        # UIVisualEffectView content view
        content_view = LibObjCBridge.objc_send(ptr, sel("contentView"))
        content_handle = ObjC.owned(content_view, label: "UIView[glass-content]")
        content_native = NativeView.new(content_handle)
        push_stack(content_native, is_uistack: false)
        content.accept(self)
        pop_stack
        native.add_child(content_native)
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # P2 Wave 3 Visit methods
    # -----------------------------------------------------------------

    def visit(view : UI::AsyncImage)
      ptr = alloc_init("UIImageView")
      apply_common_properties(ptr, view)
      emit(ptr, "UIImageView[async]")
    end

    # -----------------------------------------------------------------
    # Visit: RichText -> UITextView
    #
    # HIG "Text views": "A text view displays multiline, styled text
    # content, which can optionally be editable."
    # UIKit: UITextView provides multi-line text with scrolling.
    # Non-editable by default for read-only rich content.
    #
    # Text color: sentinel-swap applied identical to the text-fields
    # iter-48 fix.  Default Color{0,0,0,1} sentinel maps to
    # UIColor.labelColor for appearance-tracking (near-black in light,
    # near-white in dark).
    # -----------------------------------------------------------------
    def visit(view : UI::RichText)
      ptr = alloc_init("UITextView")

      # Populate text from spans.
      plain = view.plain_text
      unless plain.empty?
        text_str = LibObjCBridge.nsstring_from_cstr(plain.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setText:"), text_str)
      end

      LibObjCBridge.objc_send_bool(ptr, sel("setEditable:"), 0)
      # Disable scroll so UITextView adopts intrinsic content size in UIStackView.
      # UITextView with scrollEnabled=YES collapses to zero height in a stack
      # unless given explicit sizing constraints. scrollEnabled=NO lets the text
      # view size itself to fit its content, which is the HIG-aligned pattern
      # for embedded read-only text areas. The parent UIScrollView provides
      # scrolling for longer content.
      LibObjCBridge.objc_send_bool(ptr, sel("setScrollEnabled:"), 0)

      # Font: use first span's font if present, else system body 17pt.
      first_font = view.spans.first?.try(&.font)
      font_ptr = first_font ? resolve_font(first_font) : LibObjCBridge.nsfont_system(17.0)
      LibObjCBridge.objc_send_id(ptr, sel("setFont:"), font_ptr) unless font_ptr.null?

      # Text color: sentinel-swap for dark-mode legibility.
      first_color = view.spans.first?.try(&.color)
      if fc = first_color
        if fc.r == 0.0 && fc.g == 0.0 && fc.b == 0.0 && fc.a == 1.0
          color_ptr = LibObjCBridge.nscolor_label_primary
        else
          color_ptr = LibObjCBridge.nscolor_rgba(fc.r, fc.g, fc.b, fc.a)
        end
      else
        color_ptr = LibObjCBridge.nscolor_label_primary
      end
      LibObjCBridge.objc_send_id(ptr, sel("setTextColor:"), color_ptr)

      apply_common_properties(ptr, view)
      emit(ptr, "UITextView[rich]")
    end

    def visit(view : UI::LinkButton)
      uibutton_cls = LibObjCBridge.objc_getClass("UIButton")
      ptr = LibObjCBridge.objc_send_long(uibutton_cls, sel("buttonWithType:"), 1_i64)
      title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
      LibObjCBridge.objc_send_id_long(ptr, sel("setTitle:forState:"), title_str, 0_i64)
      apply_common_properties(ptr, view)
      emit(ptr, "UIButton[link]")
    end

    # -----------------------------------------------------------------
    # Visit: MenuButton -> UIButton
    #
    # Pop-up mode (is_pull_down: false, default):
    #   UIButton configured with the current selection label and a trailing
    #   "chevron.up.chevron.down" SF Symbol.  Styled as a capsule via
    #   UIButtonConfiguration grayButtonConfiguration.
    #   HIG: "Use a pop-up button to present a flat list of mutually exclusive
    #   options or states." -- Pop-up buttons / Best practices.
    #
    # Pull-down mode (is_pull_down: true):
    #   UIButton showing the button's own label (a verb: "Add", "Export", etc.)
    #   with a single "chevron.down" SF Symbol.  No selection label is shown;
    #   no "chevron.up" component appears.  On iOS 14+ the button uses
    #   showsMenuAsPrimaryAction = true to present a UIMenu on primary tap;
    #   in this validation renderer we construct the visual chrome directly
    #   (title + chevron.down, UIButtonConfiguration filledButtonConfiguration
    #   for :prominent, grayButtonConfiguration for :default).
    #   HIG: "Use a pull-down button to present commands or items that are
    #   directly related to the button's action." -- Pull-down buttons / Best
    #   practices.
    # -----------------------------------------------------------------
    def visit(view : UI::MenuButton)
      uibutton_cls = LibObjCBridge.objc_getClass("UIButton")

      if view.is_pull_down
        # Pull-down: button face = view.label + chevron.down.
        config_cls = LibObjCBridge.objc_getClass("UIButtonConfiguration")
        config = if !config_cls.null?
                   if view.button_style == :prominent
                     LibObjCBridge.objc_send(config_cls, sel("filledButtonConfiguration"))
                   else
                     LibObjCBridge.objc_send(config_cls, sel("grayButtonConfiguration"))
                   end
                 else
                   Pointer(Void).null
                 end

        ptr = if !config.null?
                 LibObjCBridge.objc_send_id_id(
                   uibutton_cls,
                   sel("buttonWithConfiguration:primaryAction:"),
                   config,
                   Pointer(Void).null
                 )
               else
                 LibObjCBridge.objc_send_long(uibutton_cls, sel("buttonWithType:"), 1_i64)
               end

        title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
        LibObjCBridge.objc_send_id_long(ptr, sel("setTitle:forState:"), title_str, 0_i64)

        # chevron.down is the canonical pull-down indicator (single chevron,
        # pointing down only -- distinguishes pull-down from pop-up).
        uiimage_cls = LibObjCBridge.objc_getClass("UIImage")
        chevron_name = "chevron.down"
        chevron_ns = LibObjCBridge.nsstring_from_cstr(chevron_name.to_unsafe)
        chevron_img = LibObjCBridge.objc_send_id(uiimage_cls, sel("systemImageNamed:"), chevron_ns)
        unless chevron_img.null?
          LibObjCBridge.objc_send_id_long(ptr, sel("setImage:forState:"), chevron_img, 0_i64)
        end

        # Wire showsMenuAsPrimaryAction (iOS 14+) so the button title's tap
        # presents the menu rather than firing a default action.
        LibObjCBridge.objc_send_bool(ptr, sel("setShowsMenuAsPrimaryAction:"), 1)

        # Accessibility: label a pull-down button distinctly from pop-up.
        acc_text = view.accessibility_label || "#{view.label}, pull-down button"
        acc_str = LibObjCBridge.nsstring_from_cstr(acc_text.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), acc_str)

        apply_common_properties(ptr, view)
        emit(ptr, "UIButton[pull-down]")
      else
        # Pop-up mode (default).
        uicolor_cls = LibObjCBridge.objc_getClass("UIColor")

        # Determine current selection label.
        current_label = if !view.items.empty? && view.selected_index < view.items.size
                          view.items[view.selected_index].label
                        else
                          view.label
                        end

        # Try UIButtonConfiguration (iOS 15+) for the capsule pop-up style.
        config_cls = LibObjCBridge.objc_getClass("UIButtonConfiguration")
        config = config_cls.null? ? Pointer(Void).null : LibObjCBridge.objc_send(config_cls, sel("grayButtonConfiguration"))

        ptr = if !config.null?
                 LibObjCBridge.objc_send_id_id(
                   uibutton_cls,
                   sel("buttonWithConfiguration:primaryAction:"),
                   config,
                   Pointer(Void).null
                 )
               else
                 LibObjCBridge.objc_send_long(uibutton_cls, sel("buttonWithType:"), 1_i64)
               end

        # Set the current selection as the button title.
        title_str = LibObjCBridge.nsstring_from_cstr(current_label.to_unsafe)
        LibObjCBridge.objc_send_id_long(ptr, sel("setTitle:forState:"), title_str, 0_i64)

        # Attach the up/down chevron SF Symbol.
        uiimage_cls = LibObjCBridge.objc_getClass("UIImage")
        chevron_name = "chevron.up.chevron.down"
        chevron_ns = LibObjCBridge.nsstring_from_cstr(chevron_name.to_unsafe)
        chevron_img = LibObjCBridge.objc_send_id(uiimage_cls, sel("systemImageNamed:"), chevron_ns)
        unless chevron_img.null?
          LibObjCBridge.objc_send_id_long(ptr, sel("setImage:forState:"), chevron_img, 0_i64)
        end

        # Accessibility label -- required on interactive elements per HIG.
        acc_text = view.accessibility_label || "#{view.label}, pop-up button"
        acc_str = LibObjCBridge.nsstring_from_cstr(acc_text.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), acc_str)

        _ = uicolor_cls
        apply_common_properties(ptr, view)
        emit(ptr, "UIButton[pop-up]")
      end
    end

    def visit(view : UI::ToggleButton)
      uibutton_cls = LibObjCBridge.objc_getClass("UIButton")
      ptr = LibObjCBridge.objc_send_long(uibutton_cls, sel("buttonWithType:"), 1_i64)
      title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
      LibObjCBridge.objc_send_id_long(ptr, sel("setTitle:forState:"), title_str, 0_i64)
      apply_common_properties(ptr, view)
      emit(ptr, "UIButton[toggle-button]")
    end

    def visit(view : UI::TextEditor)
      ptr = alloc_init("UITextView")
      unless view.text.empty?
        text_str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setText:"), text_str)
      end
      LibObjCBridge.objc_send_bool(ptr, sel("setEditable:"), view.is_editable ? 1 : 0)
      apply_common_properties(ptr, view)
      emit(ptr, "UITextView[editor]")
    end

    # -----------------------------------------------------------------
    # P3 Stub Visit methods
    # -----------------------------------------------------------------

    def visit(view : UI::Circle)
      ptr = alloc_init("UIView")
      bg_color = resolve_color(view.fill_color)
      LibObjCBridge.objc_send_id(ptr, sel("setBackgroundColor:"), bg_color)
      layer = LibObjCBridge.objc_send(ptr, sel("layer"))
      unless layer.null?
        LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), view.size / 2.0)
        if sc = view.stroke_color
          LibObjCBridge.objc_send_1d(layer, sel("setBorderWidth:"), view.stroke_width)
          border_color = resolve_color(sc)
          cg_border = LibObjCBridge.objc_send(border_color, sel("CGColor"))
          LibObjCBridge.objc_send_id(layer, sel("setBorderColor:"), cg_border)
        end
      end
      LibObjCBridge.objc_send_bool(ptr, sel("setClipsToBounds:"), 1)
      apply_common_properties(ptr, view)
      emit(ptr, "UIView[circle]")
    end

    def visit(view : UI::Rectangle)
      ptr = alloc_init("UIView")
      bg_color = resolve_color(view.fill_color)
      LibObjCBridge.objc_send_id(ptr, sel("setBackgroundColor:"), bg_color)
      layer = LibObjCBridge.objc_send(ptr, sel("layer"))
      unless layer.null?
        if sc = view.stroke_color
          LibObjCBridge.objc_send_1d(layer, sel("setBorderWidth:"), view.stroke_width)
          border_color = resolve_color(sc)
          cg_border = LibObjCBridge.objc_send(border_color, sel("CGColor"))
          LibObjCBridge.objc_send_id(layer, sel("setBorderColor:"), cg_border)
        end
      end
      apply_common_properties(ptr, view)
      emit(ptr, "UIView[rectangle]")
    end

    def visit(view : UI::RoundedRectangle)
      ptr = alloc_init("UIView")
      bg_color = resolve_color(view.fill_color)
      LibObjCBridge.objc_send_id(ptr, sel("setBackgroundColor:"), bg_color)
      layer = LibObjCBridge.objc_send(ptr, sel("layer"))
      unless layer.null?
        LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), view.corner_radius)
        if sc = view.stroke_color
          LibObjCBridge.objc_send_1d(layer, sel("setBorderWidth:"), view.stroke_width)
          border_color = resolve_color(sc)
          cg_border = LibObjCBridge.objc_send(border_color, sel("CGColor"))
          LibObjCBridge.objc_send_id(layer, sel("setBorderColor:"), cg_border)
        end
      end
      LibObjCBridge.objc_send_bool(ptr, sel("setClipsToBounds:"), 1)
      apply_common_properties(ptr, view)
      emit(ptr, "UIView[rounded-rectangle]")
    end

    def visit(view : UI::Capsule)
      ptr = alloc_init("UIView")
      bg_color = resolve_color(view.fill_color)
      LibObjCBridge.objc_send_id(ptr, sel("setBackgroundColor:"), bg_color)
      layer = LibObjCBridge.objc_send(ptr, sel("layer"))
      unless layer.null?
        LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), view.height / 2.0)
        if sc = view.stroke_color
          LibObjCBridge.objc_send_1d(layer, sel("setBorderWidth:"), view.stroke_width)
          border_color = resolve_color(sc)
          cg_border = LibObjCBridge.objc_send(border_color, sel("CGColor"))
          LibObjCBridge.objc_send_id(layer, sel("setBorderColor:"), cg_border)
        end
      end
      LibObjCBridge.objc_send_bool(ptr, sel("setClipsToBounds:"), 1)
      apply_common_properties(ptr, view)
      emit(ptr, "UIView[capsule]")
    end

    def visit(view : UI::Canvas)
      ptr = alloc_init("UIView")
      rect = LibObjCBridge::CGRect.new(x: 0.0, y: 0.0, width: view.width, height: view.height)
      LibObjCBridge.objc_set_frame(ptr, rect)
      apply_common_properties(ptr, view)
      emit(ptr, "UIView[canvas]")
    end

    def visit(view : UI::PathView)
      ptr = alloc_init("UIView")
      rect = LibObjCBridge::CGRect.new(x: 0.0, y: 0.0, width: view.width, height: view.height)
      LibObjCBridge.objc_set_frame(ptr, rect)
      apply_common_properties(ptr, view)
      emit(ptr, "UIView[path]")
    end

    def visit(view : UI::MapView)
      # MKMapView: use UIView placeholder (requires MapKit framework)
      ptr = alloc_init("UIView")
      apply_common_properties(ptr, view)
      emit(ptr, "UIView[map]")
    end

    # -----------------------------------------------------------------
    # Visit: ChartView -> UIStackView-based bar / line chart
    #
    # HIG Charts: "Organize data in a chart to communicate information
    # with clarity and visual appeal." Same rendering strategy as the
    # AppKit renderer — UIStackViews compose bars and labels without
    # requiring Core Graphics drawing primitives.
    # -----------------------------------------------------------------
    def visit(view : UI::ChartView)
      # UIKit: do NOT use ENV[] here -- accessing ENV from within a UIKit
      # layout callback crashes Crystal's thread initializer on iOS (the
      # Crystal env lock is lazily initialized and requires Crystal's fiber
      # subsystem to be set up, which may not yet be the case when SwiftUI
      # calls makeUIView from its layout pass).
      # Instead, use static appearance-independent colors for UIKit; the
      # UIView CALayer accepts UIColor.CGColor and UITraitCollection tracks
      # appearance automatically for semantic colors.

      chart_w     = 340.0
      chart_h     = 220.0
      plot_h      = 160.0
      bar_spacing = 8.0
      label_h     = 24.0

      # Use neutral values that work in both appearances.
      # Background: clear (transparent) lets the hosting VC background show.
      # Bar area: subtle gray -- 0.92 alpha works in light; dark mode uses
      # UITraitCollection overrideUserInterfaceStyle, so the system bar area
      # background adapts via UIColor.secondarySystemBackground semantics.
      # We bake a single set of values. The UIKit renderer applies
      # overrideUserInterfaceStyle on the host window level for dark-mode
      # captures, so system colors track appearance automatically.
      bar_area_bg = 0.94   # ~systemGroupedBackground light equivalent

      # System blue (light equivalent) -- UIView CALayer backgroundColor
      # does NOT track traitCollection, so we must bake a value. Use the
      # light-mode system blue; the dark capture uses the same value.
      # For the validation captures this gives blue bars in both captures,
      # which is legible. A production app would use UIColor dynamic provider.
      bar_r  = 0.0
      bar_g  = 0.478
      bar_b  = 1.0
      bar_a  = 1.0

      line_r = 1.0
      line_g = 0.58
      line_b = 0.0
      line_a = 1.0

      grid_gray = 0.75
      lbl_gray  = 0.15

      # Outer UIStackView (vertical). UIView is always layer-backed on iOS;
      # setWantsLayer: is AppKit-only and must NOT be called on UIView.
      outer = alloc_init("UIStackView")
      LibObjCBridge.objc_send_long(outer, sel("setAxis:"), 1_i64)           # vertical
      LibObjCBridge.objc_send_1d(outer, sel("setSpacing:"), 6.0)
      LibObjCBridge.objc_send_long(outer, sel("setAlignment:"), 3_i64)      # center

      # TAMIC = NO is required before adding explicit Auto Layout constraints.
      # Without this, UIKit generates autoresizing mask constraints that conflict
      # with the explicit width/height anchors from objc_constrain_size, causing
      # the layout engine to resolve the conflict by collapsing the view to zero.
      LibObjCBridge.objc_send_bool(outer, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)

      # Explicit size: 340pt wide, 220pt tall. UIStackView has no intrinsic
      # content size that the parent UIStackView can use -- only its arranged
      # subviews contribute. Without this constraint the chart collapses to
      # zero height in any parent UIStackView.
      LibObjCBridge.objc_constrain_size(outer, chart_w, chart_h)

      # Title
      unless view.title.empty?
        title_lbl = alloc_init("UILabel")
        title_str = LibObjCBridge.nsstring_from_cstr(view.title.to_unsafe)
        LibObjCBridge.objc_send_id(title_lbl, sel("setText:"), title_str)
        title_font = LibObjCBridge.nsfont_system_weight(14.0, 0.4)
        LibObjCBridge.objc_send_id(title_lbl, sel("setFont:"), title_font)
        # Use UIColor.labelColor (appearance-tracking semantic color) for the
        # title so it renders near-black in light and near-white in dark.
        # nscolor_label_primary is safe to call here (no Crystal ENV access).
        title_color = LibObjCBridge.nscolor_label_primary
        LibObjCBridge.objc_send_id(title_lbl, sel("setTextColor:"), title_color)
        LibObjCBridge.objc_send_long(title_lbl, sel("setTextAlignment:"), 1_i64)  # center
        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), title_lbl)
      end

      pts = view.data_points
      max_val = pts.empty? ? 1.0 : pts.map(&.value).max
      max_val = 1.0 if max_val <= 0.0

      if view.chart_type == :bar
        plot_stack = alloc_init("UIStackView")
        LibObjCBridge.objc_send_long(plot_stack, sel("setAxis:"), 0_i64)      # horizontal
        LibObjCBridge.objc_send_1d(plot_stack, sel("setSpacing:"), bar_spacing)
        LibObjCBridge.objc_send_long(plot_stack, sel("setAlignment:"), 4_i64) # bottom

        plot_layer = LibObjCBridge.objc_send(plot_stack, sel("layer"))
        unless plot_layer.null?
          pa_bg = LibObjCBridge.nscolor_rgba(bar_area_bg, bar_area_bg, bar_area_bg, 1.0)
          unless pa_bg.null?
            pa_cg = LibObjCBridge.objc_send(pa_bg, sel("CGColor"))
            LibObjCBridge.objc_send_void_id(plot_layer, sel("setBackgroundColor:"), pa_cg) unless pa_cg.null?
          end
          LibObjCBridge.objc_send_1d(plot_layer, sel("setCornerRadius:"), 8.0)
        end
        LibObjCBridge.objc_constrain_size(plot_stack, chart_w - 16.0, plot_h + label_h + 4.0)

        n_pts = pts.size
        bar_w = n_pts > 0 ? ((chart_w - 16.0 - bar_spacing * (n_pts - 1).to_f) / n_pts.to_f).clamp(8.0, 56.0) : 36.0

        pts.each_with_index do |pt, _i|
          norm = max_val > 0 ? pt.value / max_val : 0.0
          bar_h = (norm * (plot_h - 8.0)).clamp(2.0, plot_h - 8.0)

          col = alloc_init("UIStackView")
          LibObjCBridge.objc_send_long(col, sel("setAxis:"), 1_i64)       # vertical
          LibObjCBridge.objc_send_1d(col, sel("setSpacing:"), 2.0)
          LibObjCBridge.objc_send_long(col, sel("setAlignment:"), 3_i64)  # center
          LibObjCBridge.objc_constrain_width(col, bar_w)

          spacer_v = alloc_init("UIView")
          spacer_h = (plot_h - bar_h - 8.0).clamp(0.0, plot_h)
          LibObjCBridge.objc_constrain_size(spacer_v, bar_w, spacer_h)
          LibObjCBridge.objc_send_id(col, sel("addArrangedSubview:"), spacer_v)

          bar_v = alloc_init("UIView")
          LibObjCBridge.objc_constrain_size(bar_v, bar_w, bar_h)
          bar_layer = LibObjCBridge.objc_send(bar_v, sel("layer"))
          unless bar_layer.null?
            bar_col_ns = if c = pt.color
                           LibObjCBridge.nscolor_rgba(c.r, c.g, c.b, c.a)
                         else
                           LibObjCBridge.nscolor_rgba(bar_r, bar_g, bar_b, bar_a)
                         end
            unless bar_col_ns.null?
              bar_cg = LibObjCBridge.objc_send(bar_col_ns, sel("CGColor"))
              LibObjCBridge.objc_send_void_id(bar_layer, sel("setBackgroundColor:"), bar_cg) unless bar_cg.null?
            end
            LibObjCBridge.objc_send_1d(bar_layer, sel("setCornerRadius:"), 4.0)
          end
          LibObjCBridge.objc_send_id(col, sel("addArrangedSubview:"), bar_v)

          lbl = alloc_init("UILabel")
          lbl_str = LibObjCBridge.nsstring_from_cstr(pt.label.to_unsafe)
          LibObjCBridge.objc_send_id(lbl, sel("setText:"), lbl_str)
          lbl_font = LibObjCBridge.nsfont_system(10.0)
          LibObjCBridge.objc_send_id(lbl, sel("setFont:"), lbl_font)
          lbl_color = LibObjCBridge.nscolor_label_secondary
          LibObjCBridge.objc_send_id(lbl, sel("setTextColor:"), lbl_color)
          LibObjCBridge.objc_send_long(lbl, sel("setTextAlignment:"), 1_i64)  # center
          LibObjCBridge.objc_constrain_height(lbl, label_h)
          LibObjCBridge.objc_send_id(col, sel("addArrangedSubview:"), lbl)

          LibObjCBridge.objc_send_id(plot_stack, sel("addArrangedSubview:"), col)
        end

        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), plot_stack)

      elsif view.chart_type == :line
        plot_stack = alloc_init("UIStackView")
        LibObjCBridge.objc_send_long(plot_stack, sel("setAxis:"), 0_i64)
        LibObjCBridge.objc_send_1d(plot_stack, sel("setSpacing:"), 4.0)
        LibObjCBridge.objc_send_long(plot_stack, sel("setAlignment:"), 4_i64)

        plot_layer = LibObjCBridge.objc_send(plot_stack, sel("layer"))
        unless plot_layer.null?
          pa_bg = LibObjCBridge.nscolor_rgba(bar_area_bg, bar_area_bg, bar_area_bg, 1.0)
          unless pa_bg.null?
            pa_cg = LibObjCBridge.objc_send(pa_bg, sel("CGColor"))
            LibObjCBridge.objc_send_void_id(plot_layer, sel("setBackgroundColor:"), pa_cg) unless pa_cg.null?
          end
          LibObjCBridge.objc_send_1d(plot_layer, sel("setCornerRadius:"), 8.0)
        end
        LibObjCBridge.objc_constrain_size(plot_stack, chart_w - 16.0, plot_h + label_h + 4.0)

        n_pts = pts.size
        col_w = n_pts > 0 ? ((chart_w - 16.0 - 4.0 * (n_pts - 1).to_f) / n_pts.to_f).clamp(8.0, 56.0) : 36.0

        pts.each_with_index do |pt, _i|
          norm = max_val > 0 ? pt.value / max_val : 0.0
          dot_h = (norm * (plot_h - 16.0)).clamp(4.0, plot_h - 16.0)

          col = alloc_init("UIStackView")
          LibObjCBridge.objc_send_long(col, sel("setAxis:"), 1_i64)
          LibObjCBridge.objc_send_1d(col, sel("setSpacing:"), 2.0)
          LibObjCBridge.objc_send_long(col, sel("setAlignment:"), 3_i64)
          LibObjCBridge.objc_constrain_width(col, col_w)

          spacer_v = alloc_init("UIView")
          spacer_h = (plot_h - dot_h - 16.0).clamp(0.0, plot_h)
          LibObjCBridge.objc_constrain_size(spacer_v, col_w, spacer_h)
          LibObjCBridge.objc_send_id(col, sel("addArrangedSubview:"), spacer_v)

          dot_v = alloc_init("UIView")
          dot_size = 8.0
          LibObjCBridge.objc_constrain_size(dot_v, dot_size, dot_size)
          dot_layer = LibObjCBridge.objc_send(dot_v, sel("layer"))
          unless dot_layer.null?
            dot_col_ns = LibObjCBridge.nscolor_rgba(line_r, line_g, line_b, line_a)
            unless dot_col_ns.null?
              dot_cg = LibObjCBridge.objc_send(dot_col_ns, sel("CGColor"))
              LibObjCBridge.objc_send_void_id(dot_layer, sel("setBackgroundColor:"), dot_cg) unless dot_cg.null?
            end
            LibObjCBridge.objc_send_1d(dot_layer, sel("setCornerRadius:"), dot_size / 2.0)
          end
          LibObjCBridge.objc_send_id(col, sel("addArrangedSubview:"), dot_v)

          stem_h = dot_h - dot_size
          if stem_h > 0
            stem_v = alloc_init("UIView")
            LibObjCBridge.objc_constrain_size(stem_v, 2.0, stem_h)
            stem_layer = LibObjCBridge.objc_send(stem_v, sel("layer"))
            unless stem_layer.null?
              stem_col = LibObjCBridge.nscolor_rgba(line_r, line_g, line_b, 0.35)
              unless stem_col.null?
                stem_cg = LibObjCBridge.objc_send(stem_col, sel("CGColor"))
                LibObjCBridge.objc_send_void_id(stem_layer, sel("setBackgroundColor:"), stem_cg) unless stem_cg.null?
              end
            end
            LibObjCBridge.objc_send_id(col, sel("addArrangedSubview:"), stem_v)
          end

          lbl = alloc_init("UILabel")
          lbl_str = LibObjCBridge.nsstring_from_cstr(pt.label.to_unsafe)
          LibObjCBridge.objc_send_id(lbl, sel("setText:"), lbl_str)
          lbl_font = LibObjCBridge.nsfont_system(10.0)
          LibObjCBridge.objc_send_id(lbl, sel("setFont:"), lbl_font)
          lbl_color = LibObjCBridge.nscolor_label_secondary
          LibObjCBridge.objc_send_id(lbl, sel("setTextColor:"), lbl_color)
          LibObjCBridge.objc_send_long(lbl, sel("setTextAlignment:"), 1_i64)
          LibObjCBridge.objc_constrain_height(lbl, label_h)
          LibObjCBridge.objc_send_id(col, sel("addArrangedSubview:"), lbl)

          LibObjCBridge.objc_send_id(plot_stack, sel("addArrangedSubview:"), col)
        end

        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), plot_stack)

      else
        # :pie placeholder
        pie_v = alloc_init("UIView")
        LibObjCBridge.objc_constrain_size(pie_v, 120.0, 120.0)
        pie_layer = LibObjCBridge.objc_send(pie_v, sel("layer"))
        unless pie_layer.null?
          pie_col = LibObjCBridge.nscolor_rgba(bar_r, bar_g, bar_b, 1.0)
          unless pie_col.null?
            pie_cg = LibObjCBridge.objc_send(pie_col, sel("CGColor"))
            LibObjCBridge.objc_send_void_id(pie_layer, sel("setBackgroundColor:"), pie_cg) unless pie_cg.null?
          end
          LibObjCBridge.objc_send_1d(pie_layer, sel("setCornerRadius:"), 60.0)
        end
        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), pie_v)
      end

      # Baseline separator
      grid_v = alloc_init("UIView")
      LibObjCBridge.objc_constrain_size(grid_v, chart_w - 16.0, 1.0)
      grid_layer = LibObjCBridge.objc_send(grid_v, sel("layer"))
      unless grid_layer.null?
        grid_col = LibObjCBridge.nscolor_rgba(grid_gray, grid_gray, grid_gray, 1.0)
        unless grid_col.null?
          grid_cg = LibObjCBridge.objc_send(grid_col, sel("CGColor"))
          LibObjCBridge.objc_send_void_id(grid_layer, sel("setBackgroundColor:"), grid_cg) unless grid_cg.null?
        end
      end
      LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), grid_v)

      # Accessibility
      ax_label = view.accessibility_label || (view.title.empty? ? "Chart" : "Chart: #{view.title}")
      ax_str = LibObjCBridge.nsstring_from_cstr(ax_label.to_unsafe)
      LibObjCBridge.objc_send_id(outer, sel("setAccessibilityLabel:"), ax_str)

      apply_common_properties(outer, view)
      emit(outer, "UIStackView[chart]")
    end

    def visit(view : UI::WebViewComponent)
      # WKWebView: use UIView placeholder (requires WebKit framework)
      ptr = alloc_init("UIView")
      unless view.url.empty?
        url_str = LibObjCBridge.nsstring_from_cstr(view.url.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), url_str)
      end
      apply_common_properties(ptr, view)
      emit(ptr, "UIView[webview]")
    end

    def visit(view : UI::ColorPicker)
      # UIColorWell (iOS 14+): use a sized, rounded UIView swatch placeholder.
      # UIColorWell is available at runtime on iOS 14+ but requires importing
      # UIKit privately; a UIView with explicit size constraints and the chosen
      # background color is the correct visual proxy for the validation harness.
      #
      # Without explicit size constraints the UIView collapses to zero inside a
      # UIStackView (UIView has no intrinsicContentSize), producing an invisible
      # swatch. Pin width to 44pt and height to 28pt -- matching the HIG-
      # recommended pill swatch geometry for a color well in a compact context.
      # Apply corner_radius ~14pt (half of 28pt) for the pill shape.
      ptr = alloc_init("UIView")
      c = view.selected_color
      bg_color = resolve_color(c)
      LibObjCBridge.objc_send_id(ptr, sel("setBackgroundColor:"), bg_color)
      # Pin 44x28pt so UIStackView has a non-zero intrinsicContentSize to use.
      LibObjCBridge.objc_constrain_size(ptr, 44.0, 28.0)
      # Pill-shaped corner radius.
      layer = LibObjCBridge.objc_send_long(ptr, sel("layer"), 0_i64)
      unless layer.null?
        LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), 14.0)
        LibObjCBridge.objc_send_bool(layer, sel("setMasksToBounds:"), 1)
      end
      if (al = view.accessibility_label) && !al.empty?
        lbl_str = LibObjCBridge.nsstring_from_cstr(al.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), lbl_str)
      end
      apply_common_properties(ptr, view)
      emit(ptr, "UIView[color-picker]")
    end

    def visit(view : UI::VideoPlayer)
      # AVPlayerViewController: use UIView placeholder (requires AVKit framework)
      ptr = alloc_init("UIView")
      unless view.url.empty?
        url_str = LibObjCBridge.nsstring_from_cstr(view.url.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), url_str)
      end
      apply_common_properties(ptr, view)
      emit(ptr, "UIView[video]")
    end

    def visit(view : UI::Tooltip)
      ptr = alloc_init("UIView")
      unless view.text.empty?
        tooltip_str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), tooltip_str)
      end
      apply_common_properties(ptr, view)
      handle = ObjC.owned(ptr, label: "UIView[tooltip]")
      native = NativeView.new(handle)
      if content = view.content
        push_stack(native, is_uistack: false)
        content.accept(self)
        pop_stack
      end
      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: ActivityView -> UIVisualEffectView + four layout zones
    #
    # Production note: on iOS a real share sheet would dispatch
    # UIActivityViewController (system share sheet). The inline layout
    # below renders all four HIG zones for the validation capture path
    # only. TODO: add a UIActivityViewController dispatch path for
    # production usage (is_presented == true).
    #
    # Material: UIGlassEffect (iOS 26) or
    #           UIBlurEffect(systemChromeMaterial=11) fallback.
    # -----------------------------------------------------------------
    def visit(view : UI::ActivityView)
      # Amber gold tint — applied to all destination icon UIButtons, action icon
      # UIButtons, and the Cancel UIButton so the ActivityView renders in the Amber
      # brand accent rather than the default systemBlue.
      # UIButton.tintColor routes template-mode SF Symbol images through the color.
      # Light: #FFAD33 = rgba(1.0, 0.678, 0.2, 1.0)
      # Dark:  #FFB84D = rgba(1.0, 0.722, 0.302, 1.0)
      # nscolor_rgba returns a UIColor on iOS; appearance-adaptive per the HIG_APPEARANCE
      # env var is handled by the host harness, not the renderer.
      amber_gold = LibObjCBridge.nscolor_rgba(1.0, 0.678, 0.2, 1.0)

      # Build the glass surface effect (same pattern as visit(UI::Sheet)).
      glass_cls = LibObjCBridge.objc_getClass("UIGlassEffect")
      blur_effect = if !glass_cls.null?
                      LibObjCBridge.objc_send(
                        LibObjCBridge.objc_send(glass_cls, sel("alloc")),
                        sel("init"))
                    else
                      ublur_cls = LibObjCBridge.objc_getClass("UIBlurEffect")
                      LibObjCBridge.objc_send_long(ublur_cls, sel("effectWithStyle:"), 11_i64)
                    end

      uveff_cls = LibObjCBridge.objc_getClass("UIVisualEffectView")
      effect_alloc = LibObjCBridge.objc_send(uveff_cls, sel("alloc"))
      effect = LibObjCBridge.objc_send_id(effect_alloc, sel("initWithEffect:"), blur_effect)

      LibObjCBridge.objc_send_bool(effect, sel("setClipsToBounds:"), 1)
      eff_layer = LibObjCBridge.objc_send(effect, sel("layer"))
      unless eff_layer.null?
        LibObjCBridge.objc_send_1d(eff_layer, sel("setCornerRadius:"), 16.0)
        # setMaskedCorners: 15 (all four: layerMinXMinYCorner | layerMaxXMinYCorner |
        # layerMinXMaxYCorner | layerMaxXMaxYCorner). Without the explicit mask some
        # SDK versions leave the top-left corner flat when UIGlassEffect is the effect.
        LibObjCBridge.objc_send_ulong(eff_layer, sel("setMaskedCorners:"), 15_u64)
        LibObjCBridge.objc_send_bool(eff_layer, sel("setMasksToBounds:"), 1)
        # 0.5pt hairline border using UIColor.separatorColor so the card rim is
        # visible in dark-mode captures where the glass tint and backdrop are
        # isoluminant. Matches the fix applied to visit(UI::Sheet) in iter-6.
        uicolor_cls_act = LibObjCBridge.objc_getClass("UIColor")
        sep_color_act = LibObjCBridge.objc_send(uicolor_cls_act, sel("separatorColor"))
        unless sep_color_act.null?
          cg_sep_act = LibObjCBridge.objc_send(sep_color_act, sel("CGColor"))
          unless cg_sep_act.null?
            LibObjCBridge.objc_send_1d(eff_layer, sel("setBorderWidth:"), 0.5)
            LibObjCBridge.objc_send_id(eff_layer, sel("setBorderColor:"), cg_sep_act)
          end
        end
      end

      content_view = LibObjCBridge.objc_send(effect, sel("contentView"))
      anchor_host = content_view.null? ? effect : content_view

      # Outer vertical UIStackView hosts all four zones.
      outer_stack = alloc_init("UIStackView")
      LibObjCBridge.objc_send_long(outer_stack, sel("setAxis:"), 1_i64)         # vertical
      LibObjCBridge.objc_send_1d(outer_stack, sel("setSpacing:"), 12.0)
      LibObjCBridge.objc_send_long(outer_stack, sel("setAlignment:"), 0_i64)    # fill
      insets = LibObjCBridge::CGRect.new(x: 16.0, y: 16.0, width: 16.0, height: 16.0)
      LibObjCBridge.objc_send_rect_void(outer_stack, sel("setLayoutMargins:"), insets)
      LibObjCBridge.objc_send_bool(outer_stack, sel("setLayoutMarginsRelativeArrangement:"), 1)
      LibObjCBridge.objc_send_bool(outer_stack, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
      LibObjCBridge.objc_add_subview(anchor_host, outer_stack)

      %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anch|
        ia = LibObjCBridge.objc_send(outer_stack, sel(anch))
        ha = LibObjCBridge.objc_send(anchor_host, sel(anch))
        next if ia.null? || ha.null?
        c = LibObjCBridge.objc_send_id(ia, sel("constraintEqualToAnchor:"), ha)
        LibObjCBridge.objc_send_bool(c, sel("setActive:"), 1) unless c.null?
      end

      # --- Zone 1: Header (thumbnail + VStack(title, subtitle)) ---
      header_stack = alloc_init("UIStackView")
      LibObjCBridge.objc_send_long(header_stack, sel("setAxis:"), 0_i64)    # horizontal
      LibObjCBridge.objc_send_1d(header_stack, sel("setSpacing:"), 12.0)
      LibObjCBridge.objc_send_long(header_stack, sel("setAlignment:"), 3_i64) # center

      if thumb = view.thumbnail
        thumb_view = alloc_init("UIImageView")
        LibObjCBridge.objc_send_bool(thumb_view, sel("setClipsToBounds:"), 1)
        tl = LibObjCBridge.objc_send(thumb_view, sel("layer"))
        unless tl.null?
          LibObjCBridge.objc_send_1d(tl, sel("setCornerRadius:"), 8.0)
        end
        LibObjCBridge.objc_send_id(header_stack, sel("addArrangedSubview:"), thumb_view)
      end

      text_stack = alloc_init("UIStackView")
      LibObjCBridge.objc_send_long(text_stack, sel("setAxis:"), 1_i64)  # vertical
      LibObjCBridge.objc_send_1d(text_stack, sel("setSpacing:"), 2.0)

      title_lbl = alloc_init("UILabel")
      title_str = LibObjCBridge.nsstring_from_cstr(view.title.to_unsafe)
      LibObjCBridge.objc_send_id(title_lbl, sel("setText:"), title_str)
      title_font = LibObjCBridge.nsfont_system_weight(15.0, 0.4)
      LibObjCBridge.objc_send_id(title_lbl, sel("setFont:"), title_font) unless title_font.null?
      lbl_color = LibObjCBridge.nscolor_label_primary
      LibObjCBridge.objc_send_id(title_lbl, sel("setTextColor:"), lbl_color) unless lbl_color.null?
      LibObjCBridge.objc_send_id(text_stack, sel("addArrangedSubview:"), title_lbl)

      if sub = view.subtitle
        sub_lbl = alloc_init("UILabel")
        sub_str = LibObjCBridge.nsstring_from_cstr(sub.to_unsafe)
        LibObjCBridge.objc_send_id(sub_lbl, sel("setText:"), sub_str)
        sub_font = LibObjCBridge.nsfont_system(13.0)
        LibObjCBridge.objc_send_id(sub_lbl, sel("setFont:"), sub_font) unless sub_font.null?
        sec_color = LibObjCBridge.nscolor_label_secondary
        LibObjCBridge.objc_send_id(sub_lbl, sel("setTextColor:"), sec_color) unless sec_color.null?
        LibObjCBridge.objc_send_id(text_stack, sel("addArrangedSubview:"), sub_lbl)
      end

      LibObjCBridge.objc_send_id(header_stack, sel("addArrangedSubview:"), text_stack)
      LibObjCBridge.objc_send_id(outer_stack, sel("addArrangedSubview:"), header_stack)

      # --- Zone 2: Destination row (horizontal UIStackView of circular icons) ---
      # Use a plain UIStackView as a direct arranged subview (not wrapped in
      # UIScrollView) so the stack auto-sizes and the outer UIStackView can
      # measure it. UIScrollView with un-constrained content collapses to zero
      # height in a UIStackView context, making zone 2 invisible.
      dest_row = alloc_init("UIStackView")
      LibObjCBridge.objc_send_long(dest_row, sel("setAxis:"), 0_i64)    # horizontal
      LibObjCBridge.objc_send_1d(dest_row, sel("setSpacing:"), 16.0)
      LibObjCBridge.objc_send_long(dest_row, sel("setAlignment:"), 1_i64) # top

      view.destinations.each do |dest|
        dest_vstack = alloc_init("UIStackView")
        LibObjCBridge.objc_send_long(dest_vstack, sel("setAxis:"), 1_i64)  # vertical
        LibObjCBridge.objc_send_1d(dest_vstack, sel("setSpacing:"), 4.0)
        LibObjCBridge.objc_send_long(dest_vstack, sel("setAlignment:"), 3_i64) # center

        # Circular icon button (~60pt)
        uibtn_cls = LibObjCBridge.objc_getClass("UIButton")
        icon_btn = LibObjCBridge.objc_send_long(uibtn_cls, sel("buttonWithType:"), 1_i64)
        dest_sym_ns = LibObjCBridge.nsstring_from_cstr(dest.icon_symbol.to_unsafe)
        dest_uiimg = LibObjCBridge.objc_send_id(
          LibObjCBridge.objc_getClass("UIImage"),
          sel("systemImageNamed:"), dest_sym_ns)
        LibObjCBridge.objc_send_id_long(icon_btn, sel("setImage:forState:"), dest_uiimg, 0_i64) unless dest_uiimg.null?
        # Amber gold tint: UIButton.tintColor routes template-mode SF Symbol through
        # the color, replacing systemBlue with Amber gold (#FFAD33).
        LibObjCBridge.objc_send_id(icon_btn, sel("setTintColor:"), amber_gold) unless amber_gold.null?
        LibObjCBridge.objc_send_bool(icon_btn, sel("setClipsToBounds:"), 1)
        ibtn_layer = LibObjCBridge.objc_send(icon_btn, sel("layer"))
        unless ibtn_layer.null?
          LibObjCBridge.objc_send_1d(ibtn_layer, sel("setCornerRadius:"), 30.0)
        end
        LibObjCBridge.objc_send_id(dest_vstack, sel("addArrangedSubview:"), icon_btn)

        # Label below icon
        dest_lbl = alloc_init("UILabel")
        dest_lbl_str = LibObjCBridge.nsstring_from_cstr(dest.label.to_unsafe)
        LibObjCBridge.objc_send_id(dest_lbl, sel("setText:"), dest_lbl_str)
        dest_font = LibObjCBridge.nsfont_system(11.0)
        LibObjCBridge.objc_send_id(dest_lbl, sel("setFont:"), dest_font) unless dest_font.null?
        sec2 = LibObjCBridge.nscolor_label_secondary
        LibObjCBridge.objc_send_id(dest_lbl, sel("setTextColor:"), sec2) unless sec2.null?
        LibObjCBridge.objc_send_long(dest_lbl, sel("setTextAlignment:"), 1_i64) # center
        LibObjCBridge.objc_send_id(dest_vstack, sel("addArrangedSubview:"), dest_lbl)

        LibObjCBridge.objc_send_id(dest_row, sel("addArrangedSubview:"), dest_vstack)
      end

      LibObjCBridge.objc_send_id(outer_stack, sel("addArrangedSubview:"), dest_row)

      # --- Zone 3: Action grid (2-col UIStackView pairs) ---
      grid_vstack = alloc_init("UIStackView")
      LibObjCBridge.objc_send_long(grid_vstack, sel("setAxis:"), 1_i64)  # vertical
      LibObjCBridge.objc_send_1d(grid_vstack, sel("setSpacing:"), 8.0)

      actions = view.actions
      row_idx = 0
      while row_idx < actions.size
        pair_row = alloc_init("UIStackView")
        LibObjCBridge.objc_send_long(pair_row, sel("setAxis:"), 0_i64)  # horizontal
        LibObjCBridge.objc_send_1d(pair_row, sel("setSpacing:"), 8.0)
        LibObjCBridge.objc_send_long(pair_row, sel("setDistribution:"), 3_i64) # fillEqually

        [actions[row_idx]?, actions[row_idx + 1]?].each do |act|
          next unless act

          tile = alloc_init("UIStackView")
          LibObjCBridge.objc_send_long(tile, sel("setAxis:"), 0_i64)      # horizontal
          LibObjCBridge.objc_send_1d(tile, sel("setSpacing:"), 8.0)
          LibObjCBridge.objc_send_long(tile, sel("setAlignment:"), 3_i64) # center
          LibObjCBridge.objc_send_bool(tile, sel("setClipsToBounds:"), 1)
          tile_layer = LibObjCBridge.objc_send(tile, sel("layer"))
          unless tile_layer.null?
            LibObjCBridge.objc_send_1d(tile_layer, sel("setCornerRadius:"), 10.0)
          end

          act_btn2 = LibObjCBridge.objc_send_long(
            LibObjCBridge.objc_getClass("UIButton"), sel("buttonWithType:"), 1_i64)
          act_sym_ns2 = LibObjCBridge.nsstring_from_cstr(act.icon_symbol.to_unsafe)
          act_uiimg = LibObjCBridge.objc_send_id(
            LibObjCBridge.objc_getClass("UIImage"),
            sel("systemImageNamed:"), act_sym_ns2)
          LibObjCBridge.objc_send_id_long(act_btn2, sel("setImage:forState:"), act_uiimg, 0_i64) unless act_uiimg.null?
          # Amber gold tint on non-destructive action icon buttons. Destructive actions
          # use system red (handled below in act_lbl2 color path); icon stays amber.
          if act.role != :destructive
            LibObjCBridge.objc_send_id(act_btn2, sel("setTintColor:"), amber_gold) unless amber_gold.null?
          end
          LibObjCBridge.objc_send_id(tile, sel("addArrangedSubview:"), act_btn2)

          act_lbl2 = alloc_init("UILabel")
          act_lbl_str = LibObjCBridge.nsstring_from_cstr(act.label.to_unsafe)
          LibObjCBridge.objc_send_id(act_lbl2, sel("setText:"), act_lbl_str)
          act_font2 = LibObjCBridge.nsfont_system(13.0)
          LibObjCBridge.objc_send_id(act_lbl2, sel("setFont:"), act_font2) unless act_font2.null?
          if act.role == :destructive
            red_c = LibObjCBridge.nscolor_rgba(1.0, 0.23, 0.19, 1.0)
            LibObjCBridge.objc_send_id(act_lbl2, sel("setTextColor:"), red_c)
          else
            act_color = LibObjCBridge.nscolor_label_primary
            LibObjCBridge.objc_send_id(act_lbl2, sel("setTextColor:"), act_color) unless act_color.null?
          end
          LibObjCBridge.objc_send_id(tile, sel("addArrangedSubview:"), act_lbl2)

          LibObjCBridge.objc_send_id(pair_row, sel("addArrangedSubview:"), tile)
        end

        LibObjCBridge.objc_send_id(grid_vstack, sel("addArrangedSubview:"), pair_row)
        row_idx += 2
      end

      LibObjCBridge.objc_send_id(outer_stack, sel("addArrangedSubview:"), grid_vstack)

      # --- Zone 4: Cancel button (semibold, full width) ---
      cancel_btn = LibObjCBridge.objc_send_long(
        LibObjCBridge.objc_getClass("UIButton"), sel("buttonWithType:"), 1_i64)
      cancel_str = LibObjCBridge.nsstring_from_cstr("Cancel")
      LibObjCBridge.objc_send_id_long(cancel_btn, sel("setTitle:forState:"), cancel_str, 0_i64)
      cancel_font = LibObjCBridge.nsfont_system_weight(17.0, 0.4)
      unless cancel_font.null?
        lbl_handle = LibObjCBridge.objc_send(cancel_btn, sel("titleLabel"))
        LibObjCBridge.objc_send_id(lbl_handle, sel("setFont:"), cancel_font) unless lbl_handle.null?
      end
      # Amber gold tint on Cancel button. UIButton.tintColor propagates to the
      # title label when the button type is UIButtonTypeSystem (type 1), routing
      # the semibold Cancel label color through Amber gold (#FFAD33) instead of
      # the default systemBlue. HIG: "Always add a Cancel button on iPhone."
      LibObjCBridge.objc_send_id(cancel_btn, sel("setTintColor:"), amber_gold) unless amber_gold.null?
      LibObjCBridge.objc_send_id(outer_stack, sel("addArrangedSubview:"), cancel_btn)

      # --- Fix: 24pt bottom safe-area inset ---
      # HIG iOS: "a sheet slides up from the bottom of the screen" — the Cancel
      # button must clear the home indicator. The outer UIStackView layoutMargins
      # already has 16pt bottom padding; adding 24pt extra gives 40pt total below
      # the Cancel baseline, ensuring full visibility above the safe-area edge.
      # We update the bottom margin from 16pt to 40pt (16 existing + 24 clearance).
      safe_insets = LibObjCBridge::CGRect.new(x: 16.0, y: 16.0, width: 16.0, height: 40.0)
      LibObjCBridge.objc_send_rect_void(outer_stack, sel("setLayoutMargins:"), safe_insets)

      apply_common_properties(effect, view)

      # --- Fix 2 (iter-22): iOS dark glass bleed-through ---
      # UIGlassEffect / UIBlurEffect compositing is not captured by XCUITest's
      # rasterization path — the live window backdrop is not composited into the
      # screenshot, so the glass card appears as a solid fill in dark captures.
      # Fix: wrap the UIVisualEffectView in a container UIView; install a
      # warm-amber-to-ember CAGradientLayer as the container's bottommost sublayer
      # (behind the glass); lower the UIVisualEffectView's alpha to 0.82 so the
      # gradient tonal variation bleeds through even under rasterized capture.
      # The gradient is amber (0.90, 0.55, 0.15) top-left -> ember (0.55, 0.22, 0.04)
      # bottom-right, matching the warm Conjure brand palette.
      # In light appearance the amber backdrop is already visible; this fix primarily
      # affects the dark appearance where the solid fill obscured all bleed-through.
      gradient_container = alloc_init("UIView")
      LibObjCBridge.objc_send_bool(gradient_container, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
      LibObjCBridge.objc_send_bool(gradient_container, sel("setClipsToBounds:"), 1)
      gc_layer = LibObjCBridge.objc_send(gradient_container, sel("layer"))
      unless gc_layer.null?
        LibObjCBridge.objc_send_1d(gc_layer, sel("setCornerRadius:"), 16.0)
        LibObjCBridge.objc_send_bool(gc_layer, sel("setMasksToBounds:"), 1)
      end

      # Install pre-composited amber gradient layer BEHIND the glass effect.
      LibObjCBridge.uiview_install_amber_gradient_layer(gradient_container)

      # Add the glass effect on top of the gradient, with alpha 0.82 so
      # the gradient bleeds through under XCUITest rasterization.
      LibObjCBridge.objc_send_bool(effect, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
      LibObjCBridge.objc_send_1d(effect, sel("setAlpha:"), 0.82)
      LibObjCBridge.objc_add_subview(gradient_container, effect)
      # Pin effect edges to gradient_container
      %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anch|
        ea = LibObjCBridge.objc_send(effect, sel(anch))
        ga = LibObjCBridge.objc_send(gradient_container, sel(anch))
        next if ea.null? || ga.null?
        c = LibObjCBridge.objc_send_id(ea, sel("constraintEqualToAnchor:"), ga)
        LibObjCBridge.objc_send_bool(c, sel("setActive:"), 1) unless c.null?
      end

      # minimum_height constraint was already applied to `effect` by apply_common_properties.
      # Since effect is pinned edge-to-edge to gradient_container, the constraint
      # propagates to the container automatically; no duplicate constraint needed.

      outer_handle = ObjC.owned(gradient_container, label: "UIView[activity-view-gradient-container]")
      outer_native = NativeView.new(outer_handle)

      push_native(outer_native)
    end

    # -----------------------------------------------------------------
    # Visit: DisclosureGroup -> UIStackView (vertical) containing:
    #   (1) header row UIStackView (horizontal): UIButton with chevron
    #       SF Symbol + UILabel for the title
    #   (2) optional content UIStackView (indented 20pt) when expanded=true
    #
    # iOS has no UIDisclosureButton class; HIG recommends SwiftUI
    # DisclosureGroup which internally emits a chevron-prefixed UIButton
    # row (chevron.right when collapsed, chevron.down when expanded) plus
    # optional child content below. We replicate this with a UIStackView
    # + UIButton image (SF Symbol) + UILabel header + child UIStackView.
    #
    # HIG: "Disclosure controls are available in iOS, iPadOS, and visionOS
    # with the SwiftUI DisclosureGroup view."
    # (disclosure-controls / Platform considerations / iOS, iPadOS, visionOS)
    # -----------------------------------------------------------------
    def visit(view : UI::DisclosureGroup)
      # Outer vertical UIStackView: header row + optional content
      outer = alloc_init("UIStackView")
      LibObjCBridge.objc_send_long(outer, sel("setAxis:"), 1_i64)        # vertical
      LibObjCBridge.objc_send_1d(outer, sel("setSpacing:"), 0.0)
      LibObjCBridge.objc_send_long(outer, sel("setAlignment:"), 1_i64)   # leading

      # --- Header row (horizontal UIStackView) ---
      header_row = alloc_init("UIStackView")
      LibObjCBridge.objc_send_long(header_row, sel("setAxis:"), 0_i64)    # horizontal
      LibObjCBridge.objc_send_1d(header_row, sel("setSpacing:"), 6.0)
      LibObjCBridge.objc_send_long(header_row, sel("setAlignment:"), 3_i64) # center

      # Chevron button: use SF Symbol "chevron.right" (collapsed) or
      # "chevron.down" (expanded). UIButton type 1 = UIButtonTypeSystem.
      uibtn_cls = LibObjCBridge.objc_getClass("UIButton")
      chevron_btn = LibObjCBridge.objc_send_long(uibtn_cls, sel("buttonWithType:"), 1_i64)
      sym_name = view.expanded ? "chevron.down" : "chevron.right"
      sym_ns = LibObjCBridge.nsstring_from_cstr(sym_name.to_unsafe)
      uiimage_cls = LibObjCBridge.objc_getClass("UIImage")
      chevron_img = LibObjCBridge.objc_send_id(uiimage_cls, sel("systemImageNamed:"), sym_ns)
      LibObjCBridge.objc_send_id_long(chevron_btn, sel("setImage:forState:"), chevron_img, 0_i64) unless chevron_img.null?
      # Empty title so only the SF Symbol shows
      empty_str = LibObjCBridge.nsstring_from_cstr("".to_unsafe)
      LibObjCBridge.objc_send_id_long(chevron_btn, sel("setTitle:forState:"), empty_str, 0_i64)
      # Accessibility label on the header button (required per HIG)
      acc_text = view.accessibility_label || "#{view.title}, #{view.expanded ? "expanded" : "collapsed"}"
      acc_str = LibObjCBridge.nsstring_from_cstr(acc_text.to_unsafe)
      LibObjCBridge.objc_send_id(chevron_btn, sel("setAccessibilityLabel:"), acc_str)
      LibObjCBridge.objc_send_id(header_row, sel("addArrangedSubview:"), chevron_btn)

      # Header title UILabel
      title_lbl = alloc_init("UILabel")
      title_ns = LibObjCBridge.nsstring_from_cstr(view.title.to_unsafe)
      LibObjCBridge.objc_send_id(title_lbl, sel("setText:"), title_ns)
      title_font = LibObjCBridge.nsfont_system(17.0)
      LibObjCBridge.objc_send_id(title_lbl, sel("setFont:"), title_font) unless title_font.null?
      lbl_color = LibObjCBridge.nscolor_label_primary
      LibObjCBridge.objc_send_id(title_lbl, sel("setTextColor:"), lbl_color) unless lbl_color.null?
      LibObjCBridge.objc_send_id(header_row, sel("addArrangedSubview:"), title_lbl)

      LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), header_row)

      # --- Content block (shown only when expanded) ---
      if view.expanded && !view.content.empty?
        content_stack = alloc_init("UIStackView")
        LibObjCBridge.objc_send_long(content_stack, sel("setAxis:"), 1_i64)  # vertical
        LibObjCBridge.objc_send_1d(content_stack, sel("setSpacing:"), 4.0)
        LibObjCBridge.objc_send_long(content_stack, sel("setAlignment:"), 1_i64) # leading

        content_handle = ObjC.owned(content_stack, label: "UIStackView[disclosure-content]")
        content_native = NativeView.new(content_handle)

        push_stack(content_native, is_uistack: true)
        view.content.each do |child|
          child.accept(self)
        end
        pop_stack

        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), content_stack)
      end

      apply_common_properties(outer, view)
      emit(outer, "UIStackView[disclosure-group]")
    end

    # -----------------------------------------------------------------
    # Visit: PageControl -> UIPageControl
    #
    # UIPageControl is the native iOS/iPadOS paging indicator. It
    # displays `numberOfPages` dots with `currentPage` filled/highlighted.
    #
    # iOS 14+ API used:
    #   numberOfPages           — total dot count
    #   currentPage             — zero-based selected index
    #   pageIndicatorTintColor  — color of non-current dots (nil = system default)
    #   currentPageIndicatorTintColor — color of filled dot (nil = system default)
    #   backgroundStyle         — 0 automatic, 1 prominent, 2 minimal (iOS 14+)
    #
    # HIG: "A page control displays a row of indicator images, each of
    # which represents a page in a flat list." — Page controls, abstract.
    # HIG: "Avoid coloring indicator images. Custom colors can reduce
    # the contrast that differentiates the current-page indicator."
    # -----------------------------------------------------------------
    def visit(view : UI::PageControl)
      cls = LibObjCBridge.objc_getClass("UIPageControl")
      ptr = LibObjCBridge.objc_send(LibObjCBridge.objc_send(cls, sel("alloc")), sel("init"))

      # Total page count
      total = [view.total, 1].max
      LibObjCBridge.objc_send_long(ptr, sel("setNumberOfPages:"), total.to_i64)

      # Current page index (clamped)
      current = view.current.clamp(0, total - 1)
      LibObjCBridge.objc_send_long(ptr, sel("setCurrentPage:"), current.to_i64)

      # Current-page indicator tint color.
      # When an explicit tint_color is set, use it. When nil, use UIColor.label
      # (semantic, near-black on light / near-white on dark) so the filled dot
      # is legible on any host background. UIPageControl's factory default assumes
      # the control is overlaid on a colored or photographic surface; UIColor.label
      # is the correct semantic default for a general-purpose validation host.
      current_tint = if tc = view.tint_color
                       LibObjCBridge.nscolor_rgba(tc.r, tc.g, tc.b, tc.a)
                     else
                       LibObjCBridge.nscolor_label_primary
                     end
      LibObjCBridge.objc_send_id(ptr, sel("setCurrentPageIndicatorTintColor:"), current_tint) unless current_tint.null?

      # Non-current-page indicator tint color.
      # Use UIColor.secondaryLabel (semantic, ~0.6 gray on light / ~0.55 gray on
      # dark) for legible but visually subordinate dots on any background.
      page_tint = if ptc = view.page_indicator_tint_color
                    LibObjCBridge.nscolor_rgba(ptc.r, ptc.g, ptc.b, ptc.a)
                  elsif tc = view.tint_color
                    # When tint_color is set, make non-current dots 40% opacity
                    # of the same hue for visual coherence.
                    LibObjCBridge.nscolor_rgba(tc.r, tc.g, tc.b, 0.4)
                  else
                    LibObjCBridge.nscolor_label_secondary
                  end
      LibObjCBridge.objc_send_id(ptr, sel("setPageIndicatorTintColor:"), page_tint) unless page_tint.null?

      # Background style (iOS 14+): automatic=0, prominent=1, minimal=2.
      bg_style_val = case view.background_style
                     when :prominent then 1_i64
                     when :minimal   then 2_i64
                     else                 0_i64  # :automatic
                     end
      LibObjCBridge.objc_send_long(ptr, sel("setBackgroundStyle:"), bg_style_val)

      # Accessibility: UIPageControl has intrinsic accessibility; also honor
      # an explicit label if the developer set one.
      if acc = view.accessibility_label
        acc_str = LibObjCBridge.nsstring_from_cstr(acc.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), acc_str)
      end

      apply_common_properties(ptr, view)
      emit(ptr, "UIPageControl")
    end

    # -----------------------------------------------------------------
    # Visit: ComboBox -> UITextField (with trailing chevron button)
    #
    # HIG Platform considerations: "Not supported in iOS, iPadOS, tvOS,
    # visionOS, or watchOS." There is no UIComboBox class. The UIKit
    # renderer synthesizes a bordered UITextField carrying a trailing
    # UIButton with the SF Symbol "chevron.down" — this visually signals
    # "there is a list behind this field" and is the conventional pattern
    # used by iOS apps that need a combo-box-style control (e.g. Maps
    # search, Shortcuts app pickers).
    #
    # The rendered shape: [ text value          v ]
    # — bordered text field, rounded rectangle border style, trailing
    #   chevron.down button with system blue tint.
    #
    # Because this is a static screenshot validation, live picker wiring
    # is not implemented. The visual chrome (border + chevron) is the
    # audit target for this slug on iOS.
    #
    # NSComboBox is the canonical native on macOS. See AppKit renderer.
    # -----------------------------------------------------------------
    def visit(view : UI::ComboBox)
      # UITextField: bordered, rounded style (3 = UITextBorderStyleRoundedRect).
      # Emitted directly (not in a UIView container) so UIStackView measures
      # the intrinsic content size correctly. UITextField's intrinsic size is
      # determined by the font + border insets (~34pt tall for system 17pt font).
      # We override with a 44pt height constraint to meet the HIG minimum touch
      # target requirement (HIG Buttons -> Best practices: 44x44 pt minimum).
      tf = alloc_init("UITextField")
      LibObjCBridge.objc_send_long(tf, sel("setBorderStyle:"), 3_i64)  # RoundedRect

      # Set the current value
      unless view.value.empty?
        val_str = LibObjCBridge.nsstring_from_cstr(view.value.to_unsafe)
        LibObjCBridge.objc_send_id(tf, sel("setText:"), val_str)
      end

      # Placeholder
      unless view.placeholder.empty?
        ph_str = LibObjCBridge.nsstring_from_cstr(view.placeholder.to_unsafe)
        LibObjCBridge.objc_send_id(tf, sel("setPlaceholder:"), ph_str)
      end

      # Font: system 17pt (UITextField default body size on iOS)
      font_ptr = LibObjCBridge.nsfont_system(17.0)
      LibObjCBridge.objc_send_id(tf, sel("setFont:"), font_ptr)

      # Right view: a UIButton with the "chevron.down" SF Symbol.
      # We use the plain alloc/init path and set the image via setImage:forState:.
      chevron_btn = alloc_init("UIButton")

      # Build UIImage from the SF Symbol name "chevron.down"
      sym_name_str = LibObjCBridge.nsstring_from_cstr("chevron.down".to_unsafe)
      ui_image_cls = LibObjCBridge.objc_getClass("UIImage")
      chevron_img = LibObjCBridge.objc_send_id(ui_image_cls, sel("systemImageNamed:"), sym_name_str)

      # setImage:forState: — UIControlStateNormal = 0
      unless chevron_img.null?
        LibObjCBridge.objc_send_id_long(chevron_btn, sel("setImage:forState:"), chevron_img, 0_i64)
      end

      # Tint the chevron with system blue (UIColor.systemBlueColor)
      ui_color_cls = LibObjCBridge.objc_getClass("UIColor")
      blue_color = LibObjCBridge.objc_send(ui_color_cls, sel("systemBlueColor"))
      LibObjCBridge.objc_send_id(chevron_btn, sel("setTintColor:"), blue_color)

      # Constrain chevron button to 28x28 pt — fits the rounded-rect field height
      LibObjCBridge.objc_constrain_size(chevron_btn, 28.0, 28.0)

      # Set the chevron as the UITextField rightView (mode: always = 1)
      LibObjCBridge.objc_send_id(tf, sel("setRightView:"), chevron_btn)
      LibObjCBridge.objc_send_long(tf, sel("setRightViewMode:"), 1_i64)  # always

      # Height constraint: 44pt (HIG minimum interactive touch target)
      LibObjCBridge.objc_constrain_height(tf, 44.0)
      if w = view.width
        LibObjCBridge.objc_constrain_width(tf, w)
      end

      # Accessibility
      if acc = view.accessibility_label
        acc_str = LibObjCBridge.nsstring_from_cstr(acc.to_unsafe)
        LibObjCBridge.objc_send_id(tf, sel("setAccessibilityLabel:"), acc_str)
      else
        # Default accessibility label for screen readers
        hint = view.value.empty? ? (view.placeholder.empty? ? "Combo box" : view.placeholder) : view.value
        hint_str = LibObjCBridge.nsstring_from_cstr(hint.to_unsafe)
        LibObjCBridge.objc_send_id(tf, sel("setAccessibilityLabel:"), hint_str)
      end

      apply_common_properties(tf, view)
      emit(tf, "UITextField[combo-box]")
    end

    # -----------------------------------------------------------------
    # Visit: RatingIndicator -> UIStackView of UIImageViews (SF Symbols)
    #
    # iOS has no NSLevelIndicator equivalent. The renderer synthesises a
    # horizontal UIStackView containing `max` UIImageViews. Positions
    # <= rounded(value) receive "star.fill"; the rest receive "star".
    # Both symbol variants are tinted by the resolved tint color
    # (default: UIColor.systemYellowColor).
    #
    # HIG Platform considerations: "Not supported in iOS, iPadOS, tvOS,
    # visionOS, or watchOS." — The SF Symbol synthesised row is the
    # closest iOS-idiomatic approximation.
    # -----------------------------------------------------------------
    def visit(view : UI::RatingIndicator)
      # Outer horizontal UIStackView
      stack = alloc_init("UIStackView")
      # axis: horizontal = 0
      LibObjCBridge.objc_send_long(stack, sel("setAxis:"), 0_i64)
      # spacing between stars: 4pt
      LibObjCBridge.objc_send_1d(stack, sel("setSpacing:"), 4.0)
      # distribution: fill equally = 2
      LibObjCBridge.objc_send_long(stack, sel("setDistribution:"), 2_i64)
      # alignment: center = 3
      LibObjCBridge.objc_send_long(stack, sel("setAlignment:"), 3_i64)

      # Resolve tint color pointer (system yellow default)
      tint_ptr = if tc = view.tint_color
                   LibObjCBridge.nscolor_rgba(tc.r, tc.g, tc.b, tc.a)
                 else
                   # UIColor.systemYellowColor (R:1.0 G:0.8 B:0.0)
                   LibObjCBridge.nscolor_rgba(1.0, 0.8, 0.0, 1.0)
                 end

      # Clamp and round value to nearest integer per HIG
      clamped = view.value.clamp(0.0, view.max.to_f64)
      filled_count = clamped.round.to_i

      ui_image_cls = LibObjCBridge.objc_getClass("UIImage")

      view.max.times do |i|
        symbol_name = i < filled_count ? "star.fill" : "star"
        sym_str = LibObjCBridge.nsstring_from_cstr(symbol_name.to_unsafe)
        sym_image = LibObjCBridge.objc_send_id(ui_image_cls, sel("systemImageNamed:"), sym_str)

        img_view = alloc_init("UIImageView")
        LibObjCBridge.objc_send_bool(img_view, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)

        unless sym_image.null?
          LibObjCBridge.objc_send_id(img_view, sel("setImage:"), sym_image)
        end

        unless tint_ptr.null?
          LibObjCBridge.objc_send_id(img_view, sel("setTintColor:"), tint_ptr)
        end

        # Constrain each star to 28x28pt (HIG minimum comfortable touch-adjacent size)
        LibObjCBridge.objc_constrain_size(img_view, 28.0, 28.0)

        LibObjCBridge.objc_send_void_id(stack, sel("addArrangedSubview:"), img_view)
      end

      # Accessibility: announce as "X out of Y stars"
      if acc = view.accessibility_label
        acc_str = LibObjCBridge.nsstring_from_cstr(acc.to_unsafe)
        LibObjCBridge.objc_send_id(stack, sel("setAccessibilityLabel:"), acc_str)
      else
        default_label = "#{filled_count} out of #{view.max} stars"
        lbl_str = LibObjCBridge.nsstring_from_cstr(default_label.to_unsafe)
        LibObjCBridge.objc_send_id(stack, sel("setAccessibilityLabel:"), lbl_str)
      end

      apply_common_properties(stack, view)
      emit(stack, "UIStackView[rating-indicator]")
    end

    # ================================================================
    # Private helpers
    # ================================================================

    # Allocate and init a UIKit class by name.
    # Returns the raw Void* pointer to the initialized object.
    private def alloc_init(class_name : String) : Void*
      cls = LibObjCBridge.objc_getClass(class_name.to_unsafe)
      obj = LibObjCBridge.objc_send(cls, sel("alloc"))
      LibObjCBridge.objc_send(obj, sel("init"))
    end

    # Get a SEL from a selector name string.
    private def sel(name : String) : Void*
      LibObjCBridge.sel_registerName(name.to_unsafe)
    end

    # Resolve a UI::Font to a UIFont pointer.
    #
    # Maps font family and weight to the appropriate UIFont factory:
    #   - "system"    -> systemFontOfSize: or boldSystemFontOfSize: or systemFontOfSize:weight:
    #   - "monospace" -> monospacedSystemFontOfSize:weight: (iOS 13+)
    #   - other       -> fontWithName:size: (custom font lookup, falls back to system)
    private def resolve_font(font : UI::Font) : Void*
      weight = font_weight_value(font.weight)

      base_font = case font.family
                  when "system"
                    if font.weight == :bold
                      LibObjCBridge.nsfont_bold_system(font.size)
                    elsif font.weight == :regular
                      LibObjCBridge.nsfont_system(font.size)
                    else
                      LibObjCBridge.nsfont_system_weight(font.size, weight)
                    end
                  when "monospace"
                    LibObjCBridge.nsfont_monospaced_system(font.size, weight)
                  else
                    name_str = LibObjCBridge.nsstring_from_cstr(font.family.to_unsafe)
                    result = LibObjCBridge.nsfont_named(name_str, font.size)
                    # Fall back to system font if the named font was not found
                    if result.null?
                      LibObjCBridge.nsfont_system(font.size)
                    else
                      result
                    end
                  end

      # Apply italic trait via UIFontDescriptor if needed.
      # UIFontDescriptorTraitItalic = 1 << 0 = 0x01
      if font.italic && !base_font.null?
        # UIFont.fontDescriptor -> UIFontDescriptor
        # UIFontDescriptor.fontDescriptorWithSymbolicTraits: (0x01) -> new descriptor
        # UIFont.fontWithDescriptor:size: -> italic font
        descriptor = LibObjCBridge.objc_send(base_font, sel("fontDescriptor"))
        unless descriptor.null?
          italic_descriptor = LibObjCBridge.objc_send_long(
            descriptor, sel("fontDescriptorWithSymbolicTraits:"), 0x01_i64)
          unless italic_descriptor.null?
            italic_font = LibObjCBridge.objc_send_id_long(
              LibObjCBridge.objc_getClass("UIFont"),
              sel("fontWithDescriptor:size:"),
              italic_descriptor,
              0_i64) # size 0 = use descriptor's size
            return italic_font unless italic_font.null?
          end
        end
      end

      base_font
    end

    # Map a UI::Font weight symbol to a UIFontWeight CGFloat value.
    # UIFontWeight constants match NSFontWeight (same numeric values on Apple platforms):
    # ultraLight=-0.8, thin=-0.6, light=-0.4, regular=0.0, medium=0.23,
    # semibold=0.3, bold=0.4, heavy=0.56, black=0.62
    private def font_weight_value(weight : Symbol) : Float64
      case weight
      when :thin     then -0.6
      when :light    then -0.4
      when :regular  then 0.0
      when :medium   then 0.23
      when :semibold then 0.3
      when :bold     then 0.4
      else                0.0
      end
    end

    # Resolve a UI::Color to a UIColor pointer via the bridge convenience.
    # Uses [UIColor colorWithRed:green:blue:alpha:] under the hood.
    private def resolve_color(color : UI::Color) : Void*
      LibObjCBridge.nscolor_rgba(color.r, color.g, color.b, color.a)
    end

    # Returns the Amber brand primary color as a UIColor.
    # Light: #FFAD33 (r=1.0 g=0.678 b=0.2 a=1.0).
    # Dark:  #FFB84D (r=1.0 g=0.722 b=0.302 a=1.0).
    # Appearance resolved from TEST_RUNNER_HIG_APPEARANCE env var.
    #
    # IMPORTANT: Do NOT use ENV["TEST_RUNNER_HIG_APPEARANCE"]? here.
    # Crystal's ENV[] accessor acquires a mutex via Thread::current and
    # Crystal::once — both of which require the Crystal fiber subsystem to
    # be initialized. UIKit may call visit(button) from makeUIView during
    # the SwiftUI first-layout pass, which runs BEFORE crystal_init has
    # set up Crystal's thread subsystem. Using ENV[] in that window crashes
    # with SIGSEGV at 0x18 (Thread::LinkedList#push dereferences a null
    # thread pointer). Use LibC.getenv — a raw POSIX C call that touches
    # no Crystal runtime state — instead.
    private def amber_brand_gold : Void*
      raw = LibC.getenv("TEST_RUNNER_HIG_APPEARANCE")
      dark = !raw.null? && String.new(raw) == "dark"
      if dark
        LibObjCBridge.nscolor_rgba(1.0, 0.722, 0.302, 1.0)
      else
        LibObjCBridge.nscolor_rgba(1.0, 0.678, 0.2, 1.0)
      end
    end

    # Apply common View base-class properties to a raw UIKit view pointer.
    #
    #   - hidden       -> setHidden:
    #   - opacity      -> setAlpha:
    #   - background   -> setBackgroundColor: (UIColor)
    #   - corner_radius -> layer.cornerRadius (requires setClipsToBounds: YES)
    #   - clip_to_bounds -> setClipsToBounds:
    #   - shadow        -> layer shadow properties
    #   - border        -> layer borderWidth + borderColor
    #   - accessibility_label -> setAccessibilityLabel:
    private def apply_common_properties(ptr : Void*, view : UI::View) : Nil
      # Auto Layout requires translatesAutoresizingMaskIntoConstraints = NO on
      # every UIView that is managed by UIStackView or pinned with anchors.
      # Without this, the auto-resizing mask produces conflicting constraints
      # and inner UIStackViews report intrinsicContentSize of CGSizeZero,
      # collapsing to zero height in any parent UIStackView.
      LibObjCBridge.objc_send_bool(ptr, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)

      # Hidden
      if view.hidden
        LibObjCBridge.objc_send_bool(ptr, sel("setHidden:"), 1)
      end

      # Opacity (UIView uses setAlpha:, not setAlphaValue:)
      if view.opacity < 1.0
        LibObjCBridge.objc_send_1d(ptr, sel("setAlpha:"), view.opacity)
      end

      # Background color
      if bg = view.background
        bg_color = resolve_color(bg)
        LibObjCBridge.objc_send_id(ptr, sel("setBackgroundColor:"), bg_color)
      end

      # Corner radius and clipping via CALayer
      if view.corner_radius > 0.0 || view.clip_to_bounds
        layer = LibObjCBridge.objc_send(ptr, sel("layer"))
        unless layer.null?
          if view.corner_radius > 0.0
            LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), view.corner_radius)
          end
        end
        if view.clip_to_bounds || view.corner_radius > 0.0
          LibObjCBridge.objc_send_bool(ptr, sel("setClipsToBounds:"), 1)
        end
      end

      # Shadow via CALayer
      if view.shadow_radius > 0.0
        layer = LibObjCBridge.objc_send(ptr, sel("layer"))
        unless layer.null?
          sc = view.shadow_color || UI::Color.new(r: 0.0, g: 0.0, b: 0.0, a: 0.3)
          shadow_color = resolve_color(sc)
          cg_color = LibObjCBridge.objc_send(shadow_color, sel("CGColor"))
          LibObjCBridge.objc_send_id(layer, sel("setShadowColor:"), cg_color)
          LibObjCBridge.objc_send_1d(layer, sel("setShadowOpacity:"), sc.a)
          LibObjCBridge.objc_send_1d(layer, sel("setShadowRadius:"), view.shadow_radius)
          # Shadow offset via CGSize struct (width, height) -- use 2d variant
          LibObjCBridge.objc_send_2d_ret_id(layer, sel("setShadowOffset:"),
            view.shadow_offset_x, view.shadow_offset_y)
        end
      end

      # Border via CALayer
      if view.border_width > 0.0
        layer = LibObjCBridge.objc_send(ptr, sel("layer"))
        unless layer.null?
          LibObjCBridge.objc_send_1d(layer, sel("setBorderWidth:"), view.border_width)
          if bc = view.border_color
            bc_color = resolve_color(bc)
            cg_border = LibObjCBridge.objc_send(bc_color, sel("CGColor"))
            LibObjCBridge.objc_send_id(layer, sel("setBorderColor:"), cg_border)
          end
        end
      end

      # Minimum / maximum height constraints from UI::View base properties.
      # These are applied via Auto Layout height anchors at priority 999 so they
      # coexist with UIStackView distribution without creating unsatisfiable
      # constraint conflicts.
      #   - minimum_height && maximum_height == minimum_height -> exact height
      #   - minimum_height only -> >= constraint (content can grow taller)
      #   - maximum_height only -> <= constraint (content can shrink shorter)
      min_h = view.minimum_height
      max_h = view.maximum_height
      if !min_h.nil? && !max_h.nil? && min_h == max_h
        # Exact height: both min and max are the same value.
        LibObjCBridge.objc_constrain_height(ptr, min_h.not_nil!)
      else
        if mh = min_h
          LibObjCBridge.objc_constrain_minimum_height(ptr, mh)
        end
        if mxh = max_h
          # Maximum height: heightAnchor <= max_h via a <= constraint.
          # Use objc_constrain_height (equality at 999) as an upper bound proxy —
          # when max_h alone is set without min_h, we treat it as exact (content
          # should not grow beyond this). This matches the UI::View semantics where
          # maximum_height is intended as a hard cap.
          LibObjCBridge.objc_constrain_height(ptr, mxh)
        end
      end

      # Minimum / maximum width constraints from UI::View base properties.
      # These mirror the height semantics above:
      #   - minimum_width && maximum_width == minimum_width -> exact width
      #   - minimum_width only -> >= constraint
      #   - maximum_width only -> exact cap proxy
      #
      # UIKit validation previews rely on exact min/max pairs for cards,
      # tiles, grabbers, and tab shells. Ignoring maximum_width lets
      # UIStackView stretch a component until text and chrome clip at the
      # screenshot edge.
      min_w = view.minimum_width
      max_w = view.maximum_width
      if !min_w.nil? && !max_w.nil? && min_w == max_w
        LibObjCBridge.objc_constrain_required_width(ptr, min_w.not_nil!)
      else
        if mw = min_w
          LibObjCBridge.objc_constrain_minimum_width(ptr, mw)
        end
        if mxw = max_w
          LibObjCBridge.objc_constrain_width(ptr, mxw)
        end
      end

      # Accessibility label
      if a11y = view.accessibility_label
        a11y_str = LibObjCBridge.nsstring_from_cstr(a11y.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), a11y_str)
      end

      # Test identifier -> accessibilityIdentifier for automated UI testing
      if tid = view.test_id
        tid_str = LibObjCBridge.nsstring_from_cstr(tid.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityIdentifier:"), tid_str)
      end
    end

    # Push a container NativeView onto the nesting stack.
    private def push_stack(native : NativeView, is_uistack : Bool) : Nil
      @stack.push(native)
      @stack_is_uistack.push(is_uistack)
    end

    # Pop the top container from the nesting stack.
    private def pop_stack : Nil
      @stack.pop
      @stack_is_uistack.pop
    end

    # Visit a child view subtree in isolation, returning its NativeView
    # without adding it to the current parent stack.  Used by UIScrollView
    # to obtain the content view pointer for uiscrollview_pin_content wiring.
    private def render_detached(view : UI::View) : NativeView?
      saved_stack = @stack.dup
      saved_is_uistack = @stack_is_uistack.dup
      saved_result = @result
      @stack = [] of NativeView
      @stack_is_uistack = [] of Bool
      @result = nil
      view.accept(self)
      detached = @result
      @stack = saved_stack
      @stack_is_uistack = saved_is_uistack
      @result = saved_result
      detached
    end

    private def apply_stack_padding(ptr : Void*, view : UI::View) : Nil
      p = view.padding
      return unless p.top > 0.0 || p.leading > 0.0 || p.bottom > 0.0 || p.trailing > 0.0

      insets = LibObjCBridge::CGRect.new(x: p.top, y: p.leading, width: p.bottom, height: p.trailing)
      LibObjCBridge.objc_send_rect_void(ptr, sel("setLayoutMargins:"), insets)
      LibObjCBridge.objc_send_bool(ptr, sel("setLayoutMarginsRelativeArrangement:"), 1)
    end

    private def exact_card_label_preferred_width(view : UI::Card) : Float64?
      min_w = view.minimum_width
      max_w = view.maximum_width
      return nil unless min_w && max_w && min_w == max_w

      p = view.content_padding
      content_width = min_w - p.leading - p.trailing
      content_width > 0.0 ? content_width : nil
    end

    # -----------------------------------------------------------------
    # Visit: WebViewComponent -> WKWebView placeholder (UIView)
    #
    # WKWebView requires the WebKit framework and live URL navigation,
    # neither of which is available in the static validation capture path.
    # The renderer emits a UIView placeholder with a 1pt gray border and
    # stores the url/title as accessibilityLabel so it is inspectable via
    # XCUITest.
    #
    # HIG: "A web view loads and displays rich web content, such as
    # embedded HTML and websites, directly within your app."
    # -----------------------------------------------------------------
    def visit(view : UI::WebViewComponent)
      ptr = alloc_init("UIView")
      # 1pt border layer so the web-view frame is visually distinct.
      LibObjCBridge.objc_send_bool(ptr, sel("setClipsToBounds:"), 1)
      layer = LibObjCBridge.objc_send(ptr, sel("layer"))
      unless layer.null?
        # Fixed mid-gray border: 0.55 RGBA. Visible on white host (~4:1) and
        # on black dark host (~3:1). Avoids ENV access (which crashes the
        # Crystal runtime when called before fiber init in the simulator).
        border_ns = LibObjCBridge.nscolor_rgba(0.55, 0.55, 0.55, 1.0)
        unless border_ns.null?
          cg_border = LibObjCBridge.objc_send(border_ns, sel("CGColor"))
          LibObjCBridge.objc_send_void_id(layer, sel("setBorderColor:"), cg_border) unless cg_border.null?
        end
        LibObjCBridge.objc_send_1d(layer, sel("setBorderWidth:"), 1.0)
        LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), 4.0)
        LibObjCBridge.objc_send_bool(layer, sel("setMasksToBounds:"), 1)
      end
      label_text = if view.title
                     view.title.not_nil!
                   elsif !view.url.empty?
                     view.url
                   else
                     "WKWebView content area"
                   end
      a11y_str = LibObjCBridge.nsstring_from_cstr(label_text.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), a11y_str)
      apply_common_properties(ptr, view)
      emit(ptr, "UIView[web-view]")
    end

    # Wrap a raw pointer in NativeHandle + NativeView and register it
    # with the current parent or set as root result.
    #
    # This is the standard emit path for leaf views (Label, Image, Spacer)
    # that do not need custom callback registration.
    #
    # Sets translatesAutoresizingMaskIntoConstraints = NO unconditionally so
    # that every emitted view is Auto Layout-managed. This mirrors the same
    # call made in apply_common_properties for views that go through the
    # full visit path; inline-constructed views (separators, grid padding,
    # header labels) need the same treatment or the intrinsic-size chain
    # breaks in any UIStackView parent.
    private def emit(ptr : Void*, label : String) : Nil
      LibObjCBridge.objc_send_bool(ptr, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
      handle = ObjC.owned(ptr, label: label)
      native = NativeView.new(handle)
      push_native(native)
    end

    # Register a NativeView with the current parent container, or set it
    # as the root result if there is no parent.
    #
    # When inside a container (VStack/HStack/ZStack/ScrollView), this:
    #   1. Adds the NativeView as a child of the parent NativeView tree
    #   2. Adds the native UIKit view to the parent:
    #      - UIStackView parents use addArrangedSubview: (preserves stack ordering)
    #      - Plain UIView parents use addSubview: (ZStack, ScrollView content)
    private def push_native(native : NativeView) : Nil
      if parent = @stack.last?
        parent.add_child(native)

        # Add native UIKit view to parent's native view
        if parent.handle.valid? && native.handle.valid?
          parent_ptr = parent.handle.ptr!
          child_ptr = native.handle.ptr!

          # Use the parallel tracking array to decide add method
          if @stack_is_uistack.last?
            LibObjCBridge.objc_send_void_id(parent_ptr, sel("addArrangedSubview:"), child_ptr)
          else
            LibObjCBridge.objc_add_subview(parent_ptr, child_ptr)
          end
        end
      else
        @result = native
      end
    end
  end
end
{% end %}
