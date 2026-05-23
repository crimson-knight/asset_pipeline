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
      root = UI::VStack.new(spacing: 16.0)
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(top: 24.0, trailing: 20.0, bottom: 24.0, leading: 20.0)
      root.accessibility_label = "Voyager todos screen"
      root.test_id = "voyager-todos-root"

      # Header row: title + settings link
      header = UI::HStack.new(spacing: 8.0)
      header.alignment = UI::Alignment::Center

      title = UI::Label.new("Todos")
      title.font = UI::Font.new(size: 28.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary

      spacer = UI::Spacer.new

      settings_btn = UI::Button.new("Settings")
      settings_btn.role = :secondary
      settings_btn.accessibility_label = "Open settings"
      settings_btn.test_id = "voyager-todos-settings"
      settings_btn.on_tap = -> { coord.push(UI::NavigationCoordinator::Route.new(:settings)) }

      header << title.as(UI::View)
      header << spacer.as(UI::View)
      header << settings_btn.as(UI::View)

      # Chart-like row: open + completed counts. Reads state.open_count
      # and state.completed_count, which always reflect the full todo
      # list (NOT the filtered view) so the chart shows the underlying
      # data even when the list is filtered.
      chart_row = UI::HStack.new(spacing: 16.0)
      chart_row.alignment = UI::Alignment::Center

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
      list_stack.test_id = "voyager-todos-list"

      state.visible_todos.each do |todo|
        list_stack << build_todo_row(todo, state, coord).as(UI::View)
      end

      # Add button — for the web demo this is a no-op in static HTML;
      # interactive native targets push a fresh editor route with no
      # id (signaling "create new").
      add_btn = UI::Button.new("Add Todo", style: UI::ButtonStyle::Prominent)
      add_btn.accessibility_label = "Add a new todo"
      add_btn.test_id = "voyager-todos-add"
      add_btn.on_tap = -> {
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

    private def build_todo_row(todo : Todo, state : State, coord : UI::NavigationCoordinator) : UI::View
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

      edit_action = UI::SwipeAction.new(
        "Edit",
        on_tap: -> {
          params = {:id => todo.id.to_s} of Symbol => String
          coord.push(UI::NavigationCoordinator::Route.new(:todo_editor, params))
        },
        on_tap_route: "voyager-todo-editor-#{todo.id}",
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
