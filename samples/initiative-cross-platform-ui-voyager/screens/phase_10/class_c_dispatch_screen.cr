module Voyager
  # Phase 10D exerciser — `UI::Intent.dispatch` (Class C) proof.
  #
  # Demonstrates the Phase 10B.3.x Class C dispatch substrate by firing
  # 5 distinct Class C intents through `UI::Intent.dispatch` and
  # surfacing the returned `DispatchResult` to the screen. Each button
  # runs one dispatch, stores the result in
  # `Phase10ExerciserState.last_dispatch_result`, and trips a
  # Rerender so the result label updates.
  #
  # Intents wired:
  #
  #   * `:copy_to_clipboard`        — writes a literal string to the
  #                                    system pasteboard.
  #   * `:paste_from_clipboard`     — reads from the pasteboard via a
  #                                    callback token registered against
  #                                    `UI::Intent::CallbackRegistry`.
  #   * `:open_url`                 — asks the OS to open
  #                                    `https://example.com`.
  #   * `:print`                    — invokes the print subsystem
  #                                    (UIPrintInteractionController on
  #                                    iOS) with a literal text payload.
  #   * `:request_permission`       — requests notification permission.
  #
  # The "Paste from clipboard" button additionally registers a
  # `UI::Intent::CallbackRegistry` string-callback so the pasted value
  # round-trips into the visible "Last paste" label.
  class ClassCDispatchScreen < UI::Screen
    SLUG = "voyager-phase-10-class-c-dispatch"

    def build(context : UI::ScreenContext) : UI::View
      metrics = UI::DesignTokens::DeviceMetrics.current
      content_width = metrics.compact_horizontal? ? 340.0 : 480.0

      root = UI::VStack.new(spacing: 12.0)
      root.root_fill = true
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(
        top: 24.0 + metrics.safe_area_top_pt,
        trailing: 20.0 + metrics.safe_area_trailing_pt,
        bottom: 24.0 + metrics.safe_area_bottom_pt,
        leading: 20.0 + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Phase 10 — Class C dispatch exerciser"
      root.test_id = "phase-10-class-c-dispatch-root"

      title = UI::Label.new("Class C Dispatch")
      title.font = UI::Font.new(size: 24.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary

      hint = UI::Label.new(
        "Each button fires UI::Intent.dispatch(:intent). The result label\nshows DispatchResult.success / unsupported / failed."
      )
      hint.font = UI::Font.new(size: 12.0, weight: :regular)
      hint.text_color_role = UI::LabelRole::Secondary

      last_intent_label = UI::Label.new(
        "Last dispatched: " + Phase10ExerciserState.last_dispatched_intent
      )
      last_intent_label.font = UI::Font.new(size: 13.0, weight: :semibold)
      last_intent_label.text_color_role = UI::LabelRole::Primary
      last_intent_label.test_id = "phase-10-class-c-last-intent"

      result_label = UI::Label.new(
        "Result: " + Phase10ExerciserState.last_dispatch_result
      )
      result_label.font = UI::Font.new(size: 13.0, weight: :regular)
      result_label.text_color_role = UI::LabelRole::Secondary
      result_label.test_id = "phase-10-class-c-last-result"

      paste_label = UI::Label.new(
        "Last paste: " + Phase10ExerciserState.last_paste_value
      )
      paste_label.font = UI::Font.new(size: 13.0, weight: :regular)
      paste_label.text_color_role = UI::LabelRole::Secondary
      paste_label.test_id = "phase-10-class-c-last-paste"

      root << title.as(UI::View)
      root << hint.as(UI::View)
      root << last_intent_label.as(UI::View)
      root << result_label.as(UI::View)
      root << paste_label.as(UI::View)

      # --- Buttons ---
      copy_btn = make_button("Copy 'Hello, asset_pipeline!'", "phase-10-class-c-copy", content_width)
      copy_btn.on_tap = -> {
        result = UI::Intent.dispatch(:copy_to_clipboard, value: "Hello, asset_pipeline!")
        Phase10ExerciserState.last_dispatched_intent = ":copy_to_clipboard"
        Phase10ExerciserState.last_dispatch_result = Phase10ExerciserState.format_result(result)
        Voyager.dispatch(:phase_10_class_c_dispatched)
      }

      paste_btn = make_button("Paste from clipboard", "phase-10-class-c-paste", content_width)
      paste_btn.on_tap = -> {
        paste_cb = ->(pasted : String) {
          Phase10ExerciserState.last_paste_value = pasted.empty? ? "(empty)" : pasted
          nil
        }
        token = UI::CallbackRegistry.register_string(paste_cb)
        result = UI::Intent.dispatch(:paste_from_clipboard, on_paste: token.to_s)
        Phase10ExerciserState.last_dispatched_intent = ":paste_from_clipboard"
        Phase10ExerciserState.last_dispatch_result = Phase10ExerciserState.format_result(result)
        Voyager.dispatch(:phase_10_class_c_dispatched)
      }

      open_url_btn = make_button("Open https://example.com", "phase-10-class-c-open-url", content_width)
      open_url_btn.on_tap = -> {
        result = UI::Intent.dispatch(:open_url, url: "https://example.com")
        Phase10ExerciserState.last_dispatched_intent = ":open_url"
        Phase10ExerciserState.last_dispatch_result = Phase10ExerciserState.format_result(result)
        Voyager.dispatch(:phase_10_class_c_dispatched)
      }

      print_btn = make_button("Print sample text", "phase-10-class-c-print", content_width)
      print_btn.on_tap = -> {
        result = UI::Intent.dispatch(:print,
          text: "Phase 10D exerciser — print sample",
          job_name: "Phase 10 Exerciser",
        )
        Phase10ExerciserState.last_dispatched_intent = ":print"
        Phase10ExerciserState.last_dispatch_result = Phase10ExerciserState.format_result(result)
        Voyager.dispatch(:phase_10_class_c_dispatched)
      }

      perm_btn = make_button("Request notification permission", "phase-10-class-c-permission", content_width)
      perm_btn.on_tap = -> {
        result = UI::Intent.dispatch(:request_permission, permission: "notifications")
        Phase10ExerciserState.last_dispatched_intent = ":request_permission"
        Phase10ExerciserState.last_dispatch_result = Phase10ExerciserState.format_result(result)
        Voyager.dispatch(:phase_10_class_c_dispatched)
      }

      root << copy_btn.as(UI::View)
      root << paste_btn.as(UI::View)
      root << open_url_btn.as(UI::View)
      root << print_btn.as(UI::View)
      root << perm_btn.as(UI::View)

      back = UI::Button.new("Back to Phase 10 hub")
      back.role = :secondary
      back.accessibility_label = "Back to Phase 10 hub"
      back.test_id = "phase-10-class-c-back"
      back.minimum_width = content_width
      back.maximum_width = content_width
      back.on_tap = -> { Voyager.dispatch(:back) }
      root << back.as(UI::View)

      root.as(UI::View)
    end

    private def make_button(label : String, test_id : String, width : Float64) : UI::Button
      btn = UI::Button.new(label, style: UI::ButtonStyle::Prominent)
      btn.accessibility_label = label
      btn.test_id = test_id
      btn.minimum_width = width
      btn.maximum_width = width
      btn
    end
  end
end
