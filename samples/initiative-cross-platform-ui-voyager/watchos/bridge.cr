# Voyager watchOS bridge — the Crystal entry point the watch app calls to render a
# Crystal-authored UI::View tree through UI::WatchKit::Renderer (mirrors the iOS
# bridge.cr pattern). Exposes a C ABI:
#
#   void* voyager_watch_render(void)
#       — builds a UI::View tree, renders it via UI::WatchKit::Renderer, and returns
#         the retained root APSKWatchHostView* (the Swift side reads its `.content`
#         and embeds it). The pointer is +1-retained; Swift takes ownership.
#
# This is what makes the watch a first-class CRYSTAL target: the same UI::View API
# used on macOS/iOS, walked into SwiftUI by the watch renderer.
{% if flag?(:watchos) %}
  require "../../../src/ui"

  module VoyagerWatchBridge
    # iOS class-init gap also affects watchOS (Swift @main hides _main, so class-var
    # initializers + Crystal::once tables don't run). NONE of these carry side-effect
    # initializers; we explicitly bootstrap in `initialize_runtime`.
    @@initialized = false
    @@root : UI::NativeView? = nil

    def self.initialize_runtime : Nil
      return if @@initialized
      GC.init
      # Bring up the runtime subsystems __crystal_main normally initializes but the
      # watch embedding skips (Thread/Fiber/Once) — see project_crystal_ios_class_init_gap.
      Thread.init
      Fiber.init
      Crystal::Once.init
      @@initialized = true
    end

    # Build a small Crystal-authored agent-chat-style tree and render it on watch.
    def self.render : Void*
      initialize_runtime

      root = UI::VStack.new(spacing: 8.0)
      root.alignment = UI::Alignment::Leading

      title = UI::Label.new("Agent")
      title.font = UI::Font.new(size: 20.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary
      root << title.as(UI::View)

      root << UI::Label.new("Crystal on the wrist").as(UI::View)
      root << UI::Label.new("Meeting moved to 10:00.").as(UI::View)

      send = UI::Button.new("Reply")
      send.accessibility_label = "Reply"
      root << send.as(UI::View)

      renderer = UI::WatchKit::Renderer.new
      native = renderer.render(root.as(UI::View))
      @@root = native # pin against GC across the Swift round-trip
      native.handle.ptr!
    end
  end

  fun voyager_watch_render : Void*
    VoyagerWatchBridge.render
  end
{% end %}
