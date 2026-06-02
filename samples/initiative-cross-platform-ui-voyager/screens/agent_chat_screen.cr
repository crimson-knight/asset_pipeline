module Voyager
  # Voyager — Agent Chat screen (the cross-platform "talk to your agent" surface).
  #
  # This is the SAME surface the watchOS app renders (see
  # `samples/.../watchos/Sources/ContentView.swift`), authored here as a Crystal
  # `UI::Screen` so it renders natively on macOS + iOS through the platform renderer.
  # On watch the same composition is driven from Swift facades (the Crystal
  # UI::WatchKit::Renderer is blocked on a compiler fix) — so one design appears on
  # all three platforms. Both-axes adaptive via DeviceMetrics#responsive /
  # #responsive_vertical, matching the rest of the app.
  class AgentChatScreen < UI::Screen
    SLUG = "voyager-agent-chat"

    def build(context : UI::ScreenContext) : UI::View
      # The transcript lives in Voyager::State and grows when the user taps Send
      # (SendController appends a user message + a canned agent reply, then Rerender
      # rebuilds this screen from the new state). agent messages lead-align, the
      # user's replies trail-align.
      messages = Voyager.state.chat_messages

      metrics = UI::DesignTokens::DeviceMetrics.current
      content_width = metrics.responsive(compact: 340.0, regular: 460.0)
      bubble_w = content_width - 64.0
      pad_h = metrics.responsive(compact: 16.0, regular: 24.0)
      pad_v = metrics.responsive_vertical(compact: 16.0, regular: 28.0)

      root = UI::VStack.new(spacing: metrics.responsive_vertical(compact: 10.0, regular: 14.0))
      root.root_fill = true
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(
        top: pad_v + metrics.safe_area_top_pt,
        trailing: pad_h + metrics.safe_area_trailing_pt,
        bottom: pad_v + metrics.safe_area_bottom_pt,
        leading: pad_h + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Voyager agent chat"
      root.test_id = "voyager-agent-chat-root"

      title = UI::Label.new("Agent")
      title.font = UI::Font.new(size: metrics.responsive(compact: 26.0, regular: 30.0), weight: :bold)
      title.text_color_role = UI::LabelRole::Primary
      title.maximum_width = content_width
      root << title.as(UI::View)

      messages.each_with_index do |msg, i|
        root << bubble_row(msg.text, msg.is_agent, content_width, bubble_w, i)
      end

      # Collect the slack so the transcript packs to the top and the compose row
      # settles near the bottom — the messaging-app rhythm, instead of the bubbles
      # spreading evenly down a tall window.
      root << UI::Spacer.new.as(UI::View)

      # Compose row: a TextField to type a reply + a paperplane send IconButton.
      compose = UI::HStack.new(spacing: 8.0)
      compose.alignment = UI::Alignment::Center
      compose.minimum_width = content_width
      compose.maximum_width = content_width

      field = UI::TextField.new(placeholder: "Message your agent…", name: "chat_message")
      field.accessibility_label = "Message your agent"
      field.test_id = "voyager-agent-chat-input"
      field.minimum_width = content_width - 52.0
      field.maximum_width = content_width - 52.0

      send = UI::IconButton.new("paperplane.fill")
      send.accessibility_label = "Send message"
      send.test_id = "voyager-agent-chat-send"
      send.on_tap = -> { Voyager.dispatch(:send_message) }

      compose << field.as(UI::View)
      compose << send.as(UI::View)
      root << compose.as(UI::View)

      back = UI::Button.new("Back")
      back.role = :secondary
      back.accessibility_label = "Back"
      back.test_id = "voyager-agent-chat-back"
      back.minimum_width = content_width
      back.maximum_width = content_width
      back.on_tap = -> { Voyager.dispatch(:back) }
      root << back.as(UI::View)

      root.as(UI::View)
    end

    # One chat bubble: a Card wrapping a Label, pushed to the leading edge (agent)
    # or the trailing edge (user) by a Spacer in a content-width HStack.
    private def bubble_row(text : String, is_agent : Bool, content_width : Float64, bubble_w : Float64, i : Int32) : UI::View
      label = UI::Label.new(text)
      label.font = UI::Font.new(size: 15.0, weight: :regular)
      label.text_color_role = is_agent ? UI::LabelRole::Primary : UI::LabelRole::Secondary
      # Chat text must WRAP, not truncate, inside the fixed-width Card bubble. The
      # proven macOS-wrapping pattern (welcome lede) is an EXACT width (min == max),
      # which makes NSTextField wrap to fill rather than single-line-truncate;
      # preferred_max_layout_width covers the UIKit multi-line intrinsic size.
      label.minimum_width = bubble_w - 24.0
      label.maximum_width = bubble_w - 24.0
      label.preferred_max_layout_width = bubble_w - 24.0

      card = UI::Card.new(label.as(UI::View))
      card.maximum_width = bubble_w
      card.test_id = "voyager-agent-chat-msg-#{i}"

      row = UI::HStack.new(spacing: 0.0)
      row.minimum_width = content_width
      row.maximum_width = content_width
      if is_agent
        row.alignment = UI::Alignment::Leading
        row << card.as(UI::View)
        row << UI::Spacer.new.as(UI::View)
      else
        row.alignment = UI::Alignment::Trailing
        row << UI::Spacer.new.as(UI::View)
        row << card.as(UI::View)
      end
      row.as(UI::View)
    end
  end
end
