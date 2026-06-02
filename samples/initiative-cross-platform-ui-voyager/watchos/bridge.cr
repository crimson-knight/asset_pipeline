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

    # A chat bubble: a Card wrapping a Label. Mirrors the iOS/macOS agent-chat
    # transcript so the wrist design is cohesive with the larger screens.
    private def self.bubble(text : String) : UI::View
      label = UI::Label.new(text)
      label.text_color_role = UI::LabelRole::Primary
      UI::Card.new(label.as(UI::View)).as(UI::View)
    end

    # Build a Crystal-authored agent-chat surface and render it on watch. Exercises
    # the freshly-wired facades: Card (bubbles), Divider, Toggle, IconButton — so the
    # on-device capture PROVES they render, not merely compile.
    def self.render : Void*
      initialize_runtime

      root = UI::VStack.new(spacing: 8.0)
      root.alignment = UI::Alignment::Leading

      title = UI::Label.new("Agent")
      title.font = UI::Font.new(size: 20.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary
      root << title.as(UI::View)

      # Transcript bubbles (Card facades). Kept to one line each so the full
      # Crystal-authored tree — bubbles + Divider + Toggle + IconButton — fits a
      # single watch screen for a deterministic capture.
      root << bubble("10:00 confirmed")

      root << UI::Divider.new.as(UI::View)

      # A settings row: Label + Toggle (HStack), proving the control facade.
      settings_row = UI::HStack.new(spacing: 6.0)
      settings_row.alignment = UI::Alignment::Center
      settings_row << UI::Label.new("Haptics").as(UI::View)
      settings_row << UI::Toggle.new("", true).as(UI::View)
      root << settings_row.as(UI::View)

      # Compose row: a hint Label + a paperplane IconButton.
      compose = UI::HStack.new(spacing: 6.0)
      compose.alignment = UI::Alignment::Center
      compose << UI::Label.new("Reply…").as(UI::View)
      send = UI::IconButton.new("paperplane.fill")
      send.accessibility_label = "Send reply"
      compose << send.as(UI::View)
      root << compose.as(UI::View)

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
