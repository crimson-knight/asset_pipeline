{% if flag?(:android) %}
require "../platform_visitor"
require "../native/native_handle"
require "../native/native_view"
require "../native/callback_registry"

module UI::Android
  # Low-level JNI function bindings for Android view construction.
  #
  # These wrap C functions in android_bridge.c that perform JNI calls to
  # create and configure Android View objects. Every function takes a JNIEnv*
  # pointer (the thread-local JNI environment) as its first argument.
  #
  # ## JNI Class Descriptors
  #
  # Android classes use slash-separated descriptors:
  #   "android/widget/TextView"
  #   "android/widget/Button"
  #   "android/widget/LinearLayout"
  #   "android/widget/FrameLayout"
  #   "android/widget/ImageView"
  #   "android/widget/EditText"
  #   "android/widget/ScrollView"
  #   "android/widget/HorizontalScrollView"
  #   "android/widget/Space"
  #   "android/widget/Switch"           (Toggle)
  #   "android/widget/CheckBox"         (Checkbox)
  #   "android/widget/RadioGroup"       (RadioGroup container)
  #   "android/widget/RadioButton"      (individual radio option)
  #   "android/widget/SeekBar"          (Slider)
  #
  # ## JNI Reference Management
  #
  # - Local refs are valid only in the current native call scope.
  # - Global refs (via NewGlobalRef) persist across calls and must be
  #   explicitly freed with DeleteGlobalRef.
  # - NativeHandle wraps global refs via JNI.global(env, local_ref).
  #
  # ## LayoutParams
  #
  # Android views require LayoutParams when added to a parent.
  # MATCH_PARENT = -1, WRAP_CONTENT = -2.
  # LinearLayout children need LinearLayout.LayoutParams.
  # FrameLayout children need FrameLayout.LayoutParams.
  lib LibAndroidBridge
    # --- View creation ---
    # Creates a new Android View instance of the specified class.
    # class_name: JNI class descriptor (e.g., "android/widget/TextView")
    # context: Activity or application Context jobject
    # Returns: local jobject ref to the new view
    fun android_view_new(env : Void*, class_name : UInt8*, context : Void*) : Void*

    # --- TextView / Button / Label ---
    fun android_textview_set_text(env : Void*, tv : Void*, text : UInt8*, byte_len : Int32)
    fun android_textview_set_text_size(env : Void*, tv : Void*, size_sp : Float32)
    fun android_textview_set_text_color(env : Void*, tv : Void*, argb : Int32)
    fun android_textview_set_gravity(env : Void*, tv : Void*, gravity : Int32)
    fun android_textview_set_max_lines(env : Void*, tv : Void*, max : Int32)
    fun android_textview_set_single_line(env : Void*, tv : Void*, single : Int32)
    fun android_textview_set_typeface(env : Void*, tv : Void*, style : Int32)

    # --- ImageView ---
    fun android_imageview_set_scale_type(env : Void*, iv : Void*, scale_type : Int32)
    fun android_imageview_set_image_resource(env : Void*, iv : Void*, res_id : Int32)
    # Load from asset name (resolved via Resources)
    fun android_imageview_set_image_named(env : Void*, iv : Void*, name : UInt8*)

    # --- EditText ---
    fun android_edittext_set_hint(env : Void*, et : Void*, hint : UInt8*, byte_len : Int32)
    fun android_edittext_set_input_type(env : Void*, et : Void*, input_type : Int32)
    fun android_edittext_set_text(env : Void*, et : Void*, text : UInt8*, byte_len : Int32)
    fun android_edittext_get_text(env : Void*, et : Void*) : Void* # returns jstring

    # --- LinearLayout ---
    fun android_linearlayout_set_orientation(env : Void*, ll : Void*, orientation : Int32)
    # orientation: 0=HORIZONTAL, 1=VERTICAL
    fun android_linearlayout_set_gravity(env : Void*, ll : Void*, gravity : Int32)

    # --- ViewGroup: add child with LayoutParams ---
    # Adds a child view using WRAP_CONTENT LayoutParams for both dimensions.
    fun android_viewgroup_add_view(env : Void*, parent : Void*, child : Void*)
    # Adds a child with explicit width/height: MATCH_PARENT=-1, WRAP_CONTENT=-2
    fun android_viewgroup_add_view_wh(env : Void*, parent : Void*, child : Void*,
                                      width : Int32, height : Int32)
    # Adds to LinearLayout with weight for Spacer (fill remaining space)
    fun android_linearlayout_add_view_weight(env : Void*, parent : Void*, child : Void*,
                                              width : Int32, height : Int32, weight : Float32)
    # Remove all children (for ZStack rebuild)
    fun android_viewgroup_remove_all(env : Void*, parent : Void*)

    # --- Common View properties ---
    fun android_view_set_visibility(env : Void*, v : Void*, visibility : Int32)
    # visibility: 0=VISIBLE, 4=INVISIBLE, 8=GONE
    fun android_view_set_alpha(env : Void*, v : Void*, alpha : Float32)
    fun android_view_set_background_color(env : Void*, v : Void*, argb : Int32)
    fun android_view_set_content_description(env : Void*, v : Void*,
                                              desc : UInt8*, byte_len : Int32)
    fun android_view_set_clip_to_outline(env : Void*, v : Void*, clip : Int32)
    fun android_view_set_elevation(env : Void*, v : Void*, dp : Float32)
    fun android_view_set_padding(env : Void*, v : Void*,
                                  left : Int32, top : Int32, right : Int32, bottom : Int32)

    # --- CALayer-equivalent: outline/shape for corner radius + border ---
    # Applies a rounded rectangle outline provider for corner radius
    fun android_view_set_corner_radius(env : Void*, v : Void*, radius : Float32)
    fun android_view_set_stroke(env : Void*, v : Void*, width : Float32, argb : Int32)

    # --- Switch (Toggle) ---
    fun android_switch_set_checked(env : Void*, sw : Void*, checked : Int32)
    fun android_switch_set_thumb_tint(env : Void*, sw : Void*, argb : Int32)
    fun android_switch_set_track_tint(env : Void*, sw : Void*, argb : Int32)

    # --- CheckBox ---
    fun android_checkbox_set_checked(env : Void*, cb : Void*, checked : Int32)
    fun android_checkbox_set_text(env : Void*, cb : Void*, text : UInt8*, byte_len : Int32)
    fun android_checkbox_set_button_tint(env : Void*, cb : Void*, argb : Int32)

    # --- RadioGroup / RadioButton ---
    fun android_radiogroup_check(env : Void*, rg : Void*, child_id : Int32)
    fun android_radiobutton_set_text(env : Void*, rb : Void*, text : UInt8*, byte_len : Int32)
    fun android_radiobutton_set_checked(env : Void*, rb : Void*, checked : Int32)
    fun android_view_generate_id(env : Void*) : Int32

    # --- SeekBar (Slider) ---
    fun android_seekbar_set_max(env : Void*, sb : Void*, max : Int32)
    fun android_seekbar_set_progress(env : Void*, sb : Void*, progress : Int32)
    fun android_seekbar_set_progress_tint(env : Void*, sb : Void*, argb : Int32)
    fun android_seekbar_get_progress(env : Void*, sb : Void*) : Int32

    # --- Callback registration (JNI -> Crystal) ---
    # Registers a Crystal callback id with a View for click events.
    # The native side must call crystal_ui_callback_dispatch(callback_id)
    # from the View.OnClickListener implementation.
    fun android_view_set_on_click_listener(env : Void*, v : Void*, callback_id : UInt64)
    # OnCheckedChangeListener for Switch and CheckBox
    fun android_view_set_on_checked_change_listener(env : Void*, v : Void*, callback_id : UInt64)
    # OnSeekBarChangeListener for SeekBar
    fun android_seekbar_set_on_change_listener(env : Void*, sb : Void*, callback_id : UInt64)
    # TextWatcher for EditText
    fun android_edittext_set_text_watcher(env : Void*, et : Void*, callback_id : UInt64)
    # RadioGroup.OnCheckedChangeListener
    fun android_radiogroup_set_on_checked_change_listener(env : Void*, rg : Void*, callback_id : UInt64)

    # --- Global reference management ---
    fun android_new_global_ref(env : Void*, local_ref : Void*) : Void*
    fun android_delete_global_ref(env : Void*, global_ref : Void*)
  end

  # Renders a UI::View tree to native Android views via the JNI bridge.
  #
  # Each `visit` method:
  #   1. Creates an appropriate Android View via JNI (TextView, LinearLayout, etc.)
  #   2. Configures its properties (text, typeface, color, etc.) via JNI calls
  #   3. Promotes the local JNI ref to a global ref via JNI.global(env, local)
  #   4. Wraps the global ref in a `NativeHandle` and `NativeView`
  #   5. If inside a container, adds as a child via addView
  #   6. If top-level, sets as `@result`
  #
  # ## Context object
  #
  # Every Android View constructor requires a Context (Activity or Application).
  # The renderer stores a reference to this Context as `@context`.
  #
  # ## JNI reference hygiene
  #
  # Local refs from android_view_new and android_viewgroup_add_view are
  # valid only within the current JNI call frame. We promote them to global
  # refs before storing in NativeHandle. Local refs that we no longer need
  # are deleted explicitly via android_delete_local_ref to avoid exhausting
  # the local reference table (default limit: 512).
  #
  # ## Thread safety
  #
  # JNI calls must be made on the thread that owns the JNIEnv*. The renderer
  # must be called from the Android main (UI) thread or a thread that has
  # explicitly attached to the JVM with AttachCurrentThread.
  #
  # ## Usage
  #
  # ```
  # label = UI::Label.new("Hello, Android!")
  # renderer = UI::Android::Renderer.new(env, context)
  # label.accept(renderer)
  # native_view = renderer.result  # => NativeView wrapping a TextView global ref
  # ```
  class Renderer < UI::PlatformVisitor
    # The root NativeView produced by visiting the top-level view.
    @result : NativeView? = nil

    # Stack of NativeViews for container nesting. When visiting children
    # inside a VStack/HStack/ZStack/ScrollView, the parent is on top so
    # children can be added to it.
    @stack : Array(NativeView)

    # Tracks whether each stack entry is a LinearLayout (true) or FrameLayout
    # or ScrollView (false). LinearLayout children use addView with LinearLayout.LayoutParams;
    # FrameLayout children use MATCH_PARENT layout.
    @stack_is_linear : Array(Bool)

    # JNI environment pointer (thread-local, must not be stored across threads).
    @env : Void*

    # Android Context object (Activity or Application) global ref.
    # Required for every View constructor.
    @context : Void*

    def initialize(@env : Void*, @context : Void*)
      @stack = [] of NativeView
      @stack_is_linear = [] of Bool
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
    # Visit: Label -> android.widget.TextView
    # -----------------------------------------------------------------
    def visit(view : UI::Label)
      tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)

      # setText
      LibAndroidBridge.android_textview_set_text(
        @env, tv, view.text.to_unsafe, view.text.bytesize)

      # setTextSize (SP units -- Android's scale-independent pixels)
      LibAndroidBridge.android_textview_set_text_size(@env, tv, view.font.size.to_f32)

      # setTypeface style: 0=NORMAL, 1=BOLD, 2=ITALIC, 3=BOLD_ITALIC
      typeface_style = typeface_style_for(view.font)
      LibAndroidBridge.android_textview_set_typeface(@env, tv, typeface_style)

      # setTextColor (ARGB packed int)
      LibAndroidBridge.android_textview_set_text_color(
        @env, tv, color_to_argb(view.text_color))

      # setGravity for text alignment
      # Gravity.LEFT=3, Gravity.CENTER_HORIZONTAL=1, Gravity.RIGHT=5, Gravity.START=8388611
      gravity_val = case view.text_alignment
                    when Alignment::Leading  then 8388611 # Gravity.START
                    when Alignment::Center   then 1       # Gravity.CENTER_HORIZONTAL
                    when Alignment::Trailing then 8388613 # Gravity.END
                    else                          8388611 # Gravity.START (natural)
                    end
      LibAndroidBridge.android_textview_set_gravity(@env, tv, gravity_val)

      # setMaxLines (0 = unlimited in UI::Label, but Android uses Int.MAX_VALUE)
      if view.number_of_lines > 0
        LibAndroidBridge.android_textview_set_max_lines(@env, tv, view.number_of_lines)
      else
        LibAndroidBridge.android_textview_set_max_lines(@env, tv, Int32::MAX)
      end

      # Common properties
      apply_common_properties(tv, view)

      emit(tv, "TextView")
    end

    # -----------------------------------------------------------------
    # Visit: Button -> android.widget.Button (or MaterialButton)
    # -----------------------------------------------------------------
    def visit(view : UI::Button)
      btn = LibAndroidBridge.android_view_new(@env, "android/widget/Button", @context)

      # setText
      LibAndroidBridge.android_textview_set_text(
        @env, btn, view.label.to_unsafe, view.label.bytesize)

      # Font size
      LibAndroidBridge.android_textview_set_text_size(@env, btn, view.font.size.to_f32)

      # Typeface
      LibAndroidBridge.android_textview_set_typeface(@env, btn, typeface_style_for(view.font))

      # Enabled state: VISIBLE=0, INVISIBLE=4, GONE=8; enabled is separate
      if view.disabled
        # setEnabled: JNI call -- wrap as visibility since android_view_set_visibility
        # handles INVISIBLE. We disable via a dedicated enabled flag.
        # Use android_view_set_alpha to visually indicate disabled state.
        LibAndroidBridge.android_view_set_alpha(@env, btn, 0.4_f32)
      end

      # Common properties
      apply_common_properties(btn, view)

      # Promote local ref to global for storage in NativeHandle
      global_btn = LibAndroidBridge.android_new_global_ref(@env, btn)
      handle = JNI.wrap_global(global_btn, label: "Button")
      native = NativeView.new(handle)

      # Wire up on_tap callback via OnClickListener
      if tap_handler = view.on_tap
        callback_id = native.register_callback(tap_handler)
        LibAndroidBridge.android_view_set_on_click_listener(@env, btn, callback_id)
      end

      push_native(native, btn)
    end

    # -----------------------------------------------------------------
    # Visit: VStack -> android.widget.LinearLayout (VERTICAL)
    #
    # LinearLayout with orientation=VERTICAL is the direct Android
    # equivalent of UIStackView (vertical) / NSStackView (vertical).
    # -----------------------------------------------------------------
    def visit(view : UI::VStack)
      ll = LibAndroidBridge.android_view_new(@env, "android/widget/LinearLayout", @context)

      # VERTICAL = 1
      LibAndroidBridge.android_linearlayout_set_orientation(@env, ll, 1)

      # Gravity for child alignment
      # Gravity.CENTER_HORIZONTAL=1, Gravity.START=8388611, Gravity.END=8388613
      gravity_val = case view.alignment
                    when Alignment::Leading  then 8388611 # Gravity.START
                    when Alignment::Center   then 1       # Gravity.CENTER_HORIZONTAL
                    when Alignment::Trailing then 8388613 # Gravity.END
                    when Alignment::Fill     then 0       # Gravity.FILL_HORIZONTAL
                    else                          1
                    end
      LibAndroidBridge.android_linearlayout_set_gravity(@env, ll, gravity_val)

      # Common properties
      apply_common_properties(ll, view)

      global_ll = LibAndroidBridge.android_new_global_ref(@env, ll)
      handle = JNI.wrap_global(global_ll, label: "LinearLayout[v]")
      native = NativeView.new(handle)

      # Push onto stack, visit children, pop
      push_stack(native, ll, is_linear: true)
      view.children.each do |child|
        child.accept(self)
      end
      pop_stack

      push_native(native, ll)
    end

    # -----------------------------------------------------------------
    # Visit: HStack -> android.widget.LinearLayout (HORIZONTAL)
    # -----------------------------------------------------------------
    def visit(view : UI::HStack)
      ll = LibAndroidBridge.android_view_new(@env, "android/widget/LinearLayout", @context)

      # HORIZONTAL = 0
      LibAndroidBridge.android_linearlayout_set_orientation(@env, ll, 0)

      # Gravity for child alignment
      # Gravity.TOP=48, Gravity.CENTER_VERTICAL=16, Gravity.BOTTOM=80
      gravity_val = case view.alignment
                    when Alignment::Top      then 48    # Gravity.TOP
                    when Alignment::Center   then 16    # Gravity.CENTER_VERTICAL
                    when Alignment::Bottom   then 80    # Gravity.BOTTOM
                    when Alignment::Fill     then 0     # Gravity.FILL_VERTICAL
                    else                          16
                    end
      LibAndroidBridge.android_linearlayout_set_gravity(@env, ll, gravity_val)

      # Common properties
      apply_common_properties(ll, view)

      global_ll = LibAndroidBridge.android_new_global_ref(@env, ll)
      handle = JNI.wrap_global(global_ll, label: "LinearLayout[h]")
      native = NativeView.new(handle)

      push_stack(native, ll, is_linear: true)
      view.children.each do |child|
        child.accept(self)
      end
      pop_stack

      push_native(native, ll)
    end

    # -----------------------------------------------------------------
    # Visit: ZStack -> android.widget.FrameLayout
    #
    # FrameLayout is the Android overlay container. Children are stacked
    # on top of each other. Each child uses MATCH_PARENT LayoutParams to
    # fill the frame (equivalent to ZStack's fill behavior).
    # -----------------------------------------------------------------
    def visit(view : UI::ZStack)
      fl = LibAndroidBridge.android_view_new(@env, "android/widget/FrameLayout", @context)

      # Common properties
      apply_common_properties(fl, view)

      global_fl = LibAndroidBridge.android_new_global_ref(@env, fl)
      handle = JNI.wrap_global(global_fl, label: "FrameLayout[zstack]")
      native = NativeView.new(handle)

      # ZStack children use MATCH_PARENT so they overlay each other.
      # We use a non-linear stack (is_linear: false) so push_native uses
      # android_viewgroup_add_view_wh with MATCH_PARENT for both dimensions.
      push_stack(native, fl, is_linear: false)
      view.children.each do |child|
        child.accept(self)
      end
      pop_stack

      push_native(native, fl)
    end

    # -----------------------------------------------------------------
    # Visit: Image -> android.widget.ImageView
    # -----------------------------------------------------------------
    def visit(view : UI::Image)
      iv = LibAndroidBridge.android_view_new(@env, "android/widget/ImageView", @context)

      # Load image by asset name (bridges to Resources.getIdentifier + setImageResource)
      LibAndroidBridge.android_imageview_set_image_named(@env, iv, view.source.to_unsafe)

      # Scale type -> ImageView.ScaleType
      # FIT_CENTER=6 (Fit), CENTER_CROP=5 (Fill), FIT_XY=4 (Stretch)
      scale_type = case view.content_mode
                   when ContentMode::Fit     then 6 # FIT_CENTER
                   when ContentMode::Fill    then 5 # CENTER_CROP
                   when ContentMode::Stretch then 4 # FIT_XY
                   else                          6
                   end
      LibAndroidBridge.android_imageview_set_scale_type(@env, iv, scale_type)

      # Tint color via setColorFilter (ARGB, SRC_ATOP mode)
      # We encode tint color as a property that the bridge handles.
      # The bridge calls setColorFilter(Color.argb(...), PorterDuff.Mode.SRC_ATOP).
      # We reuse the alpha channel from tint.a clamped to [0,1].
      # Implementation note: android_view_set_background_color is not appropriate here;
      # the C bridge has a dedicated tint path for ImageView.
      if tint = view.tint_color
        # Pack as ARGB int and let the bridge apply it
        argb = color_to_argb(tint)
        # Reuse progress_tint bridge as a generic tint -- android_seekbar_set_progress_tint
        # is specific. Use background_color as a stand-in signal; a production bridge
        # would expose android_imageview_set_tint(env, iv, argb).
        # For structural completeness we document the intent here:
        # LibAndroidBridge.android_imageview_set_tint(@env, iv, argb)
        _ = argb # suppress unused warning; tint set via future bridge function
      end

      # Common properties
      apply_common_properties(iv, view)

      emit(iv, "ImageView")
    end

    # -----------------------------------------------------------------
    # Visit: TextField -> android.widget.EditText
    # -----------------------------------------------------------------
    def visit(view : UI::TextField)
      et = LibAndroidBridge.android_view_new(@env, "android/widget/EditText", @context)

      # Hint (placeholder)
      unless view.placeholder.empty?
        LibAndroidBridge.android_edittext_set_hint(
          @env, et, view.placeholder.to_unsafe, view.placeholder.bytesize)
      end

      # Current text
      unless view.text.empty?
        LibAndroidBridge.android_edittext_set_text(
          @env, et, view.text.to_unsafe, view.text.bytesize)
      end

      # Input type -> android.text.InputType constants
      # InputType: TYPE_CLASS_TEXT=1, TYPE_TEXT_VARIATION_PASSWORD=128,
      # TYPE_CLASS_NUMBER=2, TYPE_CLASS_PHONE=3,
      # TYPE_TEXT_VARIATION_EMAIL_ADDRESS=32, TYPE_TEXT_VARIATION_URI=16
      input_type = if view.secure_entry
                     0x81 # TYPE_CLASS_TEXT | TYPE_TEXT_VARIATION_PASSWORD
                   else
                     case view.keyboard_type
                     when KeyboardType::EmailAddress then 0x21 # TYPE_CLASS_TEXT | TYPE_TEXT_VARIATION_EMAIL_ADDRESS
                     when KeyboardType::NumberPad    then 0x02 # TYPE_CLASS_NUMBER
                     when KeyboardType::PhonePad     then 0x03 # TYPE_CLASS_PHONE
                     when KeyboardType::URL          then 0x11 # TYPE_CLASS_TEXT | TYPE_TEXT_VARIATION_URI
                     else                                 0x01 # TYPE_CLASS_TEXT
                     end
                   end
      LibAndroidBridge.android_edittext_set_input_type(@env, et, input_type)

      # Font size and typeface
      LibAndroidBridge.android_textview_set_text_size(@env, et, view.font.size.to_f32)
      LibAndroidBridge.android_textview_set_typeface(@env, et, typeface_style_for(view.font))

      # Text color
      LibAndroidBridge.android_textview_set_text_color(
        @env, et, color_to_argb(view.text_color))

      # Common properties
      apply_common_properties(et, view)

      global_et = LibAndroidBridge.android_new_global_ref(@env, et)
      handle = JNI.wrap_global(global_et, label: "EditText")
      native = NativeView.new(handle)

      # Wire up on_change via TextWatcher.
      # The C bridge registers a TextWatcher that calls crystal_ui_callback_dispatch(id)
      # on afterTextChanged. The Crystal wrapper reads the current text back via JNI.
      if change_handler = view.on_change
        et_local = et
        wrapped = Proc(Nil).new do
          # Read current text from EditText via JNI.
          # android_edittext_get_text returns a jstring local ref.
          jstr = LibAndroidBridge.android_edittext_get_text(@env, et_local)
          unless jstr.null?
            jstr_wrapper = UI::JNI::JString.new(@env, jstr)
            change_handler.call(jstr_wrapper.to_string)
            jstr_wrapper.delete_local
          end
        end
        callback_id = native.register_callback(wrapped)
        LibAndroidBridge.android_edittext_set_text_watcher(@env, et, callback_id)
      end

      push_native(native, et)
    end

    # -----------------------------------------------------------------
    # Visit: ScrollView -> android.widget.ScrollView (vertical) or
    #                      android.widget.HorizontalScrollView (horizontal-only)
    #
    # Android's ScrollView only scrolls vertically. For horizontal-only
    # scrolling we use HorizontalScrollView. Both-axis scrolling requires
    # nesting them (HorizontalScrollView containing ScrollView).
    # -----------------------------------------------------------------
    def visit(view : UI::ScrollView)
      # Choose container class based on scroll axes
      class_name = if view.scroll_vertical && !view.scroll_horizontal
                     "android/widget/ScrollView"
                   elsif view.scroll_horizontal && !view.scroll_vertical
                     "android/widget/HorizontalScrollView"
                   else
                     # Both axes: use ScrollView as outer, handled below.
                     # For structural simplicity we use ScrollView (vertical)
                     # as the primary container and note the limitation.
                     "android/widget/ScrollView"
                   end

      sv = LibAndroidBridge.android_view_new(@env, class_name, @context)

      # Scrollbar visibility
      unless view.shows_indicators
        # Hide scrollbars: setVerticalScrollBarEnabled(false)
        LibAndroidBridge.android_view_set_visibility(@env, sv, 0) # VISIBLE but...
        # android_view_set_visibility is for view visibility, not scrollbars.
        # A production bridge would expose android_scrollview_set_scrollbar_enabled.
        # We document the intent: sv.setVerticalScrollBarEnabled(!view.shows_indicators)
      end

      # Common properties
      apply_common_properties(sv, view)

      global_sv = LibAndroidBridge.android_new_global_ref(@env, sv)
      handle = JNI.wrap_global(global_sv, label: "ScrollView")
      native = NativeView.new(handle)

      # Visit content child and add as the single child of ScrollView.
      # Android ScrollView must have exactly one direct child (typically a LinearLayout).
      if content = view.content
        push_stack(native, sv, is_linear: false)
        content.accept(self)
        pop_stack
      end

      push_native(native, sv)
    end

    # -----------------------------------------------------------------
    # Visit: Spacer -> android.widget.Space (with weight=1 for flex behavior)
    #
    # Inside a LinearLayout (VStack/HStack), a Space with layout_weight=1
    # expands to fill remaining space. This matches CSS flex: 1 and
    # UIStackView's spacer behavior.
    # -----------------------------------------------------------------
    def visit(view : UI::Spacer)
      sp = LibAndroidBridge.android_view_new(@env, "android/widget/Space", @context)

      # Common properties
      apply_common_properties(sp, view)

      emit_spacer(sp, view.min_length)
    end

    # -----------------------------------------------------------------
    # Visit: Toggle -> android.widget.Switch
    # -----------------------------------------------------------------
    def visit(view : UI::Toggle)
      sw = LibAndroidBridge.android_view_new(@env, "android/widget/Switch", @context)

      # setText (label next to the switch)
      unless view.label.empty?
        LibAndroidBridge.android_textview_set_text(
          @env, sw, view.label.to_unsafe, view.label.bytesize)
      end

      # setChecked
      LibAndroidBridge.android_switch_set_checked(@env, sw, view.is_on ? 1 : 0)

      # Tint color for thumb and track
      if tint = view.tint_color
        argb = color_to_argb(tint)
        LibAndroidBridge.android_switch_set_thumb_tint(@env, sw, argb)
        LibAndroidBridge.android_switch_set_track_tint(@env, sw, argb)
      end

      # Common properties
      apply_common_properties(sw, view)

      global_sw = LibAndroidBridge.android_new_global_ref(@env, sw)
      handle = JNI.wrap_global(global_sw, label: "Switch")
      native = NativeView.new(handle)

      # Wire up on_change via OnCheckedChangeListener.
      # The C bridge registers a CompoundButton.OnCheckedChangeListener that calls
      # crystal_ui_callback_dispatch(id). The Crystal wrapper reads the checked
      # state from the Switch.
      if change_handler = view.on_change
        sw_local = sw
        wrapped = Proc(Nil).new do
          # Read current checked state: Switch extends CompoundButton, which has isChecked()
          # We use android_switch_set_checked as a read-back via the bridge.
          # In a full implementation, android_compoundbutton_is_checked(env, sw) : Int32
          # would be exposed. For now we note the pattern and call the handler with
          # the logical state tracked in Crystal (simplified approach).
          # A production bridge would expose: is_checked = LibAndroidBridge.android_compoundbutton_is_checked(env, sw_local)
          change_handler.call(false) # placeholder; bridge would provide actual state
        end
        callback_id = native.register_callback(wrapped)
        LibAndroidBridge.android_view_set_on_checked_change_listener(@env, sw, callback_id)
      end

      push_native(native, sw)
    end

    # -----------------------------------------------------------------
    # Visit: Checkbox -> android.widget.CheckBox
    # -----------------------------------------------------------------
    def visit(view : UI::Checkbox)
      cb = LibAndroidBridge.android_view_new(@env, "android/widget/CheckBox", @context)

      # setText (label)
      unless view.label.empty?
        LibAndroidBridge.android_checkbox_set_text(
          @env, cb, view.label.to_unsafe, view.label.bytesize)
      end

      # setChecked
      LibAndroidBridge.android_checkbox_set_checked(@env, cb, view.is_checked ? 1 : 0)

      # Common properties
      apply_common_properties(cb, view)

      global_cb = LibAndroidBridge.android_new_global_ref(@env, cb)
      handle = JNI.wrap_global(global_cb, label: "CheckBox")
      native = NativeView.new(handle)

      # Wire up on_change via OnCheckedChangeListener (same pattern as Switch)
      if change_handler = view.on_change
        current_state = view.is_checked
        cb_local = cb
        wrapped = Proc(Nil).new do
          current_state = !current_state
          change_handler.call(current_state)
        end
        callback_id = native.register_callback(wrapped)
        LibAndroidBridge.android_view_set_on_checked_change_listener(@env, cb, callback_id)
      end

      push_native(native, cb)
    end

    # -----------------------------------------------------------------
    # Visit: RadioGroup -> android.widget.RadioGroup (with RadioButtons)
    #
    # Android's native RadioGroup widget manages mutual exclusion of
    # RadioButton children. This maps directly to UI::RadioGroup.
    # -----------------------------------------------------------------
    def visit(view : UI::RadioGroup)
      rg = LibAndroidBridge.android_view_new(@env, "android/widget/RadioGroup", @context)

      # RadioGroup is a LinearLayout subclass (VERTICAL by default on Android)
      LibAndroidBridge.android_linearlayout_set_orientation(@env, rg, 1) # VERTICAL

      # Common properties on the container
      apply_common_properties(rg, view)

      global_rg = LibAndroidBridge.android_new_global_ref(@env, rg)
      handle = JNI.wrap_global(global_rg, label: "RadioGroup")
      native = NativeView.new(handle)

      # Create a RadioButton for each option and add to the RadioGroup.
      # We track the generated view IDs so we can call check() on the selected one.
      radio_ids = Array(Int32).new(view.options.size)

      view.options.each_with_index do |option_text, index|
        rb = LibAndroidBridge.android_view_new(@env, "android/widget/RadioButton", @context)

        LibAndroidBridge.android_radiobutton_set_text(
          @env, rb, option_text.to_unsafe, option_text.bytesize)

        is_selected = (index == view.selected_index)
        LibAndroidBridge.android_radiobutton_set_checked(@env, rb, is_selected ? 1 : 0)

        # Generate a unique view ID for this RadioButton
        rb_id = LibAndroidBridge.android_view_generate_id(@env)
        radio_ids << rb_id

        # Add RadioButton to RadioGroup
        LibAndroidBridge.android_viewgroup_add_view(@env, rg, rb)

        # Track RadioButton as child NativeView
        global_rb = LibAndroidBridge.android_new_global_ref(@env, rb)
        rb_handle = JNI.wrap_global(global_rb, label: "RadioButton[#{index}]")
        rb_native = NativeView.new(rb_handle)
        native.add_child(rb_native)
      end

      # Select the initially selected radio button
      if view.selected_index >= 0 && view.selected_index < radio_ids.size
        LibAndroidBridge.android_radiogroup_check(@env, rg, radio_ids[view.selected_index])
      end

      # Wire up on_change via OnCheckedChangeListener on the RadioGroup.
      # The C bridge registers RadioGroup.OnCheckedChangeListener that calls
      # crystal_ui_callback_dispatch(id). The Crystal wrapper maps the checked
      # view ID back to an index.
      if change_handler = view.on_change
        captured_radio_ids = radio_ids
        wrapped = Proc(Nil).new do
          # In a production bridge, the callback receives the checked view ID.
          # We would look it up in captured_radio_ids to find the index.
          # For structural completeness, we call the handler with selected_index.
          # A production implementation: change_handler.call(captured_radio_ids.index(checked_id) || 0)
          change_handler.call(view.selected_index)
        end
        callback_id = native.register_callback(wrapped)
        LibAndroidBridge.android_radiogroup_set_on_checked_change_listener(@env, rg, callback_id)
      end

      push_native(native, rg)
    end

    # -----------------------------------------------------------------
    # Visit: Slider -> android.widget.SeekBar
    #
    # SeekBar is Android's native slider. It works with integer progress
    # values (0..max), so we scale the Crystal Float64 range to integers.
    #
    # For a slider with minimum=0, maximum=1, step=0.01, we use max=100
    # and scale progress accordingly. For continuous sliders we use max=1000
    # for reasonable precision.
    # -----------------------------------------------------------------
    def visit(view : UI::Slider)
      sb = LibAndroidBridge.android_view_new(@env, "android/widget/SeekBar", @context)

      # Determine integer scale for the SeekBar
      range = view.maximum - view.minimum
      # Use step-based scaling if step is set, otherwise 1000 steps
      steps = if view.step > 0.0
                (range / view.step).round.to_i.clamp(1, 10000)
              else
                1000
              end

      LibAndroidBridge.android_seekbar_set_max(@env, sb, steps)

      # Initial progress scaled from value
      initial_progress = if range > 0.0
                           ((view.value - view.minimum) / range * steps).round.to_i.clamp(0, steps)
                         else
                           0
                         end
      LibAndroidBridge.android_seekbar_set_progress(@env, sb, initial_progress)

      # Tint color for the progress track
      if tint = view.tint_color
        LibAndroidBridge.android_seekbar_set_progress_tint(@env, sb, color_to_argb(tint))
      end

      # Common properties
      apply_common_properties(sb, view)

      global_sb = LibAndroidBridge.android_new_global_ref(@env, sb)
      handle = JNI.wrap_global(global_sb, label: "SeekBar")
      native = NativeView.new(handle)

      # Wire up on_change via OnSeekBarChangeListener.
      # The C bridge registers OnSeekBarChangeListener.onProgressChanged that calls
      # crystal_ui_callback_dispatch(id). The Crystal wrapper reads the current
      # progress and converts back to the Crystal Float64 range.
      if change_handler = view.on_change
        sb_local = sb
        captured_min = view.minimum
        captured_range = range
        captured_steps = steps
        captured_step = view.step

        wrapped = Proc(Nil).new do
          raw_progress = LibAndroidBridge.android_seekbar_get_progress(@env, sb_local)
          raw_value = if captured_steps > 0
                        captured_min + (raw_progress.to_f64 / captured_steps) * captured_range
                      else
                        captured_min
                      end
          actual_value = if captured_step > 0.0
                           snapped = (raw_value / captured_step).round * captured_step
                           snapped.clamp(captured_min, captured_min + captured_range)
                         else
                           raw_value.clamp(captured_min, captured_min + captured_range)
                         end
          change_handler.call(actual_value)
        end
        callback_id = native.register_callback(wrapped)
        LibAndroidBridge.android_seekbar_set_on_change_listener(@env, sb, callback_id)
      end

      push_native(native, sb)
    end

    # -----------------------------------------------------------------
    # Visit: NavigationStack -> android.widget.FrameLayout (navigation container)
    # -----------------------------------------------------------------
    def visit(view : UI::NavigationStack)
      fl = LibAndroidBridge.android_view_new(@env, "android/widget/FrameLayout", @context)

      apply_common_properties(fl, view)

      global_fl = LibAndroidBridge.android_new_global_ref(@env, fl)
      handle = JNI.wrap_global(global_fl, label: "FrameLayout[nav-stack]")
      native = NativeView.new(handle)

      # Render the current view (top of stack or root) into this container
      push_stack(native, fl, is_linear: false)
      view.current_view.accept(self)
      pop_stack

      push_native(native, fl)
    end

    # -----------------------------------------------------------------
    # Visit: NavigationLink -> android.widget.Button (link row)
    # -----------------------------------------------------------------
    def visit(view : UI::NavigationLink)
      btn = LibAndroidBridge.android_view_new(@env, "android/widget/Button", @context)

      LibAndroidBridge.android_textview_set_text(
        @env, btn, view.label.to_unsafe, view.label.bytesize)

      apply_common_properties(btn, view)

      emit(btn, "Button[nav-link]")
    end

    # -----------------------------------------------------------------
    # Visit: TabView -> android.widget.FrameLayout (tab container)
    # -----------------------------------------------------------------
    def visit(view : UI::TabView)
      fl = LibAndroidBridge.android_view_new(@env, "android/widget/FrameLayout", @context)

      apply_common_properties(fl, view)

      global_fl = LibAndroidBridge.android_new_global_ref(@env, fl)
      handle = JNI.wrap_global(global_fl, label: "FrameLayout[tab-view]")
      native = NativeView.new(handle)

      if content = view.current_content
        push_stack(native, fl, is_linear: false)
        content.accept(self)
        pop_stack
      end

      push_native(native, fl)
    end

    # -----------------------------------------------------------------
    # Visit: ProgressView -> android.widget.ProgressBar
    # -----------------------------------------------------------------
    def visit(view : UI::ProgressView)
      # ProgressBar default style is indeterminate circular spinner.
      # For determinate linear we use android/widget/ProgressBar with horizontal style.
      pb = LibAndroidBridge.android_view_new(@env, "android/widget/ProgressBar", @context)

      if val = view.value
        # Determinate: setIndeterminate(false), setProgress(0..10000)
        LibAndroidBridge.android_seekbar_set_max(@env, pb, 10000)
        progress = (val * 10000).round.to_i.clamp(0, 10000)
        LibAndroidBridge.android_seekbar_set_progress(@env, pb, progress)
      end
      # else indeterminate: ProgressBar default behavior is indeterminate

      if tint = view.tint_color
        LibAndroidBridge.android_seekbar_set_progress_tint(@env, pb, color_to_argb(tint))
      end

      apply_common_properties(pb, view)

      emit(pb, "ProgressBar")
    end

    # -----------------------------------------------------------------
    # Visit: ActivityIndicator -> android.widget.ProgressBar (spinner)
    # -----------------------------------------------------------------
    def visit(view : UI::ActivityIndicator)
      spinner = LibAndroidBridge.android_view_new(@env, "android/widget/ProgressBar", @context)

      # Visibility: VISIBLE=0, INVISIBLE=4, GONE=8
      unless view.is_animating
        LibAndroidBridge.android_view_set_visibility(@env, spinner, 4) # INVISIBLE
      end

      if tint = view.color
        LibAndroidBridge.android_seekbar_set_progress_tint(@env, spinner, color_to_argb(tint))
      end

      apply_common_properties(spinner, view)

      emit(spinner, "ProgressBar[spinner]")
    end

    # -----------------------------------------------------------------
    # Visit: Alert -> android.app.AlertDialog (stub: creates a FrameLayout placeholder)
    # -----------------------------------------------------------------
    def visit(view : UI::Alert)
      # AlertDialog requires a fully instantiated Activity context and must be
      # shown on the main UI thread. We create a FrameLayout as a structural
      # placeholder. Production code would call AlertDialog.Builder on the host side.
      fl = LibAndroidBridge.android_view_new(@env, "android/widget/FrameLayout", @context)

      title_tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
      LibAndroidBridge.android_textview_set_text(
        @env, title_tv, view.title.to_unsafe, view.title.bytesize)
      LibAndroidBridge.android_viewgroup_add_view(@env, fl, title_tv)

      unless view.message.empty?
        msg_tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
        LibAndroidBridge.android_textview_set_text(
          @env, msg_tv, view.message.to_unsafe, view.message.bytesize)
        LibAndroidBridge.android_viewgroup_add_view(@env, fl, msg_tv)
      end

      apply_common_properties(fl, view)

      emit(fl, "FrameLayout[alert]")
    end

    # -----------------------------------------------------------------
    # Visit: Picker -> android.widget.Spinner
    # -----------------------------------------------------------------
    def visit(view : UI::Picker)
      spinner = LibAndroidBridge.android_view_new(@env, "android/widget/Spinner", @context)

      apply_common_properties(spinner, view)

      global_sp = LibAndroidBridge.android_new_global_ref(@env, spinner)
      handle = JNI.wrap_global(global_sp, label: "Spinner")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        wrapped = Proc(Nil).new do
          change_handler.call(view.selected_index)
        end
        callback_id = native.register_callback(wrapped)
        LibAndroidBridge.android_view_set_on_click_listener(@env, spinner, callback_id)
      end

      push_native(native, spinner)
    end

    # -----------------------------------------------------------------
    # Visit: IconButton -> android.widget.ImageButton
    # -----------------------------------------------------------------
    def visit(view : UI::IconButton)
      ib = LibAndroidBridge.android_view_new(@env, "android/widget/ImageButton", @context)

      # Load icon by name (treated as a drawable resource name)
      LibAndroidBridge.android_imageview_set_image_named(@env, ib, view.icon.to_unsafe)

      if view.disabled
        LibAndroidBridge.android_view_set_alpha(@env, ib, 0.4_f32)
      end

      apply_common_properties(ib, view)

      global_ib = LibAndroidBridge.android_new_global_ref(@env, ib)
      handle = JNI.wrap_global(global_ib, label: "ImageButton[icon]")
      native = NativeView.new(handle)

      if tap_handler = view.on_tap
        callback_id = native.register_callback(tap_handler)
        LibAndroidBridge.android_view_set_on_click_listener(@env, ib, callback_id)
      end

      push_native(native, ib)
    end

    # -----------------------------------------------------------------
    # Visit: ListView -> android.widget.LinearLayout (vertical, with rows)
    # -----------------------------------------------------------------
    def visit(view : UI::ListView)
      ll = LibAndroidBridge.android_view_new(@env, "android/widget/LinearLayout", @context)

      # VERTICAL = 1
      LibAndroidBridge.android_linearlayout_set_orientation(@env, ll, 1)

      apply_common_properties(ll, view)

      global_ll = LibAndroidBridge.android_new_global_ref(@env, ll)
      handle = JNI.wrap_global(global_ll, label: "LinearLayout[list]")
      native = NativeView.new(handle)

      push_stack(native, ll, is_linear: true)

      view.sections.each do |section|
        if header = section.header
          header_tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
          LibAndroidBridge.android_textview_set_text(
            @env, header_tv, header.to_unsafe, header.bytesize)
          emit(header_tv, "TextView[list-header]")
        end

        section.items.each do |item|
          item.accept(self)
        end
      end

      pop_stack

      push_native(native, ll)
    end

    def visit(view : UI::OutlineView)
      view.fallback_view.accept(self)
    end

    def visit(view : UI::ColumnView)
      view.fallback_view.accept(self)
    end

    def visit(view : UI::TokenField)
      view.fallback_view.accept(self)
    end

    # -----------------------------------------------------------------
    # Visit: SecureField -> android.widget.EditText (password input type)
    # -----------------------------------------------------------------
    def visit(view : UI::SecureField)
      et = LibAndroidBridge.android_view_new(@env, "android/widget/EditText", @context)

      unless view.placeholder.empty?
        LibAndroidBridge.android_edittext_set_hint(
          @env, et, view.placeholder.to_unsafe, view.placeholder.bytesize)
      end

      unless view.text.empty?
        LibAndroidBridge.android_edittext_set_text(
          @env, et, view.text.to_unsafe, view.text.bytesize)
      end

      # TYPE_CLASS_TEXT | TYPE_TEXT_VARIATION_PASSWORD = 0x81
      LibAndroidBridge.android_edittext_set_input_type(@env, et, 0x81)

      LibAndroidBridge.android_textview_set_text_size(@env, et, view.font.size.to_f32)
      LibAndroidBridge.android_textview_set_text_color(
        @env, et, color_to_argb(view.text_color))

      apply_common_properties(et, view)

      global_et = LibAndroidBridge.android_new_global_ref(@env, et)
      handle = JNI.wrap_global(global_et, label: "EditText[secure]")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        et_local = et
        wrapped = Proc(Nil).new do
          jstr = LibAndroidBridge.android_edittext_get_text(@env, et_local)
          unless jstr.null?
            jstr_wrapper = UI::JNI::JString.new(@env, jstr)
            change_handler.call(jstr_wrapper.to_string)
            jstr_wrapper.delete_local
          end
        end
        callback_id = native.register_callback(wrapped)
        LibAndroidBridge.android_edittext_set_text_watcher(@env, et, callback_id)
      end

      push_native(native, et)
    end

    # -----------------------------------------------------------------
    # Visit: Stepper -> android.widget.LinearLayout (increment/decrement buttons)
    # -----------------------------------------------------------------
    def visit(view : UI::Stepper)
      ll = LibAndroidBridge.android_view_new(@env, "android/widget/LinearLayout", @context)

      # HORIZONTAL = 0
      LibAndroidBridge.android_linearlayout_set_orientation(@env, ll, 0)

      apply_common_properties(ll, view)

      minus_btn = LibAndroidBridge.android_view_new(@env, "android/widget/Button", @context)
      LibAndroidBridge.android_textview_set_text(@env, minus_btn, "-", 1)
      LibAndroidBridge.android_viewgroup_add_view(@env, ll, minus_btn)

      value_tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
      val_str = view.value.to_s
      LibAndroidBridge.android_textview_set_text(@env, value_tv, val_str.to_unsafe, val_str.bytesize)
      LibAndroidBridge.android_viewgroup_add_view(@env, ll, value_tv)

      plus_btn = LibAndroidBridge.android_view_new(@env, "android/widget/Button", @context)
      LibAndroidBridge.android_textview_set_text(@env, plus_btn, "+", 1)
      LibAndroidBridge.android_viewgroup_add_view(@env, ll, plus_btn)

      global_ll = LibAndroidBridge.android_new_global_ref(@env, ll)
      handle = JNI.wrap_global(global_ll, label: "LinearLayout[stepper]")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        current_val = view.value
        wrapped = Proc(Nil).new do
          change_handler.call(current_val)
        end
        callback_id = native.register_callback(wrapped)
        LibAndroidBridge.android_view_set_on_click_listener(@env, plus_btn, callback_id)
      end

      push_native(native, ll)
    end

    # -----------------------------------------------------------------
    # Visit: SegmentedControl -> android.widget.RadioGroup (segmented style)
    # -----------------------------------------------------------------
    def visit(view : UI::SegmentedControl)
      rg = LibAndroidBridge.android_view_new(@env, "android/widget/RadioGroup", @context)

      # HORIZONTAL = 0
      LibAndroidBridge.android_linearlayout_set_orientation(@env, rg, 0)

      apply_common_properties(rg, view)

      view.segments.each_with_index do |segment, index|
        rb = LibAndroidBridge.android_view_new(@env, "android/widget/RadioButton", @context)
        LibAndroidBridge.android_radiobutton_set_text(@env, rb, segment.to_unsafe, segment.bytesize)
        LibAndroidBridge.android_radiobutton_set_checked(@env, rb, index == view.selected_index ? 1 : 0)
        LibAndroidBridge.android_viewgroup_add_view(@env, rg, rb)
      end

      global_rg = LibAndroidBridge.android_new_global_ref(@env, rg)
      handle = JNI.wrap_global(global_rg, label: "RadioGroup[segmented]")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        wrapped = Proc(Nil).new do
          change_handler.call(view.selected_index)
        end
        callback_id = native.register_callback(wrapped)
        LibAndroidBridge.android_radiogroup_set_on_checked_change_listener(@env, rg, callback_id)
      end

      push_native(native, rg)
    end

    # -----------------------------------------------------------------
    # Visit: DatePicker -> android.widget.DatePicker
    # -----------------------------------------------------------------
    def visit(view : UI::DatePicker)
      dp = LibAndroidBridge.android_view_new(@env, "android/widget/DatePicker", @context)

      apply_common_properties(dp, view)

      emit(dp, "DatePicker")
    end

    # -----------------------------------------------------------------
    # Visit: TimePicker -> android.widget.TimePicker
    # -----------------------------------------------------------------
    def visit(view : UI::TimePicker)
      tp = LibAndroidBridge.android_view_new(@env, "android/widget/TimePicker", @context)

      apply_common_properties(tp, view)

      emit(tp, "TimePicker")
    end

    # -----------------------------------------------------------------
    # Visit: SearchField -> android.widget.SearchView
    # -----------------------------------------------------------------
    def visit(view : UI::SearchField)
      sv = LibAndroidBridge.android_view_new(@env, "android/widget/SearchView", @context)

      apply_common_properties(sv, view)

      global_sv = LibAndroidBridge.android_new_global_ref(@env, sv)
      handle = JNI.wrap_global(global_sv, label: "SearchView")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        wrapped = Proc(Nil).new do
          change_handler.call(view.text)
        end
        callback_id = native.register_callback(wrapped)
        LibAndroidBridge.android_view_set_on_click_listener(@env, sv, callback_id)
      end

      push_native(native, sv)
    end

    # -----------------------------------------------------------------
    # Visit: TextArea -> android.widget.EditText (multiline)
    # -----------------------------------------------------------------
    def visit(view : UI::TextArea)
      et = LibAndroidBridge.android_view_new(@env, "android/widget/EditText", @context)

      unless view.placeholder.empty?
        LibAndroidBridge.android_edittext_set_hint(
          @env, et, view.placeholder.to_unsafe, view.placeholder.bytesize)
      end

      unless view.text.empty?
        LibAndroidBridge.android_edittext_set_text(
          @env, et, view.text.to_unsafe, view.text.bytesize)
      end

      # InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE = 0x00020001
      LibAndroidBridge.android_edittext_set_input_type(@env, et, 0x00020001)

      LibAndroidBridge.android_textview_set_text_size(@env, et, view.font.size.to_f32)
      LibAndroidBridge.android_textview_set_typeface(@env, et, typeface_style_for(view.font))
      LibAndroidBridge.android_textview_set_text_color(@env, et, color_to_argb(view.text_color))

      apply_common_properties(et, view)

      global_et = LibAndroidBridge.android_new_global_ref(@env, et)
      handle = JNI.wrap_global(global_et, label: "EditText[textarea]")
      native = NativeView.new(handle)

      if change_handler = view.on_change
        et_local = et
        wrapped = Proc(Nil).new do
          jstr = LibAndroidBridge.android_edittext_get_text(@env, et_local)
          unless jstr.null?
            jstr_wrapper = UI::JNI::JString.new(@env, jstr)
            change_handler.call(jstr_wrapper.to_string)
            jstr_wrapper.delete_local
          end
        end
        callback_id = native.register_callback(wrapped)
        LibAndroidBridge.android_edittext_set_text_watcher(@env, et, callback_id)
      end

      push_native(native, et)
    end

    # -----------------------------------------------------------------
    # Visit: Grid -> android.widget.LinearLayout (grid rows)
    # -----------------------------------------------------------------
    def visit(view : UI::Grid)
      ll = LibAndroidBridge.android_view_new(@env, "android/widget/LinearLayout", @context)

      # VERTICAL = 1
      LibAndroidBridge.android_linearlayout_set_orientation(@env, ll, 1)

      apply_common_properties(ll, view)

      global_ll = LibAndroidBridge.android_new_global_ref(@env, ll)
      handle = JNI.wrap_global(global_ll, label: "LinearLayout[grid]")
      native = NativeView.new(handle)

      push_stack(native, ll, is_linear: true)
      view.children.each do |row|
        row.each do |cell|
          cell.accept(self)
        end
      end
      pop_stack

      push_native(native, ll)
    end

    # -----------------------------------------------------------------
    # Visit: Form -> android.widget.LinearLayout (form sections)
    # -----------------------------------------------------------------
    def visit(view : UI::Form)
      ll = LibAndroidBridge.android_view_new(@env, "android/widget/LinearLayout", @context)

      # VERTICAL = 1
      LibAndroidBridge.android_linearlayout_set_orientation(@env, ll, 1)

      apply_common_properties(ll, view)

      global_ll = LibAndroidBridge.android_new_global_ref(@env, ll)
      handle = JNI.wrap_global(global_ll, label: "LinearLayout[form]")
      native = NativeView.new(handle)

      push_stack(native, ll, is_linear: true)

      view.sections.each do |section|
        if header = section.header
          header_tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
          LibAndroidBridge.android_textview_set_text(@env, header_tv, header.to_unsafe, header.bytesize)
          emit(header_tv, "TextView[form-header]")
        end

        section.fields.each do |field|
          row_ll = LibAndroidBridge.android_view_new(@env, "android/widget/LinearLayout", @context)
          LibAndroidBridge.android_linearlayout_set_orientation(@env, row_ll, 0) # HORIZONTAL

          unless field.label.empty?
            lbl_tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
            LibAndroidBridge.android_textview_set_text(@env, lbl_tv, field.label.to_unsafe, field.label.bytesize)
            LibAndroidBridge.android_viewgroup_add_view(@env, row_ll, lbl_tv)
          end

          if content = field.content
            row_global = LibAndroidBridge.android_new_global_ref(@env, row_ll)
            row_handle = JNI.wrap_global(row_global, label: "LinearLayout[form-row]")
            row_native = NativeView.new(row_handle)
            push_stack(row_native, row_ll, is_linear: true)
            content.accept(self)
            pop_stack
            LibAndroidBridge.android_viewgroup_add_view(@env, ll, row_ll)
          else
            LibAndroidBridge.android_viewgroup_add_view(@env, ll, row_ll)
          end
        end

        if footer = section.footer
          footer_tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
          LibAndroidBridge.android_textview_set_text(@env, footer_tv, footer.to_unsafe, footer.bytesize)
          emit(footer_tv, "TextView[form-footer]")
        end
      end

      pop_stack

      push_native(native, ll)
    end

    # -----------------------------------------------------------------
    # Visit: NavigationSplitView -> android.widget.LinearLayout (horizontal split)
    # -----------------------------------------------------------------
    def visit(view : UI::NavigationSplitView)
      ll = LibAndroidBridge.android_view_new(@env, "android/widget/LinearLayout", @context)

      # HORIZONTAL = 0
      LibAndroidBridge.android_linearlayout_set_orientation(@env, ll, 0)

      apply_common_properties(ll, view)

      global_ll = LibAndroidBridge.android_new_global_ref(@env, ll)
      handle = JNI.wrap_global(global_ll, label: "LinearLayout[split]")
      native = NativeView.new(handle)

      push_stack(native, ll, is_linear: true)

      if view.shows_sidebar
        if sidebar = view.sidebar
          sidebar.accept(self)
        end
      end

      if content = view.content
        content.accept(self)
      end

      if detail = view.detail
        detail.accept(self)
      end

      pop_stack

      push_native(native, ll)
    end

    # -----------------------------------------------------------------
    # Visit: Toolbar -> android.widget.LinearLayout (toolbar container)
    # -----------------------------------------------------------------
    def visit(view : UI::Toolbar)
      ll = LibAndroidBridge.android_view_new(@env, "android/widget/LinearLayout", @context)

      # HORIZONTAL = 0
      LibAndroidBridge.android_linearlayout_set_orientation(@env, ll, 0)

      if title = view.title
        tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
        LibAndroidBridge.android_textview_set_text(
          @env, tv, title.to_unsafe, title.bytesize)
        LibAndroidBridge.android_viewgroup_add_view(@env, ll, tv)
      end

      apply_common_properties(ll, view)

      emit(ll, "LinearLayout[toolbar]")
    end

    # -----------------------------------------------------------------
    # Visit: Sheet -> android.widget.FrameLayout (bottom sheet placeholder)
    # -----------------------------------------------------------------
    def visit(view : UI::Sheet)
      fl = LibAndroidBridge.android_view_new(@env, "android/widget/FrameLayout", @context)

      unless view.is_presented
        LibAndroidBridge.android_view_set_visibility(@env, fl, 8) # GONE
      end

      apply_common_properties(fl, view)

      global_fl = LibAndroidBridge.android_new_global_ref(@env, fl)
      handle = JNI.wrap_global(global_fl, label: "FrameLayout[sheet]")
      native = NativeView.new(handle)

      if content = view.content
        push_stack(native, fl, is_linear: false)
        content.accept(self)
        pop_stack
      end

      push_native(native, fl)
    end

    # -----------------------------------------------------------------
    # Visit: Popover -> android.widget.FrameLayout (popover placeholder)
    # -----------------------------------------------------------------
    def visit(view : UI::Popover)
      fl = LibAndroidBridge.android_view_new(@env, "android/widget/FrameLayout", @context)

      unless view.is_presented
        LibAndroidBridge.android_view_set_visibility(@env, fl, 8) # GONE
      end

      apply_common_properties(fl, view)

      global_fl = LibAndroidBridge.android_new_global_ref(@env, fl)
      handle = JNI.wrap_global(global_fl, label: "FrameLayout[popover]")
      native = NativeView.new(handle)

      if content = view.content
        push_stack(native, fl, is_linear: false)
        content.accept(self)
        pop_stack
      end

      push_native(native, fl)
    end

    # -----------------------------------------------------------------
    # Visit: ConfirmationDialog -> android.widget.FrameLayout (dialog placeholder)
    # -----------------------------------------------------------------
    def visit(view : UI::ConfirmationDialog)
      fl = LibAndroidBridge.android_view_new(@env, "android/widget/FrameLayout", @context)

      title_tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
      LibAndroidBridge.android_textview_set_text(
        @env, title_tv, view.title.to_unsafe, view.title.bytesize)
      LibAndroidBridge.android_viewgroup_add_view(@env, fl, title_tv)

      unless view.message.empty?
        msg_tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
        LibAndroidBridge.android_textview_set_text(
          @env, msg_tv, view.message.to_unsafe, view.message.bytesize)
        LibAndroidBridge.android_viewgroup_add_view(@env, fl, msg_tv)
      end

      unless view.is_presented
        LibAndroidBridge.android_view_set_visibility(@env, fl, 8) # GONE
      end

      apply_common_properties(fl, view)

      emit(fl, "FrameLayout[confirmation-dialog]")
    end

    # -----------------------------------------------------------------
    # Visit: Snackbar -> android.widget.TextView (snackbar placeholder)
    # -----------------------------------------------------------------
    def visit(view : UI::Snackbar)
      tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)

      LibAndroidBridge.android_textview_set_text(
        @env, tv, view.message.to_unsafe, view.message.bytesize)

      unless view.is_presented
        LibAndroidBridge.android_view_set_visibility(@env, tv, 8) # GONE
      end

      apply_common_properties(tv, view)

      emit(tv, "TextView[snackbar]")
    end

    # -----------------------------------------------------------------
    # Visit: Card -> com.google.android.material.card.MaterialCardView (via FrameLayout)
    # -----------------------------------------------------------------
    def visit(view : UI::Card)
      fl = LibAndroidBridge.android_view_new(@env, "android/widget/FrameLayout", @context)

      if view.elevation > 0
        LibAndroidBridge.android_view_set_elevation(@env, fl, view.elevation.to_f32)
      end

      apply_common_properties(fl, view)

      global_fl = LibAndroidBridge.android_new_global_ref(@env, fl)
      handle = JNI.wrap_global(global_fl, label: "FrameLayout[card]")
      native = NativeView.new(handle)

      if content = view.content
        push_stack(native, fl, is_linear: false)
        content.accept(self)
        pop_stack
      end

      push_native(native, fl)
    end

    # -----------------------------------------------------------------
    # Visit: Surface -> android.widget.FrameLayout (elevated surface)
    # -----------------------------------------------------------------
    def visit(view : UI::Surface)
      fl = LibAndroidBridge.android_view_new(@env, "android/widget/FrameLayout", @context)

      if view.elevation > 0
        LibAndroidBridge.android_view_set_elevation(@env, fl, view.elevation.to_f32)
      end

      apply_common_properties(fl, view)

      global_fl = LibAndroidBridge.android_new_global_ref(@env, fl)
      handle = JNI.wrap_global(global_fl, label: "FrameLayout[surface]")
      native = NativeView.new(handle)

      if content = view.content
        push_stack(native, fl, is_linear: false)
        content.accept(self)
        pop_stack
      end

      push_native(native, fl)
    end

    # -----------------------------------------------------------------
    # Visit: Divider -> android.view.View (thin separator)
    # -----------------------------------------------------------------
    def visit(view : UI::Divider)
      v = LibAndroidBridge.android_view_new(@env, "android/view/View", @context)

      c = view.color
      LibAndroidBridge.android_view_set_background_color(@env, v, color_to_argb(c))

      apply_common_properties(v, view)

      emit(v, "View[divider]")
    end

    # -----------------------------------------------------------------
    # Visit: GlassBackground -> android.widget.FrameLayout (blur placeholder)
    #
    # Android doesn't have a built-in blur/frosted glass effect equivalent
    # to UIVisualEffectView or NSVisualEffectView. We use a FrameLayout
    # with a semi-transparent background as a structural placeholder.
    # Production code would use a RenderEffect blur or a third-party library.
    # -----------------------------------------------------------------
    def visit(view : UI::GlassBackground)
      fl = LibAndroidBridge.android_view_new(@env, "android/widget/FrameLayout", @context)

      # Semi-transparent white background as visual approximation
      alpha_int = case view.material
                  when :ultra_thin then 0x33FFFFFF # 20% opacity
                  when :thin       then 0x66FFFFFF # 40% opacity
                  when :regular    then 0x99FFFFFF # 60% opacity
                  when :thick      then 0xBBFFFFFF # 73% opacity
                  when :chrome     then 0xDDFFFFFF # 87% opacity
                  else                  0x99FFFFFF
                  end
      LibAndroidBridge.android_view_set_background_color(@env, fl, alpha_int.to_i32)

      apply_common_properties(fl, view)

      global_fl = LibAndroidBridge.android_new_global_ref(@env, fl)
      handle = JNI.wrap_global(global_fl, label: "FrameLayout[glass]")
      native = NativeView.new(handle)

      if content = view.content
        push_stack(native, fl, is_linear: false)
        content.accept(self)
        pop_stack
      end

      push_native(native, fl)
    end

    # -----------------------------------------------------------------
    # P2 Wave 3 Visit methods
    # -----------------------------------------------------------------

    def visit(view : UI::AsyncImage)
      iv = LibAndroidBridge.android_view_new(@env, "android/widget/ImageView", @context)
      apply_common_properties(iv, view)
      emit(iv, "ImageView[async]")
    end

    def visit(view : UI::RichText)
      tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
      unless view.plain_text.empty?
        LibAndroidBridge.android_textview_set_text(
          @env, tv, view.plain_text.to_unsafe, view.plain_text.bytesize)
      end
      apply_common_properties(tv, view)
      emit(tv, "TextView[rich]")
    end

    def visit(view : UI::LinkButton)
      btn = LibAndroidBridge.android_view_new(@env, "android/widget/Button", @context)
      LibAndroidBridge.android_textview_set_text(
        @env, btn, view.label.to_unsafe, view.label.bytesize)
      apply_common_properties(btn, view)
      emit(btn, "Button[link]")
    end

    def visit(view : UI::MenuButton)
      btn = LibAndroidBridge.android_view_new(@env, "android/widget/Button", @context)
      LibAndroidBridge.android_textview_set_text(
        @env, btn, view.label.to_unsafe, view.label.bytesize)
      apply_common_properties(btn, view)
      emit(btn, "Button[menu]")
    end

    def visit(view : UI::ContextMenu)
      ll = LibAndroidBridge.android_view_new(@env, "android/widget/LinearLayout", @context)
      LibAndroidBridge.android_linearlayout_set_orientation(@env, ll, 1)
      apply_common_properties(ll, view)

      global_ll = LibAndroidBridge.android_new_global_ref(@env, ll)
      handle = JNI.wrap_global(global_ll, label: "LinearLayout[context-menu]")
      native = NativeView.new(handle)

      view.items.each do |entry|
        case entry
        when UI::ContextMenu::Separator
          sep = LibAndroidBridge.android_view_new(@env, "android/view/View", @context)
          LibAndroidBridge.android_view_set_background_color(@env, sep, 0x2E3C3C43)
          sep_global = LibAndroidBridge.android_new_global_ref(@env, sep)
          sep_handle = JNI.wrap_global(sep_global, label: "View[context-menu-separator]")
          sep_native = NativeView.new(sep_handle)
          native.add_child(sep_native)
          LibAndroidBridge.android_viewgroup_add_view_wh(@env, ll, sep, -1, 1)
        when UI::ContextMenu::Item
          tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
          LibAndroidBridge.android_textview_set_text(@env, tv, entry.label.to_unsafe, entry.label.bytesize)
          color = if entry.is_destructive
                    0xFFFF3B30_u32
                  elsif entry.is_disabled
                    0xFF8E8E93_u32
                  else
                    0xFF111111_u32
                  end
          LibAndroidBridge.android_textview_set_text_color(@env, tv, color.to_i32)
          LibAndroidBridge.android_view_set_padding(@env, tv, 24, 18, 24, 18)
          tv_global = LibAndroidBridge.android_new_global_ref(@env, tv)
          tv_handle = JNI.wrap_global(tv_global, label: "TextView[context-menu-item]")
          tv_native = NativeView.new(tv_handle)
          native.add_child(tv_native)
          LibAndroidBridge.android_viewgroup_add_view_wh(@env, ll, tv, -1, -2)
        end
      end

      push_native(native, ll)
    end

    def visit(view : UI::ToggleButton)
      btn = LibAndroidBridge.android_view_new(@env, "android/widget/ToggleButton", @context)
      LibAndroidBridge.android_textview_set_text(
        @env, btn, view.label.to_unsafe, view.label.bytesize)
      apply_common_properties(btn, view)
      emit(btn, "ToggleButton")
    end

    def visit(view : UI::TextEditor)
      et = LibAndroidBridge.android_view_new(@env, "android/widget/EditText", @context)
      unless view.text.empty?
        LibAndroidBridge.android_edittext_set_text(
          @env, et, view.text.to_unsafe, view.text.bytesize)
      end
      unless view.placeholder.empty?
        LibAndroidBridge.android_edittext_set_hint(
          @env, et, view.placeholder.to_unsafe, view.placeholder.bytesize)
      end
      apply_common_properties(et, view)
      emit(et, "EditText[editor]")
    end

    # -----------------------------------------------------------------
    # P3 Visit methods
    # -----------------------------------------------------------------

    # Circle: android.view.View with background color, corner radius = size/2
    # (full circle via outline provider), and optional stroke.
    def visit(view : UI::Circle)
      v = LibAndroidBridge.android_view_new(@env, "android/view/View", @context)

      # Fill color as background
      LibAndroidBridge.android_view_set_background_color(
        @env, v, color_to_argb(view.fill_color))

      # Corner radius = half the size to make a circle
      radius = (view.size / 2.0).to_f32
      LibAndroidBridge.android_view_set_corner_radius(@env, v, radius)
      LibAndroidBridge.android_view_set_clip_to_outline(@env, v, 1)

      # Optional stroke
      if view.stroke_width > 0.0
        stroke_color = view.stroke_color || UI::Color.new(r: 0.0, g: 0.0, b: 0.0)
        LibAndroidBridge.android_view_set_stroke(
          @env, v, view.stroke_width.to_f32, color_to_argb(stroke_color))
      end

      apply_common_properties(v, view)
      emit(v, "View[circle]")
    end

    # Rectangle: android.view.View with background color and optional stroke.
    def visit(view : UI::Rectangle)
      v = LibAndroidBridge.android_view_new(@env, "android/view/View", @context)

      # Fill color as background
      LibAndroidBridge.android_view_set_background_color(
        @env, v, color_to_argb(view.fill_color))

      # Optional stroke
      if view.stroke_width > 0.0
        stroke_color = view.stroke_color || UI::Color.new(r: 0.0, g: 0.0, b: 0.0)
        LibAndroidBridge.android_view_set_stroke(
          @env, v, view.stroke_width.to_f32, color_to_argb(stroke_color))
      end

      apply_common_properties(v, view)
      emit(v, "View[rectangle]")
    end

    # RoundedRectangle: android.view.View with corner radius, fill, and stroke.
    def visit(view : UI::RoundedRectangle)
      v = LibAndroidBridge.android_view_new(@env, "android/view/View", @context)

      # Fill color as background
      LibAndroidBridge.android_view_set_background_color(
        @env, v, color_to_argb(view.fill_color))

      # Corner radius
      if view.corner_radius > 0.0
        LibAndroidBridge.android_view_set_corner_radius(
          @env, v, view.corner_radius.to_f32)
        LibAndroidBridge.android_view_set_clip_to_outline(@env, v, 1)
      end

      # Optional stroke
      if view.stroke_width > 0.0
        stroke_color = view.stroke_color || UI::Color.new(r: 0.0, g: 0.0, b: 0.0)
        LibAndroidBridge.android_view_set_stroke(
          @env, v, view.stroke_width.to_f32, color_to_argb(stroke_color))
      end

      apply_common_properties(v, view)
      emit(v, "View[rounded-rectangle]")
    end

    # Capsule: android.view.View with corner radius = height/2 for pill shape,
    # fill color, and optional stroke.
    def visit(view : UI::Capsule)
      v = LibAndroidBridge.android_view_new(@env, "android/view/View", @context)

      # Fill color as background
      LibAndroidBridge.android_view_set_background_color(
        @env, v, color_to_argb(view.fill_color))

      # Pill shape: corner radius = half height
      radius = (view.height / 2.0).to_f32
      LibAndroidBridge.android_view_set_corner_radius(@env, v, radius)
      LibAndroidBridge.android_view_set_clip_to_outline(@env, v, 1)

      # Optional stroke
      if view.stroke_width > 0.0
        stroke_color = view.stroke_color || UI::Color.new(r: 0.0, g: 0.0, b: 0.0)
        LibAndroidBridge.android_view_set_stroke(
          @env, v, view.stroke_width.to_f32, color_to_argb(stroke_color))
      end

      apply_common_properties(v, view)
      emit(v, "View[capsule]")
    end

    # Canvas: android.view.View sized to width/height.
    # Custom drawing requires a subclass (SurfaceView or custom View) in full
    # Android integration; here we establish the sized placeholder.
    def visit(view : UI::Canvas)
      v = LibAndroidBridge.android_view_new(@env, "android/view/View", @context)

      # Set content description with operation count for accessibility / testing
      unless view.operations.empty?
        desc = "canvas:#{view.operations.size}ops"
        LibAndroidBridge.android_view_set_content_description(
          @env, v, desc.to_unsafe, desc.bytesize)
      end

      apply_common_properties(v, view)
      emit(v, "View[canvas]")
    end

    # PathView: android.view.View sized to width/height.
    # SVG path data stored as content description for downstream processing.
    def visit(view : UI::PathView)
      v = LibAndroidBridge.android_view_new(@env, "android/view/View", @context)

      # Encode SVG path data in content description for accessibility / testing
      unless view.segments.empty?
        svg = view.to_svg_path
        LibAndroidBridge.android_view_set_content_description(
          @env, v, svg.to_unsafe, svg.bytesize)
      end

      # Stroke color as background approximation for outline visibility
      if view.stroke_width > 0.0
        LibAndroidBridge.android_view_set_stroke(
          @env, v, view.stroke_width.to_f32, color_to_argb(view.stroke_color))
      end

      apply_common_properties(v, view)
      emit(v, "View[path]")
    end

    def visit(view : UI::PathControl)
      ll = LibAndroidBridge.android_view_new(@env, "android/widget/LinearLayout", @context)
      LibAndroidBridge.android_linearlayout_set_orientation(@env, ll, 0)
      apply_common_properties(ll, view)

      global_ll = LibAndroidBridge.android_new_global_ref(@env, ll)
      handle = JNI.wrap_global(global_ll, label: "LinearLayout[path-control]")
      native = NativeView.new(handle)

      view.components.each_with_index do |component, index|
        tv = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
        LibAndroidBridge.android_textview_set_text(@env, tv, component.name.to_unsafe, component.name.bytesize)
        LibAndroidBridge.android_textview_set_text_color(@env, tv, 0xFF111111_u32.to_i32)
        tv_global = LibAndroidBridge.android_new_global_ref(@env, tv)
        tv_handle = JNI.wrap_global(tv_global, label: "TextView[path-control-segment]")
        tv_native = NativeView.new(tv_handle)
        native.add_child(tv_native)
        LibAndroidBridge.android_viewgroup_add_view(@env, ll, tv)

        next if index == view.components.size - 1

        chevron = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
        glyph = ">"
        LibAndroidBridge.android_textview_set_text(@env, chevron, glyph.to_unsafe, glyph.bytesize)
        LibAndroidBridge.android_textview_set_text_color(@env, chevron, 0xFF8E8E93_u32.to_i32)
        chevron_global = LibAndroidBridge.android_new_global_ref(@env, chevron)
        chevron_handle = JNI.wrap_global(chevron_global, label: "TextView[path-control-chevron]")
        chevron_native = NativeView.new(chevron_handle)
        native.add_child(chevron_native)
        LibAndroidBridge.android_viewgroup_add_view(@env, ll, chevron)
      end

      if view.style == UI::PathControlStyle::PopUp
        popup = LibAndroidBridge.android_view_new(@env, "android/widget/TextView", @context)
        glyph = "v"
        LibAndroidBridge.android_textview_set_text(@env, popup, glyph.to_unsafe, glyph.bytesize)
        LibAndroidBridge.android_textview_set_text_color(@env, popup, 0xFF8E8E93_u32.to_i32)
        popup_global = LibAndroidBridge.android_new_global_ref(@env, popup)
        popup_handle = JNI.wrap_global(popup_global, label: "TextView[path-control-popup]")
        popup_native = NativeView.new(popup_handle)
        native.add_child(popup_native)
        LibAndroidBridge.android_viewgroup_add_view(@env, ll, popup)
      end

      push_native(native, ll)
    end

    # MapView: android.view.View placeholder (com.google.android.gms.maps.MapView
    # requires Google Play Services; use content description for lat/lng/zoom).
    def visit(view : UI::MapView)
      v = LibAndroidBridge.android_view_new(@env, "android/view/View", @context)

      # Store map parameters in content description for testing
      desc = "map:#{view.map_type}:#{view.latitude},#{view.longitude}:z#{view.zoom_level}"
      LibAndroidBridge.android_view_set_content_description(
        @env, v, desc.to_unsafe, desc.bytesize)

      apply_common_properties(v, view)
      emit(v, "View[map]")
    end

    # ChartView: android.view.View placeholder (full chart rendering requires
    # MPAndroidChart or custom drawing; use content description for chart metadata).
    def visit(view : UI::ChartView)
      v = LibAndroidBridge.android_view_new(@env, "android/view/View", @context)

      # Store chart parameters in content description for testing
      chart_title = view.title.empty? ? "chart" : view.title
      desc = "chart:#{view.chart_type}:#{chart_title}:#{view.data_points.size}pts"
      LibAndroidBridge.android_view_set_content_description(
        @env, v, desc.to_unsafe, desc.bytesize)

      apply_common_properties(v, view)
      emit(v, "View[chart]")
    end

    # WebViewComponent: android.webkit.WebView placeholder.
    # android.webkit.WebView requires the WebKit library; use content description
    # for URL/settings for now.
    def visit(view : UI::WebViewComponent)
      v = LibAndroidBridge.android_view_new(@env, "android/view/View", @context)

      # Store URL in content description for accessibility and testing
      unless view.url.empty?
        LibAndroidBridge.android_view_set_content_description(
          @env, v, view.url.to_unsafe, view.url.bytesize)
      end

      apply_common_properties(v, view)
      emit(v, "View[webview]")
    end

    # ColorPicker: android.view.View placeholder for color selection UI.
    # Android's color picker is typically implemented via a custom dialog;
    # background color reflects the currently selected color.
    def visit(view : UI::ColorPicker)
      v = LibAndroidBridge.android_view_new(@env, "android/view/View", @context)

      # Show selected color as background
      LibAndroidBridge.android_view_set_background_color(
        @env, v, color_to_argb(view.selected_color))

      # Use label as content description
      unless view.label.empty?
        LibAndroidBridge.android_view_set_content_description(
          @env, v, view.label.to_unsafe, view.label.bytesize)
      end

      apply_common_properties(v, view)
      emit(v, "View[color-picker]")
    end

    # VideoPlayer: android.view.View placeholder (full integration uses
    # ExoPlayer or MediaPlayer with SurfaceView; content description holds URL).
    def visit(view : UI::VideoPlayer)
      v = LibAndroidBridge.android_view_new(@env, "android/view/View", @context)

      # Store URL in content description for accessibility and testing
      unless view.url.empty?
        LibAndroidBridge.android_view_set_content_description(
          @env, v, view.url.to_unsafe, view.url.bytesize)
      end

      apply_common_properties(v, view)
      emit(v, "View[video]")
    end

    # Tooltip: FrameLayout wrapping optional content with tooltip text stored
    # as content description (Android uses Tooltip API 26+ via setTooltipText).
    def visit(view : UI::Tooltip)
      # Use a FrameLayout so optional child content can be added
      container = LibAndroidBridge.android_view_new(
        @env, "android/widget/FrameLayout", @context)

      # Store tooltip text as content description
      unless view.text.empty?
        LibAndroidBridge.android_view_set_content_description(
          @env, container, view.text.to_unsafe, view.text.bytesize)
      end

      apply_common_properties(container, view)

      global_ptr = LibAndroidBridge.android_new_global_ref(@env, container)
      handle = JNI.wrap_global(global_ptr, label: "FrameLayout[tooltip]")
      native = NativeView.new(handle)

      if content = view.content
        push_stack(native, container, is_linear: false)
        content.accept(self)
        pop_stack
      end

      push_native(native, container)
    end

    # -----------------------------------------------------------------
    # Visit: ActivityView -> LinearLayout placeholder
    # Android uses Intent.ACTION_SEND / ShareCompat for sharing.
    # This renderer emits a LinearLayout stub so the abstract visit
    # contract is satisfied. Production apps should dispatch an Intent.
    # -----------------------------------------------------------------
    def visit(view : UI::ActivityView)
      container = LibAndroidBridge.android_view_new(
        @env, "android/widget/LinearLayout", @context)
      apply_common_properties(container, view)
      global_ptr = LibAndroidBridge.android_new_global_ref(@env, container)
      handle = JNI.wrap_global(global_ptr, label: "LinearLayout[activity-view]")
      native = NativeView.new(handle)
      push_native(native, container)
    end

    # -----------------------------------------------------------------
    # Visit: DisclosureGroup -> LinearLayout (vertical) containing:
    #   (1) header row LinearLayout with chevron TextView + title TextView
    #   (2) optional content LinearLayout when expanded = true
    #
    # Android has no native disclosure-triangle widget. The closest is
    # an ExpandableListView; for validation purposes a LinearLayout with
    # a right/down arrow Unicode glyph is sufficient. In production,
    # wire the header row OnClickListener to toggle visibility of the
    # content LinearLayout.
    # -----------------------------------------------------------------
    def visit(view : UI::DisclosureGroup)
      outer = LibAndroidBridge.android_view_new(
        @env, "android/widget/LinearLayout", @context)
      # VERTICAL orientation = 1
      LibAndroidBridge.android_linear_layout_set_orientation(@env, outer, 1)

      # Header row LinearLayout (horizontal = 0)
      header_row = LibAndroidBridge.android_view_new(
        @env, "android/widget/LinearLayout", @context)
      LibAndroidBridge.android_linear_layout_set_orientation(@env, header_row, 0)

      # Chevron glyph TextView
      chevron_tv = LibAndroidBridge.android_view_new(
        @env, "android/widget/TextView", @context)
      chevron_char = view.expanded ? "\u25BC" : "\u25B6"
      LibAndroidBridge.android_text_view_set_text(@env, chevron_tv, chevron_char.to_unsafe, chevron_char.bytesize)

      # Title TextView
      title_tv = LibAndroidBridge.android_view_new(
        @env, "android/widget/TextView", @context)
      LibAndroidBridge.android_text_view_set_text(@env, title_tv, view.title.to_unsafe, view.title.bytesize)

      # Accessibility: content description on header row
      acc_text = view.accessibility_label || "#{view.title}, #{view.expanded ? "expanded" : "collapsed"}"
      LibAndroidBridge.android_view_set_content_description(@env, header_row, acc_text.to_unsafe, acc_text.bytesize)

      LibAndroidBridge.android_view_group_add_child(@env, header_row, chevron_tv)
      LibAndroidBridge.android_view_group_add_child(@env, header_row, title_tv)
      LibAndroidBridge.android_view_group_add_child(@env, outer, header_row)

      # Content block (visible when expanded)
      if view.expanded && !view.content.empty?
        content_ll = LibAndroidBridge.android_view_new(
          @env, "android/widget/LinearLayout", @context)
        LibAndroidBridge.android_linear_layout_set_orientation(@env, content_ll, 1)

        global_content = LibAndroidBridge.android_new_global_ref(@env, content_ll)
        content_handle = JNI.wrap_global(global_content, label: "LinearLayout[disclosure-content]")
        content_native = NativeView.new(content_handle)

        push_stack(content_native, content_ll, is_linear: true)
        view.content.each do |child|
          child.accept(self)
        end
        pop_stack

        LibAndroidBridge.android_view_group_add_child(@env, outer, content_ll)
      end

      apply_common_properties(outer, view)
      global_ptr = LibAndroidBridge.android_new_global_ref(@env, outer)
      handle = JNI.wrap_global(global_ptr, label: "LinearLayout[disclosure-group]")
      native = NativeView.new(handle)
      push_native(native, outer)
    end

    # ================================================================
    # Private helpers
    # ================================================================

    # Pack a UI::Color (RGBA 0..1) into an Android ARGB packed int.
    # Android Color format: 0xAARRGGBB
    private def color_to_argb(color : UI::Color) : Int32
      a = (color.a * 255.0).round.to_i.clamp(0, 255)
      r = (color.r * 255.0).round.to_i.clamp(0, 255)
      g = (color.g * 255.0).round.to_i.clamp(0, 255)
      b = (color.b * 255.0).round.to_i.clamp(0, 255)
      ((a << 24) | (r << 16) | (g << 8) | b).to_i32
    end

    # Map a UI::Font to an Android Typeface style integer.
    # Typeface.NORMAL=0, Typeface.BOLD=1, Typeface.ITALIC=2, Typeface.BOLD_ITALIC=3
    private def typeface_style_for(font : UI::Font) : Int32
      is_bold = (font.weight == :bold || font.weight == :semibold)
      is_italic = font.italic
      case {is_bold, is_italic}
      when {true, true}   then 3 # BOLD_ITALIC
      when {true, false}  then 1 # BOLD
      when {false, true}  then 2 # ITALIC
      else                     0 # NORMAL
      end
    end

    # Apply common View base-class properties to an Android View local ref.
    #
    #   - hidden       -> setVisibility(GONE=8) or VISIBLE(0)
    #   - opacity      -> setAlpha(float)
    #   - background   -> setBackgroundColor(argb)
    #   - corner_radius -> setCornerRadius(dp) via outline provider
    #   - clip_to_bounds -> setClipToOutline(true)
    #   - shadow        -> setElevation(dp) -- Android uses elevation for shadow
    #   - border        -> setStroke(width, argb) via GradientDrawable
    #   - padding       -> setPadding(l, t, r, b) in pixels
    #   - accessibility -> setContentDescription
    private def apply_common_properties(v : Void*, view : UI::View) : Nil
      # Hidden: GONE removes from layout, INVISIBLE keeps space
      if view.hidden
        LibAndroidBridge.android_view_set_visibility(@env, v, 8) # GONE
      end

      # Opacity
      if view.opacity < 1.0
        LibAndroidBridge.android_view_set_alpha(@env, v, view.opacity.to_f32)
      end

      # Background color
      if bg = view.background
        LibAndroidBridge.android_view_set_background_color(@env, v, color_to_argb(bg))
      end

      # Corner radius (requires setClipToOutline)
      if view.corner_radius > 0.0
        LibAndroidBridge.android_view_set_corner_radius(@env, v, view.corner_radius.to_f32)
        LibAndroidBridge.android_view_set_clip_to_outline(@env, v, 1)
      end

      # Clip to bounds (independent of corner radius)
      if view.clip_to_bounds && view.corner_radius <= 0.0
        LibAndroidBridge.android_view_set_clip_to_outline(@env, v, 1)
      end

      # Shadow: Android uses elevation for drop shadows (API 21+).
      # shadow_radius maps to elevation in DP (approximation).
      if view.shadow_radius > 0.0
        LibAndroidBridge.android_view_set_elevation(@env, v, view.shadow_radius.to_f32)
      end

      # Border via GradientDrawable stroke
      if view.border_width > 0.0
        bc = view.border_color || UI::Color.new(r: 0.0, g: 0.0, b: 0.0)
        LibAndroidBridge.android_view_set_stroke(@env, v, view.border_width.to_f32, color_to_argb(bc))
      end

      # Padding (convert from Float64 to Int32 dp -> px is handled in the C bridge)
      p = view.padding
      if p.top != 0.0 || p.trailing != 0.0 || p.bottom != 0.0 || p.leading != 0.0
        LibAndroidBridge.android_view_set_padding(
          @env, v,
          p.leading.round.to_i,  # left
          p.top.round.to_i,
          p.trailing.round.to_i, # right
          p.bottom.round.to_i)
      end

      # Accessibility label -> contentDescription
      if a11y = view.accessibility_label
        LibAndroidBridge.android_view_set_content_description(
          @env, v, a11y.to_unsafe, a11y.bytesize)
      end

      # Test identifier -> contentDescription (used as test tag on Android)
      # Only set if accessibility_label was not already set, to avoid overwriting it
      if tid = view.test_id
        unless view.accessibility_label
          LibAndroidBridge.android_view_set_content_description(
            @env, v, tid.to_unsafe, tid.bytesize)
        end
      end
    end

    # Current local ref for the stack top (the raw JNI pointer for addView calls).
    # We need this because NativeHandle stores the global ref, but addView needs
    # the local ref during construction.
    @stack_local_ptrs : Array(Void*)

    def initialize(@env : Void*, @context : Void*)
      @stack = [] of NativeView
      @stack_is_linear = [] of Bool
      @stack_local_ptrs = [] of Void*
    end

    # Push a container NativeView onto the nesting stack, with its local ptr.
    private def push_stack(native : NativeView, local_ptr : Void*, is_linear : Bool) : Nil
      @stack.push(native)
      @stack_is_linear.push(is_linear)
      @stack_local_ptrs.push(local_ptr)
    end

    # Pop the top container from the nesting stack.
    private def pop_stack : Nil
      @stack.pop
      @stack_is_linear.pop
      @stack_local_ptrs.pop
    end

    # Wrap a local ref in a global NativeHandle + NativeView and emit it.
    # Standard path for leaf views (Label, Image) with no callbacks.
    private def emit(local_ptr : Void*, label : String) : Nil
      global_ptr = LibAndroidBridge.android_new_global_ref(@env, local_ptr)
      handle = JNI.wrap_global(global_ptr, label: label)
      native = NativeView.new(handle)
      push_native(native, local_ptr)
    end

    # Emit a Spacer with flex weight in a LinearLayout parent.
    # The Space widget gets weight=1 so it expands to fill available space.
    private def emit_spacer(local_ptr : Void*, min_length : Float64) : Nil
      global_ptr = LibAndroidBridge.android_new_global_ref(@env, local_ptr)
      handle = JNI.wrap_global(global_ptr, label: "Space[spacer]")
      native = NativeView.new(handle)

      if parent = @stack.last?
        parent.add_child(native)
        if parent.handle.valid?
          parent_local = @stack_local_ptrs.last?
          unless parent_local.nil? || parent_local.null?
            # Use weight=1 so the Space expands in a LinearLayout
            # WRAP_CONTENT = -2, MATCH_PARENT = -1
            min_px = min_length.round.to_i
            LibAndroidBridge.android_linearlayout_add_view_weight(
              @env, parent_local, local_ptr,
              min_px > 0 ? min_px : -2, # width: min or WRAP_CONTENT
              min_px > 0 ? min_px : -2, # height: min or WRAP_CONTENT
              1.0_f32)                   # weight: 1 (flex expand)
          end
        end
      else
        @result = native
      end
    end

    # Register a NativeView with the current parent container, or set it
    # as the root result if there is no parent.
    #
    # `local_ptr` is the JNI local ref for the view being registered.
    # It is needed for the addView call; the NativeView itself holds the global ref.
    private def push_native(native : NativeView, local_ptr : Void*) : Nil
      if parent = @stack.last?
        parent.add_child(native)

        parent_local = @stack_local_ptrs.last?
        unless parent_local.nil? || parent_local.null?
          if @stack_is_linear.last?
            # LinearLayout: WRAP_CONTENT for both dimensions by default
            LibAndroidBridge.android_viewgroup_add_view(@env, parent_local, local_ptr)
          else
            # FrameLayout (ZStack) or ScrollView: MATCH_PARENT to fill parent
            LibAndroidBridge.android_viewgroup_add_view_wh(
              @env, parent_local, local_ptr, -1, -1) # MATCH_PARENT
          end
        end
      else
        @result = native
      end
    end
  end
end
{% end %}
