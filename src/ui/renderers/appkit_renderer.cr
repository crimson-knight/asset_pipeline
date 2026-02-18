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
    fun nsfont_system(size : Float64) : Void*
    fun nsfont_bold_system(size : Float64) : Void*
    fun nsfont_system_weight(size : Float64, weight : Float64) : Void*
    fun nsfont_monospaced_system(size : Float64, weight : Float64) : Void*
    fun nsfont_named(name : Void*, size : Float64) : Void*
    fun objc_add_subview(parent : Void*, child : Void*) : Void
    fun objc_set_autoresize(view : Void*, mask : UInt64) : Void
    fun objc_set_frame(obj : Void*, frame : CGRect) : Void

    # --- ObjC runtime ---
    fun sel_registerName(name : UInt8*) : Void*
    fun objc_getClass(name : UInt8*) : Void*
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

      # Text color
      color_ptr = resolve_color(view.text_color)
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
    # -----------------------------------------------------------------
    def visit(view : UI::Button)
      ptr = alloc_init("NSButton")

      # Title
      title_str = LibObjCBridge.nsstring_from_cstr(view.label.to_unsafe)
      LibObjCBridge.objc_send_id(ptr, sel("setTitle:"), title_str)

      # Bezel style: NSBezelStyleRounded = 1
      LibObjCBridge.objc_send_long(ptr, sel("setBezelStyle:"), 1_i64)

      # Font
      font_ptr = resolve_font(view.font)
      LibObjCBridge.objc_send_id(ptr, sel("setFont:"), font_ptr)

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
      alignment_val = case view.alignment
                      when Alignment::Leading  then 5_i64
                      when Alignment::Center   then 9_i64
                      when Alignment::Trailing then 6_i64
                      when Alignment::Fill     then 9_i64 # center; fill needs additional constraints
                      else                          9_i64
                      end
      LibObjCBridge.objc_send_long(ptr, sel("setAlignment:"), alignment_val)

      # Common properties
      apply_common_properties(ptr, view)

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
      alignment_val = case view.alignment
                      when Alignment::Top      then 3_i64
                      when Alignment::Center   then 10_i64
                      when Alignment::Bottom   then 4_i64
                      when Alignment::Fill     then 10_i64
                      else                          10_i64
                      end
      LibObjCBridge.objc_send_long(ptr, sel("setAlignment:"), alignment_val)

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

      # Load the image by name from the app bundle.
      # +[NSImage imageNamed:] returns an autoreleased NSImage* (or nil).
      nsimage_cls = LibObjCBridge.objc_getClass("NSImage")
      image_name = LibObjCBridge.nsstring_from_cstr(view.source.to_unsafe)
      nsimage = LibObjCBridge.objc_send_id(nsimage_cls, sel("imageNamed:"), image_name)
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

      # Font
      font_ptr = resolve_font(view.font)
      LibObjCBridge.objc_send_id(ptr, sel("setFont:"), font_ptr)

      # Text color
      color_ptr = resolve_color(view.text_color)
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

      # Common properties
      apply_common_properties(ptr, view)

      handle = ObjC.owned(ptr, label: "NSScrollView")
      native = NativeView.new(handle)

      # Visit content child and set as NSScrollView's documentView
      if content = view.content
        push_stack(native, is_nsstack: false)
        content.accept(self)
        pop_stack

        # The content's native view was added to native.children.
        # Also set it as the NSScrollView's documentView.
        if content_nv = native.children.first?
          if content_nv.handle.valid?
            LibObjCBridge.objc_send_id(ptr, sel("setDocumentView:"), content_nv.handle.ptr!)
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

    # Apply common View base-class properties to a raw AppKit view pointer.
    #
    #   - hidden  -> setHidden:
    #   - opacity -> setAlphaValue:
    #   - background -> setWantsLayer: + layer.setBackgroundColor:
    #   - accessibility_label -> setAccessibilityLabel:
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

      # Accessibility label
      if a11y = view.accessibility_label
        a11y_str = LibObjCBridge.nsstring_from_cstr(a11y.to_unsafe)
        LibObjCBridge.objc_send_id(ptr, sel("setAccessibilityLabel:"), a11y_str)
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
  end
end
{% end %}
