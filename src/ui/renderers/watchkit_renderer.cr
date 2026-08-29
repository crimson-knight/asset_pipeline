# watchOS / WatchKit platform renderer. Walks a UI::View tree and produces a
# SwiftUI hierarchy via the AssetPipelineSwiftKit facades, composed declaratively
# through the APSKWatchHostView boundary node (which carries each subtree's SwiftUI
# `.content`). Unlike the AppKit/UIKit renderers — which build NSStackView/UIStackView
# imperatively — watchOS has no imperative stack host, so containers compose via
# `apsk_make_watch_stack` (see WatchStackFacade.swift + the foundational-output-and-
# layout-model.md §"Principle 3").
#
# STATUS: skeleton (renderer brick 3). The core leaves + stacks are wired to the real
# facades; the long tail of view types falls back to a labelled placeholder so the
# renderer compiles + renders SOMETHING for every view. Each fallback is upgraded to
# its real facade incrementally (brick 4+).

{% if flag?(:watchos) %}
  require "../platform_visitor"
  require "../native/native_handle"
  require "../native/native_view"
  require "../native/callback_registry"
  require "../native/swiftkit_bridge"
  require "../native/swiftkit_overrides"
  require "../design_tokens"

  module UI::WatchKit
    # WatchKit renderer — a PlatformVisitor that emits APSKWatchHostView boxes.
    class Renderer < PlatformVisitor
      @result : UI::NativeView?
      @runtime_installed : Bool = false

      def initialize(@design_tokens : UI::DesignTokens::Tokens = UI::DesignTokens::Tokens.default)
        install_device_provider
      end

      # Install a watchOS Device metrics provider so screens that query
      # `UI::DesignTokens::DeviceMetrics.current` (the shared, adaptive screen
      # authoring path used on macOS + iOS) reflow to the WATCH canvas instead of
      # the 390pt iPhone fallback. Mirrors the UIKit/AppKit renderers, which each
      # install an OS-querying provider in their initializer.
      #
      # Conservative static watch-class snapshot (compact horizontal + vertical,
      # ~176pt usable width) that fits every current watch size from 40mm (162pt)
      # up; per-device-exact bounds via a WKInterfaceDevice trampoline is a
      # follow-up refinement. The point is the size-CLASS + width-ORDER are now
      # watch-correct, so `responsive(...)` picks compact values and content-width
      # clamps to the small screen — the whole layout reflows.
      private def install_device_provider : Nil
        UI::DesignTokens::Device.install_provider do
          UI::DesignTokens::DeviceMetrics.new(
            screen_width_pt: 176.0,
            screen_height_pt: 215.0,
            # watchOS overlays the system clock at the top of every app; reserve
            # headroom so screen content (e.g. a title) starts below it.
            safe_area_top_pt: 22.0,
            safe_area_bottom_pt: 0.0,
            safe_area_leading_pt: 0.0,
            safe_area_trailing_pt: 0.0,
            horizontal_size_class: UI::DesignTokens::SizeClass::Compact,
            vertical_size_class: UI::DesignTokens::SizeClass::Compact,
          )
        end
      end

      # Entry point: walk the tree, return the root box's NativeView.
      def render(view : UI::View) : UI::NativeView
        ensure_runtime!
        view.accept(self)
        @result.not_nil!
      end

      private def ensure_runtime! : Nil
        unless @runtime_installed
          LibSwiftKitBridge.apsk_runtime_install_default_action_trampoline
          @runtime_installed = true
        end
      end

      # Wrap a +1 APSKWatchHostView pointer and set it as the current result.
      private def emit(ptr : Void*) : Nil
        handle = ObjC.owned(ptr, label: "APSKWatchHostView")
        @result = UI::NativeView.new(handle)
      end

      # Render a child subtree to its own box without disturbing the current result.
      private def render_child(view : UI::View) : UI::NativeView?
        saved = @result
        @result = nil
        view.accept(self)
        child = @result
        @result = saved
        child
      end

      # Pack child box pointers into a flat buffer for apsk_make_watch_stack.
      private def child_buffer(natives : Array(UI::NativeView)) : Pointer(Void*)
        size = natives.size == 0 ? 1_u64 : natives.size.to_u64
        buf = Pointer(Void*).malloc(size)
        natives.each_with_index { |nv, i| buf[i] = nv.handle.ptr! }
        buf
      end

      # 0 = leading/top, 1 = center, 2 = trailing/bottom.
      private def alignment_int(a : UI::Alignment) : Int64
        case a
        when UI::Alignment::Leading, UI::Alignment::Top    then 0_i64
        when UI::Alignment::Trailing, UI::Alignment::Bottom then 2_i64
        else                                                    1_i64
        end
      end

      # A labelled placeholder for not-yet-wired view types.
      private def fallback(name : String) : Nil
        o = LibSwiftKitBridge.apsk_label_overrides_new
        text = "[#{name}]"
        emit(LibSwiftKitBridge.apsk_make_label(text.to_unsafe, o))
      end

      # -------------------------------------------------------------------------
      # Core leaves
      # -------------------------------------------------------------------------
      def visit(view : UI::Label)
        o = LibSwiftKitBridge.apsk_label_overrides_new
        sender = UI::Native::SwiftKitObjCSender.new(o)
        UI::Native::Populator.populate_label(o.address.to_s(16), view, sender)
        text = view.text
        emit(LibSwiftKitBridge.apsk_make_label(text.to_unsafe, o))
      end

      # -------------------------------------------------------------------------
      # Core containers — declarative VStack/HStack via apsk_make_watch_stack
      # -------------------------------------------------------------------------
      def visit(view : UI::VStack)
        compose_stack(view, 0_i64, view.spacing, view.alignment)
      end

      def visit(view : UI::HStack)
        compose_stack(view, 1_i64, view.spacing, view.alignment)
      end

      private def compose_stack(view : UI::View, axis : Int64,
                                spacing : Float64, align : UI::Alignment) : Nil
        children = view.is_a?(UI::VStack) ? view.children : view.as(UI::HStack).children
        kids = [] of UI::NativeView
        children.each do |c|
          if nv = render_child(c)
            kids << nv
          end
        end
        buf = child_buffer(kids)
        # Populate the common view overrides (padding, min/max width + height,
        # background, opacity, border, shadow, accessibility) so the watch stack
        # honors the same adaptive layout props the imperative UIKit/AppKit stacks
        # apply. Without this VStack/HStack dropped root padding + content-width pins
        # and shared screens could not reflow to the watch.
        o = LibSwiftKitBridge.apsk_view_overrides_new
        sender = UI::Native::SwiftKitObjCSender.new(o)
        UI::Native::Populator.populate_view_common(o.address.to_s(16), view, sender)
        # root_fill: the root container should fill the watch canvas and top-align so
        # content packs from the top and any inter-section Spacer expands to pin the
        # compose/action row to the bottom (the messaging-app rhythm). Other renderers
        # special-case root_fill (UIKit/AppKit/web); the watch honors it via the facade.
        ptr = LibSwiftKitBridge.apsk_make_watch_stack(
          buf.as(Void*), kids.size.to_i32, axis, spacing, alignment_int(align), o,
          view.root_fill ? 1 : 0,
        )
        emit(ptr)
      end

      # -------------------------------------------------------------------------
      # Core leaves wired to real facades (Button / Image / TextField).
      # -------------------------------------------------------------------------
      def visit(view : UI::Button)
        o = LibSwiftKitBridge.apsk_button_overrides_new
        sender = UI::Native::SwiftKitObjCSender.new(o)
        UI::Native::Populator.populate_button(o.address.to_s(16), view, sender)
        token = 0_u64
        if handler = view.on_tap
          token = UI::CallbackRegistry.register_action(&handler)
        end
        label = view.label
        emit(LibSwiftKitBridge.apsk_make_button(label.to_unsafe, o, token))
      end

      def visit(view : UI::Image)
        o = LibSwiftKitBridge.apsk_image_overrides_new
        sender = UI::Native::SwiftKitObjCSender.new(o)
        UI::Native::Populator.populate_image(o.address.to_s(16), view, sender)
        src = view.source
        emit(LibSwiftKitBridge.apsk_make_image(src.to_unsafe, o))
      end

      def visit(view : UI::TextField)
        o = LibSwiftKitBridge.apsk_text_field_overrides_new
        sender = UI::Native::SwiftKitObjCSender.new(o)
        UI::Native::Populator.populate_text_field(o.address.to_s(16), view, sender)
        token = 0_u64
        if wrapped = UI::FormStateRendererHook.wrap_text_handler(view)
          token = UI::CallbackRegistry.register_string(wrapped)
        end
        placeholder = view.placeholder
        text = view.text
        emit(LibSwiftKitBridge.apsk_make_text_field(placeholder.to_unsafe, text.to_unsafe, o, token))
      end

      # -------------------------------------------------------------------------
      # Surfaces & layout helpers wired to real facades.
      # -------------------------------------------------------------------------
      def visit(view : UI::Card)
        compose_container(view.content, LibSwiftKitBridge.apsk_card_overrides_new) do |o, sender|
          UI::Native::Populator.populate_card(o.address.to_s(16), view, sender)
        end
      end

      def visit(view : UI::Surface)
        compose_container(view.content, LibSwiftKitBridge.apsk_surface_overrides_new) do |o, sender|
          UI::Native::Populator.populate_surface(o.address.to_s(16), view, sender)
        end
      end

      # Card/Surface share the (single optional content child) shape — render
      # the child to its own box, pack a 1-element buffer, call the facade.
      private def compose_container(content : UI::View?, overrides : Void*, kind : String = "card", &)
        sender = UI::Native::SwiftKitObjCSender.new(overrides)
        yield overrides, sender
        kids = [] of UI::NativeView
        if c = content
          if nv = render_child(c)
            kids << nv
          end
        end
        buf = child_buffer(kids)
        ptr = if kind == "surface"
                LibSwiftKitBridge.apsk_make_surface(buf.as(Void*), kids.size.to_i32, overrides)
              else
                LibSwiftKitBridge.apsk_make_card(buf.as(Void*), kids.size.to_i32, overrides)
              end
        emit(ptr)
      end

      # NOTE: GlassBackground + SegmentedControl are deliberately NOT wired here —
      # their @objc facade classes live inside `#if !os(watchOS)` (whole-class gate),
      # so they do not exist on watchOS (Bucket 3, no honest watch analog). Calling
      # apsk_make_* for them would hit objc_getClass(nil) → crash. They route through
      # the fallback macro below. The authoritative rule when promoting a fallback:
      # only wire a facade whose `@objc(...)` line sits OUTSIDE any whole-class
      # `#if !os(watchOS)` guard (inner per-modifier guards are fine).

      def visit(view : UI::Divider)
        o = LibSwiftKitBridge.apsk_divider_overrides_new
        sender = UI::Native::SwiftKitObjCSender.new(o)
        UI::Native::Populator.populate_divider(o.address.to_s(16), view, sender)
        emit(LibSwiftKitBridge.apsk_make_divider(o))
      end

      def visit(view : UI::Spacer)
        o = LibSwiftKitBridge.apsk_spacer_overrides_new
        sender = UI::Native::SwiftKitObjCSender.new(o)
        UI::Native::Populator.populate_spacer(o.address.to_s(16), view, sender)
        emit(LibSwiftKitBridge.apsk_make_spacer(o))
      end

      # -------------------------------------------------------------------------
      # Controls wired to real facades (Toggle / Slider / Stepper / IconButton).
      # Non-reactive variants: a watch render is rebuilt wholesale on state
      # change (no in-place reconciliation channel wired yet), so the simpler
      # trampolines suffice.
      # -------------------------------------------------------------------------
      def visit(view : UI::Toggle)
        o = LibSwiftKitBridge.apsk_toggle_overrides_new
        sender = UI::Native::SwiftKitObjCSender.new(o)
        UI::Native::Populator.populate_toggle(o.address.to_s(16), view, sender)
        token = 0_u64
        if handler = view.on_change
          token = UI::CallbackRegistry.register_action_with_value { |v| handler.call(v != 0.0) }
        end
        emit(LibSwiftKitBridge.apsk_make_toggle(view.label.to_unsafe, view.is_on ? 1 : 0, o, token))
      end

      def visit(view : UI::Slider)
        o = LibSwiftKitBridge.apsk_slider_overrides_new
        sender = UI::Native::SwiftKitObjCSender.new(o)
        UI::Native::Populator.populate_slider(o.address.to_s(16), view, sender)
        token = 0_u64
        if handler = view.on_change
          token = UI::CallbackRegistry.register_action_with_value { |v| handler.call(v) }
        end
        emit(LibSwiftKitBridge.apsk_make_slider(view.value, view.minimum, view.maximum, o, token))
      end

      def visit(view : UI::Stepper)
        o = LibSwiftKitBridge.apsk_stepper_overrides_new
        sender = UI::Native::SwiftKitObjCSender.new(o)
        UI::Native::Populator.populate_stepper(o.address.to_s(16), view, sender)
        token = 0_u64
        if handler = view.on_change
          token = UI::CallbackRegistry.register_action_with_value { |v| handler.call(v) }
        end
        emit(LibSwiftKitBridge.apsk_make_stepper(view.label.to_unsafe, view.value, view.minimum, view.maximum, o, token))
      end

      def visit(view : UI::IconButton)
        o = LibSwiftKitBridge.apsk_icon_button_overrides_new
        sender = UI::Native::SwiftKitObjCSender.new(o)
        UI::Native::Populator.populate_icon_button(o.address.to_s(16), view, sender)
        token = 0_u64
        if handler = view.on_tap
          token = UI::CallbackRegistry.register_action(&handler)
        end
        emit(LibSwiftKitBridge.apsk_make_icon_button(view.icon.to_unsafe, o, token))
      end

      # SecureField — mirrors TextField; register on the STRING channel so the real
      # typed cleartext reaches FormState (the numeric-channel bug dropped passwords).
      def visit(view : UI::SecureField)
        o = LibSwiftKitBridge.apsk_secure_field_overrides_new
        sender = UI::Native::SwiftKitObjCSender.new(o)
        UI::Native::Populator.populate_secure_field(o.address.to_s(16), view, sender)
        token = 0_u64
        if wrapped = UI::FormStateRendererHook.wrap_secure_handler(view)
          token = UI::CallbackRegistry.register_string(wrapped)
        end
        emit(LibSwiftKitBridge.apsk_make_secure_field(view.placeholder.to_unsafe, view.text.to_unsafe, o, token))
      end

      def visit(view : UI::Picker)
        o = LibSwiftKitBridge.apsk_picker_overrides_new
        sender = UI::Native::SwiftKitObjCSender.new(o)
        UI::Native::Populator.populate_picker(o.address.to_s(16), view, sender)
        token = 0_u64
        if handler = view.on_change
          token = UI::CallbackRegistry.register_action_with_value { |v| handler.call(v.to_i32) }
        end
        buf = string_buffer(view.options)
        emit(LibSwiftKitBridge.apsk_make_picker(
          view.label.to_unsafe, buf.as(Void*), view.options.size.to_i32,
          view.selected_index.to_i32, o, token))
      end

      # Pack a String array into a UInt8** buffer for the option facade.
      private def string_buffer(strings : Array(String)) : Pointer(UInt8*)
        size = strings.size == 0 ? 1_u64 : strings.size.to_u64
        buf = Pointer(UInt8*).malloc(size)
        strings.each_with_index { |s, i| buf[i] = s.to_unsafe }
        buf
      end

      # -------------------------------------------------------------------------
      # Long tail — fallback placeholders (upgraded to real facades incrementally).
      # Generated for every remaining abstract visit so the renderer compiles.
      # -------------------------------------------------------------------------
      {% for t in %w(
                    ZStack ScrollView Checkbox RadioGroup
                    NavigationStack NavigationLink TabView ProgressView
                    ActivityIndicator Alert ListView OutlineView
                    DatePicker TimePicker SearchField SegmentedControl GlassBackground
                    TextArea Grid Form NavigationSplitView Toolbar Sheet Popover
                    ConfirmationDialog Snackbar
                    AsyncImage RichText LinkButton MenuButton ContextMenu ToggleButton
                    TextEditor Circle Rectangle RoundedRectangle Capsule Canvas PathView
                    PathControl Complication MapView ChartView WebViewComponent ColorPicker
                    VideoPlayer Tooltip ActivityView DisclosureGroup PageControl ComboBox
                    RatingIndicator ActionSheet ActionSheetWithWebFallback
                    ContextMenuWithWebFallback PathControlWithWebFallback SwipeActionRow
                    InlineActionRow AndroidSwipeActionRow FullScreenCover Inspector
                    ToolbarItemGroup ToolbarSpacer
                  ) %}
        def visit(view : UI::{{t.id}})
          fallback({{t}})
        end
      {% end %}
    end
  end
{% end %}
