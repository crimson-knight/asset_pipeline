module Voyager
  # Voyager — Todos screen.
  #
  # Anatomy:
  #   VStack
  #     HStack [title="Todos", spacer, settings button]
  #     HStack [chart-like row: open count + completed count]
  #     ListView (or VStack of SwipeActionRow per visible todo)
  #     Button "Add Todo"
  #
  # State propagation litmus: when Settings toggles hide_completed
  # and pops, the host rebuilds THIS screen with state.visible_todos
  # (which filters out completed ones) and the open/completed
  # counts reflect the same.
  module TodosScreen
    extend self

    SLUG = "voyager-todos"

    def build(state : State, coord : UI::NavigationCoordinator) : UI::View
      # Phase 6.10 Rem 4 (Item 2D/2E) — device-aware sizing.
      #
      # OUTER root uses `root_fill = true` so iOS / macOS / web sizes
      # the container to the live device bounds. Inner full-width rows
      # still carry an explicit `content_width` cap so HStack-with-
      # Spacer rows don't collapse to intrinsic content on iOS.
      metrics = UI::DesignTokens::DeviceMetrics.current
      content_width = metrics.compact_horizontal? ? 340.0 : 480.0

      root = UI::VStack.new(spacing: 16.0)
      root.root_fill = true
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(
        top: 24.0 + metrics.safe_area_top_pt,
        trailing: 20.0 + metrics.safe_area_trailing_pt,
        bottom: 24.0 + metrics.safe_area_bottom_pt,
        leading: 20.0 + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Voyager todos screen"
      root.test_id = "voyager-todos-root"

      # Header row: title + settings link
      header = UI::HStack.new(spacing: 8.0)
      header.alignment = UI::Alignment::Center
      header.minimum_width = content_width
      header.maximum_width = content_width

      title = UI::Label.new("Todos")
      title.font = UI::Font.new(size: 28.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary

      spacer = UI::Spacer.new

      settings_btn = UI::Button.new("Settings")
      settings_btn.role = :secondary
      settings_btn.accessibility_label = "Settings"
      settings_btn.test_id = "voyager-todos-settings"
      settings_btn.on_tap = -> {
        Voyager.log_interaction("todos settings button tapped")
        coord.push(UI::NavigationCoordinator::Route.new(:settings))
      }

      header << title.as(UI::View)
      header << spacer.as(UI::View)
      header << settings_btn.as(UI::View)

      # Chart-like row: open + completed counts. Reads state.open_count
      # and state.completed_count, which always reflect the full todo
      # list (NOT the filtered view) so the chart shows the underlying
      # data even when the list is filtered.
      chart_row = UI::HStack.new(spacing: 16.0)
      chart_row.alignment = UI::Alignment::Center
      chart_row.minimum_width = content_width
      chart_row.maximum_width = content_width

      open_card = build_count_card("Open", state.open_count.to_s, :primary)
      completed_card = build_count_card("Done", state.completed_count.to_s, :secondary)
      chart_row << open_card
      chart_row << completed_card

      # Filter banner when hide_completed is on — gives the user a
      # visible cue that the list is filtered. Helps the
      # state-propagation litmus result be immediately legible.
      banner : UI::View? = nil
      if state.hide_completed
        b = UI::Label.new("Completed items hidden (toggle in Settings)")
        b.font = UI::Font.new(size: 13.0, weight: :regular)
        b.text_color_role = UI::LabelRole::Tertiary
        b.test_id = "voyager-todos-filter-banner"
        banner = b.as(UI::View)
      end

      # The list itself — one SwipeActionRow per visible todo. Edit
      # action navigates to the todo editor with the id in route
      # params. Delete is harder to wire across pop without a Crystal
      # callback fire from the web side; for now, the web demo's
      # inline JS handles delete via setFragment dispatch.
      list_stack = UI::VStack.new(spacing: 8.0)
      list_stack.alignment = UI::Alignment::Leading
      list_stack.minimum_width = content_width
      list_stack.maximum_width = content_width
      list_stack.test_id = "voyager-todos-list"

      visible = state.visible_todos
      visible.each do |todo|
        list_stack << build_todo_row(todo, state, coord, content_width).as(UI::View)
      end

      # Add button — for the web demo this is a no-op in static HTML;
      # interactive native targets push a fresh editor route with no
      # id (signaling "create new").
      add_btn = UI::Button.new("Add Todo", style: UI::ButtonStyle::Prominent)
      add_btn.accessibility_label = "Add a new todo"
      add_btn.test_id = "voyager-todos-add"
      add_btn.minimum_width = content_width
      add_btn.maximum_width = content_width
      add_btn.on_tap = -> {
        Voyager.log_interaction("todos add button tapped")
        params = {:id => "0"} of Symbol => String
        coord.push(UI::NavigationCoordinator::Route.new(:todo_editor, params))
      }

      root << header.as(UI::View)
      root << chart_row.as(UI::View)
      if b = banner
        root << b
      end
      root << list_stack.as(UI::View)
      root << add_btn.as(UI::View)

      # Phase 6.10 Rem 3 (Item 3): the framework default in VoyagerHost
      # (ios/Sources/ContentView.swift) wraps this root in a UIKit
      # UIScrollView when content overflows the viewport, preserving
      # AX traversal. The screen author can opt into explicit
      # UI::ScrollView wrapping here if they want a Crystal-controlled
      # scroll container with knobs (indicators, bounce, axis), but the
      # default-wrap covers the iPhone 17 portrait overflow case for
      # Voyager. Leaving as-is for now so the framework path stays
      # responsible.
      root.as(UI::View)
    end

    private def build_count_card(label : String, value : String, tint : Symbol) : UI::View
      card = UI::VStack.new(spacing: 4.0)
      card.alignment = UI::Alignment::Leading
      card.padding = UI::EdgeInsets.new(top: 12.0, trailing: 16.0, bottom: 12.0, leading: 16.0)
      card.minimum_width = 120.0

      v = UI::Label.new(value)
      v.font = UI::Font.new(size: 32.0, weight: :bold)
      v.text_color_role = tint == :primary ? UI::LabelRole::Primary : UI::LabelRole::Secondary
      v.test_id = "voyager-count-#{label.downcase}"

      l = UI::Label.new(label)
      l.font = UI::Font.new(size: 13.0, weight: :regular)
      l.text_color_role = UI::LabelRole::Tertiary

      card << v.as(UI::View)
      card << l.as(UI::View)
      card.as(UI::View)
    end

    private def build_todo_row(todo : Todo, state : State, coord : UI::NavigationCoordinator, content_width : Float64) : UI::View
      # The inner content HStack stays unconstrained on width — the
      # outer SwipeActionRow is the row pinned to the band, and its
      # NSStackView/UIStackView host distributes the remaining width
      # between the content and the trailing Edit/Delete buttons. If
      # we pin the inner content to `content_width` it eats the
      # trailing-button slot and the buttons collapse to zero width.
      content = UI::HStack.new(spacing: 12.0)
      content.alignment = UI::Alignment::Center
      content.padding = UI::EdgeInsets.new(top: 10.0, trailing: 12.0, bottom: 10.0, leading: 12.0)
      content.test_id = "voyager-todo-row-#{todo.id}"

      check_icon = UI::Label.new(todo.completed ? "[x]" : "[ ]")
      check_icon.font = UI::Font.new(size: 17.0, weight: :regular)

      title_label = UI::Label.new(todo.title)
      title_label.font = UI::Font.new(size: 16.0, weight: :semibold)
      title_label.text_color_role = todo.completed ? UI::LabelRole::Tertiary : UI::LabelRole::Primary

      content << check_icon.as(UI::View)
      content << title_label.as(UI::View)

      row = UI::SwipeActionRow.new(content.as(UI::View))
      row.accessibility_label = "Todo: #{todo.title}"
      row.minimum_width = content_width
      row.maximum_width = content_width

      edit_action = UI::SwipeAction.new(
        "Edit",
        on_tap: -> {
          params = {:id => todo.id.to_s} of Symbol => String
          coord.push(UI::NavigationCoordinator::Route.new(:todo_editor, params))
        },
        # Web routes to the static todo_editor fragment (web demo
        # uses a fresh draft since per-todo params can't survive
        # the static-site round trip without a server). Native
        # targets honour the params via the on_tap Proc above.
        on_tap_route: "voyager-todo-editor",
      )
      del_action = UI::SwipeAction.new(
        "Delete",
        on_tap: -> { state.delete_todo(todo.id) },
        role: :destructive,
      )

      row.trailing_actions = [edit_action, del_action]
      row.as(UI::View)
    end
  end
end
