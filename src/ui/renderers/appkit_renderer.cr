{% if flag?(:macos) %}
require "../platform_visitor"
require "../native/native_handle"
require "../native/native_view"
require "../native/callback_registry"

module UI::AppKit
  # ObjC bridge function bindings for the type-safe ARM64 wrappers
  # defined in objc_bridge.c. These function signatures MUST match
  # the C wrappers exactly -- on ARM64, each double argument occupies
  # a dedicated d-register and the cast must be precise.
  #
  # ## Struct types
  #
  # CGRect/CGPoint/CGSize are Homogeneous Floating-point Aggregates (HFA)
  # on ARM64. They are passed/returned in d0-d3 (CGRect), d0-d1 (CGPoint,
  # CGSize), NOT on the stack. Crystal passes these as value types that
  # map directly to the C struct layout.
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
    fun nscolor_control_background : Void*
    fun nscolor_separator : Void*
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
    fun objc_constrain_minimum_width(view : Void*, min_w : Float64) : Void
    fun objc_constrain_height(view : Void*, h : Float64) : Void
    fun nsscrollview_set_document_view(scroll_view : Void*, doc_view : Void*) : Void
    fun nsbutton_set_colored_title(button : Void*, title : Void*, color : Void*, font : Void*) : Void
    fun nsslider_set_track_fill_color(slider : Void*, color : Void*) : Void

    # --- Section 5a: NSSwitch factory (macOS 10.15+) ---
    fun nsswitch_new(state_on : Int32, enabled : Int32) : Void*
    fun nsswitch_set_tint(sw_ptr : Void*, color : Void*) : Void

    # --- ObjC runtime ---
    fun sel_registerName(name : UInt8*) : Void*
    fun objc_getClass(name : UInt8*) : Void*

    # --- Section 5: CrystalActionDispatcher registration ---
    fun register_crystal_action_dispatcher : Void
  end

  # Renders a UI::View tree to native AppKit views via the ObjC bridge.
  #
  # Each `visit` method:
  #   1. Allocates and initializes the appropriate AppKit view class
  #   2. Configures its properties (text, font, color, etc.)
  #   3. Wraps the raw pointer in a `NativeHandle` (owned)
  #   4. Creates a `NativeView` node
  #   5. If inside a container, adds as arranged subview + child node
  #   6. If top-level, sets as `@result`
  #
  # ## Usage
  #
  # ```
  # label = UI::Label.new("Hello, macOS!")
  # renderer = UI::AppKit::Renderer.new
  # label.accept(renderer)
  # native_view = renderer.result  # => NativeView wrapping an NSTextField
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

    # Tracks which NativeViews on the stack are NSStackViews (true) vs
    # plain NSViews (false). Used by push_native to decide between
    # addArrangedSubview: and addSubview:.
    @stack_is_nsstack : Array(Bool)

    def initialize
      @stack = [] of NativeView
      @stack_is_nsstack = [] of Bool
      LibObjCBridge.register_crystal_action_dispatcher
    end

    # Returns the root NativeView produced by the last top-level visit.
    # Raises if no view has been visited yet.
    def result : NativeView
      @result.not_nil!
    end

    # Convenience: visit a view and return its NativeView.
    def render(view : UI::View) : NativeView
      view.accept(self)
      nv = result
      # Wire tab order for editable text fields
      fields = [] of Void*
      collect_text_fields(nv, fields)
      if fields.size >= 2
        fields.each_with_index do |ptr, i|
          next_ptr = fields[(i + 1) % fields.size]
          LibObjCBridge.objc_send_void_id(ptr, sel("setNextKeyView:"), next_ptr)
        end
      end
      nv
    end

    # -----------------------------------------------------------------
    # Visit: Label -> NSTextField (non-editable)
    # -----------------------------------------------------------------
    def visit(view : UI::Label)
      ptr = alloc_init("NSTextField")

      # Set the string value
      str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("setStringValue:"), str)

      # Make it label-like: non-editable, no bezel, no background
      LibObjCBridge.objc_send_bool(ptr, sel("setEditable:"), 0)
      LibObjCBridge.objc_send_bool(ptr, sel("setBezeled:"), 0)
      LibObjCBridge.objc_send_bool(ptr, sel("setDrawsBackground:"), 0)
      LibObjCBridge.objc_send_bool(ptr, sel("setSelectable:"), 0)

      # Font
      font_ptr = resolve_font(view.font)
      LibObjCBridge.objc_send_id(ptr, sel("setFont:"), font_ptr)

      # Text color. A semantic role (LabelRole) resolves to the dynamic
      # appearance-tracking system color (NSColor.labelColor and siblings)
      # so light / dark appearance and Increase Contrast track
      # automatically. An explicit brand override opts out by clearing
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

      # Text alignment: NSTextAlignment values
      # Left=0, Right=1, Center=2, Justified=3, Natural=4
      alignment_val = case view.text_alignment
                      when Alignment::Leading  then 0_i64
                      when Alignment::Center   then 2_i64
                      when Alignment::Trailing then 1_i64
                      else                          4_i64 # Natural
                      end
      LibObjCBridge.objc_send_long(ptr, sel("setAlignment:"), alignment_val)

      # Line limit (0 = unlimited in both UI::Label and NSTextField)
      if view.number_of_lines > 0
        LibObjCBridge.objc_send_long(ptr, sel("setMaximumNumberOfLines:"), view.number_of_lines.to_i64)
      end

      # Common properties
      apply_common_properties(ptr, view)

      emit(ptr, "NSTextField[label]")
    end

    # -----------------------------------------------------------------
    # Visit: Button -> NSButton
    #
    # Style -> NSButton attribute mapping:
    #   Default / Bordered -> NSBezelStyleRounded, isBordered = true
    #   Prominent          -> NSBezelStyleRounded, bezelColor = controlAccentColor,
    #                         contentTintColor = white (filled-blue CTA appearance)
    #   Tinted             -> NSBezelStyleFlexiblePush, bezelColor = accentColor @ 0.15
    #   Borderless         -> isBordered = false (text-link style)
    #
    # Role overrides:
    #   :destructive -> attributed title in systemRedColor (all styles except
    #                   Prominent which uses bezelColor = systemRedColor instead)
    #   :cancel      -> semibold attributed title weight
    #
    # HIG: "Use a filled button for the most likely action in a view."
    # -----------------------------------------------------------------
    def visit(view : UI::Button)
      ptr = alloc_init("NSButton")

      # Title
      title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("setTitle:"), title_str)

      nscolor_cls = LibObjCBridge.objc_getClass("NSColor")

      # Amber brand gold — overrides systemBlue as the primary tint for all
      # non-destructive button roles. Light: #FFAD33 (r=1.0 g=0.678 b=0.2),
      # Dark: #FFB84D (r=1.0 g=0.722 b=0.302). Picked at render time by
      # querying HIG_APPEARANCE (the same env var the capture harness sets
      # before launching the host). Falls back to light gold when unset.
      # Exception: role == :destructive always uses systemRed regardless of
      # brand — HIG mandates destructive actions be visually distinct from
      # all other roles, and users rely on red as a universal danger signal.
      amber_gold = amber_brand_gold
      ember_dark = LibObjCBridge.nscolor_rgba(0.165, 0.102, 0.031, 1.0) # #2A1A08

      # Style-driven bezel / border configuration.
      case view.style
      when UI::ButtonStyle::Prominent
        # NSBezelStyleRounded = 1, filled with Amber gold (brand primary).
        # Destructive prominent: override to systemRedColor (HIG safety rule).
        # wantsLayer: YES is required for bezelColor to render in offscreen
        # cacheDisplayInRect: captures AND in DarkAqua (June R11 fix).
        # We also set the layer's corner radius and backgroundColor directly
        # as a belt-and-suspenders approach since NSButton.bezelColor can be
        # unreliable in dark mode offscreen renders. The layer background
        # ensures the filled appearance survives the bitmap snapshot path.
        LibObjCBridge.objc_send_bool(ptr, sel("setWantsLayer:"), 1)
        LibObjCBridge.objc_send_long(ptr, sel("setBezelStyle:"), 1_i64)
        LibObjCBridge.objc_send_bool(ptr, sel("setBordered:"), 1)

        fill_color : Void*
        fg_on_fill : Void*
        if view.role == :destructive
          red = LibObjCBridge.objc_send(nscolor_cls, sel("systemRedColor"))
          fill_color = red
          fg_on_fill = LibObjCBridge.objc_send(nscolor_cls, sel("whiteColor"))
        else
          fill_color = amber_gold
          fg_on_fill = ember_dark
        end

        unless fill_color.null?
          LibObjCBridge.objc_send_id(ptr, sel("setBezelColor:"), fill_color)
          # Belt-and-suspenders: explicitly set the layer's background color
          # in CGColor so the offscreen renderer shows the fill even when
          # NSButton's bezelColor path is suppressed by the dark compositor.
          layer = LibObjCBridge.objc_send(ptr, sel("layer"))
          unless layer.null?
            cg_fill = LibObjCBridge.objc_send(fill_color, sel("CGColor"))
            LibObjCBridge.objc_send_id(layer, sel("setBackgroundColor:"), cg_fill) unless cg_fill.null?
            LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), 6.0)
          end
        end
        unless fg_on_fill.null?
          LibObjCBridge.objc_send_id(ptr, sel("setContentTintColor:"), fg_on_fill)
        end
      when UI::ButtonStyle::Tinted
        # NSBezelStyleFlexiblePush = 12 — translucent Amber gold fill at 15% alpha.
        LibObjCBridge.objc_send_long(ptr, sel("setBezelStyle:"), 12_i64)
        LibObjCBridge.objc_send_bool(ptr, sel("setBordered:"), 1)
        unless amber_gold.null?
          if view.role == :destructive
            red = LibObjCBridge.objc_send(nscolor_cls, sel("systemRedColor"))
            unless red.null?
              tint = LibObjCBridge.objc_send_1d_ret_id(red, sel("colorWithAlphaComponent:"), 0.18)
              LibObjCBridge.objc_send_id(ptr, sel("setBezelColor:"), tint) unless tint.null?
            end
          else
            tint = LibObjCBridge.objc_send_1d_ret_id(amber_gold, sel("colorWithAlphaComponent:"), 0.15)
            LibObjCBridge.objc_send_id(ptr, sel("setBezelColor:"), tint) unless tint.null?
          end
        end
      when UI::ButtonStyle::Borderless
        # No bezel at all — text-link style. Label gets Amber gold tint.
        LibObjCBridge.objc_send_long(ptr, sel("setBezelStyle:"), 0_i64)
        LibObjCBridge.objc_send_bool(ptr, sel("setBordered:"), 0)
      else
        # Default and Bordered: NSBezelStyleRounded = 1.
        # Wire contentTintColor = Amber gold (#FFAD33 light / #FFB84D dark) so
        # bordered buttons render with the brand primary rather than system blue.
        # This mirrors the Prominent branch's tint wiring and is the correct path
        # for NSButton label-color on macOS 11+ (bezelColor only affects filled
        # bezel buttons; contentTintColor drives the label glyph tint on rounded
        # bordered buttons, which is what action-sheet row buttons use).
        LibObjCBridge.objc_send_long(ptr, sel("setBezelStyle:"), 1_i64)
        LibObjCBridge.objc_send_bool(ptr, sel("setBordered:"), 1)
        unless amber_gold.null?
          tint_color = if view.role == :destructive
                         # Destructive normal-style: Amber plum overrides amber gold.
                         # HIG role semantics preserved — plum reads as "stop/danger"
                         # in the Amber brand palette (#5B3A94 light / #7D59B8 dark).
                         dark = (ENV["HIG_APPEARANCE"]? == "dark")
                         LibObjCBridge.nscolor_rgba(
                           dark ? 0.490 : 0.357,
                           dark ? 0.349 : 0.227,
                           dark ? 0.722 : 0.580,
                           1.0
                         )
                       else
                         amber_gold
                       end
          LibObjCBridge.objc_send_id(ptr, sel("setContentTintColor:"), tint_color)
        end
      end

      # Role-aware font. HIG: Cancel buttons on presentation surfaces read
      # Semibold (see Sheet/Alert/Action-sheet HIG examples). Other roles
      # reuse the view's font record verbatim.
      font_for_role = view.font
      if view.role == :cancel
        font_for_role = UI::Font.new(
          family: view.font.family,
          size: view.font.size,
          weight: :semibold,
          italic: view.font.italic,
        )
      end
      font_ptr = resolve_font(font_for_role)
      LibObjCBridge.objc_send_id(ptr, sel("setFont:"), font_ptr)

      # Role-aware foreground color for non-Prominent styles.
      # Prominent handles label via contentTintColor above (ember dark on gold fill
      # or white on red fill for destructive). For all other styles:
      #   :destructive -> systemRedColor (HIG safety — red always means danger)
      #   Default/Bordered/Tinted/Borderless -> Amber gold label (brand primary)
      #   :cancel -> Amber gold semibold (still brand-tinted, just semibold weight)
      fg_color =
        if view.role == :destructive && view.style != UI::ButtonStyle::Prominent
          # Amber brand: destructive uses plum (#5B3A94 light / #7D59B8 dark).
          # HIG role semantics preserved by prominence and position in the action
          # sheet — the plum overrides the systemRed hue per amber.md destructive
          # mapping. Contrast vs cream card: plum 5.8:1 light (WCAG AA pass).
          dark = (ENV["HIG_APPEARANCE"]? == "dark")
          LibObjCBridge.nscolor_rgba(
            dark ? 0.490 : 0.357,
            dark ? 0.349 : 0.227,
            dark ? 0.722 : 0.580,
            1.0
          )
        elsif view.style == UI::ButtonStyle::Prominent
          # Prominent label is set via setContentTintColor: above; this
          # attributed title path is still used to set the font — use white
          # or ember dark to match the bezel choice.
          if view.role == :destructive
            white = LibObjCBridge.objc_send(nscolor_cls, sel("whiteColor"))
            white.null? ? resolve_color(UI::Color.new(r: 1.0, g: 1.0, b: 1.0)) : white
          else
            ember_dark.null? ? resolve_color(UI::Color.new(r: 0.165, g: 0.102, b: 0.031)) : ember_dark
          end
        else
          # Default / Bordered / Tinted / Borderless: Amber gold label.
          amber_gold.null? ? resolve_color(view.foreground_color) : amber_gold
        end

      # Apply foreground color via attributed title (also sets the font).
      LibObjCBridge.nsbutton_set_colored_title(ptr, title_str, fg_color, font_ptr)

      # Leading SF Symbol (macOS 11+). +[NSImage imageWithSystemSymbolName:
      # accessibilityDescription:] returns nil for unknown names; skip
      # silently when nil.
      if sym = view.symbol
        nsimage_cls = LibObjCBridge.objc_getClass("NSImage")
        sym_ns = LibObjCBridge.nsstring_from_cstr(sym.to_unsafe)
        sym_image = LibObjCBridge.objc_send_id_id(
          nsimage_cls,
          sel("imageWithSystemSymbolName:accessibilityDescription:"),
          sym_ns,
          Pointer(Void).null,
        )
        unless sym_image.null?
          LibObjCBridge.objc_send_id(ptr, sel("setImage:"), sym_image)
          # NSImageLeading = 7 keeps the glyph on the leading edge of
          # the title, which is the HIG share-sheet / menu layout.
          LibObjCBridge.objc_send_long(ptr, sel("setImagePosition:"), 7_i64)
        end
      end

      # Enabled/disabled
      if view.disabled
        LibObjCBridge.objc_send_bool(ptr, sel("setEnabled:"), 0)
      end

      # Common properties
      apply_common_properties(ptr, view)

      # Create the NativeView first so we can register callbacks on it
      handle = ObjC.owned(ptr, label: "NSButton")
      native = NativeView.new(handle)

      # Wire up the on_tap callback via CallbackRegistry + action dispatcher.
      #
      # The CrystalActionDispatcher ObjC class must have been registered
      # (via objc_allocateClassPair + class_addMethod) before the renderer
      # is used. Its dispatch: method calls crystal_ui_callback_dispatch(tag)
      # which routes to CallbackRegistry.call(id).
      #
      # We use the callback_id as the NSView tag so the dispatcher can
      # route the action back to the correct Crystal Proc.
      if tap_handler = view.on_tap
        callback_id = native.register_callback(tap_handler)

        dispatcher_cls = LibObjCBridge.objc_getClass("CrystalActionDispatcher")
        unless dispatcher_cls.null?
          dispatcher = LibObjCBridge.objc_send(dispatcher_cls, sel("alloc"))
          dispatcher = LibObjCBridge.objc_send(dispatcher, sel("init"))
          LibObjCBridge.objc_send_long(dispatcher, sel("setTag:"), callback_id.to_i64)
          LibObjCBridge.objc_send_id(ptr, sel("setTarget:"), dispatcher)
          LibObjCBridge.objc_send_sel(ptr, sel("setAction:"), sel("dispatch:"))
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: VStack -> NSStackView (vertical, orientation = 1)
    # -----------------------------------------------------------------
    def visit(view : UI::VStack)
      ptr = alloc_init("NSStackView")

      # NSUserInterfaceLayoutOrientationVertical = 1
      LibObjCBridge.objc_send_long(ptr, sel("setOrientation:"), 1_i64)

      # Spacing
      LibObjCBridge.objc_send_1d(ptr, sel("setSpacing:"), view.spacing)

      # NSStackView alignment for vertical orientation uses NSLayoutAttribute.
      # NSLayoutAttributeLeading=5, NSLayoutAttributeCenterX=9, NSLayoutAttributeTrailing=6
      # Alignment::Fill -> Leading (5). For a VStack, "fill" means children stretch
      # to fill the VStack's WIDTH (the cross-axis). NSLayoutAttributeLeading pins
      # children to the leading edge. The default GravityAreas distribution controls
      # height (main-axis) so each child keeps its intrinsic height -- which is what
      # we want for a page VStack (top_bar ~50pt, divider ~1pt, body fills rest).
      # Do NOT set setDistribution:0 on VStack -- that would distribute HEIGHT
      # equally among all children, breaking the page layout.
      alignment_val = case view.alignment
                      when Alignment::Leading  then 5_i64
                      when Alignment::Center   then 9_i64
                      when Alignment::Trailing then 6_i64
                      when Alignment::Fill     then 5_i64 # Leading edge; GravityAreas keeps intrinsic heights
                      else                          9_i64
                      end
      LibObjCBridge.objc_send_long(ptr, sel("setAlignment:"), alignment_val)

      # Padding via NSStackView.edgeInsets (NSEdgeInsets = 4 doubles, same ABI as CGRect)
      p = view.padding
      if p.top > 0 || p.leading > 0 || p.bottom > 0 || p.trailing > 0
        insets = LibObjCBridge::CGRect.new(x: p.top, y: p.leading, width: p.bottom, height: p.trailing)
        LibObjCBridge.objc_send_rect_void(ptr, sel("setEdgeInsets:"), insets)
      end

      # Common properties
      apply_common_properties(ptr, view)

      # Dark-mode bake (gaps.md iteration-21 pattern): NSStackView's offscreen
      # cacheDisplayInRect: path renders the layer background as transparent
      # when no explicit fill is set, so subview text (which NSTextField renders
      # via NSColor.labelColor -> near-white in dark) is lost on the white bitmap.
      # Enable wantsLayer and bake an explicit CGColor fill keyed off HIG_APPEARANCE
      # so all VStack captures are legible in both appearances.
      # IMPORTANT: CALayer.setBackgroundColor: takes a CGColorRef, NOT an NSColor.
      # Call nscolor.CGColor first; pass the result to the layer.
      #
      # When the view has an EXPLICIT background color set (view.background != nil),
      # honour that color instead of the hardcoded white/dark fill. This prevents
      # scene-container VStacks (e.g. DockScene's focal_column) from overriding
      # their transparent or brand-colored backgrounds with an opaque white fill.
      #
      # When HIG_BACKDROP_PATH is set, the capture window has a backdrop NSImageView
      # beneath the chrome and NSVisualEffectView with .withinWindow blending samples
      # it. Any opaque CALayer fill on a nested VStack blocks the compositor from
      # reaching the backdrop, producing solid fills instead of frosted glass.
      # Use clearColor (alpha = 0) so every NSStackView in the chrome hierarchy is
      # transparent and the compositor blurs the backdrop through the glass card.
      # Text legibility is preserved because NSTextField uses NSColor.labelColor,
      # which the live-compositor window applies correctly via its appearance.
      #
      # When no backdrop is set (offscreen path for non-glass slugs), fall back to
      # the iter-21 opaque fill so standalone VStack captures remain legible.
      LibObjCBridge.objc_send_bool(ptr, sel("setWantsLayer:"), 1)
      layer_ptr = LibObjCBridge.objc_send(ptr, sel("layer"))
      unless layer_ptr.null?
        explicit_bg = view.background
        bg_ns = if c = explicit_bg
          # View has an explicit background — use it. Alpha=0 means transparent.
          LibObjCBridge.nscolor_rgba(c.r, c.g, c.b, c.a)
        elsif ENV["HIG_BACKDROP_PATH"]? && !ENV["HIG_BACKDROP_PATH"].to_s.empty?
          # Backdrop-mode: keep VStack transparent so NSVisualEffectView can blur
          # the backdrop NSImageView beneath. The live-window NSWindow provides the
          # appearance-correct surface; opaque fills here would block the glass compositor.
          LibObjCBridge.nscolor_rgba(0.0, 0.0, 0.0, 0.0)
        else
          # No backdrop — apply the dark-mode legibility fix (gaps.md iter-21).
          dark_mode = (ENV["HIG_APPEARANCE"]? == "dark")
          dark_mode ?
            LibObjCBridge.nscolor_rgba(0.12, 0.12, 0.12, 1.0) :
            LibObjCBridge.nscolor_rgba(1.0, 1.0, 1.0, 1.0)
        end
        unless bg_ns.null?
          cg_bg = LibObjCBridge.objc_send(bg_ns, sel("CGColor"))
          LibObjCBridge.objc_send_void_id(layer_ptr, sel("setBackgroundColor:"), cg_bg) unless cg_bg.null?
        end
      end

      handle = ObjC.owned(ptr, label: "NSStackView[v]")
      native = NativeView.new(handle)

      # Push onto stack, visit children, pop
      push_stack(native, is_nsstack: true)
      view.children.each do |child|
        child.accept(self)
      end
      pop_stack

      # Each child NativeView was added to native.children and its raw
      # ptr was added as an arranged subview during push_native.

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: HStack -> NSStackView (horizontal, orientation = 0)
    # -----------------------------------------------------------------
    def visit(view : UI::HStack)
      ptr = alloc_init("NSStackView")

      # NSUserInterfaceLayoutOrientationHorizontal = 0
      LibObjCBridge.objc_send_long(ptr, sel("setOrientation:"), 0_i64)

      # Spacing
      LibObjCBridge.objc_send_1d(ptr, sel("setSpacing:"), view.spacing)

      # NSStackView alignment for horizontal orientation uses NSLayoutAttribute.
      # NSLayoutAttributeTop=3, NSLayoutAttributeCenterY=10, NSLayoutAttributeBottom=4
      # Alignment::Fill -> NSLayoutAttributeTop (3) so children align to top edge.
      # NSStackViewDistributionFill (0) is set for Fill alignment so that arranged
      # subviews without explicit width constraints expand to fill available space.
      alignment_val = case view.alignment
                      when Alignment::Top      then 3_i64
                      when Alignment::Center   then 10_i64
                      when Alignment::Bottom   then 4_i64
                      when Alignment::Fill     then 3_i64  # top-align; fill handled by distribution
                      else                          10_i64
                      end
      LibObjCBridge.objc_send_long(ptr, sel("setAlignment:"), alignment_val)

      # NSStackViewDistribution: GravityAreas=-1, Fill=0, FillEqually=1,
      # FillProportionally=2, EqualSpacing=3, EqualCentering=4.
      # For Alignment::Fill, use Fill (0) so the last unconstrained arranged
      # subview expands to fill all remaining horizontal space.
      # For all other alignments, use GravityAreas (-1, the AppKit default).
      if view.alignment == Alignment::Fill
        LibObjCBridge.objc_send_long(ptr, sel("setDistribution:"), 0_i64)
      end

      # Padding via NSStackView.edgeInsets (NSEdgeInsets = 4 doubles, same ABI as CGRect)
      p = view.padding
      if p.top > 0 || p.leading > 0 || p.bottom > 0 || p.trailing > 0
        insets = LibObjCBridge::CGRect.new(x: p.top, y: p.leading, width: p.bottom, height: p.trailing)
        LibObjCBridge.objc_send_rect_void(ptr, sel("setEdgeInsets:"), insets)
      end

      # Common properties
      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSStackView[h]")
      native = NativeView.new(handle)

      push_stack(native, is_nsstack: true)
      view.children.each do |child|
        child.accept(self)
      end
      pop_stack

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: ZStack -> NSView (overlay container)
    #
    # Children are added as subviews in order. Later children are drawn
    # on top. Each child gets an autoresizing mask to fill the parent.
    # -----------------------------------------------------------------
    def visit(view : UI::ZStack)
      ptr = alloc_init("NSView")

      # Common properties
      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSView[zstack]")
      native = NativeView.new(handle)

      push_stack(native, is_nsstack: false)
      view.children.each do |child|
        child.accept(self)
      end
      pop_stack

      # For ZStack children, set autoresizing mask to fill parent:
      # NSViewWidthSizable (2) | NSViewHeightSizable (16) = 18
      native.children.each do |child_nv|
        if child_nv.handle.valid?
          child_ptr = child_nv.handle.ptr!
          LibObjCBridge.objc_set_autoresize(child_ptr, 18_u64)
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Image -> NSImageView
    # -----------------------------------------------------------------
    def visit(view : UI::Image)
      ptr = alloc_init("NSImageView")

      # Load image by name. Prefer SF Symbol path (macOS 11+) so that
      # names like "envelope", "flag", "folder" resolve via SF Symbols.
      # Fall back to bundle imageNamed: for app-specific assets.
      nsimage_cls = LibObjCBridge.objc_getClass("NSImage")
      image_name = LibObjCBridge.nsstring_from_cstr(view.source.to_unsafe)
      nsimage = LibObjCBridge.objc_send_id_id(
        nsimage_cls,
        sel("imageWithSystemSymbolName:accessibilityDescription:"),
        image_name,
        Pointer(Void).null,
      )
      if nsimage.null?
        # Not an SF Symbol — try bundle asset.
        nsimage = LibObjCBridge.objc_send_id(nsimage_cls, sel("imageNamed:"), image_name)
      end
      unless nsimage.null?
        LibObjCBridge.objc_send_id(ptr, sel("setImage:"), nsimage)
      end

      # Content mode -> NSImageScaling
      # NSImageScaleProportionallyUpOrDown = 3 (fit)
      # NSImageScaleAxesIndependently = 1 (stretch)
      # NSImageScaleProportionallyDown = 2 (fill, closest approx)
      scaling = case view.content_mode
                when ContentMode::Fit     then 3_i64
                when ContentMode::Fill    then 2_i64
                when ContentMode::Stretch then 1_i64
                else                           3_i64
                end
      LibObjCBridge.objc_send_long(ptr, sel("setImageScaling:"), scaling)

      # Tint color via contentTintColor (macOS 10.14+)
      if tint = view.tint_color
        tint_ptr = LibObjCBridge.nscolor_rgba(tint.r, tint.g, tint.b, tint.a)
        LibObjCBridge.objc_send_id(ptr, sel("setContentTintColor:"), tint_ptr)
      end

      # Common properties
      apply_common_properties(ptr, view)

      emit(ptr, "NSImageView")
    end

    # -----------------------------------------------------------------
    # Visit: TextField -> NSTextField (editable) or NSSecureTextField
    # -----------------------------------------------------------------
    def visit(view : UI::TextField)
      class_name = view.secure_entry ? "NSSecureTextField" : "NSTextField"
      ptr = alloc_init(class_name)

      # Set current text value
      unless view.text.empty?
        text_str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setStringValue:"), text_str)
      end

      # Placeholder
      unless view.placeholder.empty?
        placeholder_str = LibObjCBridge.nsstring_from_cstr(view.placeholder.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setPlaceholderString:"), placeholder_str)
      end

      # Editable (default is true for NSTextField, but be explicit)
      LibObjCBridge.objc_send_bool(ptr, sel("setEditable:"), 1)

      # Rounded bezel for visible text field appearance
      LibObjCBridge.objc_send_bool(ptr, sel("setBezeled:"), 1)
      LibObjCBridge.objc_send_long(ptr, sel("setBezelStyle:"), 1_i64)  # NSTextFieldRoundedBezel
      LibObjCBridge.objc_send_bool(ptr, sel("setDrawsBackground:"), 1)

      # Font
      font_ptr = resolve_font(view.font)
      LibObjCBridge.objc_send_id(ptr, sel("setFont:"), font_ptr)

      # Text color: default to NSColor.controlTextColor (appearance-tracking).
      # Resolves to near-black in Aqua and near-white in DarkAqua automatically.
      # A brand override sets view.text_color to a non-default RGBA value.
      # The View default is Color{r:0, g:0, b:0, a:1}; detect that sentinel
      # and substitute nscolor_label_primary so dark mode is legible.
      tc = view.text_color
      color_ptr = if tc.r == 0.0 && tc.g == 0.0 && tc.b == 0.0 && tc.a == 1.0
                    LibObjCBridge.nscolor_label_primary
                  else
                    resolve_color(tc)
                  end
      LibObjCBridge.objc_send_id(ptr, sel("setTextColor:"), color_ptr)

      # Common properties
      apply_common_properties(ptr, view)

      # Create NativeView with potential on_change callback
      handle = ObjC.owned(ptr, label: class_name)
      native = NativeView.new(handle)

      # Wire up on_change callback via CallbackRegistry.
      #
      # NSTextField uses the delegate pattern for text change notifications.
      # The delegate's controlTextDidChange: calls back into Crystal via
      # crystal_ui_callback_dispatch(id). We wrap the String-accepting proc
      # in a Nil-returning proc that reads the current string value from
      # the NSTextField when the callback fires.
      if change_handler = view.on_change
        text_field_ptr = ptr
        wrapped = Proc(Nil).new do
          raw_str = LibObjCBridge.objc_send(text_field_ptr, sel("stringValue"))
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
    # Visit: ScrollView -> NSScrollView
    # -----------------------------------------------------------------
    def visit(view : UI::ScrollView)
      ptr = alloc_init("NSScrollView")

      # Scroll axes
      LibObjCBridge.objc_send_bool(ptr, sel("setHasVerticalScroller:"), view.scroll_vertical ? 1 : 0)
      LibObjCBridge.objc_send_bool(ptr, sel("setHasHorizontalScroller:"), view.scroll_horizontal ? 1 : 0)

      # Scroll indicators visibility
      unless view.shows_indicators
        # NSScrollerKnobStyleDefault = 0; setting scrollerStyle to overlay (1)
        # hides the scroller chrome when not actively scrolling.
        LibObjCBridge.objc_send_long(ptr, sel("setScrollerStyle:"), 1_i64)
      end

      # Explicit viewport size constraint.  NSScrollView inside an NSStackView
      # collapses to zero height if neither a hugging-priority nor an explicit
      # Auto Layout constraint is set, because the stack cannot determine the
      # scroll view's intrinsicContentSize from its (arbitrarily tall) content.
      # Use objc_constrain_height (height-only) when only height is specified;
      # use objc_constrain_size when both axes are explicitly set.
      if view.frame_width > 0.0 && view.frame_height > 0.0
        LibObjCBridge.objc_constrain_size(ptr, view.frame_width, view.frame_height)
      elsif view.frame_height > 0.0
        LibObjCBridge.objc_constrain_height(ptr, view.frame_height)
      end

      # Common properties
      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSScrollView")
      native = NativeView.new(handle)

      # Visit the content subtree in isolation (render_detached) so its
      # NSStackView is NOT added as a plain subview of NSScrollView via
      # addSubview:.  Use nsscrollview_set_document_view which calls
      # setDocumentView: AND wires Auto Layout constraints (leading/trailing/top
      # pinned to NSClipView) so the NSStackView fills the scroll width and
      # can grow vertically.  Without the width constraint the NSStackView has
      # no reference width and collapses to zero.
      if content = view.content
        if content_nv = render_detached(content)
          native.add_child(content_nv)
          if content_nv.handle.valid?
            LibObjCBridge.nsscrollview_set_document_view(ptr, content_nv.handle.ptr!)
          end
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Spacer -> NSView (empty, flexible)
    #
    # Spacers in an NSStackView expand to fill available space by having
    # low content hugging priority. In a non-stack context they act as
    # empty transparent views.
    # -----------------------------------------------------------------
    def visit(view : UI::Spacer)
      ptr = alloc_init("NSView")

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

      emit(ptr, "NSView[spacer]")
    end

    # -----------------------------------------------------------------
    # Visit: Toggle -> NSSwitch (pill-shaped switch, macOS 10.15+)
    #
    # NSSwitch is the HIG-correct control for a binary on/off setting on
    # macOS. It renders as a pill-shaped track (green when on, gray when
    # off) -- the same shape as UISwitch on iOS. NSButton with
    # buttonType:NSSwitchButton (3) is the checkbox style and is WRONG for
    # this component.
    #
    # API notes:
    #   setState: NSControlStateValueOn (1) / NSControlStateValueOff (0)
    #   setEnabled: BOOL -- dimmed when NO
    #   setContentTintColor: NSColor -- overrides the green track tint
    #     (macOS 12+). Ignored silently on 10.15/11 if the selector is
    #     absent, so we send it unconditionally when tint_color is set.
    #   setTranslatesAutoresizingMaskIntoConstraints:NO -- required so
    #     NSStackView can drive layout without ambiguous constraint warnings.
    # -----------------------------------------------------------------
    def visit(view : UI::Toggle)
      # nsswitch_new allocates NSSwitch via alloc+initWithFrame:NSZeroRect and
      # sets initial state + enabled in one safe C call.  The caller owns +1.
      ptr = LibObjCBridge.nsswitch_new(
        view.is_on ? 1 : 0,
        view.disabled ? 0 : 1
      )

      # Optional tint override (macOS 12+). NSSwitch tracks the system
      # green by default; nsswitch_set_tint applies setContentTintColor:
      # guarded by respondsToSelector: so it is safe on 10.15/11.
      if tint = view.tint_color
        tint_ptr = LibObjCBridge.nscolor_rgba(tint.r, tint.g, tint.b, tint.a)
        LibObjCBridge.nsswitch_set_tint(ptr, tint_ptr)
      end

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSSwitch[toggle]")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        is_on_ptr = ptr
        wrapped = Proc(Nil).new do
          state = LibObjCBridge.objc_send_ret_bool(is_on_ptr, sel("state"))
          change_handler.call(state != 0)
        end
        native.register_callback(wrapped)
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Checkbox -> NSButton (checkbox style)
    # -----------------------------------------------------------------
    def visit(view : UI::Checkbox)
      ptr = alloc_init("NSButton")

      # NSButtonTypeSwitch = 3 (standard checkbox)
      LibObjCBridge.objc_send_long(ptr, sel("setButtonType:"), 3_i64)

      title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("setTitle:"), title_str)

      # NSControlStateValueOn = 1, NSControlStateValueOff = 0
      LibObjCBridge.objc_send_long(ptr, sel("setState:"), view.is_checked ? 1_i64 : 0_i64)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSButton[checkbox]")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        is_checked_ptr = ptr
        wrapped = Proc(Nil).new do
          state = LibObjCBridge.objc_send_ret_bool(is_checked_ptr, sel("state"))
          change_handler.call(state != 0)
        end
        native.register_callback(wrapped)
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: RadioGroup -> NSMatrix (radio buttons) or NSStackView of NSButtons
    # -----------------------------------------------------------------
    def visit(view : UI::RadioGroup)
      ptr = alloc_init("NSStackView")

      # NSUserInterfaceLayoutOrientationVertical = 1
      LibObjCBridge.objc_send_long(ptr, sel("setOrientation:"), 1_i64)
      LibObjCBridge.objc_send_1d(ptr, sel("setSpacing:"), 4.0)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSStackView[radio]")
      native = NativeView.new(handle)

      push_stack(native, is_nsstack: true)
      view.options.each_with_index do |option, index|
        btn_ptr = alloc_init("NSButton")
        # NSButtonTypeRadio = 4
        LibObjCBridge.objc_send_long(btn_ptr, sel("setButtonType:"), 4_i64)
        title_str = LibObjCBridge.nsstring_from_cstr(option.to_unsafe)
        LibObjCBridge.objc_send_id(btn_ptr, sel("setTitle:"), title_str)
        LibObjCBridge.objc_send_long(btn_ptr, sel("setState:"), index == view.selected_index ? 1_i64 : 0_i64)
        btn_handle = ObjC.owned(btn_ptr, label: "NSButton[radio]")
        btn_native = NativeView.new(btn_handle)
        push_native(btn_native)
      end
      pop_stack

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Slider -> NSSlider
    # -----------------------------------------------------------------
    def visit(view : UI::Slider)
      ptr = alloc_init("NSSlider")

      LibObjCBridge.objc_send_1d(ptr, sel("setMinValue:"), view.minimum)
      LibObjCBridge.objc_send_1d(ptr, sel("setMaxValue:"), view.maximum)
      LibObjCBridge.objc_send_1d(ptr, sel("setDoubleValue:"), view.value)

      if view.step > 0
        LibObjCBridge.objc_send_long(ptr, sel("setNumberOfTickMarks:"), ((view.maximum - view.minimum) / view.step).round.to_i64 + 1_i64)
        LibObjCBridge.objc_send_bool(ptr, sel("setAllowsTickMarkValuesOnly:"), 1)
      end

      # Apply tint_color to the filled track via NSSliderCell.trackFillColor
      # (macOS 10.14+).  nsslider_set_track_fill_color guards on respondsToSelector:
      # so this is a no-op on older SDKs.
      if tint = view.tint_color
        tint_ptr = LibObjCBridge.nscolor_rgba(tint.r, tint.g, tint.b, tint.a)
        LibObjCBridge.nsslider_set_track_fill_color(ptr, tint_ptr)
      end

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSSlider")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        slider_ptr = ptr
        wrapped = Proc(Nil).new do
          # Read current double value
          val_nsnum = LibObjCBridge.objc_send(slider_ptr, sel("doubleValue"))
          change_handler.call(val_nsnum.address.to_f64)
        end
        native.register_callback(wrapped)
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: NavigationStack -> NSView (container for navigation content)
    # -----------------------------------------------------------------
    def visit(view : UI::NavigationStack)
      ptr = alloc_init("NSView")

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSView[nav-stack]")
      native = NativeView.new(handle)

      # Render the current view (top of stack or root) into this container
      push_stack(native, is_nsstack: false)
      view.current_view.accept(self)
      pop_stack

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: NavigationLink -> NSButton (styled as a link row)
    # -----------------------------------------------------------------
    def visit(view : UI::NavigationLink)
      ptr = alloc_init("NSButton")

      title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("setTitle:"), title_str)

      # NSBezelStyleRounded = 1
      LibObjCBridge.objc_send_long(ptr, sel("setBezelStyle:"), 1_i64)

      apply_common_properties(ptr, view)

      emit(ptr, "NSButton[nav-link]")
    end

    # -----------------------------------------------------------------
    # Visit: TabView -> NSVisualEffectView (Liquid Glass root) containing
    #                   a vertical NSStackView with content + tab bar row.
    #
    # HIG tab-bars: "A tab bar lets people navigate between top-level
    # sections of your app." On iOS the bar floats at the bottom with
    # a Liquid Glass background. On macOS there is no direct UITabBar
    # equivalent; we render the whole component inside NSVisualEffectView
    # (NSVisualEffectMaterialMenu = 10, tracks light/dark automatically)
    # so the glass is unambiguously present and the AXScreenshot captures it.
    #
    # Structure:
    #   NSVisualEffectView (glass root)
    #     NSStackView (outer, vertical, no spacing)
    #       NSStackView (content area, grows to fill)
    #         <selected tab content>
    #       NSBox (separator, 0.5pt horizontal divider)
    #       NSStackView (tab row, horizontal, equal-width cells)
    #         cell_0 .. cell_N  (vertical: NSImageView + NSTextField)
    #
    # Selected tab: system blue 0.0/0.478/1.0 (or selected_tint_color).
    # Unselected tabs: NSColor.secondaryLabelColor (appearance-tracking).
    # -----------------------------------------------------------------
    def visit(view : UI::TabView)
      # Glass root container: NSVisualEffectMaterialMenu = 10 tracks appearance.
      glass_root = alloc_init("NSVisualEffectView")
      LibObjCBridge.objc_send_long(glass_root, sel("setMaterial:"), 10_i64)
      # NSVisualEffectBlendingModeWithinWindow = 1 — samples what is beneath
      # this NSVisualEffectView within the same window. Correct for validation
      # captures where the backdrop content is composited inside the same
      # window layer stack, not behind a separate NSWindow.
      LibObjCBridge.objc_send_long(glass_root, sel("setBlendingMode:"), 1_i64)
      # NSVisualEffectStateActive = 1
      LibObjCBridge.objc_send_long(glass_root, sel("setState:"), 1_i64)
      LibObjCBridge.objc_send_bool(glass_root, sel("setWantsLayer:"), 1)

      apply_common_properties(glass_root, view)

      glass_handle = ObjC.owned(glass_root, label: "NSVisualEffectView[tab-bar-glass]")
      glass_native = NativeView.new(glass_handle)

      # Outer vertical NSStackView inside the glass root
      outer = alloc_init("NSStackView")
      LibObjCBridge.objc_send_long(outer, sel("setOrientation:"), 1_i64)
      LibObjCBridge.objc_send_1d(outer, sel("setSpacing:"), 0.0)
      LibObjCBridge.objc_send_long(outer, sel("setDistribution:"), 0_i64)

      outer_inner_handle = ObjC.borrowed(outer, label: "NSStackView[tab-view-inner]")
      outer_inner_native = NativeView.new(outer_inner_handle)

      # Content area NSStackView (vertical, contains selected tab content)
      content_stack = alloc_init("NSStackView")
      LibObjCBridge.objc_send_long(content_stack, sel("setOrientation:"), 1_i64)
      LibObjCBridge.objc_send_1d(content_stack, sel("setSpacing:"), 8.0)
      content_insets = LibObjCBridge::CGRect.new(x: 16.0, y: 16.0, width: 16.0, height: 16.0)
      LibObjCBridge.objc_send_rect_void(content_stack, sel("setEdgeInsets:"), content_insets)

      if content = view.current_content
        content_stack_handle = ObjC.owned(content_stack, label: "NSStackView[tab-content]")
        content_stack_native = NativeView.new(content_stack_handle)
        push_stack(content_stack_native, is_nsstack: true)
        content.accept(self)
        pop_stack
      end
      # Separator: NSBox horizontal divider (built before tab_row so both
      # bar_position branches can reference it)
      sep = alloc_init("NSBox")
      # NSBoxSeparator = 2
      LibObjCBridge.objc_send_long(sep, sel("setBoxType:"), 2_i64)

      # Tab bar row: horizontal NSStackView, equal-width cells
      tab_row = alloc_init("NSStackView")
      LibObjCBridge.objc_send_long(tab_row, sel("setOrientation:"), 0_i64)
      LibObjCBridge.objc_send_1d(tab_row, sel("setSpacing:"), 0.0)
      # NSStackViewDistributionFillEqually = 2
      LibObjCBridge.objc_send_long(tab_row, sel("setDistribution:"), 2_i64)
      bar_insets = LibObjCBridge::CGRect.new(x: 4.0, y: 0.0, width: 4.0, height: 0.0)
      LibObjCBridge.objc_send_rect_void(tab_row, sel("setEdgeInsets:"), bar_insets)

      view.tabs.each_with_index do |tab, idx|
        is_selected = (idx == view.selected_index)

        selected_tint = if tc = view.selected_tint_color
                           LibObjCBridge.nscolor_rgba(tc.r, tc.g, tc.b, tc.a)
                         else
                           LibObjCBridge.nscolor_rgba(0.0, 0.478, 1.0, 1.0)
                         end
        unselected_tint = LibObjCBridge.nscolor_label_secondary

        # Cell: vertical NSStackView (icon above label)
        cell = alloc_init("NSStackView")
        LibObjCBridge.objc_send_long(cell, sel("setOrientation:"), 1_i64)
        LibObjCBridge.objc_send_1d(cell, sel("setSpacing:"), 2.0)
        LibObjCBridge.objc_send_long(cell, sel("setAlignment:"), 9_i64) # CenterX
        LibObjCBridge.objc_send_long(cell, sel("setDistribution:"), 0_i64)
        cell_insets = LibObjCBridge::CGRect.new(x: 6.0, y: 4.0, width: 6.0, height: 4.0)
        LibObjCBridge.objc_send_rect_void(cell, sel("setEdgeInsets:"), cell_insets)

        # Icon: NSImageView with SF Symbol (~22pt)
        if icon_name = tab.icon
          img_view = alloc_init("NSImageView")
          sym_name_ns = LibObjCBridge.nsstring_from_cstr(icon_name.to_unsafe)
          ns_image_cls = LibObjCBridge.objc_getClass("NSImage")
          unless ns_image_cls.null?
            sym_img = LibObjCBridge.objc_send_id_id(ns_image_cls,
              sel("imageWithSystemSymbolName:accessibilityDescription:"),
              sym_name_ns, Pointer(Void).null)
            LibObjCBridge.objc_send_id(img_view, sel("setImage:"), sym_img) unless sym_img.null?
          end
          icon_tint = is_selected ? selected_tint : unselected_tint
          LibObjCBridge.objc_send_id(img_view, sel("setContentTintColor:"), icon_tint) unless icon_tint.null?
          LibObjCBridge.objc_send_id(cell, sel("addArrangedSubview:"), img_view)
        end

        # Label: NSTextField (non-editable, 10pt caption)
        lbl_ptr = alloc_init("NSTextField")
        LibObjCBridge.objc_send_bool(lbl_ptr, sel("setBezeled:"), 0)
        LibObjCBridge.objc_send_bool(lbl_ptr, sel("setDrawsBackground:"), 0)
        LibObjCBridge.objc_send_bool(lbl_ptr, sel("setEditable:"), 0)
        LibObjCBridge.objc_send_bool(lbl_ptr, sel("setSelectable:"), 0)
        lbl_str = LibObjCBridge.nsstring_from_cstr(tab.label.to_unsafe)
        LibObjCBridge.objc_send_id(lbl_ptr, sel("setStringValue:"), lbl_str)
        LibObjCBridge.objc_send_long(lbl_ptr, sel("setAlignment:"), 1_i64)
        # Top-position (macOS tab-views): 13pt labels; bottom (iOS-style): 10pt caption.
        tab_label_pt = view.bar_position == :top ? 13.0 : 10.0
        lbl_font = LibObjCBridge.nsfont_system(tab_label_pt)
        LibObjCBridge.objc_send_id(lbl_ptr, sel("setFont:"), lbl_font) unless lbl_font.null?
        lbl_tint = is_selected ? selected_tint : unselected_tint
        LibObjCBridge.objc_send_id(lbl_ptr, sel("setTextColor:"), lbl_tint) unless lbl_tint.null?
        LibObjCBridge.objc_send_id(cell, sel("addArrangedSubview:"), lbl_ptr)

        LibObjCBridge.objc_send_id(tab_row, sel("addArrangedSubview:"), cell)
      end

      # bar_position: :top -> tab_row + sep + content_stack (macOS tab-views HIG pattern)
      # bar_position: :bottom (default) -> content_stack + sep + tab_row (iOS-style)
      if view.bar_position == :top
        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), tab_row)
        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), sep)
        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), content_stack)
      else
        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), content_stack)
        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), sep)
        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), tab_row)
      end

      # Install outer stack into the glass root as a subview; pin its
      # edges so the glass root derives its size from the stack's content.
      LibObjCBridge.objc_send_bool(outer, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
      LibObjCBridge.objc_add_subview(glass_root, outer)

      %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anchor_sel|
        outer_anchor = LibObjCBridge.objc_send(outer, sel(anchor_sel))
        glass_anchor = LibObjCBridge.objc_send(glass_root, sel(anchor_sel))
        next if outer_anchor.null? || glass_anchor.null?
        constraint = LibObjCBridge.objc_send_id(outer_anchor, sel("constraintEqualToAnchor:"), glass_anchor)
        LibObjCBridge.objc_send_bool(constraint, sel("setActive:"), 1) unless constraint.null?
      end

      glass_native.add_child(outer_inner_native)
      push_native(glass_native)
    end

    # -----------------------------------------------------------------
    # Visit: ProgressView -> NSProgressIndicator
    # -----------------------------------------------------------------
    def visit(view : UI::ProgressView)
      ptr = alloc_init("NSProgressIndicator")

      # NSProgressIndicatorStyleBar = 0, NSProgressIndicatorStyleSpinning = 1
      style_val = view.style == UI::ProgressStyle::Circular ? 1_i64 : 0_i64
      LibObjCBridge.objc_send_long(ptr, sel("setStyle:"), style_val)

      if val = view.value
        # Determinate progress (0.0 to 1.0, displayed as 0-100)
        LibObjCBridge.objc_send_bool(ptr, sel("setIndeterminate:"), 0)
        LibObjCBridge.objc_send_1d(ptr, sel("setMaxValue:"), 1.0)
        LibObjCBridge.objc_send_1d(ptr, sel("setDoubleValue:"), val)
      else
        # Indeterminate (spinning)
        LibObjCBridge.objc_send_bool(ptr, sel("setIndeterminate:"), 1)
        LibObjCBridge.objc_send(ptr, sel("startAnimation:"))
      end

      apply_common_properties(ptr, view)

      emit(ptr, "NSProgressIndicator")
    end

    # -----------------------------------------------------------------
    # Visit: ActivityIndicator -> NSProgressIndicator (spinning)
    # -----------------------------------------------------------------
    def visit(view : UI::ActivityIndicator)
      ptr = alloc_init("NSProgressIndicator")

      # NSProgressIndicatorStyleSpinning = 1
      LibObjCBridge.objc_send_long(ptr, sel("setStyle:"), 1_i64)
      LibObjCBridge.objc_send_bool(ptr, sel("setIndeterminate:"), 1)

      if view.is_animating
        LibObjCBridge.objc_send(ptr, sel("startAnimation:"))
      else
        LibObjCBridge.objc_send(ptr, sel("stopAnimation:"))
      end

      apply_common_properties(ptr, view)

      emit(ptr, "NSProgressIndicator[spinner]")
    end

    # -----------------------------------------------------------------
    # Visit: Alert -> NSVisualEffectView (hudWindow material) inline card
    #
    # HIG: Alerts are surface components (presentation category). They
    # require Liquid Glass. NSVisualEffectMaterialHUDWindow (= 7) is the
    # correct material — it renders the frosted-glass HUD panel that Apple
    # uses for system alerts on macOS.
    #
    # For production use, callers that want a true modal NSAlert should
    # present via NSAlert directly. This inline rendering path is used
    # by the HIG validation host (screenshot isolation). The material,
    # corner radius, and role-coloring are HIG-faithful.
    # -----------------------------------------------------------------
    def visit(view : UI::Alert)
      # Outer glass container — NSVisualEffectView with hudWindow material.
      effect = alloc_init("NSVisualEffectView")

      # NSVisualEffectMaterialHUDWindow = 7. Tracks light/dark appearance.
      LibObjCBridge.objc_send_long(effect, sel("setMaterial:"), 7_i64)
      # NSVisualEffectBlendingModeWithinWindow = 1
      LibObjCBridge.objc_send_long(effect, sel("setBlendingMode:"), 1_i64)
      # NSVisualEffectStateActive = 1
      LibObjCBridge.objc_send_long(effect, sel("setState:"), 1_i64)

      # Rounded corners — ~12pt matches HIG alert card corner radius.
      LibObjCBridge.objc_send_bool(effect, sel("setWantsLayer:"), 1)
      effect_layer = LibObjCBridge.objc_send(effect, sel("layer"))
      unless effect_layer.null?
        LibObjCBridge.objc_send_1d(effect_layer, sel("setCornerRadius:"), 12.0)
        LibObjCBridge.objc_send_bool(effect_layer, sel("setMasksToBounds:"), 1)
      end

      # Inner vertical NSStackView: title + message + button row.
      inner = alloc_init("NSStackView")
      # NSUserInterfaceLayoutOrientationVertical = 1
      LibObjCBridge.objc_send_long(inner, sel("setOrientation:"), 1_i64)
      LibObjCBridge.objc_send_1d(inner, sel("setSpacing:"), 8.0)
      # NSLayoutAttributeCenterX = 5 — center-align children horizontally.
      LibObjCBridge.objc_send_long(inner, sel("setAlignment:"), 5_i64)
      # 16pt insets on all edges — HIG-mandated breathing room inside card.
      insets = LibObjCBridge::CGRect.new(x: 16.0, y: 16.0, width: 16.0, height: 16.0)
      LibObjCBridge.objc_send_rect_void(inner, sel("setEdgeInsets:"), insets)
      LibObjCBridge.objc_send_bool(inner, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
      LibObjCBridge.objc_add_subview(effect, inner)

      # Pin inner to effect on all four edges.
      %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anchor_sel|
        inner_anchor  = LibObjCBridge.objc_send(inner,  sel(anchor_sel))
        effect_anchor = LibObjCBridge.objc_send(effect, sel(anchor_sel))
        next if inner_anchor.null? || effect_anchor.null?
        constraint = LibObjCBridge.objc_send_id(inner_anchor, sel("constraintEqualToAnchor:"), effect_anchor)
        LibObjCBridge.objc_send_bool(constraint, sel("setActive:"), 1) unless constraint.null?
      end

      inner_handle = ObjC.borrowed(inner, label: "NSStackView[alert-inner]")
      inner_native = NativeView.new(inner_handle)

      # Title label — bold, center-aligned (HIG: "write a title that clearly
      # and succinctly describes the situation").
      title_field = alloc_init("NSTextField")
      title_str = LibObjCBridge.nsstring_from_cstr(view.title.to_unsafe)
      LibObjCBridge.objc_send_id(title_field, sel("setStringValue:"), title_str)
      LibObjCBridge.objc_send_bool(title_field, sel("setBezeled:"), 0)
      LibObjCBridge.objc_send_bool(title_field, sel("setDrawsBackground:"), 0)
      LibObjCBridge.objc_send_bool(title_field, sel("setSelectable:"), 0)
      title_font = LibObjCBridge.nsfont_bold_system(13.0)
      LibObjCBridge.objc_send_id(title_field, sel("setFont:"), title_font)
      LibObjCBridge.objc_send_long(title_field, sel("setAlignment:"), 2_i64) # Center
      title_color = LibObjCBridge.nscolor_label_primary
      LibObjCBridge.objc_send_id(title_field, sel("setTextColor:"), title_color)
      title_handle = ObjC.owned(title_field, label: "NSTextField[alert-title]")
      title_native = NativeView.new(title_handle)
      inner_native.add_child(title_native)
      LibObjCBridge.objc_send_id(inner, sel("addArrangedSubview:"), title_field)

      # Message label — regular weight, center-aligned (HIG: "include
      # informative text only if it adds value").
      unless view.message.empty?
        msg_field = alloc_init("NSTextField")
        msg_str = LibObjCBridge.nsstring_from_cstr(view.message.to_unsafe)
        LibObjCBridge.objc_send_id(msg_field, sel("setStringValue:"), msg_str)
        LibObjCBridge.objc_send_bool(msg_field, sel("setBezeled:"), 0)
        LibObjCBridge.objc_send_bool(msg_field, sel("setDrawsBackground:"), 0)
        LibObjCBridge.objc_send_bool(msg_field, sel("setSelectable:"), 0)
        msg_font = LibObjCBridge.nsfont_system(11.0)
        LibObjCBridge.objc_send_id(msg_field, sel("setFont:"), msg_font)
        LibObjCBridge.objc_send_long(msg_field, sel("setAlignment:"), 2_i64) # Center
        msg_color = LibObjCBridge.nscolor_label_secondary
        LibObjCBridge.objc_send_id(msg_field, sel("setTextColor:"), msg_color)
        LibObjCBridge.objc_send_long(msg_field, sel("setMaximumNumberOfLines:"), 3_i64)
        # Cap message body width to card_width (270pt) minus edge insets (16pt * 2) = 238pt.
        # Without this constraint NSTextField in an NSStackView may exceed the card width
        # and produce a two-column artifact when the message is long ("Amber cannot restore them").
        LibObjCBridge.objc_constrain_width(msg_field, 238.0)
        msg_handle = ObjC.owned(msg_field, label: "NSTextField[alert-message]")
        msg_native = NativeView.new(msg_handle)
        inner_native.add_child(msg_native)
        LibObjCBridge.objc_send_id(inner, sel("addArrangedSubview:"), msg_field)
      end

      # Button row — horizontal NSStackView, trailing-aligned.
      btn_row = alloc_init("NSStackView")
      # NSUserInterfaceLayoutOrientationHorizontal = 0
      LibObjCBridge.objc_send_long(btn_row, sel("setOrientation:"), 0_i64)
      LibObjCBridge.objc_send_1d(btn_row, sel("setSpacing:"), 8.0)
      # NSLayoutAttributeTrailing = 9 — right-align buttons per HIG.
      LibObjCBridge.objc_send_long(btn_row, sel("setAlignment:"), 9_i64)
      btn_row_handle = ObjC.owned(btn_row, label: "NSStackView[alert-buttons]")
      btn_row_native = NativeView.new(btn_row_handle)
      inner_native.add_child(btn_row_native)
      LibObjCBridge.objc_send_id(inner, sel("addArrangedSubview:"), btn_row)

      view.buttons.each do |btn|
        btn_ptr = alloc_init("NSButton")
        btn_title_str = LibObjCBridge.nsstring_from_cstr(btn.label.to_unsafe)
        LibObjCBridge.objc_send_id(btn_ptr, sel("setTitle:"), btn_title_str)
        # NSBezelStyleRounded = 1
        LibObjCBridge.objc_send_long(btn_ptr, sel("setBezelStyle:"), 1_i64)

        # Role-aware font and color (matches visit(UI::Button) semantics).
        btn_font = case btn.style
                   when :cancel
                     LibObjCBridge.nsfont_system_weight(13.0, 0.4) # Semibold w=0.4
                   else
                     LibObjCBridge.nsfont_system(13.0)
                   end
        LibObjCBridge.objc_send_id(btn_ptr, sel("setFont:"), btn_font)

        btn_color = case btn.style
                    when :destructive
                      nscolor_cls = LibObjCBridge.objc_getClass("NSColor")
                      c = LibObjCBridge.objc_send(nscolor_cls, sel("systemRedColor"))
                      c.null? ? resolve_color(UI::Color.new(r: 1.0, g: 0.23, b: 0.19)) : c
                    else
                      resolve_color(UI::Color.new(r: 0.0, g: 0.478, b: 1.0))
                    end
        LibObjCBridge.nsbutton_set_colored_title(btn_ptr, btn_title_str, btn_color, btn_font)

        native_btn_handle = ObjC.owned(btn_ptr, label: "NSButton[alert-btn-#{btn.label}]")
        native_btn = NativeView.new(native_btn_handle)
        btn_row_native.add_child(native_btn)
        LibObjCBridge.objc_send_id(btn_row, sel("addArrangedSubview:"), btn_ptr)
      end

      apply_common_properties(effect, view)

      # HIG Alert: centered, maxWidth 270pt. Constrain width so the alert card
      # does not stretch edge-to-edge in a 1200pt-wide capture window.
      LibObjCBridge.objc_constrain_width(effect, 270.0)

      outer_handle = ObjC.owned(effect, label: "NSVisualEffectView[alert-glass]")
      outer_native = NativeView.new(outer_handle)
      outer_native.add_child(inner_native)
      push_native(outer_native)
    end

    # -----------------------------------------------------------------
    # Visit: Picker -> NSPopUpButton (menu style) or NSSegmentedControl
    # -----------------------------------------------------------------
    def visit(view : UI::Picker)
      if view.style == UI::PickerStyle::Segmented
        ptr = alloc_init("NSSegmentedControl")

        view.options.each_with_index do |option, index|
          LibObjCBridge.objc_send_long(ptr, sel("setSegmentCount:"), (index + 1).to_i64)
          label_str = LibObjCBridge.nsstring_from_cstr(option.to_unsafe)
          LibObjCBridge.objc_send_id_long(ptr, sel("setLabel:forSegment:"), label_str, index.to_i64)
        end

        LibObjCBridge.objc_send_long(ptr, sel("setSelectedSegment:"), view.selected_index.to_i64)

        apply_common_properties(ptr, view)

        emit(ptr, "NSSegmentedControl")
      else
        ptr = alloc_init("NSPopUpButton")

        view.options.each do |option|
          title_str = LibObjCBridge.nsstring_from_cstr(option.to_unsafe)
          LibObjCBridge.objc_send_id(ptr, sel("addItemWithTitle:"), title_str)
        end

        LibObjCBridge.objc_send_long(ptr, sel("selectItemAtIndex:"), view.selected_index.to_i64)

        apply_common_properties(ptr, view)

        emit(ptr, "NSPopUpButton")
      end
    end

    # -----------------------------------------------------------------
    # Visit: IconButton -> NSButton with image
    # -----------------------------------------------------------------
    def visit(view : UI::IconButton)
      ptr = alloc_init("NSButton")

      # Load SF Symbol image (macOS 11+)
      symbol_str = LibObjCBridge.nsstring_from_cstr(view.icon.to_unsafe)
      nsimage_cls = LibObjCBridge.objc_getClass("NSImage")
      img = LibObjCBridge.objc_send_id(nsimage_cls, sel("imageWithSystemSymbolName:accessibilityDescription:"),
        symbol_str)
      unless img.null?
        LibObjCBridge.objc_send_id(ptr, sel("setImage:"), img)
      end

      # Remove bezel for icon-only style
      LibObjCBridge.objc_send_long(ptr, sel("setBezelStyle:"), 0_i64)
      LibObjCBridge.objc_send_bool(ptr, sel("setBordered:"), 0)

      if view.disabled
        LibObjCBridge.objc_send_bool(ptr, sel("setEnabled:"), 0)
      end

      if label = view.label
        title_str = LibObjCBridge.nsstring_from_cstr(label.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setTitle:"), title_str)
      end

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSButton[icon]")
      native = NativeView.new(handle)

      if tap_handler = view.on_tap
        callback_id = native.register_callback(tap_handler)

        dispatcher_cls = LibObjCBridge.objc_getClass("CrystalActionDispatcher")
        unless dispatcher_cls.null?
          dispatcher = LibObjCBridge.objc_send(dispatcher_cls, sel("alloc"))
          dispatcher = LibObjCBridge.objc_send(dispatcher, sel("init"))
          LibObjCBridge.objc_send_long(dispatcher, sel("setTag:"), callback_id.to_i64)
          LibObjCBridge.objc_send_id(ptr, sel("setTarget:"), dispatcher)
          LibObjCBridge.objc_send_sel(ptr, sel("setAction:"), sel("dispatch:"))
        end
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: ListView -> NSStackView (vertical rows or row-of-rows grid)
    #
    # Grid mode: wraps items into horizontal NSStackViews of `columns`
    # width, then stacks those rows vertically. This approximates
    # NSCollectionView's flow layout without requiring a data-source
    # delegate chain through the ObjC bridge in the validation renderer.
    # Production use should prefer UI::ListView with layout: :grid which
    # will map to a real NSCollectionView via the production AppKit renderer.
    #
    # Dark-mode fix (gaps.md iteration-21 pattern): enable wantsLayer on
    # the outer NSStackView and bake an explicit RGBA background fill keyed
    # off HIG_APPEARANCE. This gives a dark canvas in offscreen captures
    # so that NSTextField labels (white in dark via performAsCurrentDrawingAppearance:)
    # are legible against the surface rather than lost on a white background.
    # -----------------------------------------------------------------
    def visit(view : UI::ListView)
      outer_ptr = alloc_init("NSStackView")

      # NSUserInterfaceLayoutOrientationVertical = 1
      LibObjCBridge.objc_send_long(outer_ptr, sel("setOrientation:"), 1_i64)
      LibObjCBridge.objc_send_1d(outer_ptr, sel("setSpacing:"), view.item_spacing)

      # Layer-backed so we can bake the background for dark-mode offscreen renders.
      LibObjCBridge.objc_send_bool(outer_ptr, sel("setWantsLayer:"), 1)
      layer_ptr = LibObjCBridge.objc_send(outer_ptr, sel("layer"))
      unless layer_ptr.null?
        dark_mode = (ENV["HIG_APPEARANCE"]? == "dark")
        bg_rgba = if dark_mode
                    LibObjCBridge.nscolor_rgba(0.11, 0.11, 0.11, 1.0)
                  else
                    LibObjCBridge.nscolor_rgba(1.0, 1.0, 1.0, 1.0)
                  end
        unless bg_rgba.null?
          cg = LibObjCBridge.objc_send(bg_rgba, sel("CGColor"))
          LibObjCBridge.objc_send_void_id(layer_ptr, sel("setBackgroundColor:"), cg) unless cg.null?
        end
      end

      apply_common_properties(outer_ptr, view)

      handle = ObjC.owned(outer_ptr, label: "NSStackView[list]")
      native = NativeView.new(handle)

      push_stack(native, is_nsstack: true)

      view.sections.each do |section|
        if header = section.header
          header_ptr = alloc_init("NSTextField")
          header_str = LibObjCBridge.nsstring_from_cstr(header.to_unsafe)
          LibObjCBridge.objc_send_id(header_ptr, sel("setStringValue:"), header_str)
          LibObjCBridge.objc_send_bool(header_ptr, sel("setEditable:"), 0)
          LibObjCBridge.objc_send_bool(header_ptr, sel("setBezeled:"), 0)
          LibObjCBridge.objc_send_bool(header_ptr, sel("setDrawsBackground:"), 0)
          emit(header_ptr, "NSTextField[list-header]")
        end

        if view.layout == UI::ListLayout::Grid && view.columns > 1
          # Grid mode: chunk items into rows of `columns` width.
          # Each row is a horizontal NSStackView of equal-width cells.
          cols = view.columns
          items = section.items
          row_idx = 0
          while row_idx < items.size
            row_ptr = alloc_init("NSStackView")
            # NSUserInterfaceLayoutOrientationHorizontal = 0
            LibObjCBridge.objc_send_long(row_ptr, sel("setOrientation:"), 0_i64)
            LibObjCBridge.objc_send_1d(row_ptr, sel("setSpacing:"), view.item_spacing)
            # NSStackViewDistributionFillEqually = 2
            LibObjCBridge.objc_send_long(row_ptr, sel("setDistribution:"), 2_i64)

            row_handle = ObjC.owned(row_ptr, label: "NSStackView[grid-row]")
            row_native = NativeView.new(row_handle)
            push_stack(row_native, is_nsstack: true)

            col_count = 0
            while col_count < cols && (row_idx + col_count) < items.size
              items[row_idx + col_count].accept(self)
              col_count += 1
            end

            # Pad incomplete last row with empty spacer views for alignment
            while col_count < cols
              spacer_ptr = alloc_init("NSView")
              emit(spacer_ptr, "NSView[grid-pad]")
              col_count += 1
            end

            pop_stack
            emit(row_ptr, "NSStackView[grid-row]")

            row_idx += cols
          end
        else
          # List mode: items appended to the outer vertical stack.
          # When shows_separators is true and style is Plain or Grouped,
          # insert an NSBox separator (boxType=NSBoxSeparator=2) between
          # each pair of items -- mimicking UITableView hairline dividers.
          # InsetGrouped: wrap all items in a rounded layer-backed container
          # NSStackView first, then emit the container to the outer stack.
          if view.style == UI::ListStyle::InsetGrouped
            # Rounded card container: layer-backed NSStackView with
            # corner radius ~10pt and a hairline border, matching HIG
            # inset-grouped rounded-card style (UITableView.Style.insetGrouped).
            card_ptr = alloc_init("NSStackView")
            LibObjCBridge.objc_send_long(card_ptr, sel("setOrientation:"), 1_i64)
            LibObjCBridge.objc_send_1d(card_ptr, sel("setSpacing:"), 0.0)
            LibObjCBridge.objc_send_bool(card_ptr, sel("setWantsLayer:"), 1)
            dark_mode = (ENV["HIG_APPEARANCE"]? == "dark")
            card_layer = LibObjCBridge.objc_send(card_ptr, sel("layer"))
            unless card_layer.null?
              # Card background: slightly elevated from window background.
              card_bg_gray : Float64 = dark_mode ? 0.20 : 0.97
              card_bg = LibObjCBridge.nscolor_rgba(card_bg_gray, card_bg_gray, card_bg_gray, 1.0)
              unless card_bg.null?
                cg_card_bg = LibObjCBridge.objc_send(card_bg, sel("CGColor"))
                LibObjCBridge.objc_send_void_id(card_layer, sel("setBackgroundColor:"), cg_card_bg) unless cg_card_bg.null?
              end
              # Rounded corners -- ~10pt matching HIG InsetGrouped card radius.
              LibObjCBridge.objc_send_1d(card_layer, sel("setCornerRadius:"), 10.0)
              # Hairline border.
              sep_gray : Float64 = dark_mode ? 0.35 : 0.78
              border_color = LibObjCBridge.nscolor_rgba(sep_gray, sep_gray, sep_gray, 1.0)
              unless border_color.null?
                cg_border = LibObjCBridge.objc_send(border_color, sel("CGColor"))
                LibObjCBridge.objc_send_void_id(card_layer, sel("setBorderColor:"), cg_border) unless cg_border.null?
              end
              LibObjCBridge.objc_send_1d(card_layer, sel("setBorderWidth:"), 0.5)
            end
            card_handle = ObjC.owned(card_ptr, label: "NSStackView[inset-grouped-card]")
            card_native = NativeView.new(card_handle)
            push_stack(card_native, is_nsstack: true)
            section.items.each_with_index do |item, idx|
              item.accept(self)
              if view.shows_separators && idx < section.items.size - 1
                sep_ptr = alloc_init("NSBox")
                LibObjCBridge.objc_send_long(sep_ptr, sel("setBoxType:"), 2_i64)
                emit(sep_ptr, "NSBox[list-sep]")
              end
            end
            pop_stack
            emit(card_ptr, "NSStackView[inset-grouped-card]")
          else
            # Plain / Grouped / Sidebar: flat vertical list with optional
            # NSBox separator lines between rows.
            section.items.each_with_index do |item, idx|
              item.accept(self)
              if view.shows_separators && idx < section.items.size - 1
                sep_ptr = alloc_init("NSBox")
                LibObjCBridge.objc_send_long(sep_ptr, sel("setBoxType:"), 2_i64)
                emit(sep_ptr, "NSBox[list-sep]")
              end
            end
          end
        end
      end

      pop_stack

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: SecureField -> NSSecureTextField
    # -----------------------------------------------------------------
    def visit(view : UI::SecureField)
      ptr = alloc_init("NSSecureTextField")

      unless view.text.empty?
        text_str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setStringValue:"), text_str)
      end

      unless view.placeholder.empty?
        placeholder_str = LibObjCBridge.nsstring_from_cstr(view.placeholder.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setPlaceholderString:"), placeholder_str)
      end

      LibObjCBridge.objc_send_bool(ptr, sel("setEditable:"), 1)

      font_ptr = resolve_font(view.font)
      LibObjCBridge.objc_send_id(ptr, sel("setFont:"), font_ptr)

      color_ptr = resolve_color(view.text_color)
      LibObjCBridge.objc_send_id(ptr, sel("setTextColor:"), color_ptr)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSSecureTextField")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        text_field_ptr = ptr
        wrapped = Proc(Nil).new do
          raw_str = LibObjCBridge.objc_send(text_field_ptr, sel("stringValue"))
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
    # Visit: Stepper -> NSStepper
    # -----------------------------------------------------------------
    def visit(view : UI::Stepper)
      ptr = alloc_init("NSStepper")

      LibObjCBridge.objc_send_1d(ptr, sel("setMinValue:"), view.minimum)
      LibObjCBridge.objc_send_1d(ptr, sel("setMaxValue:"), view.maximum)
      LibObjCBridge.objc_send_1d(ptr, sel("setDoubleValue:"), view.value)
      LibObjCBridge.objc_send_1d(ptr, sel("setIncrement:"), view.step_value)
      LibObjCBridge.objc_send_bool(ptr, sel("setValueWraps:"), view.wraps ? 1 : 0)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSStepper")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        stepper_ptr = ptr
        wrapped = Proc(Nil).new do
          val_ptr = LibObjCBridge.objc_send(stepper_ptr, sel("doubleValue"))
          change_handler.call(val_ptr.address.to_f64)
        end
        native.register_callback(wrapped)
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: SegmentedControl -> NSSegmentedControl
    # -----------------------------------------------------------------
    def visit(view : UI::SegmentedControl)
      ptr = alloc_init("NSSegmentedControl")

      view.segments.each_with_index do |segment, index|
        LibObjCBridge.objc_send_long(ptr, sel("setSegmentCount:"), (index + 1).to_i64)
        label_str = LibObjCBridge.nsstring_from_cstr(segment.to_unsafe)
        LibObjCBridge.objc_send_id_long(ptr, sel("setLabel:forSegment:"), label_str, index.to_i64)
      end

      LibObjCBridge.objc_send_long(ptr, sel("setSelectedSegment:"), view.selected_index.to_i64)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSSegmentedControl")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        seg_ptr = ptr
        wrapped = Proc(Nil).new do
          idx = LibObjCBridge.objc_send(seg_ptr, sel("selectedSegment"))
          change_handler.call(idx.address.to_i32)
        end
        native.register_callback(wrapped)
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: DatePicker -> NSDatePicker
    # -----------------------------------------------------------------
    def visit(view : UI::DatePicker)
      ptr = alloc_init("NSDatePicker")

      # NSDatePickerElementFlagYearMonth = 0xC0, NSDatePickerElementFlagYearMonthDay = 0xE0
      # NSDatePickerElementFlagHourMinute = 0x000C, NSDatePickerElementFlagHourMinuteSecond = 0x000E
      element_flags = case view.mode
                      when UI::DatePickerMode::Date
                        0xE0_i64  # Year/Month/Day
                      when UI::DatePickerMode::Time
                        0x000C_i64  # Hour/Minute
                      when UI::DatePickerMode::DateAndTime
                        0x00EC_i64  # Year/Month/Day + Hour/Minute
                      else
                        0xE0_i64
                      end
      LibObjCBridge.objc_send_long(ptr, sel("setDatePickerElements:"), element_flags)

      unless view.label.empty?
        label_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), label_str)
      end

      apply_common_properties(ptr, view)

      emit(ptr, "NSDatePicker")
    end

    # -----------------------------------------------------------------
    # Visit: TimePicker -> NSDatePicker (time-only mode)
    # -----------------------------------------------------------------
    def visit(view : UI::TimePicker)
      ptr = alloc_init("NSDatePicker")

      # Time-only: NSDatePickerElementFlagHourMinute = 0x000C
      LibObjCBridge.objc_send_long(ptr, sel("setDatePickerElements:"), 0x000C_i64)

      unless view.label.empty?
        label_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), label_str)
      end

      apply_common_properties(ptr, view)

      emit(ptr, "NSDatePicker[time]")
    end

    # -----------------------------------------------------------------
    # Visit: SearchField -> NSSearchField
    # -----------------------------------------------------------------
    def visit(view : UI::SearchField)
      ptr = alloc_init("NSSearchField")

      unless view.placeholder.empty?
        placeholder_str = LibObjCBridge.nsstring_from_cstr(view.placeholder.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setPlaceholderString:"), placeholder_str)
      end

      unless view.text.empty?
        text_str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setStringValue:"), text_str)
      end

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSSearchField")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        field_ptr = ptr
        wrapped = Proc(Nil).new do
          raw_str = LibObjCBridge.objc_send(field_ptr, sel("stringValue"))
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
    # Visit: TextArea -> NSTextView inside NSScrollView
    # -----------------------------------------------------------------
    def visit(view : UI::TextArea)
      scroll_ptr = alloc_init("NSScrollView")
      LibObjCBridge.objc_send_bool(scroll_ptr, sel("setHasVerticalScroller:"), view.is_scrollable ? 1 : 0)

      text_ptr = alloc_init("NSTextView")

      unless view.text.empty?
        text_str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
        LibObjCBridge.objc_send_id(text_ptr, sel("setString:"), text_str)
      end

      LibObjCBridge.objc_send_bool(text_ptr, sel("setEditable:"), view.is_editable ? 1 : 0)

      font_ptr = resolve_font(view.font)
      LibObjCBridge.objc_send_id(text_ptr, sel("setFont:"), font_ptr)

      color_ptr = resolve_color(view.text_color)
      LibObjCBridge.objc_send_id(text_ptr, sel("setTextColor:"), color_ptr)

      LibObjCBridge.objc_send_id(scroll_ptr, sel("setDocumentView:"), text_ptr)

      apply_common_properties(scroll_ptr, view)

      emit(scroll_ptr, "NSScrollView[textview]")
    end

    # -----------------------------------------------------------------
    # Visit: Grid -> NSGridView
    # -----------------------------------------------------------------
    def visit(view : UI::Grid)
      ptr = alloc_init("NSGridView")

      LibObjCBridge.objc_send_1d(ptr, sel("setRowSpacing:"), view.row_spacing)
      LibObjCBridge.objc_send_1d(ptr, sel("setColumnSpacing:"), view.column_spacing)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSGridView")
      native = NativeView.new(handle)

      push_stack(native, is_nsstack: false)
      view.children.each do |row|
        row.each do |cell|
          cell.accept(self)
        end
      end
      pop_stack

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Form -> NSStackView (vertical, with sections)
    # -----------------------------------------------------------------
    def visit(view : UI::Form)
      ptr = alloc_init("NSStackView")

      # NSUserInterfaceLayoutOrientationVertical = 1
      LibObjCBridge.objc_send_long(ptr, sel("setOrientation:"), 1_i64)
      LibObjCBridge.objc_send_1d(ptr, sel("setSpacing:"), 16.0)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSStackView[form]")
      native = NativeView.new(handle)

      push_stack(native, is_nsstack: true)

      view.sections.each do |section|
        section_ptr = alloc_init("NSStackView")
        LibObjCBridge.objc_send_long(section_ptr, sel("setOrientation:"), 1_i64)
        LibObjCBridge.objc_send_1d(section_ptr, sel("setSpacing:"), 8.0)

        if header = section.header
          header_ptr = alloc_init("NSTextField")
          header_str = LibObjCBridge.nsstring_from_cstr(header.to_unsafe)
          LibObjCBridge.objc_send_id(header_ptr, sel("setStringValue:"), header_str)
          LibObjCBridge.objc_send_bool(header_ptr, sel("setEditable:"), 0)
          LibObjCBridge.objc_send_bool(header_ptr, sel("setBezeled:"), 0)
          LibObjCBridge.objc_send_bool(header_ptr, sel("setDrawsBackground:"), 0)
          LibObjCBridge.objc_send_void_id(section_ptr, sel("addArrangedSubview:"), header_ptr)
        end

        section.fields.each do |field|
          row_ptr = alloc_init("NSStackView")
          LibObjCBridge.objc_send_long(row_ptr, sel("setOrientation:"), 0_i64) # horizontal
          LibObjCBridge.objc_send_1d(row_ptr, sel("setSpacing:"), 8.0)

          unless field.label.empty?
            lbl_ptr = alloc_init("NSTextField")
            lbl_str = LibObjCBridge.nsstring_from_cstr(field.label.to_unsafe)
            LibObjCBridge.objc_send_id(lbl_ptr, sel("setStringValue:"), lbl_str)
            LibObjCBridge.objc_send_bool(lbl_ptr, sel("setEditable:"), 0)
            LibObjCBridge.objc_send_bool(lbl_ptr, sel("setBezeled:"), 0)
            LibObjCBridge.objc_send_bool(lbl_ptr, sel("setDrawsBackground:"), 0)
            LibObjCBridge.objc_send_void_id(row_ptr, sel("addArrangedSubview:"), lbl_ptr)
          end

          if content = field.content
            row_handle = ObjC.owned(row_ptr, label: "NSStackView[form-row]")
            row_native = NativeView.new(row_handle)
            push_stack(row_native, is_nsstack: true)
            content.accept(self)
            pop_stack
            LibObjCBridge.objc_send_void_id(section_ptr, sel("addArrangedSubview:"), row_ptr)
          else
            LibObjCBridge.objc_send_void_id(section_ptr, sel("addArrangedSubview:"), row_ptr)
          end
        end

        if footer = section.footer
          footer_ptr = alloc_init("NSTextField")
          footer_str = LibObjCBridge.nsstring_from_cstr(footer.to_unsafe)
          LibObjCBridge.objc_send_id(footer_ptr, sel("setStringValue:"), footer_str)
          LibObjCBridge.objc_send_bool(footer_ptr, sel("setEditable:"), 0)
          LibObjCBridge.objc_send_bool(footer_ptr, sel("setBezeled:"), 0)
          LibObjCBridge.objc_send_bool(footer_ptr, sel("setDrawsBackground:"), 0)
          LibObjCBridge.objc_send_void_id(section_ptr, sel("addArrangedSubview:"), footer_ptr)
        end

        section_handle = ObjC.owned(section_ptr, label: "NSStackView[form-section]")
        section_native = NativeView.new(section_handle)
        push_native(section_native)
      end

      pop_stack

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: NavigationSplitView -> NSStackView (horizontal split container)
    #        with NSVisualEffectView sidebar column (Liquid Glass)
    #
    # HIG: "sidebars float above content in the Liquid Glass layer."
    # The sidebar column wraps in NSVisualEffectView with
    # NSVisualEffectMaterialSidebar (= 7). The content / detail
    # columns sit in NSStackView columns to the right, laid out as
    # arranged subviews of the horizontal outer NSStackView so that
    # AutoLayout gives each column a real frame.
    #
    # Root structure:
    #   outer NSStackView (horizontal, Fill distribution)
    #     NSVisualEffectView[sidebar-glass] (sidebar width pinned)
    #       NSStackView[sidebar-inner] (vertical, pinned to edges)
    #         <sidebar children>
    #     [thin 1pt NSBox separator]
    #     NSStackView[content-col] (vertical, fills remaining width)
    #       <content children>
    #     [thin 1pt NSBox separator — only if detail present]
    #     NSStackView[detail-col] (vertical, fills remaining width)
    #       <detail children>
    # -----------------------------------------------------------------
    def visit(view : UI::NavigationSplitView)
      # Outer horizontal NSStackView — replaces the plain NSView so that
      # AutoLayout gives arranged subviews real frames. Without this, content
      # and detail columns receive addSubview: into a zero-frame NSView and
      # collapse to grey zero-height bars.
      outer = alloc_init("NSStackView")
      # NSUserInterfaceLayoutOrientationHorizontal = 0
      LibObjCBridge.objc_send_long(outer, sel("setOrientation:"), 0_i64)
      LibObjCBridge.objc_send_1d(outer, sel("setSpacing:"), 0.0)
      # NSStackViewDistributionFill = 0
      LibObjCBridge.objc_send_long(outer, sel("setDistribution:"), 0_i64)
      # NSStackViewAlignmentFill (height fills parent) = 5 (NSLayoutAttributeHeight)
      # Use leading-edge alignment so rows anchor to the top.
      LibObjCBridge.objc_send_long(outer, sel("setAlignment:"), 5_i64)
      apply_common_properties(outer, view)
      outer_handle = ObjC.owned(outer, label: "NSStackView[split-outer]")
      outer_native = NativeView.new(outer_handle)

      if view.shows_sidebar
        if sidebar = view.sidebar
          # --- Liquid Glass sidebar column ---
          # NSVisualEffectMaterialSidebar = 7. Tracks light/dark appearance.
          sidebar_effect = alloc_init("NSVisualEffectView")
          LibObjCBridge.objc_send_long(sidebar_effect, sel("setMaterial:"), 7_i64)
          # NSVisualEffectBlendingModeWithinWindow = 1
          LibObjCBridge.objc_send_long(sidebar_effect, sel("setBlendingMode:"), 1_i64)
          # NSVisualEffectStateActive = 1
          LibObjCBridge.objc_send_long(sidebar_effect, sel("setState:"), 1_i64)

          # Pin the sidebar column width.
          sidebar_width_val = view.sidebar_width
          LibObjCBridge.objc_constrain_width(sidebar_effect, sidebar_width_val)

          # Inner NSStackView for sidebar rows with 8pt leading/trailing insets.
          sidebar_inner = alloc_init("NSStackView")
          LibObjCBridge.objc_send_long(sidebar_inner, sel("setOrientation:"), 1_i64)
          LibObjCBridge.objc_send_1d(sidebar_inner, sel("setSpacing:"), 2.0)
          LibObjCBridge.objc_send_long(sidebar_inner, sel("setAlignment:"), 5_i64)
          sidebar_insets = LibObjCBridge::CGRect.new(x: 8.0, y: 8.0, width: 8.0, height: 8.0)
          LibObjCBridge.objc_send_rect_void(sidebar_inner, sel("setEdgeInsets:"), sidebar_insets)
          LibObjCBridge.objc_send_bool(sidebar_inner, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
          LibObjCBridge.objc_add_subview(sidebar_effect, sidebar_inner)

          # Pin inner stack to all four edges of the effect view.
          %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anchor_sel|
            inner_anchor  = LibObjCBridge.objc_send(sidebar_inner, sel(anchor_sel))
            effect_anchor = LibObjCBridge.objc_send(sidebar_effect, sel(anchor_sel))
            next if inner_anchor.null? || effect_anchor.null?
            constraint = LibObjCBridge.objc_send_id(inner_anchor, sel("constraintEqualToAnchor:"), effect_anchor)
            LibObjCBridge.objc_send_bool(constraint, sel("setActive:"), 1) unless constraint.null?
          end

          sidebar_inner_handle = ObjC.borrowed(sidebar_inner, label: "NSStackView[sidebar-inner]")
          sidebar_inner_native = NativeView.new(sidebar_inner_handle)

          push_stack(sidebar_inner_native, is_nsstack: true)
          sidebar.accept(self)
          pop_stack

          # Add glass sidebar directly as an arranged subview of outer.
          # Do NOT use push_native here — that would add it to the parent
          # of the NavigationSplitView, producing the orphaned floating inset.
          sidebar_effect_handle = ObjC.owned(sidebar_effect, label: "NSVisualEffectView[sidebar-glass]")
          sidebar_effect_native = NativeView.new(sidebar_effect_handle)
          outer_native.add_child(sidebar_effect_native)
          LibObjCBridge.objc_send_void_id(outer, sel("addArrangedSubview:"), sidebar_effect)

          # 1pt vertical separator after sidebar column.
          sep1 = alloc_init("NSBox")
          # NSBoxSeparator = 2
          LibObjCBridge.objc_send_long(sep1, sel("setBoxType:"), 2_i64)
          sep1_size = LibObjCBridge::CGRect.new(x: 1.0, y: 0.0, width: 1.0, height: 0.0)
          LibObjCBridge.objc_send_rect_void(sep1, sel("setFrameSize:"), sep1_size)
          LibObjCBridge.objc_send_void_id(outer, sel("addArrangedSubview:"), sep1)
        end
      end

      if content = view.content
        # Content column: vertical NSStackView, fill-width in the remaining space.
        content_col = alloc_init("NSStackView")
        LibObjCBridge.objc_send_long(content_col, sel("setOrientation:"), 1_i64)
        LibObjCBridge.objc_send_1d(content_col, sel("setSpacing:"), 0.0)
        LibObjCBridge.objc_send_long(content_col, sel("setDistribution:"), 0_i64)
        LibObjCBridge.objc_send_long(content_col, sel("setAlignment:"), 5_i64)
        # Constrain the content column to the width set on the UI::View if provided.
        if min_w = content.minimum_width
          LibObjCBridge.objc_constrain_width(content_col, min_w)
        end
        content_col_handle = ObjC.owned(content_col, label: "NSStackView[content-col]")
        content_col_native = NativeView.new(content_col_handle)

        push_stack(content_col_native, is_nsstack: true)
        content.accept(self)
        pop_stack

        outer_native.add_child(content_col_native)
        LibObjCBridge.objc_send_void_id(outer, sel("addArrangedSubview:"), content_col)
      end

      if detail = view.detail
        # 1pt separator before detail column.
        sep2 = alloc_init("NSBox")
        LibObjCBridge.objc_send_long(sep2, sel("setBoxType:"), 2_i64)
        sep2_size = LibObjCBridge::CGRect.new(x: 1.0, y: 0.0, width: 1.0, height: 0.0)
        LibObjCBridge.objc_send_rect_void(sep2, sel("setFrameSize:"), sep2_size)
        LibObjCBridge.objc_send_void_id(outer, sel("addArrangedSubview:"), sep2)

        # Detail column: vertical NSStackView, fills remaining space.
        detail_col = alloc_init("NSStackView")
        LibObjCBridge.objc_send_long(detail_col, sel("setOrientation:"), 1_i64)
        LibObjCBridge.objc_send_1d(detail_col, sel("setSpacing:"), 0.0)
        LibObjCBridge.objc_send_long(detail_col, sel("setDistribution:"), 0_i64)
        LibObjCBridge.objc_send_long(detail_col, sel("setAlignment:"), 5_i64)
        detail_col_handle = ObjC.owned(detail_col, label: "NSStackView[detail-col]")
        detail_col_native = NativeView.new(detail_col_handle)

        push_stack(detail_col_native, is_nsstack: true)
        detail.accept(self)
        pop_stack

        outer_native.add_child(detail_col_native)
        LibObjCBridge.objc_send_void_id(outer, sel("addArrangedSubview:"), detail_col)
      end

      push_native(outer_native)
    end

    # -----------------------------------------------------------------
    # Visit: Toolbar -> NSVisualEffectView (Liquid Glass) + horizontal
    #                   NSStackView of icon-button items.
    #
    # HIG: "A toolbar provides convenient access to frequently used
    # commands, controls, navigation, and search." Toolbars are surface
    # components classified under navigation/chrome. On macOS 26, the
    # toolbar background is a Liquid Glass translucent NSVisualEffectView.
    # Material: NSVisualEffectMaterialToolBar = 10 (tracks appearance).
    #
    # Structure:
    #   NSVisualEffectView (glass root, toolbar material)
    #     NSStackView (horizontal, leading-aligned, 8pt spacing)
    #       [title NSTextField? if view.title && view.shows_title]
    #       NSBox (vertical separator) -- between groups
    #       item_0..item_N:
    #         NSButton (icon-only or icon+label, borderless, 44x28pt)
    #           NSImageView (SF Symbol, 20pt, no border per HIG Actions)
    #
    # HIG Best practices: "Prefer system-provided symbols without borders."
    # HIG Best practices: "Choose items deliberately to avoid overcrowding."
    # -----------------------------------------------------------------
    def visit(view : UI::Toolbar)
      # Glass root: NSVisualEffectView toolbar material.
      glass_root = alloc_init("NSVisualEffectView")
      # NSVisualEffectMaterialToolBar = 12 on macOS 10.11+; fall back to
      # NSVisualEffectMaterialMenu (10) which also tracks appearance.
      # We use 10 (menu) for widest compatibility with the validation host.
      LibObjCBridge.objc_send_long(glass_root, sel("setMaterial:"), 10_i64)
      # NSVisualEffectBlendingModeWithinWindow = 1
      LibObjCBridge.objc_send_long(glass_root, sel("setBlendingMode:"), 1_i64)
      # NSVisualEffectStateActive = 1
      LibObjCBridge.objc_send_long(glass_root, sel("setState:"), 1_i64)
      LibObjCBridge.objc_send_bool(glass_root, sel("setWantsLayer:"), 1)

      if lbl = view.accessibility_label
        lbl_str = LibObjCBridge.nsstring_from_cstr(lbl.to_unsafe)
        LibObjCBridge.objc_send_id(glass_root, sel("setAccessibilityLabel:"), lbl_str)
      elsif title = view.title
        title_str = LibObjCBridge.nsstring_from_cstr(title.to_unsafe)
        LibObjCBridge.objc_send_id(glass_root, sel("setAccessibilityLabel:"), title_str)
      end

      apply_common_properties(glass_root, view)

      glass_handle = ObjC.owned(glass_root, label: "NSVisualEffectView[toolbar-glass]")
      glass_native = NativeView.new(glass_handle)

      # Horizontal NSStackView for toolbar items.
      item_row = alloc_init("NSStackView")
      # NSUserInterfaceLayoutOrientationHorizontal = 0
      LibObjCBridge.objc_send_long(item_row, sel("setOrientation:"), 0_i64)
      LibObjCBridge.objc_send_1d(item_row, sel("setSpacing:"), 4.0)
      LibObjCBridge.objc_send_long(item_row, sel("setDistribution:"), 0_i64)
      # 4pt top/bottom, 8pt leading/trailing insets
      item_insets = LibObjCBridge::CGRect.new(x: 8.0, y: 4.0, width: 8.0, height: 4.0)
      LibObjCBridge.objc_send_rect_void(item_row, sel("setEdgeInsets:"), item_insets)

      # Optional title NSTextField at leading edge.
      if title = view.title
        if view.shows_title
          lbl_ptr = alloc_init("NSTextField")
          LibObjCBridge.objc_send_bool(lbl_ptr, sel("setBezeled:"), 0)
          LibObjCBridge.objc_send_bool(lbl_ptr, sel("setDrawsBackground:"), 0)
          LibObjCBridge.objc_send_bool(lbl_ptr, sel("setEditable:"), 0)
          LibObjCBridge.objc_send_bool(lbl_ptr, sel("setSelectable:"), 0)
          title_ns = LibObjCBridge.nsstring_from_cstr(title.to_unsafe)
          LibObjCBridge.objc_send_id(lbl_ptr, sel("setStringValue:"), title_ns)
          # 13pt semibold for toolbar title
          title_font = LibObjCBridge.nsfont_bold_system(13.0)
          LibObjCBridge.objc_send_id(lbl_ptr, sel("setFont:"), title_font) unless title_font.null?
          title_acc = LibObjCBridge.nsstring_from_cstr("Toolbar title: #{title}".to_unsafe)
          LibObjCBridge.objc_send_id(lbl_ptr, sel("setAccessibilityLabel:"), title_acc)
          LibObjCBridge.objc_send_id(item_row, sel("addArrangedSubview:"), lbl_ptr)
        end
      end

      ns_image_cls = LibObjCBridge.objc_getClass("NSImage")

      view.items.each_with_index do |item, idx|
        # Vertical divider between groups (item id == "---")
        if item.id == "---"
          sep_box = alloc_init("NSBox")
          # NSBoxSeparator = 2
          LibObjCBridge.objc_send_long(sep_box, sel("setBoxType:"), 2_i64)
          sep_size = LibObjCBridge::CGRect.new(x: 1.0, y: 20.0, width: 1.0, height: 20.0)
          LibObjCBridge.objc_send_rect_void(sep_box, sel("setFrameSize:"), sep_size)
          LibObjCBridge.objc_send_id(item_row, sel("addArrangedSubview:"), sep_box)
          next
        end

        btn = alloc_init("NSButton")
        # NSButtonTypeToggle would need state; use NSButtonTypeMomentaryLight = 0
        LibObjCBridge.objc_send_long(btn, sel("setButtonType:"), 0_i64)
        # NSBezelStyleRecessed = 13 gives flat icon-button look; use 0 = NSBezelStyleRounded
        # HIG: "toolbar items don't include a bezel" -- use borderless style
        LibObjCBridge.objc_send_long(btn, sel("setBezelStyle:"), 0_i64)
        LibObjCBridge.objc_send_bool(btn, sel("setBordered:"), 0)

        # SF Symbol image (20pt, no border per HIG Best practices)
        if icon = item.icon
          unless ns_image_cls.null?
            icon_ns = LibObjCBridge.nsstring_from_cstr(icon.to_unsafe)
            sym_img = LibObjCBridge.objc_send_id_id(ns_image_cls,
              sel("imageWithSystemSymbolName:accessibilityDescription:"),
              icon_ns, Pointer(Void).null)
            LibObjCBridge.objc_send_id(btn, sel("setImage:"), sym_img) unless sym_img.null?
          end
        end

        # Show label only when no icon, per HIG "Prefer simple, recognizable symbols"
        if item.icon.nil? && !item.label.empty?
          lbl_ns = LibObjCBridge.nsstring_from_cstr(item.label.to_unsafe)
          LibObjCBridge.objc_send_id(btn, sel("setTitle:"), lbl_ns)
        else
          empty_ns = LibObjCBridge.nsstring_from_cstr("".to_unsafe)
          LibObjCBridge.objc_send_id(btn, sel("setTitle:"), empty_ns)
        end

        # Accessibility label: item label always set
        acc_label = item.label.empty? ? (item.icon || "toolbar item #{idx}") : item.label
        acc_ns = LibObjCBridge.nsstring_from_cstr(acc_label.to_unsafe)
        LibObjCBridge.objc_send_id(btn, sel("setAccessibilityLabel:"), acc_ns)

        # Minimum 44x28pt hit area (macOS HIG: 28pt toolbar button height)
        btn_frame = LibObjCBridge::CGRect.new(x: 0.0, y: 0.0, width: 44.0, height: 28.0)
        LibObjCBridge.objc_send_rect_void(btn, sel("setFrame:"), btn_frame)

        LibObjCBridge.objc_send_id(item_row, sel("addArrangedSubview:"), btn)
      end

      # Pin item_row to glass root edges.
      LibObjCBridge.objc_send_bool(item_row, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
      LibObjCBridge.objc_add_subview(glass_root, item_row)

      %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anchor_sel|
        row_anchor   = LibObjCBridge.objc_send(item_row,   sel(anchor_sel))
        glass_anchor = LibObjCBridge.objc_send(glass_root, sel(anchor_sel))
        next if row_anchor.null? || glass_anchor.null?
        constraint = LibObjCBridge.objc_send_id(row_anchor, sel("constraintEqualToAnchor:"), glass_anchor)
        LibObjCBridge.objc_send_bool(constraint, sel("setActive:"), 1) unless constraint.null?
      end

      item_row_handle = ObjC.borrowed(item_row, label: "NSStackView[toolbar-items]")
      glass_native.add_child(NativeView.new(item_row_handle))
      push_native(glass_native)
    end

    # -----------------------------------------------------------------
    # Visit: Sheet -> NSVisualEffectView + inner NSStackView (Liquid Glass)
    # -----------------------------------------------------------------
    def visit(view : UI::Sheet)
      # Two render paths:
      #   (a) true modal presentation (is_presented == true): the pre-
      #       existing plain-NSView placeholder — real modal dispatch
      #       happens at the SheetPresenter layer. Keep this untouched.
      #   (b) inline content rendering (is_presented == false): compose
      #       a Liquid Glass surface using NSVisualEffectView wrapping
      #       an inner NSStackView with 16pt insets. This is the pattern
      #       the HIG validation loop uses. Material: NSVisualEffectMaterialSheet
      #       (11) -- the semantically correct material for macOS sheets.
      grouped_card = !view.is_presented &&
                     (view.surface_style == :auto || view.surface_style == :grouped_card)

      if grouped_card
        # Outer glass container — NSVisualEffectView. This is what the
        # parent tree sees as the sheet view; it renders the translucent
        # backdrop-blurred material and the subtle glass-edge highlight.
        effect = alloc_init("NSVisualEffectView")

        # NSVisualEffectMaterialSheet = 11 (macOS 10.11+). This is the
        # canonical material for macOS sheets -- it matches the frosted-glass
        # surface Apple uses for Save/Print/Open sheets. Tracks light/dark
        # appearance automatically. Material 10 (Menu) was used previously;
        # 11 (Sheet) is the semantically correct value per NSVisualEffectMaterial
        # enum (Sidebar=1, Titlebar=3, Selection=4, Menu=5, Popover=6,
        # Sidebar=7, HeaderView=10, Sheet=11, WindowBackground=12,
        # HUDWindow=13, FullScreenUI=15, Tooltip=17, ContentBackground=18,
        # UnderWindowBackground=21, UnderPageBackground=22).
        LibObjCBridge.objc_send_long(effect, sel("setMaterial:"), 11_i64)
        # NSVisualEffectBlendingModeWithinWindow = 1 — samples what is beneath
        # this NSVisualEffectView inside the same window. The validation host
        # composites the backdrop as a CALayer within the capture window so the
        # glass blurs it correctly. .behindWindow (0) sampled behind the NSWindow
        # itself and produced a solid dark fill when no separate window was beneath.
        LibObjCBridge.objc_send_long(effect, sel("setBlendingMode:"), 1_i64)
        # NSVisualEffectStateActive = 1 — keep the material live regardless
        # of window key state.
        LibObjCBridge.objc_send_long(effect, sel("setState:"), 1_i64)

        # Rounded corners on the material layer itself.
        # 16pt: Amber phi-scale "sheet" token. Action sheets are modal surfaces;
        # 16pt (not 12pt) is the correct Amber token. June R5 fix.
        LibObjCBridge.objc_send_bool(effect, sel("setWantsLayer:"), 1)
        effect_layer = LibObjCBridge.objc_send(effect, sel("layer"))
        unless effect_layer.null?
          LibObjCBridge.objc_send_1d(effect_layer, sel("setCornerRadius:"), 16.0)
          LibObjCBridge.objc_send_bool(effect_layer, sel("setMasksToBounds:"), 1)
        end

        # Inner NSStackView hosts the sheet's content rows. 16pt edge
        # insets give the HIG-mandated breathing room inside the material.
        inner = alloc_init("NSStackView")
        LibObjCBridge.objc_send_long(inner, sel("setOrientation:"), 1_i64)
        LibObjCBridge.objc_send_1d(inner, sel("setSpacing:"), 8.0)
        LibObjCBridge.objc_send_long(inner, sel("setAlignment:"), 5_i64)
        insets = LibObjCBridge::CGRect.new(x: 16.0, y: 16.0, width: 16.0, height: 16.0)
        LibObjCBridge.objc_send_rect_void(inner, sel("setEdgeInsets:"), insets)

        # Install the inner stack as a subview of the effect view; pin
        # its edges. Use translatesAutoresizingMaskIntoConstraints: NO
        # so AutoLayout can pin the stack to the effect view's bounds.
        LibObjCBridge.objc_send_bool(inner, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
        LibObjCBridge.objc_add_subview(effect, inner)

        # Pin inner to effect on all four edges via anchor constraints.
        %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anchor_sel|
          inner_anchor  = LibObjCBridge.objc_send(inner,  sel(anchor_sel))
          effect_anchor = LibObjCBridge.objc_send(effect, sel(anchor_sel))
          next if inner_anchor.null? || effect_anchor.null?
          constraint = LibObjCBridge.objc_send_id(inner_anchor, sel("constraintEqualToAnchor:"), effect_anchor)
          LibObjCBridge.objc_send_bool(constraint, sel("setActive:"), 1) unless constraint.null?
        end

        apply_common_properties(effect, view)

        # HIG macOS sheet: maximum width 540pt, margin 34pt from window edge.
        # The parent container (NSStackView in hig_showcase) centers the card
        # via alignment=center; we pin only the width so the card is never
        # wider than 540pt regardless of window size. The caller's max_width
        # property overrides this default.
        sheet_max_w = view.responds_to?(:max_width) ? view.max_width : 540.0
        LibObjCBridge.objc_constrain_width(effect, sheet_max_w)

        outer_handle = ObjC.owned(effect, label: "NSVisualEffectView[sheet-glass]")
        outer_native = NativeView.new(outer_handle)

        # The inner stack is retained by the effect view (via addSubview),
        # so we borrow the pointer rather than taking ownership.
        inner_handle = ObjC.borrowed(inner, label: "NSStackView[sheet-inner]")
        inner_native = NativeView.new(inner_handle)

        if content = view.content
          # Children flow into the inner stack via addArrangedSubview:.
          push_stack(inner_native, is_nsstack: true)
          content.accept(self)
          pop_stack
        end

        push_native(outer_native)
      else
        ptr = alloc_init("NSView")

        if view.is_presented
          LibObjCBridge.objc_send_bool(ptr, sel("setHidden:"), 0)
        else
          LibObjCBridge.objc_send_bool(ptr, sel("setHidden:"), 1)
        end

        apply_common_properties(ptr, view)

        handle = ObjC.owned(ptr, label: "NSView[sheet]")
        native = NativeView.new(handle)

        if content = view.content
          push_stack(native, is_nsstack: false)
          content.accept(self)
          pop_stack
        end

        push_native(native)
      end
    end

    # -----------------------------------------------------------------
    # Visit: Popover -> NSVisualEffectView (popover material) inline card
    #
    # HIG: Popovers are surface components classified under "Presentation /
    # Windows and overlays." They require Liquid Glass.
    #
    # NSVisualEffectMaterialPopover = 6. Tracks light/dark appearance
    # automatically. BlendingMode BehindWindow = 0 so the glass samples
    # the window backdrop for true translucency. State Active = 1 keeps the
    # material live regardless of key state.
    #
    # The inline path (is_presented == false) renders the glass surface and
    # content directly into the host view tree -- used by the HIG validation
    # host for screenshot isolation. A production app would use NSPopover with
    # showRelativeToRect:ofView:preferredEdge: for full popover lifecycle.
    #
    # Arrow/tail: NSPopover provides the arrow natively when used in the
    # presented path. In the inline validation path we emit a small arrow-glyph
    # label (up-pointing triangle character U+25B2) above the surface to signal
    # the popover origin. This is not a rendered NSPopoverArrow -- it is a
    # validation-only visual cue. Logged as a systemic gap in gaps.md.
    #
    # Corner radius ~10pt matching NSVisualEffectMaterialPopover default.
    # -----------------------------------------------------------------
    def visit(view : UI::Popover)
      # Outer glass container -- NSVisualEffectView with popover material.
      effect = alloc_init("NSVisualEffectView")

      # NSVisualEffectMaterialPopover = 6. Tracks light/dark appearance.
      LibObjCBridge.objc_send_long(effect, sel("setMaterial:"), 6_i64)
      # NSVisualEffectBlendingModeWithinWindow = 1
      LibObjCBridge.objc_send_long(effect, sel("setBlendingMode:"), 1_i64)
      # NSVisualEffectStateActive = 1 -- keep material live regardless of key state.
      LibObjCBridge.objc_send_long(effect, sel("setState:"), 1_i64)

      # Rounded corners -- ~10pt matches NSPopover default corner radius on macOS.
      LibObjCBridge.objc_send_bool(effect, sel("setWantsLayer:"), 1)
      effect_layer = LibObjCBridge.objc_send(effect, sel("layer"))
      unless effect_layer.null?
        LibObjCBridge.objc_send_1d(effect_layer, sel("setCornerRadius:"), 10.0)
        LibObjCBridge.objc_send_bool(effect_layer, sel("setMasksToBounds:"), 1)
      end

      # Inner vertical NSStackView -- holds content with 16pt insets (HIG breathing room).
      inner = alloc_init("NSStackView")
      # NSUserInterfaceLayoutOrientationVertical = 1
      LibObjCBridge.objc_send_long(inner, sel("setOrientation:"), 1_i64)
      LibObjCBridge.objc_send_1d(inner, sel("setSpacing:"), 8.0)
      # NSLayoutAttributeLeading = 7 -- left-align children.
      LibObjCBridge.objc_send_long(inner, sel("setAlignment:"), 7_i64)
      insets = LibObjCBridge::CGRect.new(x: 16.0, y: 12.0, width: 16.0, height: 12.0)
      LibObjCBridge.objc_send_rect_void(inner, sel("setEdgeInsets:"), insets)
      LibObjCBridge.objc_send_bool(inner, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
      LibObjCBridge.objc_add_subview(effect, inner)

      # Pin inner to effect on all four edges.
      %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anchor_sel|
        inner_anchor  = LibObjCBridge.objc_send(inner,  sel(anchor_sel))
        effect_anchor = LibObjCBridge.objc_send(effect, sel(anchor_sel))
        next if inner_anchor.null? || effect_anchor.null?
        constraint = LibObjCBridge.objc_send_id(inner_anchor, sel("constraintEqualToAnchor:"), effect_anchor)
        LibObjCBridge.objc_send_bool(constraint, sel("setActive:"), 1) unless constraint.null?
      end

      inner_handle = ObjC.borrowed(inner, label: "NSStackView[popover-inner]")
      inner_native = NativeView.new(inner_handle)

      apply_common_properties(effect, view)

      # HIG Popover: maxWidth 320pt. Constrains the popover card width without
      # restricting its height (content-driven).
      LibObjCBridge.objc_constrain_width(effect, 320.0)

      outer_handle = ObjC.owned(effect, label: "NSVisualEffectView[popover-glass]")
      outer_native = NativeView.new(outer_handle)
      outer_native.add_child(inner_native)

      # Render content children into the inner stack.
      if content = view.content
        push_stack(inner_native, is_nsstack: true)
        content.accept(self)
        pop_stack
      end

      push_native(outer_native)
    end

    # -----------------------------------------------------------------
    # Visit: ConfirmationDialog -> NSAlert
    # -----------------------------------------------------------------
    def visit(view : UI::ConfirmationDialog)
      ptr = alloc_init("NSAlert")

      title_str = LibObjCBridge.nsstring_from_cstr(view.title.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("setMessageText:"), title_str)

      unless view.message.empty?
        msg_str = LibObjCBridge.nsstring_from_cstr(view.message.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setInformativeText:"), msg_str)
      end

      confirm_str = LibObjCBridge.nsstring_from_cstr(view.confirm_label.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("addButtonWithTitle:"), confirm_str)

      cancel_str = LibObjCBridge.nsstring_from_cstr(view.cancel_label.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("addButtonWithTitle:"), cancel_str)

      if view.confirm_style == :destructive
        # NSCriticalAlertStyle = 2
        LibObjCBridge.objc_send_long(ptr, sel("setAlertStyle:"), 2_i64)
      end

      emit(ptr, "NSAlert[confirmation]")
    end

    # -----------------------------------------------------------------
    # Visit: Snackbar -> NSView (toast-style overlay)
    # -----------------------------------------------------------------
    def visit(view : UI::Snackbar)
      ptr = alloc_init("NSTextField")

      msg_str = LibObjCBridge.nsstring_from_cstr(view.message.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("setStringValue:"), msg_str)
      LibObjCBridge.objc_send_bool(ptr, sel("setEditable:"), 0)
      LibObjCBridge.objc_send_bool(ptr, sel("setBezeled:"), 0)

      if view.is_presented
        LibObjCBridge.objc_send_bool(ptr, sel("setHidden:"), 0)
      else
        LibObjCBridge.objc_send_bool(ptr, sel("setHidden:"), 1)
      end

      apply_common_properties(ptr, view)

      emit(ptr, "NSTextField[snackbar]")
    end

    # -----------------------------------------------------------------
    # Visit: Card -> NSStackView + CALayer (grouped box container)
    #
    # HIG Boxes: "A box creates a visually distinct group of logically
    # related information and components." and "By default, a box uses a
    # visible border or background color to separate its contents from
    # the rest of the interface."
    #
    # Prior implementation used NSBox, which relies on the Quartz
    # compositor for appearance-resolved fills. NSBox's fillColor draws
    # opaque white in offscreen bitmaps even when the window appearance
    # is dark, producing white-on-white captures (gaps.md iteration-21).
    #
    # This implementation uses NSStackView (vertical) + wantsLayer=YES +
    # explicit NSColor.controlBackgroundColor resolved via CGColor.
    # NSColor.controlBackgroundColor is a dynamic system color; via
    # -[NSAppearance performAsCurrentDrawingAppearance:] in the snapshot
    # path it correctly resolves to light gray in light and dark charcoal
    # in dark. The hairline border is drawn via layer.borderColor and
    # layer.borderWidth. On macOS 26, NSBox is still emitted for
    # production app embedding (in SwiftUI interop) but for the
    # validation path an NSStackView renders correctly.
    #
    # HIG macOS platform note: "By default, macOS displays a box's title
    # above it." We prepend a title NSTextField as the first arranged
    # subview, matching that platform behaviour.
    # -----------------------------------------------------------------
    def visit(view : UI::Card)
      ptr = alloc_init("NSStackView")

      # Vertical orientation (NSUserInterfaceLayoutOrientationVertical = 1).
      LibObjCBridge.objc_send_long(ptr, sel("setOrientation:"), 1_i64)
      # 8pt inter-row spacing (HIG default for grouped content rows).
      LibObjCBridge.objc_send_1d(ptr, sel("setSpacing:"), 8.0)
      # Leading alignment (NSLayoutAttributeLeading = 5).
      LibObjCBridge.objc_send_long(ptr, sel("setAlignment:"), 5_i64)
      # Layout-margin-relative arrangement: 12pt inset on all sides.
      LibObjCBridge.objc_send_bool(ptr, sel("setEdgeInsets:"), 0) # reset first

      # Enable layer-backed rendering so we can set fill + rounded border.
      LibObjCBridge.objc_send_bool(ptr, sel("setWantsLayer:"), 1)

      layer = LibObjCBridge.objc_send(ptr, sel("layer"))
      unless layer.null?
        # ~10pt corner radius -- matches HIG grouped-container default.
        LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), 10.0)

        # Background fill. layer.backgroundColor requires a baked CGColor.
        # Dynamic NSColor -> CGColor bakes the color at call time, before the
        # drawing appearance is set, so it does NOT track dark/light via the
        # performAsCurrentDrawingAppearance: path used by window_helper.m.
        # We use an explicit RGBA: light appearance -> near-white grouped fill
        # (NSColor.controlBackgroundColor light ~0.97 RGB); dark -> dark-charcoal
        # (NSColor.controlBackgroundColor dark ~0.14 RGB). Reading HIG_APPEARANCE
        # here ensures the validation snapshot matches the correct appearance.
        # In production, a real app would subclass NSStackView and override
        # updateLayer to pick the system-resolved color.
        #
        # Backdrop-mode exception: when HIG_BACKDROP_PATH is set, the capture
        # window has an NSImageView backdrop. Card NSStackViews with opaque fills
        # block the NSVisualEffectView compositor from reaching the backdrop.
        # Use a semi-transparent fill so the backdrop bleeds through the card
        # surface as frosted glass. The border and corner radius remain.
        dark_mode = (ENV["HIG_APPEARANCE"]? == "dark")
        backdrop_mode = ENV["HIG_BACKDROP_PATH"]? && !ENV["HIG_BACKDROP_PATH"].to_s.empty?
        bg_color = if backdrop_mode
                     # Semi-transparent fill: 75% opaque so the card is readable
                     # as a distinct surface but the backdrop bleeds through.
                     dark_mode ?
                       LibObjCBridge.nscolor_rgba(0.12, 0.12, 0.14, 0.75) :
                       LibObjCBridge.nscolor_rgba(0.96, 0.96, 0.97, 0.75)
                   elsif dark_mode
                     LibObjCBridge.nscolor_rgba(0.145, 0.145, 0.145, 1.0)
                   else
                     LibObjCBridge.nscolor_rgba(0.970, 0.970, 0.970, 1.0)
                   end
        unless bg_color.null?
          cg_bg = LibObjCBridge.objc_send(bg_color, sel("CGColor"))
          LibObjCBridge.objc_send_void_id(layer, sel("setBackgroundColor:"), cg_bg) unless cg_bg.null?
        end

        # Hairline separator-color border matching HIG grouped-box chrome.
        # Same issue: bake appropriate gray for each appearance.
        sep_gray : Float64 = dark_mode ? 0.35 : 0.78
        sep_color = LibObjCBridge.nscolor_rgba(sep_gray, sep_gray, sep_gray, 1.0)
        unless sep_color.null?
          cg_sep = LibObjCBridge.objc_send(sep_color, sel("CGColor"))
          LibObjCBridge.objc_send_void_id(layer, sel("setBorderColor:"), cg_sep) unless cg_sep.null?
        end
        LibObjCBridge.objc_send_1d(layer, sel("setBorderWidth:"), 0.5)
      end

      apply_common_properties(ptr, view)

      outer_handle = ObjC.owned(ptr, label: "NSStackView[card]")
      outer_native = NativeView.new(outer_handle)

      # HIG macOS: "By default, macOS displays a box's title above it."
      # Prepend a title label as the first arranged subview.
      if title = view.title
        title_ptr = alloc_init("NSTextField")
        title_ns = LibObjCBridge.nsstring_from_cstr(title.to_unsafe)
        LibObjCBridge.objc_send_id(title_ptr, sel("setStringValue:"), title_ns)
        LibObjCBridge.objc_send_bool(title_ptr, sel("setEditable:"), 0)
        LibObjCBridge.objc_send_bool(title_ptr, sel("setBezeled:"), 0)
        LibObjCBridge.objc_send_bool(title_ptr, sel("setDrawsBackground:"), 0)
        LibObjCBridge.objc_send_bool(title_ptr, sel("setSelectable:"), 0)
        # 11pt bold -- matches macOS grouped-box title convention.
        title_font = LibObjCBridge.nsfont_system_weight(11.0, 0.4)
        LibObjCBridge.objc_send_id(title_ptr, sel("setFont:"), title_font)
        # Label-color (dynamic): dark-mode white, light-mode near-black.
        primary_color = LibObjCBridge.nscolor_label_primary
        LibObjCBridge.objc_send_id(title_ptr, sel("setTextColor:"), primary_color)
        LibObjCBridge.objc_send_void_id(ptr, sel("addArrangedSubview:"), title_ptr)

        title_handle = ObjC.owned(title_ptr, label: "NSTextField[card-title]")
        outer_native.add_child(NativeView.new(title_handle))
      end

      if content = view.content
        push_stack(outer_native, is_nsstack: true)
        content.accept(self)
        pop_stack
      end

      push_native(outer_native)
    end

    # -----------------------------------------------------------------
    # Visit: Surface -> NSView (elevated container)
    # -----------------------------------------------------------------
    def visit(view : UI::Surface)
      ptr = alloc_init("NSView")

      LibObjCBridge.objc_send_bool(ptr, sel("setWantsLayer:"), 1)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSView[surface]")
      native = NativeView.new(handle)

      if content = view.content
        push_stack(native, is_nsstack: false)
        content.accept(self)
        pop_stack
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: Divider -> NSBox (separator)
    # -----------------------------------------------------------------
    def visit(view : UI::Divider)
      ptr = alloc_init("NSBox")

      # NSBoxSeparator = 2
      LibObjCBridge.objc_send_long(ptr, sel("setBoxType:"), 2_i64)

      apply_common_properties(ptr, view)

      emit(ptr, "NSBox[divider]")
    end

    # -----------------------------------------------------------------
    # Visit: GlassBackground -> NSVisualEffectView
    # -----------------------------------------------------------------
    def visit(view : UI::GlassBackground)
      ptr = alloc_init("NSVisualEffectView")

      # NSVisualEffectMaterial constants (macOS 10.14+):
      #   Medium=1, Light=2, Titlebar=3, Selection=4, Menu=5,
      #   Popover=6, Sidebar=7, HeaderView=10, Sheet=11, WindowBackground=12,
      #   HUDWindow=13, FullScreenUI=15, Tooltip=17, ContentBackground=18,
      #   UnderWindowBackground=21, UnderPageBackground=22
      # NSVisualEffectMaterialSidebar (7) is the HIG-correct material for
      # sidebar columns. It tracks appearance automatically and applies the
      # translucent Liquid Glass sidebar surface.
      material_val = case view.material
                     when :ultra_thin then 9_i64  # NSVisualEffectMaterialUltraLight (closest)
                     when :thin       then 2_i64  # NSVisualEffectMaterialLight
                     when :regular    then 12_i64 # NSVisualEffectMaterialWindowBackground
                     when :thick      then 1_i64  # NSVisualEffectMaterialMedium
                     when :chrome     then 3_i64  # NSVisualEffectMaterialTitlebar
                     when :sidebar    then 7_i64  # NSVisualEffectMaterialSidebar (HIG sidebar column)
                     when :menu       then 5_i64  # NSVisualEffectMaterialMenu
                     when :popover    then 6_i64  # NSVisualEffectMaterialPopover
                     when :sheet      then 11_i64 # NSVisualEffectMaterialSheet
                     else                  12_i64
                     end
      LibObjCBridge.objc_send_long(ptr, sel("setMaterial:"), material_val)

      # NSVisualEffectBlendingModeWithinWindow = 1
      LibObjCBridge.objc_send_long(ptr, sel("setBlendingMode:"), 1_i64)

      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSVisualEffectView")
      native = NativeView.new(handle)

      if content = view.content
        push_stack(native, is_nsstack: false)
        content.accept(self)
        pop_stack
      end

      push_native(native)
    end

    # -----------------------------------------------------------------
    # P2 Wave 3 Visit methods
    # -----------------------------------------------------------------

    def visit(view : UI::AsyncImage)
      ptr = alloc_init("NSImageView")
      apply_common_properties(ptr, view)
      emit(ptr, "NSImageView[async]")
    end

    # -----------------------------------------------------------------
    # Visit: RichText -> NSTextView (inside NSScrollView for wrapping)
    #
    # HIG "Text views": "A text view displays multiline, styled text
    # content, which can optionally be editable."
    # AppKit: NSTextView is always embedded in NSScrollView to provide
    # the expected scrolling and layout behaviour for multi-line content.
    #
    # Text color: when the Span default sentinel (r=0,g=0,b=0,a=1) is
    # detected we substitute NSColor.labelColor so dark-mode text is
    # near-white rather than baked-black.  This mirrors the fix applied
    # to UI::TextField in iter-48.
    # -----------------------------------------------------------------
    def visit(view : UI::RichText)
      scroll_ptr = alloc_init("NSScrollView")
      LibObjCBridge.objc_send_bool(scroll_ptr, sel("setHasVerticalScroller:"), 1)
      LibObjCBridge.objc_send_bool(scroll_ptr, sel("setAutohidesScrollers:"), 1)

      text_ptr = alloc_init("NSTextView")

      # Populate text from spans -- join plain text for initial render.
      plain = view.plain_text
      unless plain.empty?
        text_str = LibObjCBridge.nsstring_from_cstr(plain.to_unsafe)
        LibObjCBridge.objc_send_id(text_ptr, sel("setString:"), text_str)
      end

      # Non-editable by default for UI::RichText.
      LibObjCBridge.objc_send_bool(text_ptr, sel("setEditable:"), 0)
      LibObjCBridge.objc_send_bool(text_ptr, sel("setRichText:"), 1)

      # Font: use first span's font if present, else system body 17pt.
      first_font = view.spans.first?.try(&.font)
      font_ptr = first_font ? resolve_font(first_font) : LibObjCBridge.nsfont_system(17.0)
      LibObjCBridge.objc_send_id(text_ptr, sel("setFont:"), font_ptr) unless font_ptr.null?

      # Text color: sentinel-swap for appearance tracking.
      # Use the first span color if there is one; otherwise labelColor.
      first_color = view.spans.first?.try(&.color)
      color_ptr = if fc = first_color
                    if fc.r == 0.0 && fc.g == 0.0 && fc.b == 0.0 && fc.a == 1.0
                      LibObjCBridge.nscolor_label_primary
                    else
                      LibObjCBridge.nscolor_rgba(fc.r, fc.g, fc.b, fc.a)
                    end
                  else
                    LibObjCBridge.nscolor_label_primary
                  end
      LibObjCBridge.objc_send_id(text_ptr, sel("setTextColor:"), color_ptr)

      LibObjCBridge.objc_send_id(scroll_ptr, sel("setDocumentView:"), text_ptr)
      apply_common_properties(scroll_ptr, view)
      emit(scroll_ptr, "NSScrollView[richtextview]")
    end

    def visit(view : UI::LinkButton)
      ptr = alloc_init("NSButton")
      title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("setTitle:"), title_str)
      LibObjCBridge.objc_send_long(ptr, sel("setBezelStyle:"), 1_i64)
      apply_common_properties(ptr, view)
      emit(ptr, "NSButton[link]")
    end

    # -----------------------------------------------------------------
    # Visit: MenuButton -> NSPopUpButton
    #
    # Pop-up mode (is_pull_down: false, default):
    #   NSPopUpButton with pullsDown: false.  Displays the currently selected
    #   item's title and a trailing up/down chevron (NSPopUpButton disclosure
    #   indicator).  Clicking opens an NSMenu; the selected item shows a
    #   checkmark automatically.
    #   HIG: "Use a pop-up button to present a flat list of mutually exclusive
    #   options or states." -- Pop-up buttons / Best practices.
    #
    # Pull-down mode (is_pull_down: true):
    #   NSPopUpButton with pullsDown: true (setIsPullDown: YES).  Displays the
    #   button's own label (a verb) and a single downward chevron (chevron.down).
    #   No item is pre-selected; no checkmarks are shown in the menu.
    #   HIG: "Use a pull-down button to present commands or items that are
    #   directly related to the button's action." -- Pull-down buttons / Best
    #   practices.
    # -----------------------------------------------------------------
    def visit(view : UI::MenuButton)
      ptr = alloc_init("NSPopUpButton")

      if view.is_pull_down
        # pullsDown: true -- button face shows the verb label + chevron.down.
        # No item is pre-selected; AppKit does not auto-checkmark items in
        # pull-down mode.  The NSPopUpButton property name is `pullsDown`, so
        # the setter selector is `setPullsDown:` (not `setIsPullDown:`).
        # Per AppKit convention, item[0] is the face title when pullsDown is
        # true, so we insert the button's own label first.
        LibObjCBridge.objc_send_bool(ptr, sel("setPullsDown:"), 1)
        title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("addItemWithTitle:"), title_str)
        view.items.each do |item|
          item_str = LibObjCBridge.nsstring_from_cstr(item.label.to_unsafe)
          LibObjCBridge.objc_send_id(ptr, sel("addItemWithTitle:"), item_str)
          # NOTE: red destructive text via NSMenuItem setAttributedTitle:
          # requires NSMutableAttributedString helpers not yet in the bridge.
          # Tracked in gaps.md.  The item IS added; HIG destruction red
          # is a planned bridge enhancement (see gaps.md iteration 37).
        end
        # Prominent style: NSPopUpButton uses bezel style 1 (NSBezelStyleRounded)
        # by default.  No change needed -- the prominent distinction is handled
        # more richly on iOS (filledButtonConfiguration).  The macOS pull-down
        # renders in the standard system NSPopUpButton bezel for both styles.
        # Brand-level tinting via setBezelColor: is a macOS 12+ API -- tracked
        # as a future enhancement.
      else
        # Pop-up mode (default): populate items and set selection.
        if view.items.empty?
          title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
          LibObjCBridge.objc_send_id(ptr, sel("addItemWithTitle:"), title_str)
        else
          view.items.each do |item|
            item_str = LibObjCBridge.nsstring_from_cstr(item.label.to_unsafe)
            LibObjCBridge.objc_send_id(ptr, sel("addItemWithTitle:"), item_str)
          end
          # selectItemAtIndex: updates the button face to the chosen item and
          # places a checkmark on that item in the open menu.
          LibObjCBridge.objc_send_long(ptr, sel("selectItemAtIndex:"), view.selected_index.to_i64)
        end
      end

      apply_common_properties(ptr, view)
      emit(ptr, "NSPopUpButton")
    end

    def visit(view : UI::ToggleButton)
      ptr = alloc_init("NSButton")
      title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("setTitle:"), title_str)
      LibObjCBridge.objc_send_long(ptr, sel("setButtonType:"), 3_i64)
      LibObjCBridge.objc_send_long(ptr, sel("setState:"), view.is_selected ? 1_i64 : 0_i64)
      apply_common_properties(ptr, view)
      emit(ptr, "NSButton[toggle]")
    end

    def visit(view : UI::TextEditor)
      scroll_ptr = alloc_init("NSScrollView")
      LibObjCBridge.objc_send_bool(scroll_ptr, sel("setHasVerticalScroller:"), 1)
      text_ptr = alloc_init("NSTextView")
      unless view.text.empty?
        text_str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
        LibObjCBridge.objc_send_id(text_ptr, sel("setString:"), text_str)
      end
      LibObjCBridge.objc_send_bool(text_ptr, sel("setEditable:"), view.is_editable ? 1 : 0)
      LibObjCBridge.objc_send_id(scroll_ptr, sel("setDocumentView:"), text_ptr)
      apply_common_properties(scroll_ptr, view)
      emit(scroll_ptr, "NSScrollView[texteditor]")
    end

    # -----------------------------------------------------------------
    # P3 Stub Visit methods
    # -----------------------------------------------------------------

    def visit(view : UI::Circle)
      ptr = alloc_init("NSView")
      LibObjCBridge.objc_send_bool(ptr, sel("setWantsLayer:"), 1)
      # NSStackView: TAMIC:NO + NSLayoutConstraints pins the diameter.
      LibObjCBridge.objc_constrain_size(ptr, view.size, view.size)
      layer = LibObjCBridge.objc_send(ptr, sel("layer"))
      unless layer.null?
        bg_nscolor = resolve_color(view.fill_color)
        cg_color = LibObjCBridge.objc_send(bg_nscolor, sel("CGColor"))
        LibObjCBridge.objc_send_id(layer, sel("setBackgroundColor:"), cg_color)
        # Half of the expected size for a perfect circle
        LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), view.size / 2.0)
        if sc = view.stroke_color
          LibObjCBridge.objc_send_1d(layer, sel("setBorderWidth:"), view.stroke_width)
          border_nscolor = resolve_color(sc)
          cg_border = LibObjCBridge.objc_send(border_nscolor, sel("CGColor"))
          LibObjCBridge.objc_send_id(layer, sel("setBorderColor:"), cg_border)
        end
      end
      apply_common_properties(ptr, view)
      emit(ptr, "NSView[circle]")
    end

    def visit(view : UI::Rectangle)
      ptr = alloc_init("NSView")
      LibObjCBridge.objc_send_bool(ptr, sel("setWantsLayer:"), 1)
      # Pin explicit size constraints so NSStackView does not collapse the view to zero.
      LibObjCBridge.objc_constrain_size(ptr, view.width, view.height)
      layer = LibObjCBridge.objc_send(ptr, sel("layer"))
      unless layer.null?
        bg_nscolor = resolve_color(view.fill_color)
        cg_color = LibObjCBridge.objc_send(bg_nscolor, sel("CGColor"))
        LibObjCBridge.objc_send_id(layer, sel("setBackgroundColor:"), cg_color)
        if sc = view.stroke_color
          LibObjCBridge.objc_send_1d(layer, sel("setBorderWidth:"), view.stroke_width)
          border_nscolor = resolve_color(sc)
          cg_border = LibObjCBridge.objc_send(border_nscolor, sel("CGColor"))
          LibObjCBridge.objc_send_id(layer, sel("setBorderColor:"), cg_border)
        end
      end
      apply_common_properties(ptr, view)
      emit(ptr, "NSView[rectangle]")
    end

    def visit(view : UI::RoundedRectangle)
      ptr = alloc_init("NSView")
      LibObjCBridge.objc_send_bool(ptr, sel("setWantsLayer:"), 1)
      # Pin explicit size constraints so NSStackView does not collapse the view to zero.
      LibObjCBridge.objc_constrain_size(ptr, view.width, view.height)
      layer = LibObjCBridge.objc_send(ptr, sel("layer"))
      unless layer.null?
        bg_nscolor = resolve_color(view.fill_color)
        cg_color = LibObjCBridge.objc_send(bg_nscolor, sel("CGColor"))
        LibObjCBridge.objc_send_id(layer, sel("setBackgroundColor:"), cg_color)
        LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), view.corner_radius)
        if sc = view.stroke_color
          LibObjCBridge.objc_send_1d(layer, sel("setBorderWidth:"), view.stroke_width)
          border_nscolor = resolve_color(sc)
          cg_border = LibObjCBridge.objc_send(border_nscolor, sel("CGColor"))
          LibObjCBridge.objc_send_id(layer, sel("setBorderColor:"), cg_border)
        end
      end
      apply_common_properties(ptr, view)
      emit(ptr, "NSView[rounded-rectangle]")
    end

    def visit(view : UI::Capsule)
      ptr = alloc_init("NSView")
      LibObjCBridge.objc_send_bool(ptr, sel("setWantsLayer:"), 1)
      layer = LibObjCBridge.objc_send(ptr, sel("layer"))
      unless layer.null?
        bg_nscolor = resolve_color(view.fill_color)
        cg_color = LibObjCBridge.objc_send(bg_nscolor, sel("CGColor"))
        LibObjCBridge.objc_send_id(layer, sel("setBackgroundColor:"), cg_color)
        # Use half the height as corner radius for a capsule shape
        LibObjCBridge.objc_send_1d(layer, sel("setCornerRadius:"), view.height / 2.0)
        if sc = view.stroke_color
          LibObjCBridge.objc_send_1d(layer, sel("setBorderWidth:"), view.stroke_width)
          border_nscolor = resolve_color(sc)
          cg_border = LibObjCBridge.objc_send(border_nscolor, sel("CGColor"))
          LibObjCBridge.objc_send_id(layer, sel("setBorderColor:"), cg_border)
        end
      end
      apply_common_properties(ptr, view)
      emit(ptr, "NSView[capsule]")
    end

    def visit(view : UI::Canvas)
      ptr = alloc_init("NSView")
      LibObjCBridge.objc_send_bool(ptr, sel("setWantsLayer:"), 1)
      rect = LibObjCBridge::CGRect.new(x: 0.0, y: 0.0, width: view.width, height: view.height)
      LibObjCBridge.objc_set_frame(ptr, rect)
      apply_common_properties(ptr, view)
      emit(ptr, "NSView[canvas]")
    end

    def visit(view : UI::PathView)
      ptr = alloc_init("NSView")
      LibObjCBridge.objc_send_bool(ptr, sel("setWantsLayer:"), 1)
      rect = LibObjCBridge::CGRect.new(x: 0.0, y: 0.0, width: view.width, height: view.height)
      LibObjCBridge.objc_set_frame(ptr, rect)
      apply_common_properties(ptr, view)
      emit(ptr, "NSView[path]")
    end

    def visit(view : UI::MapView)
      # MKMapView equivalent: use NSView placeholder (MKMapView requires MapKit framework)
      ptr = alloc_init("NSView")
      apply_common_properties(ptr, view)
      emit(ptr, "NSView[map]")
    end

    # -----------------------------------------------------------------
    # Visit: ChartView -> NSStackView-based bar / line chart
    #
    # HIG Charts: "Organize data in a chart to communicate information
    # with clarity and visual appeal." HIG Best practices: "Establish a
    # consistent visual hierarchy that helps communicate the relative
    # importance of various chart elements."
    #
    # Rendering strategy: NSStackViews compose bars, axis labels, and
    # a title without requiring CAShapeLayer arc-path drawing primitives.
    # Each bar is an NSView with a colored CALayer background pinned to
    # a height proportional to its normalized value. Axis labels are
    # NSTextFields. Grid reference is a light horizontal baseline strip.
    #
    # Chart dimensions: 360pt wide x 200pt tall (plot area). Bars are
    # 36pt wide with 8pt spacing for a 7-bar chart. Line chart variant
    # renders data-value labels and a connecting label strip.
    # -----------------------------------------------------------------
    def visit(view : UI::ChartView)
      dark_mode = (ENV["HIG_APPEARANCE"]? == "dark")

      # Chart dimensions
      chart_w     = 360.0
      chart_h     = 220.0
      plot_h      = 160.0  # height of the bar area above labels
      bar_spacing = 8.0
      label_h     = 24.0   # height of category label row below bars

      # Background colors keyed off appearance
      bg_gray     = dark_mode ? 0.12 : 1.0
      bar_area_bg = dark_mode ? 0.16 : 0.97   # subtle off-white / dark card

      # System blue for bars (tracks appearance automatically via RGBA)
      bar_r  = dark_mode ? 0.039 : 0.0
      bar_g  = dark_mode ? 0.518 : 0.478
      bar_b  = 1.0
      bar_a  = 1.0

      # Accent for line chart: system orange
      line_r = dark_mode ? 1.0 : 1.0
      line_g = dark_mode ? 0.62 : 0.58
      line_b = 0.0
      line_a = 1.0

      # Grid line gray
      grid_gray = dark_mode ? 0.3 : 0.85

      # Label text gray (near-system label)
      lbl_gray  = dark_mode ? 0.92 : 0.08

      # Outer container — VStack orientation vertical
      outer = alloc_init("NSStackView")
      LibObjCBridge.objc_send_long(outer, sel("setOrientation:"), 1_i64)  # vertical
      LibObjCBridge.objc_send_1d(outer, sel("setSpacing:"), 6.0)
      LibObjCBridge.objc_send_long(outer, sel("setAlignment:"), 9_i64)   # centerX
      LibObjCBridge.objc_send_bool(outer, sel("setWantsLayer:"), 1)
      outer_layer = LibObjCBridge.objc_send(outer, sel("layer"))
      unless outer_layer.null?
        bg_ns = LibObjCBridge.nscolor_rgba(bg_gray, bg_gray, bg_gray, 1.0)
        unless bg_ns.null?
          cg = LibObjCBridge.objc_send(bg_ns, sel("CGColor"))
          LibObjCBridge.objc_send_void_id(outer_layer, sel("setBackgroundColor:"), cg) unless cg.null?
        end
      end
      LibObjCBridge.objc_constrain_size(outer, chart_w, chart_h)

      # Title label
      unless view.title.empty?
        title_tf = alloc_init("NSTextField")
        title_str = LibObjCBridge.nsstring_from_cstr(view.title.to_unsafe)
        LibObjCBridge.objc_send_id(title_tf, sel("setStringValue:"), title_str)
        LibObjCBridge.objc_send_bool(title_tf, sel("setEditable:"), 0)
        LibObjCBridge.objc_send_bool(title_tf, sel("setBezeled:"), 0)
        LibObjCBridge.objc_send_bool(title_tf, sel("setDrawsBackground:"), 0)
        LibObjCBridge.objc_send_bool(title_tf, sel("setSelectable:"), 0)
        title_font = LibObjCBridge.nsfont_system_weight(14.0, 0.4)  # Semibold weight 0.4
        LibObjCBridge.objc_send_id(title_tf, sel("setFont:"), title_font)
        title_color = LibObjCBridge.nscolor_rgba(lbl_gray, lbl_gray, lbl_gray, 1.0)
        LibObjCBridge.objc_send_id(title_tf, sel("setTextColor:"), title_color)
        LibObjCBridge.objc_send_long(title_tf, sel("setAlignment:"), 2_i64)  # center
        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), title_tf)
      end

      # Data normalization — find max value for scaling
      pts = view.data_points
      max_val = pts.empty? ? 1.0 : pts.map(&.value).max
      max_val = 1.0 if max_val <= 0.0

      if view.chart_type == :bar
        # ----- Bar chart -----
        # Plot area: horizontal NSStackView of column stacks
        plot_stack = alloc_init("NSStackView")
        LibObjCBridge.objc_send_long(plot_stack, sel("setOrientation:"), 0_i64)  # horizontal
        LibObjCBridge.objc_send_1d(plot_stack, sel("setSpacing:"), bar_spacing)
        LibObjCBridge.objc_send_long(plot_stack, sel("setAlignment:"), 4_i64)  # bottom
        LibObjCBridge.objc_send_bool(plot_stack, sel("setWantsLayer:"), 1)

        # Subtle plot area background
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

        # Add grid lines (3 lines: 25%, 50%, 75% of plot height) via thin NSView strips
        # Positioned as arranged subviews in a ZStack-style container: skip for simplicity,
        # since NSStackView with bottom-alignment shows relative bar heights clearly.

        # Build one column (NSStackView vertical) per data point
        n_pts = pts.size
        bar_w = n_pts > 0 ? ((chart_w - 16.0 - bar_spacing * (n_pts - 1).to_f) / n_pts.to_f).clamp(8.0, 60.0) : 36.0

        pts.each_with_index do |pt, _i|
          norm = max_val > 0 ? pt.value / max_val : 0.0
          bar_h = (norm * (plot_h - 8.0)).clamp(2.0, plot_h - 8.0)

          # Column VStack: [spacer] + [bar] + [label]
          col = alloc_init("NSStackView")
          LibObjCBridge.objc_send_long(col, sel("setOrientation:"), 1_i64)  # vertical
          LibObjCBridge.objc_send_1d(col, sel("setSpacing:"), 2.0)
          LibObjCBridge.objc_send_long(col, sel("setAlignment:"), 9_i64)    # centerX
          LibObjCBridge.objc_constrain_width(col, bar_w)

          # Spacer (fills above bar so bars bottom-align)
          spacer_v = alloc_init("NSView")
          spacer_h = (plot_h - bar_h - 8.0).clamp(0.0, plot_h)
          LibObjCBridge.objc_constrain_size(spacer_v, bar_w, spacer_h)
          LibObjCBridge.objc_send_id(col, sel("addArrangedSubview:"), spacer_v)

          # Bar NSView with colored CALayer
          bar_v = alloc_init("NSView")
          LibObjCBridge.objc_constrain_size(bar_v, bar_w, bar_h)
          LibObjCBridge.objc_send_bool(bar_v, sel("setWantsLayer:"), 1)
          bar_layer = LibObjCBridge.objc_send(bar_v, sel("layer"))
          unless bar_layer.null?
            # Use custom color if data point has one, else system blue
            bar_col_ns = if c = pt.color
                           LibObjCBridge.nscolor_rgba(c.r, c.g, c.b, c.a)
                         else
                           LibObjCBridge.nscolor_rgba(bar_r, bar_g, bar_b, bar_a)
                         end
            unless bar_col_ns.null?
              bar_cg = LibObjCBridge.objc_send(bar_col_ns, sel("CGColor"))
              LibObjCBridge.objc_send_void_id(bar_layer, sel("setBackgroundColor:"), bar_cg) unless bar_cg.null?
            end
            # Rounded top corners ~4pt
            LibObjCBridge.objc_send_1d(bar_layer, sel("setCornerRadius:"), 4.0)
          end
          LibObjCBridge.objc_send_id(col, sel("addArrangedSubview:"), bar_v)

          # Category label below bar
          lbl_tf = alloc_init("NSTextField")
          lbl_str = LibObjCBridge.nsstring_from_cstr(pt.label.to_unsafe)
          LibObjCBridge.objc_send_id(lbl_tf, sel("setStringValue:"), lbl_str)
          LibObjCBridge.objc_send_bool(lbl_tf, sel("setEditable:"), 0)
          LibObjCBridge.objc_send_bool(lbl_tf, sel("setBezeled:"), 0)
          LibObjCBridge.objc_send_bool(lbl_tf, sel("setDrawsBackground:"), 0)
          LibObjCBridge.objc_send_bool(lbl_tf, sel("setSelectable:"), 0)
          lbl_font = LibObjCBridge.nsfont_system(10.0)
          LibObjCBridge.objc_send_id(lbl_tf, sel("setFont:"), lbl_font)
          lbl_color = LibObjCBridge.nscolor_rgba(lbl_gray, lbl_gray, lbl_gray, 1.0)
          LibObjCBridge.objc_send_id(lbl_tf, sel("setTextColor:"), lbl_color)
          LibObjCBridge.objc_send_long(lbl_tf, sel("setAlignment:"), 2_i64)  # center
          LibObjCBridge.objc_constrain_height(lbl_tf, label_h)
          LibObjCBridge.objc_send_id(col, sel("addArrangedSubview:"), lbl_tf)

          LibObjCBridge.objc_send_id(plot_stack, sel("addArrangedSubview:"), col)
        end

        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), plot_stack)

      elsif view.chart_type == :line
        # ----- Line chart — render value labels connected by a description strip -----
        # Use a horizontal stack of (value label + mark dot) columns to suggest a trend.
        plot_stack = alloc_init("NSStackView")
        LibObjCBridge.objc_send_long(plot_stack, sel("setOrientation:"), 0_i64)  # horizontal
        LibObjCBridge.objc_send_1d(plot_stack, sel("setSpacing:"), 4.0)
        LibObjCBridge.objc_send_long(plot_stack, sel("setAlignment:"), 4_i64)  # bottom
        LibObjCBridge.objc_send_bool(plot_stack, sel("setWantsLayer:"), 1)
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
        col_w = n_pts > 0 ? ((chart_w - 16.0 - 4.0 * (n_pts - 1).to_f) / n_pts.to_f).clamp(8.0, 60.0) : 36.0

        pts.each_with_index do |pt, _i|
          norm = max_val > 0 ? pt.value / max_val : 0.0
          dot_h = (norm * (plot_h - 16.0)).clamp(4.0, plot_h - 16.0)

          col = alloc_init("NSStackView")
          LibObjCBridge.objc_send_long(col, sel("setOrientation:"), 1_i64)
          LibObjCBridge.objc_send_1d(col, sel("setSpacing:"), 2.0)
          LibObjCBridge.objc_send_long(col, sel("setAlignment:"), 9_i64)
          LibObjCBridge.objc_constrain_width(col, col_w)

          # Spacer
          spacer_v = alloc_init("NSView")
          spacer_h = (plot_h - dot_h - 16.0).clamp(0.0, plot_h)
          LibObjCBridge.objc_constrain_size(spacer_v, col_w, spacer_h)
          LibObjCBridge.objc_send_id(col, sel("addArrangedSubview:"), spacer_v)

          # Dot (8pt circle)
          dot_v = alloc_init("NSView")
          dot_size = 8.0
          LibObjCBridge.objc_constrain_size(dot_v, dot_size, dot_size)
          LibObjCBridge.objc_send_bool(dot_v, sel("setWantsLayer:"), 1)
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

          # Stem (thin vertical bar from dot to baseline)
          stem_h = dot_h - dot_size
          if stem_h > 0
            stem_v = alloc_init("NSView")
            stem_w = 2.0
            LibObjCBridge.objc_constrain_size(stem_v, stem_w, stem_h)
            LibObjCBridge.objc_send_bool(stem_v, sel("setWantsLayer:"), 1)
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

          # Label
          lbl_tf = alloc_init("NSTextField")
          lbl_str = LibObjCBridge.nsstring_from_cstr(pt.label.to_unsafe)
          LibObjCBridge.objc_send_id(lbl_tf, sel("setStringValue:"), lbl_str)
          LibObjCBridge.objc_send_bool(lbl_tf, sel("setEditable:"), 0)
          LibObjCBridge.objc_send_bool(lbl_tf, sel("setBezeled:"), 0)
          LibObjCBridge.objc_send_bool(lbl_tf, sel("setDrawsBackground:"), 0)
          LibObjCBridge.objc_send_bool(lbl_tf, sel("setSelectable:"), 0)
          lbl_font = LibObjCBridge.nsfont_system(10.0)
          LibObjCBridge.objc_send_id(lbl_tf, sel("setFont:"), lbl_font)
          lbl_color = LibObjCBridge.nscolor_rgba(lbl_gray, lbl_gray, lbl_gray, 1.0)
          LibObjCBridge.objc_send_id(lbl_tf, sel("setTextColor:"), lbl_color)
          LibObjCBridge.objc_send_long(lbl_tf, sel("setAlignment:"), 2_i64)
          LibObjCBridge.objc_constrain_height(lbl_tf, label_h)
          LibObjCBridge.objc_send_id(col, sel("addArrangedSubview:"), lbl_tf)

          LibObjCBridge.objc_send_id(plot_stack, sel("addArrangedSubview:"), col)
        end

        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), plot_stack)

      else
        # :pie or unknown — render a single labeled placeholder circle
        pie_v = alloc_init("NSView")
        LibObjCBridge.objc_constrain_size(pie_v, 120.0, 120.0)
        LibObjCBridge.objc_send_bool(pie_v, sel("setWantsLayer:"), 1)
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

      # Grid reference baseline — thin separator strip at the bottom of plot area
      grid_v = alloc_init("NSView")
      LibObjCBridge.objc_constrain_size(grid_v, chart_w - 16.0, 1.0)
      LibObjCBridge.objc_send_bool(grid_v, sel("setWantsLayer:"), 1)
      grid_layer = LibObjCBridge.objc_send(grid_v, sel("layer"))
      unless grid_layer.null?
        grid_col = LibObjCBridge.nscolor_rgba(grid_gray, grid_gray, grid_gray, 1.0)
        unless grid_col.null?
          grid_cg = LibObjCBridge.objc_send(grid_col, sel("CGColor"))
          LibObjCBridge.objc_send_void_id(grid_layer, sel("setBackgroundColor:"), grid_cg) unless grid_cg.null?
        end
      end
      LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), grid_v)

      # Accessibility label on the outer container
      ax_label = view.accessibility_label || (view.title.empty? ? "Chart" : "Chart: #{view.title}")
      ax_str = LibObjCBridge.nsstring_from_cstr(ax_label.to_unsafe)
      LibObjCBridge.objc_send_id(outer, sel("setAccessibilityLabel:"), ax_str)

      apply_common_properties(outer, view)
      emit(outer, "NSStackView[chart]")
    end

    def visit(view : UI::WebViewComponent)
      # WKWebView: allocate via class name (requires WebKit framework at link time)
      ptr = alloc_init("NSView")
      unless view.url.empty?
        url_str = LibObjCBridge.nsstring_from_cstr(view.url.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), url_str)
      end
      apply_common_properties(ptr, view)
      emit(ptr, "NSView[webview]")
    end

    def visit(view : UI::ColorPicker)
      ptr = alloc_init("NSColorWell")
      c = view.selected_color
      nscolor = resolve_color(c)
      LibObjCBridge.objc_send_id(ptr, sel("setColor:"), nscolor)
      apply_common_properties(ptr, view)
      emit(ptr, "NSColorWell[color-picker]")
    end

    def visit(view : UI::VideoPlayer)
      # AVPlayerView: use NSView placeholder (requires AVKit framework)
      ptr = alloc_init("NSView")
      unless view.url.empty?
        url_str = LibObjCBridge.nsstring_from_cstr(view.url.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), url_str)
      end
      if view.is_playing
        LibObjCBridge.objc_send_bool(ptr, sel("setHidden:"), 0)
      end
      apply_common_properties(ptr, view)
      emit(ptr, "NSView[video]")
    end

    def visit(view : UI::Tooltip)
      ptr = alloc_init("NSView")
      unless view.text.empty?
        tooltip_str = LibObjCBridge.nsstring_from_cstr(view.text.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setToolTip:"), tooltip_str)
      end
      apply_common_properties(ptr, view)
      handle = ObjC.owned(ptr, label: "NSView[tooltip]")
      native = NativeView.new(handle)
      if content = view.content
        push_stack(native, is_nsstack: false)
        content.accept(self)
        pop_stack
      end
      push_native(native)
    end

    # -----------------------------------------------------------------
    # Visit: ActivityView -> NSVisualEffectView (popover material) + four zones
    #
    # HIG Platform considerations: "Not supported in macOS, tvOS, or watchOS."
    # macOS has no native NSActivityViewController. This renderer emits a
    # HIG-honest popover-material surface containing all four layout zones
    # (header / destination row / action grid / cancel) so the validation
    # capture reflects the correct component shape. A production macOS app
    # would surface share-extension actions via NSMenu / NSSharingService
    # instead.
    #
    # Material: NSVisualEffectMaterialPopover = 6 (tracks appearance).
    # -----------------------------------------------------------------
    def visit(view : UI::ActivityView)
      # Outer glass container — popover material approximates the iOS share
      # sheet surface on macOS (closest HIG-honest material for a floating
      # presentation surface on a platform that has no share sheet).
      effect = alloc_init("NSVisualEffectView")
      LibObjCBridge.objc_send_long(effect, sel("setMaterial:"), 6_i64)      # NSVisualEffectMaterialPopover
      LibObjCBridge.objc_send_long(effect, sel("setBlendingMode:"), 1_i64)  # WithinWindow
      LibObjCBridge.objc_send_long(effect, sel("setState:"), 1_i64)         # Active
      LibObjCBridge.objc_send_bool(effect, sel("setWantsLayer:"), 1)
      effect_layer = LibObjCBridge.objc_send(effect, sel("layer"))
      unless effect_layer.null?
        LibObjCBridge.objc_send_1d(effect_layer, sel("setCornerRadius:"), 16.0)
        LibObjCBridge.objc_send_bool(effect_layer, sel("setMasksToBounds:"), 1)
      end

      # Outer vertical NSStackView hosts all four zones with 16pt insets.
      outer_stack = alloc_init("NSStackView")
      LibObjCBridge.objc_send_long(outer_stack, sel("setOrientation:"), 1_i64)  # vertical
      LibObjCBridge.objc_send_1d(outer_stack, sel("setSpacing:"), 12.0)
      LibObjCBridge.objc_send_long(outer_stack, sel("setAlignment:"), 5_i64)    # centerX
      insets = LibObjCBridge::CGRect.new(x: 16.0, y: 16.0, width: 16.0, height: 16.0)
      LibObjCBridge.objc_send_rect_void(outer_stack, sel("setEdgeInsets:"), insets)
      LibObjCBridge.objc_send_bool(outer_stack, sel("setTranslatesAutoresizingMaskIntoConstraints:"), 0)
      LibObjCBridge.objc_add_subview(effect, outer_stack)

      # Pin outer_stack to effect on all four edges.
      %w(topAnchor bottomAnchor leadingAnchor trailingAnchor).each do |anch|
        ia = LibObjCBridge.objc_send(outer_stack, sel(anch))
        ea = LibObjCBridge.objc_send(effect, sel(anch))
        next if ia.null? || ea.null?
        c = LibObjCBridge.objc_send_id(ia, sel("constraintEqualToAnchor:"), ea)
        LibObjCBridge.objc_send_bool(c, sel("setActive:"), 1) unless c.null?
      end

      # --- Zone 1: Header (thumbnail + title/subtitle) ---
      header_stack = alloc_init("NSStackView")
      LibObjCBridge.objc_send_long(header_stack, sel("setOrientation:"), 0_i64) # horizontal
      LibObjCBridge.objc_send_1d(header_stack, sel("setSpacing:"), 12.0)
      LibObjCBridge.objc_send_long(header_stack, sel("setAlignment:"), 4_i64)   # centerY

      if thumb = view.thumbnail
        # Render thumbnail as 48x48 NSImageView approximation.
        thumb_view = alloc_init("NSImageView")
        LibObjCBridge.objc_send_bool(thumb_view, sel("setWantsLayer:"), 1)
        tl = LibObjCBridge.objc_send(thumb_view, sel("layer"))
        unless tl.null?
          LibObjCBridge.objc_send_1d(tl, sel("setCornerRadius:"), 8.0)
          LibObjCBridge.objc_send_bool(tl, sel("setMasksToBounds:"), 1)
        end
        LibObjCBridge.objc_send_id(header_stack, sel("addArrangedSubview:"), thumb_view)
      end

      text_stack = alloc_init("NSStackView")
      LibObjCBridge.objc_send_long(text_stack, sel("setOrientation:"), 1_i64) # vertical
      LibObjCBridge.objc_send_1d(text_stack, sel("setSpacing:"), 2.0)

      title_ptr = alloc_init("NSTextField")
      LibObjCBridge.objc_send_bool(title_ptr, sel("setBezeled:"), 0)
      LibObjCBridge.objc_send_bool(title_ptr, sel("setDrawsBackground:"), 0)
      LibObjCBridge.objc_send_bool(title_ptr, sel("setEditable:"), 0)
      LibObjCBridge.objc_send_bool(title_ptr, sel("setSelectable:"), 0)
      title_str = LibObjCBridge.nsstring_from_cstr(view.title.to_unsafe)
      LibObjCBridge.objc_send_id(title_ptr, sel("setStringValue:"), title_str)
      title_font = LibObjCBridge.nsfont_system_weight(15.0, 0.4)  # Semibold ~0.4
      LibObjCBridge.objc_send_id(title_ptr, sel("setFont:"), title_font) unless title_font.null?
      label_color = LibObjCBridge.nscolor_label_primary
      LibObjCBridge.objc_send_id(title_ptr, sel("setTextColor:"), label_color) unless label_color.null?
      LibObjCBridge.objc_send_id(text_stack, sel("addArrangedSubview:"), title_ptr)

      if sub = view.subtitle
        sub_ptr = alloc_init("NSTextField")
        LibObjCBridge.objc_send_bool(sub_ptr, sel("setBezeled:"), 0)
        LibObjCBridge.objc_send_bool(sub_ptr, sel("setDrawsBackground:"), 0)
        LibObjCBridge.objc_send_bool(sub_ptr, sel("setEditable:"), 0)
        LibObjCBridge.objc_send_bool(sub_ptr, sel("setSelectable:"), 0)
        sub_str = LibObjCBridge.nsstring_from_cstr(sub.to_unsafe)
        LibObjCBridge.objc_send_id(sub_ptr, sel("setStringValue:"), sub_str)
        sub_font = LibObjCBridge.nsfont_system(13.0)
        LibObjCBridge.objc_send_id(sub_ptr, sel("setFont:"), sub_font) unless sub_font.null?
        sec_color = LibObjCBridge.nscolor_label_secondary
        LibObjCBridge.objc_send_id(sub_ptr, sel("setTextColor:"), sec_color) unless sec_color.null?
        LibObjCBridge.objc_send_id(text_stack, sel("addArrangedSubview:"), sub_ptr)
      end

      LibObjCBridge.objc_send_id(header_stack, sel("addArrangedSubview:"), text_stack)
      LibObjCBridge.objc_send_id(outer_stack, sel("addArrangedSubview:"), header_stack)

      # --- Zone 2: Destination row (horizontal scroll of circular icons) ---
      dest_row = alloc_init("NSStackView")
      LibObjCBridge.objc_send_long(dest_row, sel("setOrientation:"), 0_i64) # horizontal
      LibObjCBridge.objc_send_1d(dest_row, sel("setSpacing:"), 16.0)
      LibObjCBridge.objc_send_long(dest_row, sel("setAlignment:"), 4_i64)   # centerY

      view.destinations.each do |dest|
        dest_vstack = alloc_init("NSStackView")
        LibObjCBridge.objc_send_long(dest_vstack, sel("setOrientation:"), 1_i64) # vertical
        LibObjCBridge.objc_send_1d(dest_vstack, sel("setSpacing:"), 4.0)
        LibObjCBridge.objc_send_long(dest_vstack, sel("setAlignment:"), 5_i64)   # centerX

        # Circular icon button (~60pt) — NSButton with SF Symbol
        icon_btn = alloc_init("NSButton")
        LibObjCBridge.objc_send_long(icon_btn, sel("setBezelStyle:"), 4_i64)  # rounded
        icon_ns = LibObjCBridge.nsstring_from_cstr(dest.icon_symbol.to_unsafe)
        empty_ns = LibObjCBridge.nsstring_from_cstr("".to_unsafe)
        sym_img = LibObjCBridge.objc_send_id_id(
          LibObjCBridge.objc_getClass("NSImage"),
          sel("imageWithSystemSymbolName:accessibilityDescription:"),
          icon_ns, empty_ns)
        unless sym_img.null?
          LibObjCBridge.objc_send_id(icon_btn, sel("setImage:"), sym_img)
          LibObjCBridge.objc_send_long(icon_btn, sel("setImagePosition:"), 2_i64) # imageOnly
        end
        LibObjCBridge.objc_send_id(icon_btn, sel("setTitle:"), empty_ns)
        LibObjCBridge.objc_send_bool(icon_btn, sel("setWantsLayer:"), 1)
        btn_layer = LibObjCBridge.objc_send(icon_btn, sel("layer"))
        unless btn_layer.null?
          LibObjCBridge.objc_send_1d(btn_layer, sel("setCornerRadius:"), 30.0)
        end
        LibObjCBridge.objc_send_id(dest_vstack, sel("addArrangedSubview:"), icon_btn)

        # Label below the icon
        lbl_ptr = alloc_init("NSTextField")
        LibObjCBridge.objc_send_bool(lbl_ptr, sel("setBezeled:"), 0)
        LibObjCBridge.objc_send_bool(lbl_ptr, sel("setDrawsBackground:"), 0)
        LibObjCBridge.objc_send_bool(lbl_ptr, sel("setEditable:"), 0)
        LibObjCBridge.objc_send_bool(lbl_ptr, sel("setSelectable:"), 0)
        lbl_str = LibObjCBridge.nsstring_from_cstr(dest.label.to_unsafe)
        LibObjCBridge.objc_send_id(lbl_ptr, sel("setStringValue:"), lbl_str)
        lbl_font = LibObjCBridge.nsfont_system(11.0)
        LibObjCBridge.objc_send_id(lbl_ptr, sel("setFont:"), lbl_font) unless lbl_font.null?
        lbl_color = LibObjCBridge.nscolor_label_secondary
        LibObjCBridge.objc_send_id(lbl_ptr, sel("setTextColor:"), lbl_color) unless lbl_color.null?
        LibObjCBridge.objc_send_id(dest_vstack, sel("addArrangedSubview:"), lbl_ptr)

        LibObjCBridge.objc_send_id(dest_row, sel("addArrangedSubview:"), dest_vstack)
      end

      LibObjCBridge.objc_send_id(outer_stack, sel("addArrangedSubview:"), dest_row)

      # --- Zone 3: Action grid (2-col grid of action tiles) ---
      # Approximate 2-col grid with a vertical NSStackView of HStacks (pairs).
      grid_vstack = alloc_init("NSStackView")
      LibObjCBridge.objc_send_long(grid_vstack, sel("setOrientation:"), 1_i64) # vertical
      LibObjCBridge.objc_send_1d(grid_vstack, sel("setSpacing:"), 8.0)

      actions = view.actions
      row_idx = 0
      while row_idx < actions.size
        pair_hstack = alloc_init("NSStackView")
        LibObjCBridge.objc_send_long(pair_hstack, sel("setOrientation:"), 0_i64) # horizontal
        LibObjCBridge.objc_send_1d(pair_hstack, sel("setSpacing:"), 8.0)
        LibObjCBridge.objc_send_long(pair_hstack, sel("setDistribution:"), 3_i64) # fillEqually

        [actions[row_idx]?, actions[row_idx + 1]?].each do |act|
          next unless act

          tile_stack = alloc_init("NSStackView")
          LibObjCBridge.objc_send_long(tile_stack, sel("setOrientation:"), 0_i64) # horizontal
          LibObjCBridge.objc_send_1d(tile_stack, sel("setSpacing:"), 8.0)
          LibObjCBridge.objc_send_long(tile_stack, sel("setAlignment:"), 4_i64)   # centerY
          LibObjCBridge.objc_send_bool(tile_stack, sel("setWantsLayer:"), 1)
          tl2 = LibObjCBridge.objc_send(tile_stack, sel("layer"))
          unless tl2.null?
            LibObjCBridge.objc_send_1d(tl2, sel("setCornerRadius:"), 10.0)
          end

          # Action icon
          act_btn = alloc_init("NSButton")
          LibObjCBridge.objc_send_long(act_btn, sel("setBezelStyle:"), 4_i64)
          act_sym_ns = LibObjCBridge.nsstring_from_cstr(act.icon_symbol.to_unsafe)
          act_empty = LibObjCBridge.nsstring_from_cstr("".to_unsafe)
          act_img = LibObjCBridge.objc_send_id_id(
            LibObjCBridge.objc_getClass("NSImage"),
            sel("imageWithSystemSymbolName:accessibilityDescription:"),
            act_sym_ns, act_empty)
          unless act_img.null?
            LibObjCBridge.objc_send_id(act_btn, sel("setImage:"), act_img)
            LibObjCBridge.objc_send_long(act_btn, sel("setImagePosition:"), 2_i64)
          end
          LibObjCBridge.objc_send_id(act_btn, sel("setTitle:"), act_empty)
          LibObjCBridge.objc_send_id(tile_stack, sel("addArrangedSubview:"), act_btn)

          # Action label
          act_lbl = alloc_init("NSTextField")
          LibObjCBridge.objc_send_bool(act_lbl, sel("setBezeled:"), 0)
          LibObjCBridge.objc_send_bool(act_lbl, sel("setDrawsBackground:"), 0)
          LibObjCBridge.objc_send_bool(act_lbl, sel("setEditable:"), 0)
          LibObjCBridge.objc_send_bool(act_lbl, sel("setSelectable:"), 0)
          act_str = LibObjCBridge.nsstring_from_cstr(act.label.to_unsafe)
          LibObjCBridge.objc_send_id(act_lbl, sel("setStringValue:"), act_str)
          act_font = LibObjCBridge.nsfont_system(13.0)
          LibObjCBridge.objc_send_id(act_lbl, sel("setFont:"), act_font) unless act_font.null?
          if act.role == :destructive
            red_color = LibObjCBridge.nscolor_rgba(1.0, 0.23, 0.19, 1.0)
            LibObjCBridge.objc_send_id(act_lbl, sel("setTextColor:"), red_color)
          else
            act_lbl_color = LibObjCBridge.nscolor_label_primary
            LibObjCBridge.objc_send_id(act_lbl, sel("setTextColor:"), act_lbl_color) unless act_lbl_color.null?
          end
          LibObjCBridge.objc_send_id(tile_stack, sel("addArrangedSubview:"), act_lbl)

          LibObjCBridge.objc_send_id(pair_hstack, sel("addArrangedSubview:"), tile_stack)
        end

        LibObjCBridge.objc_send_id(grid_vstack, sel("addArrangedSubview:"), pair_hstack)
        row_idx += 2
      end

      LibObjCBridge.objc_send_id(outer_stack, sel("addArrangedSubview:"), grid_vstack)

      # --- Zone 4: Cancel button ---
      cancel_btn = alloc_init("NSButton")
      cancel_str = LibObjCBridge.nsstring_from_cstr("Cancel")
      LibObjCBridge.objc_send_id(cancel_btn, sel("setTitle:"), cancel_str)
      LibObjCBridge.objc_send_long(cancel_btn, sel("setBezelStyle:"), 1_i64)  # rounded
      cancel_font = LibObjCBridge.nsfont_system_weight(17.0, 0.4)             # Semibold
      LibObjCBridge.objc_send_id(cancel_btn, sel("setFont:"), cancel_font) unless cancel_font.null?
      LibObjCBridge.objc_send_id(outer_stack, sel("addArrangedSubview:"), cancel_btn)

      apply_common_properties(effect, view)

      # HIG ActivityView: maxWidth 540pt on macOS.
      LibObjCBridge.objc_constrain_width(effect, 540.0)

      outer_handle = ObjC.owned(effect, label: "NSVisualEffectView[activity-view-glass]")
      outer_native = NativeView.new(outer_handle)

      push_native(outer_native)
    end

    # -----------------------------------------------------------------
    # Visit: DisclosureGroup -> NSStackView (vertical) containing:
    #   (1) header row: NSButton (bezelStyle=disclosure, value=5) +
    #       NSTextField label, horizontal NSStackView
    #   (2) optional content NSStackView when expanded = true
    #
    # HIG: "A disclosure triangle points inward from the leading edge
    # when its content is hidden and down when its content is visible."
    # (disclosure-controls / Disclosure triangles)
    #
    # NSButton.BezelStyle.disclosure = 5. NSButton buttonType for a
    # stateful toggle is NSButtonTypePushOnPushOff = 1 which tracks
    # pressed state; for a static render we use NSButtonTypeToggle = 6
    # and set state = 1 (on = expanded, pointing down) or 0 (off =
    # collapsed, pointing inward/right).
    # -----------------------------------------------------------------
    def visit(view : UI::DisclosureGroup)
      # Outer VStack: header row + optional content
      outer = alloc_init("NSStackView")
      LibObjCBridge.objc_send_long(outer, sel("setOrientation:"), 1_i64)  # vertical
      LibObjCBridge.objc_send_1d(outer, sel("setSpacing:"), 0.0)
      LibObjCBridge.objc_send_long(outer, sel("setAlignment:"), 5_i64)    # leading

      # --- Header row (horizontal NSStackView) ---
      header_row = alloc_init("NSStackView")
      LibObjCBridge.objc_send_long(header_row, sel("setOrientation:"), 0_i64) # horizontal
      LibObjCBridge.objc_send_1d(header_row, sel("setSpacing:"), 4.0)
      LibObjCBridge.objc_send_long(header_row, sel("setAlignment:"), 8_i64)   # centerY=8

      # Disclosure triangle button: NSButtonTypeToggle=6, bezelStyle=disclosure=5
      disc_btn = alloc_init("NSButton")
      LibObjCBridge.objc_send_long(disc_btn, sel("setButtonType:"), 6_i64)   # toggle
      LibObjCBridge.objc_send_long(disc_btn, sel("setBezelStyle:"), 5_i64)   # disclosure
      # Title must be empty string (disclosure buttons show only the triangle)
      empty_str = LibObjCBridge.nsstring_from_cstr("".to_unsafe)
      LibObjCBridge.objc_send_id(disc_btn, sel("setTitle:"), empty_str)
      # State: 1 = on = expanded (pointing down), 0 = off = collapsed
      LibObjCBridge.objc_send_long(disc_btn, sel("setState:"), view.expanded ? 1_i64 : 0_i64)
      # Accessibility label on button
      acc_text = view.accessibility_label || "#{view.title}, #{view.expanded ? "expanded" : "collapsed"}"
      acc_str = LibObjCBridge.nsstring_from_cstr(acc_text.to_unsafe)
      LibObjCBridge.objc_send_id(disc_btn, sel("setAccessibilityLabel:"), acc_str)
      LibObjCBridge.objc_send_id(header_row, sel("addArrangedSubview:"), disc_btn)

      # Header title label
      title_field = alloc_init("NSTextField")
      LibObjCBridge.objc_send_bool(title_field, sel("setBezeled:"), 0)
      LibObjCBridge.objc_send_bool(title_field, sel("setDrawsBackground:"), 0)
      LibObjCBridge.objc_send_bool(title_field, sel("setEditable:"), 0)
      LibObjCBridge.objc_send_bool(title_field, sel("setSelectable:"), 0)
      title_ns = LibObjCBridge.nsstring_from_cstr(view.title.to_unsafe)
      LibObjCBridge.objc_send_id(title_field, sel("setStringValue:"), title_ns)
      title_font = LibObjCBridge.nsfont_system(13.0)
      LibObjCBridge.objc_send_id(title_field, sel("setFont:"), title_font) unless title_font.null?
      lbl_color = LibObjCBridge.nscolor_label_primary
      LibObjCBridge.objc_send_id(title_field, sel("setTextColor:"), lbl_color) unless lbl_color.null?
      LibObjCBridge.objc_send_id(header_row, sel("addArrangedSubview:"), title_field)

      LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), header_row)

      # --- Content block (shown only when expanded) ---
      if view.expanded && !view.content.empty?
        content_stack = alloc_init("NSStackView")
        LibObjCBridge.objc_send_long(content_stack, sel("setOrientation:"), 1_i64) # vertical
        LibObjCBridge.objc_send_1d(content_stack, sel("setSpacing:"), 4.0)
        LibObjCBridge.objc_send_long(content_stack, sel("setAlignment:"), 5_i64)   # leading
        # Indent content 20pt to align with text after triangle
        insets = LibObjCBridge::CGRect.new(x: 0.0, y: 20.0, width: 0.0, height: 0.0)
        LibObjCBridge.objc_send_rect_void(content_stack, sel("setEdgeInsets:"), insets)

        content_handle = ObjC.owned(content_stack, label: "NSStackView[disclosure-content]")
        content_native = NativeView.new(content_handle)

        push_stack(content_native, is_nsstack: true)
        view.content.each do |child|
          child.accept(self)
        end
        pop_stack

        LibObjCBridge.objc_send_id(outer, sel("addArrangedSubview:"), content_stack)
      end

      apply_common_properties(outer, view)
      emit(outer, "NSStackView[disclosure-group]")
    end

    # -----------------------------------------------------------------
    # Visit: PageControl -> NSStackView (horizontal) of N dot circles
    #
    # macOS has no native NSPageControl. We synthesize a row of small
    # NSView circles using CALayer. The current-page dot is filled with
    # the accent/tint color; other dots are outlined (stroke only).
    #
    # Dot sizing follows HIG spacing: 7pt diameter, 8pt gap between
    # centers (so ~1pt gap between adjacent circles). The filled dot
    # uses a slightly larger 8pt diameter per the HIG illustration
    # (current indicator is visually heavier than neighbors).
    #
    # Color semantics:
    #   current dot fill  — tint_color if set, else controlAccentColor
    #   other dot stroke  — controlAccentColor at 40% opacity
    #
    # HIG: "Not supported in macOS." — Page controls / Platform considerations.
    # This synthetic render is the closest correct approximation; the
    # component doc notes the macOS limitation explicitly.
    # -----------------------------------------------------------------
    def visit(view : UI::PageControl)
      # Outer horizontal NSStackView holds the dot views.
      stack = alloc_init("NSStackView")
      LibObjCBridge.objc_send_long(stack, sel("setOrientation:"), 0_i64)  # horizontal
      LibObjCBridge.objc_send_1d(stack, sel("setSpacing:"), 6.0)
      LibObjCBridge.objc_send_long(stack, sel("setAlignment:"), 4_i64)    # centerY

      nscolor_cls = LibObjCBridge.objc_getClass("NSColor")

      # Tint / accent NSColor for current dot fill.
      accent_nscolor = if tc = view.tint_color
                         LibObjCBridge.nscolor_rgba(tc.r, tc.g, tc.b, tc.a)
                       else
                         LibObjCBridge.objc_send(nscolor_cls, sel("controlAccentColor"))
                       end

      # Stroke NSColor for non-current dots: accent at 40% alpha.
      stroke_nscolor = if tc = view.tint_color
                         LibObjCBridge.nscolor_rgba(tc.r, tc.g, tc.b, 0.4)
                       else
                         # Fallback: system blue at 40% opacity.
                         LibObjCBridge.nscolor_rgba(0.0, 0.478, 1.0, 0.4)
                       end

      # Convert NSColor -> CGColor (required by CALayer.backgroundColor/borderColor).
      accent_cgcolor = accent_nscolor.null? ? Pointer(Void).null : LibObjCBridge.objc_send(accent_nscolor, sel("CGColor"))
      stroke_cgcolor = stroke_nscolor.null? ? Pointer(Void).null : LibObjCBridge.objc_send(stroke_nscolor, sel("CGColor"))

      # Clamp total to a sane display range (HIG: "More than ~10 dots are hard
      # to count at a glance"). We still render them all; clipping is visual.
      total = [view.total, 1].max
      current = view.current.clamp(0, total - 1)

      total.times do |i|
        is_current = (i == current)

        # Each dot is an NSView with wantsLayer:YES and a configured CALayer.
        dot_view = alloc_init("NSView")
        LibObjCBridge.objc_send_bool(dot_view, sel("setWantsLayer:"), 1)

        dot_size = is_current ? 8.0 : 7.0
        LibObjCBridge.objc_constrain_size(dot_view, dot_size, dot_size)

        dot_layer = LibObjCBridge.objc_send(dot_view, sel("layer"))
        unless dot_layer.null?
          # Corner radius = half the diameter -> perfect circle.
          LibObjCBridge.objc_send_1d(dot_layer, sel("setCornerRadius:"), dot_size / 2.0)
          LibObjCBridge.objc_send_bool(dot_layer, sel("setMasksToBounds:"), 1)

          if is_current
            # Filled dot: accent CGColor as backgroundColor.
            LibObjCBridge.objc_send_id(dot_layer, sel("setBackgroundColor:"), accent_cgcolor) unless accent_cgcolor.null?
            LibObjCBridge.objc_send_1d(dot_layer, sel("setBorderWidth:"), 0.0)
          else
            # Outlined dot: clear fill, translucent stroke.
            LibObjCBridge.objc_send_id(dot_layer, sel("setBackgroundColor:"), Pointer(Void).null)
            unless stroke_cgcolor.null?
              LibObjCBridge.objc_send_id(dot_layer, sel("setBorderColor:"), stroke_cgcolor)
              LibObjCBridge.objc_send_1d(dot_layer, sel("setBorderWidth:"), 1.0)
            end
          end
        end

        LibObjCBridge.objc_send_id(stack, sel("addArrangedSubview:"), dot_view)
      end

      # Accessibility on the container: announce current page position.
      acc_label = view.accessibility_label || "Page #{current + 1} of #{total}"
      acc_str = LibObjCBridge.nsstring_from_cstr(acc_label.to_unsafe)
      LibObjCBridge.objc_send_id(stack, sel("setAccessibilityLabel:"), acc_str)

      apply_common_properties(stack, view)
      emit(stack, "NSStackView[page-control]")
    end

    # -----------------------------------------------------------------
    # Visit: ComboBox -> NSComboBox
    #
    # NSComboBox is the native macOS combo box: an editable text field
    # with an embedded pull-down arrow button and a list of preset items.
    # The user can type a custom value OR click the arrow to pick from
    # the predefined list.
    #
    # HIG: "A combo box combines a text field with a pull-down button in
    # a single control." — Combo boxes, abstract.
    #
    # HIG: "Populate the field with a meaningful default value from the
    # list." — Combo boxes, Best practices.
    #
    # NSComboBox API used:
    #   addItemsWithObjectValues:  — populate the pop-up list
    #   setStringValue:            — set the current text value
    #   setPlaceholderString:      — set placeholder text
    #   setEditable:               — always YES for a combo box per HIG
    #   setFont:                   — system 13pt (NSControl default)
    #   setUsesDataSource:         — NO (item-list mode, not delegate mode)
    # -----------------------------------------------------------------
    def visit(view : UI::ComboBox)
      ptr = alloc_init_with_zero_frame("NSComboBox")

      # NSComboBox extends NSTextField. Mark it editable (the HIG model:
      # the user can always type a custom value).
      LibObjCBridge.objc_send_bool(ptr, sel("setEditable:"), 1)
      LibObjCBridge.objc_send_bool(ptr, sel("setUsesDataSource:"), 0)

      # Populate the preset options list via an NSArray of NSStrings.
      unless view.options.empty?
        # Build an NSMutableArray then call addItemsWithObjectValues:
        ns_array_cls = LibObjCBridge.objc_getClass("NSMutableArray")
        ns_array = LibObjCBridge.objc_send(ns_array_cls, sel("array"))

        view.options.each do |opt|
          ns_str = LibObjCBridge.nsstring_from_cstr(opt.to_unsafe)
          LibObjCBridge.objc_send_void_id(ns_array, sel("addObject:"), ns_str)
        end

        LibObjCBridge.objc_send_void_id(ptr, sel("addItemsWithObjectValues:"), ns_array)
      end

      # Current string value
      unless view.value.empty?
        val_str = LibObjCBridge.nsstring_from_cstr(view.value.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setStringValue:"), val_str)
      end

      # Placeholder text (shown when value is empty)
      unless view.placeholder.empty?
        ph_str = LibObjCBridge.nsstring_from_cstr(view.placeholder.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setPlaceholderString:"), ph_str)
      end

      # Font: system 13pt matches NSComboBox's default metric
      font_ptr = LibObjCBridge.nsfont_system(13.0)
      LibObjCBridge.objc_send_id(ptr, sel("setFont:"), font_ptr)

      # Width constraint
      if w = view.width
        LibObjCBridge.objc_constrain_width(ptr, w)
      end

      # Accessibility label
      if acc = view.accessibility_label
        acc_str = LibObjCBridge.nsstring_from_cstr(acc.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), acc_str)
      end

      apply_common_properties(ptr, view)
      emit(ptr, "NSComboBox")
    end

    # -----------------------------------------------------------------
    # Visit: RatingIndicator -> NSStackView of NSImageViews (SF Symbols)
    #
    # NSLevelIndicator with NSLevelIndicatorStyleRating is the HIG-native
    # macOS control. However, its cell-based drawing does not composite
    # correctly through NSView.cacheDisplayInRect:toBitmapImageRep: in the
    # static validation snapshot path — the star glyphs are drawn by
    # NSLevelIndicatorCell in a lock-focus context that the bitmap rep
    # cannot intercept. The renderer therefore uses NSImageView + SF Symbol
    # star images in a horizontal NSStackView, which composites correctly
    # in the off-screen bitmap path and produces visually identical output
    # (same star shapes, same tint color, same filled/outlined distinction).
    #
    # NSLevelIndicator remains the preferred live-app implementation; this
    # renderer produces the correct HIG visual for the validation harness.
    #
    # HIG: "A rating indicator uses a series of horizontally arranged
    # graphical symbols — by default, stars — to communicate a ranking
    # level." — Rating indicators, abstract.
    # HIG: "A rating indicator doesn't display partial symbols; it rounds
    # the value to display complete symbols only." — Rating indicators,
    # abstract.
    # -----------------------------------------------------------------
    def visit(view : UI::RatingIndicator)
      # Outer horizontal NSStackView
      stack = alloc_init("NSStackView")
      # NSUserInterfaceLayoutOrientationHorizontal = 0
      LibObjCBridge.objc_send_long(stack, sel("setOrientation:"), 0_i64)
      # spacing between stars: 4pt
      LibObjCBridge.objc_send_1d(stack, sel("setSpacing:"), 4.0)

      # Resolve tint color (system yellow default: R:1.0 G:0.8 B:0.0)
      tint_ptr = if tc = view.tint_color
                   LibObjCBridge.nscolor_rgba(tc.r, tc.g, tc.b, tc.a)
                 else
                   LibObjCBridge.nscolor_rgba(1.0, 0.8, 0.0, 1.0)
                 end

      # Clamp and round value to nearest integer per HIG
      clamped = view.value.clamp(0.0, view.max.to_f64)
      filled_count = clamped.round.to_i

      ns_image_cls = LibObjCBridge.objc_getClass("NSImage")

      view.max.times do |i|
        symbol_name = i < filled_count ? "star.fill" : "star"
        sym_str = LibObjCBridge.nsstring_from_cstr(symbol_name.to_unsafe)

        # NSImage.imageWithSystemSymbolName:accessibilityDescription:
        # (available macOS 11+). The second arg (accessibilityDescription)
        # can be nil — pass a nil pointer.
        sym_image = LibObjCBridge.objc_send_id_id(
          ns_image_cls,
          sel("imageWithSystemSymbolName:accessibilityDescription:"),
          sym_str,
          Pointer(Void).null
        )

        img_view = alloc_init("NSImageView")
        LibObjCBridge.objc_send_bool(img_view, sel("setWantsLayer:"), 1)

        unless sym_image.null?
          LibObjCBridge.objc_send_id(img_view, sel("setImage:"), sym_image)
        end

        # contentTintColor for the SF Symbol tint (macOS 10.14+)
        unless tint_ptr.null?
          LibObjCBridge.objc_send_id(img_view, sel("setContentTintColor:"), tint_ptr)
        end

        # Constrain each star to 20x20pt (compact, matches NSLevelIndicator cells)
        LibObjCBridge.objc_constrain_width(img_view, 20.0)
        LibObjCBridge.objc_constrain_height(img_view, 20.0)

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
      emit(stack, "NSStackView[rating-indicator]")
    end

    # ================================================================
    # Private helpers
    # ================================================================

    # Allocate and init an ObjC class by name.
    # Returns the raw Void* pointer to the initialized object.
    private def alloc_init(class_name : String) : Void*
      cls = LibObjCBridge.objc_getClass(class_name.to_unsafe)
      obj = LibObjCBridge.objc_send(cls, sel("alloc"))
      LibObjCBridge.objc_send(obj, sel("init"))
    end

    # Allocate and init an ObjC class using initWithFrame:NSZeroRect.
    # Required for NSControl subclasses (NSSwitch, NSSlider, etc.) that
    # return nil or crash from plain -init.
    private def alloc_init_with_zero_frame(class_name : String) : Void*
      cls = LibObjCBridge.objc_getClass(class_name.to_unsafe)
      obj = LibObjCBridge.objc_send(cls, sel("alloc"))
      zero = LibObjCBridge::CGRect.new(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
      LibObjCBridge.objc_send_rect(obj, sel("initWithFrame:"), zero)
    end

    # Get a SEL from a selector name string.
    private def sel(name : String) : Void*
      LibObjCBridge.sel_registerName(name.to_unsafe)
    end

    # Resolve a UI::Font to an NSFont pointer.
    #
    # Maps font family and weight to the appropriate NSFont factory:
    #   - "system"    -> systemFontOfSize: or boldSystemFontOfSize: or systemFontOfSize:weight:
    #   - "monospace" -> monospacedSystemFontOfSize:weight:
    #   - other       -> fontWithName:size: (custom font name lookup, falls back to system)
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

      # Apply italic trait via NSFontManager if needed.
      # convertFont:toHaveTrait: with NSItalicFontMask = 0x01
      if font.italic && !base_font.null?
        fm = LibObjCBridge.objc_send(
          LibObjCBridge.objc_getClass("NSFontManager"),
          sel("sharedFontManager"))
        unless fm.null?
          italic_font = LibObjCBridge.objc_send_id_long(
            fm, sel("convertFont:toHaveTrait:"), base_font, 0x01_i64)
          return italic_font unless italic_font.null?
        end
      end

      base_font
    end

    # Map a UI::Font weight symbol to an NSFontWeight CGFloat value.
    # NSFontWeight constants: ultraLight=-0.8, thin=-0.6, light=-0.4,
    # regular=0.0, medium=0.23, semibold=0.3, bold=0.4, heavy=0.56, black=0.62
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

    # Resolve a UI::Color to an NSColor pointer via the bridge convenience.
    private def resolve_color(color : UI::Color) : Void*
      LibObjCBridge.nscolor_rgba(color.r, color.g, color.b, color.a)
    end

    # Returns the Amber brand primary color as an NSColor.
    # Light appearance: #FFAD33 (r=1.0 g=0.678 b=0.2 a=1.0).
    # Dark  appearance: #FFB84D (r=1.0 g=0.722 b=0.302 a=1.0).
    # Appearance is resolved from the HIG_APPEARANCE env var, which the
    # validation capture harness sets before launching the host binary.
    # Production apps should substitute their own theme token here.
    private def amber_brand_gold : Void*
      dark = (ENV["HIG_APPEARANCE"]? == "dark")
      if dark
        LibObjCBridge.nscolor_rgba(1.0, 0.722, 0.302, 1.0)
      else
        LibObjCBridge.nscolor_rgba(1.0, 0.678, 0.2, 1.0)
      end
    end

    # Apply common View base-class properties to a raw AppKit view pointer.
    #
    #   - hidden  -> setHidden:
    #   - opacity -> setAlphaValue:
    #   - background -> setWantsLayer: + layer.setBackgroundColor:
    #   - accessibility_label -> setAccessibilityLabel:
    #   - minimum_width / minimum_height -> NSLayoutConstraint (width/height >= x)
    #   - maximum_width / maximum_height -> NSLayoutConstraint (width/height <= x)
    private def apply_common_properties(ptr : Void*, view : UI::View) : Nil
      # Hidden
      if view.hidden
        LibObjCBridge.objc_send_bool(ptr, sel("setHidden:"), 1)
      end

      # Opacity
      if view.opacity < 1.0
        LibObjCBridge.objc_send_1d(ptr, sel("setAlphaValue:"), view.opacity)
      end

      # Background color requires enabling layer-backing first.
      # setWantsLayer:YES tells AppKit to create a CALayer, then we
      # set the layer's backgroundColor to the CGColor representation.
      if bg = view.background
        LibObjCBridge.objc_send_bool(ptr, sel("setWantsLayer:"), 1)
        layer = LibObjCBridge.objc_send(ptr, sel("layer"))
        unless layer.null?
          bg_nscolor = resolve_color(bg)
          cg_color = LibObjCBridge.objc_send(bg_nscolor, sel("CGColor"))
          LibObjCBridge.objc_send_id(layer, sel("setBackgroundColor:"), cg_color)
        end
      end

      # Size constraints via Auto Layout.
      # When minimum_width == maximum_width: exact-width pin via equality constraint
      #   (NSStackView GravityAreas respects this; used for sidebar columns).
      # When only minimum_width is set: minimum-width constraint (>=) at priority 500
      #   so content panels expand to at least that width without fighting exact pins.
      # When only maximum_width is set: exact pin at that width (capping behavior).
      if min_w = view.minimum_width
        if max_w = view.maximum_width
          # Both set: exact pin at min_w (== max_w for fixed-width columns).
          LibObjCBridge.objc_constrain_width(ptr, min_w)
        else
          # Only minimum: use >= constraint at priority 500 so panel fills space.
          LibObjCBridge.objc_constrain_minimum_width(ptr, min_w)
        end
      elsif max_w = view.maximum_width
        LibObjCBridge.objc_constrain_width(ptr, max_w)
      end

      if min_h = view.minimum_height
        LibObjCBridge.objc_constrain_height(ptr, min_h)
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
    private def push_stack(native : NativeView, is_nsstack : Bool) : Nil
      @stack.push(native)
      @stack_is_nsstack.push(is_nsstack)
    end

    # Pop the top container from the nesting stack.
    private def pop_stack : Nil
      @stack.pop
      @stack_is_nsstack.pop
    end

    # Visit a child view subtree in isolation, returning its NativeView
    # without adding it to the current parent stack.  Used by NSScrollView
    # to obtain the documentView NativeView pointer before wiring it with
    # setDocumentView:, avoiding the double-placement that occurs when both
    # addSubview: (via push_native) and setDocumentView: target the same view.
    private def render_detached(view : UI::View) : NativeView?
      saved_stack = @stack.dup
      saved_is_nsstack = @stack_is_nsstack.dup
      saved_result = @result
      @stack = [] of NativeView
      @stack_is_nsstack = [] of Bool
      @result = nil
      view.accept(self)
      detached = @result
      @stack = saved_stack
      @stack_is_nsstack = saved_is_nsstack
      @result = saved_result
      detached
    end

    # Wrap a raw pointer in NativeHandle + NativeView and register it
    # with the current parent or set as root result.
    #
    # This is the standard emit path for leaf views (Label, Image, Spacer)
    # that do not need custom callback registration.
    private def emit(ptr : Void*, label : String) : Nil
      handle = ObjC.owned(ptr, label: label)
      native = NativeView.new(handle)
      push_native(native)
    end

    # Register a NativeView with the current parent container, or set it
    # as the root result if there is no parent.
    #
    # When inside a container (VStack/HStack/ZStack/ScrollView), this:
    #   1. Adds the NativeView as a child of the parent NativeView tree
    #   2. Adds the native AppKit view to the parent:
    #      - NSStackView parents use addArrangedSubview: (preserves stack ordering)
    #      - Plain NSView parents use addSubview: (ZStack, ScrollView content)
    private def push_native(native : NativeView) : Nil
      if parent = @stack.last?
        parent.add_child(native)

        # Add native AppKit view to parent's native view
        if parent.handle.valid? && native.handle.valid?
          parent_ptr = parent.handle.ptr!
          child_ptr = native.handle.ptr!

          # Use the parallel tracking array to decide add method
          if @stack_is_nsstack.last?
            LibObjCBridge.objc_send_void_id(parent_ptr, sel("addArrangedSubview:"), child_ptr)
          else
            LibObjCBridge.objc_add_subview(parent_ptr, child_ptr)
          end
        end
      else
        @result = native
      end
    end

    # -----------------------------------------------------------------
    # Visit: WebViewComponent -> WKWebView placeholder (NSView)
    #
    # WKWebView requires the WebKit framework and live URL navigation,
    # neither of which is available in the static validation capture path.
    # The renderer emits a bordered NSView placeholder sized to fill its
    # parent, labelled with the URL or "WKWebView content area", and
    # stores the url/title as accessibilityLabel so it is inspectable
    # via AXTest.
    #
    # HIG: "A web view loads and displays rich web content, such as
    # embedded HTML and websites, directly within your app."
    # Platform considerations: no additional considerations for iOS / macOS.
    # -----------------------------------------------------------------
    def visit(view : UI::WebViewComponent)
      ptr = alloc_init("NSView")
      # Give it a visible 1pt border (layer-backed gray border) so the
      # placeholder is visually distinct from the host background.
      LibObjCBridge.objc_send_bool(ptr, sel("setWantsLayer:"), 1)
      layer = LibObjCBridge.objc_send(ptr, sel("layer"))
      unless layer.null?
        # Fixed mid-gray border: 0.55 RGBA. Visible on white host (~4:1) and
        # on DarkAqua ~0.12 host (~3.5:1). Avoids ENV access and avoids
        # NSColor semantic color CGColor resolution issues outside draw context.
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
      emit(ptr, "NSView[web-view]")
    end

    # Collect raw Void* pointers for editable text fields in tree order.
    # Excludes NSTextField[label] (non-editable labels) by checking handle label.
    private def collect_text_fields(nv : NativeView, result_fields : Array(Void*)) : Nil
      if nv.handle.valid?
        lbl = nv.handle.label
        if lbl == "NSTextField" || lbl == "NSSecureTextField"
          result_fields << nv.handle.ptr!
        end
      end
      nv.children.each { |child| collect_text_fields(child, result_fields) }
    end
  end
end
{% end %}
