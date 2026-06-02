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
        compose_stack(view.children, 0_i64, view.spacing, view.alignment)
      end

      def visit(view : UI::HStack)
        compose_stack(view.children, 1_i64, view.spacing, view.alignment)
      end

      private def compose_stack(children : Array(UI::View), axis : Int64,
                                spacing : Float64, align : UI::Alignment) : Nil
        kids = [] of UI::NativeView
        children.each do |c|
          if nv = render_child(c)
            kids << nv
          end
        end
        buf = child_buffer(kids)
        ptr = LibSwiftKitBridge.apsk_make_watch_stack(
          buf.as(Void*), kids.size.to_i32, axis, spacing, alignment_int(align),
        )
        emit(ptr)
      end

      # -------------------------------------------------------------------------
      # Long tail — fallback placeholders (upgraded to real facades incrementally).
      # Generated for every remaining abstract visit so the renderer compiles.
      # -------------------------------------------------------------------------
      {% for t in %w(
                    Button ZStack Image TextField ScrollView Spacer Toggle Checkbox RadioGroup
                    Slider NavigationStack NavigationLink TabView ProgressView
                    ActivityIndicator Alert Picker IconButton ListView OutlineView
                    SecureField Stepper SegmentedControl DatePicker TimePicker SearchField
                    TextArea Grid Form NavigationSplitView Toolbar Sheet Popover
                    ConfirmationDialog Snackbar Card Surface Divider GlassBackground
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
