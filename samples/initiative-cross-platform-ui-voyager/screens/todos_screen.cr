module Voyager
  # Voyager — Todos screen.
  #
  # Phase 8D.1: migrated to `UI::Screen` subclass with
  # `build(ctx : UI::ScreenContext) : UI::View`. All callbacks route
  # through `Voyager.dispatch(action_ref, action_params)`.
  #
  # Phase 10D-refocus: this screen is now the integrated Phase 10 demo.
  # The Phase 10 surface exercised here:
  #
  #   * UI::WidgetRoute.resolve(:swipe_actions, ctx) — Phase 10B.0 resolver
  #     picks the platform-appropriate widget class (SwipeActionRow on
  #     iOS via SwiftKit, InlineActionRow on macOS, etc.). No screen-
  #     local `UI::SwipeActionRow.new` call site survives.
  #   * Leading-swipe Archive tile (Phase 10D-refocus enabled iOS leading
  #     edge via APSKSwipeActionRowFacade).
  #   * Trailing-swipe Edit + Delete + Share tiles. Share fires the
  #     Class C :copy_to_clipboard intent.
  #   * Toolbar Print button fires the Class C :print intent with a
  #     formatted list.
  #   * First-launch :request_permission Class C dispatch (notifications)
  #     guarded so we don't re-prompt every render.
  #   * Tap-to-edit on each row (whole-row tap navigates to the editor).
  #
  # Reorder via long-press-drag is wired via a separate :move_row action
  # the controller mutates state in. The drag gesture itself is wired
  # in the facade slice (deferred follow-up — see refocus brief).
  class TodosScreen < UI::Screen
    SLUG = "voyager-todos"

    # Module-level guard so the first-launch :request_permission dispatch
    # fires once per process — re-prompting on every render would block
    # the rest of the screen build behind the system permission alert.
    @@requested_notification_permission : Bool = false

    def build(context : UI::ScreenContext) : UI::View
      # Phase 10D-refocus — register this screen class so the dispatcher
      # path's intent resolver consults the screen-tier override table.
      context.active_screen_class = self.class

      # First-launch notification permission. Guarded so it fires once.
      maybe_request_notification_permission

      metrics = UI::DesignTokens::DeviceMetrics.current
      content_width = metrics.compact_horizontal? ? 340.0 : 480.0

      state = Voyager.state

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

      header = UI::HStack.new(spacing: 8.0)
      header.alignment = UI::Alignment::Center
      header.minimum_width = content_width
      header.maximum_width = content_width

      title = UI::Label.new("Todos")
      title.font = UI::Font.new(size: 28.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary

      spacer = UI::Spacer.new

      # Phase 10D-refocus — Print toolbar button (top-right). Fires
      # Class C :print intent. We render it inline in the header rather
      # than via UI::Toolbar so it composes with the rest of the screen
      # chrome without requiring a NavigationStack root.
      print_btn = UI::Button.new("Print")
      print_btn.role = :secondary
      print_btn.accessibility_label = "Print todo list"
      print_btn.test_id = "voyager-todos-print"
      print_btn.on_tap = -> { Voyager.dispatch(:print_list) }

      settings_btn = UI::Button.new("Settings")
      settings_btn.role = :secondary
      settings_btn.accessibility_label = "Settings"
      settings_btn.test_id = "voyager-todos-settings"
      settings_btn.on_tap = -> { Voyager.dispatch(:open_settings) }

      header << title.as(UI::View)
      header << spacer.as(UI::View)
      header << print_btn.as(UI::View)
      header << settings_btn.as(UI::View)

      chart_row = UI::HStack.new(spacing: 16.0)
      chart_row.alignment = UI::Alignment::Center
      chart_row.minimum_width = content_width
      chart_row.maximum_width = content_width

      open_card = build_count_card("Open", state.open_count_total.to_s, :primary, dimmed: false)
      completed_card = build_count_card("Done", state.completed_count_total.to_s, :secondary, dimmed: state.hide_completed)
      chart_row << open_card
      chart_row << completed_card

      banner : UI::View? = nil
      if state.hide_completed
        b = UI::Label.new("Completed items hidden (toggle in Settings)")
        b.font = UI::Font.new(size: 13.0, weight: :regular)
        b.text_color_role = UI::LabelRole::Tertiary
        b.test_id = "voyager-todos-filter-banner"
        banner = b.as(UI::View)
      end

      list_stack = UI::VStack.new(spacing: 8.0)
      list_stack.alignment = UI::Alignment::Leading
      list_stack.minimum_width = content_width
      list_stack.maximum_width = content_width
      list_stack.test_id = "voyager-todos-list"

      # Phase 10D-refocus — Phase 10B.0 resolver. Picks the platform-
      # appropriate widget for `:swipe_actions`. On iOS this returns
      # `UI::SwipeActionRow` (SwiftKit-backed); on macOS it returns
      # `UI::InlineActionRow`; on web it depends on viewport.
      swipe_row_class = UI::WidgetRoute.resolve(:swipe_actions, context)

      visible = state.visible_todos
      visible.each do |todo|
        list_stack << build_todo_row(todo, content_width, swipe_row_class).as(UI::View)
      end

      add_btn = UI::Button.new("Add Todo", style: UI::ButtonStyle::Prominent)
      add_btn.accessibility_label = "Add a new todo"
      add_btn.test_id = "voyager-todos-add"
      add_btn.minimum_width = content_width
      add_btn.maximum_width = content_width
      add_btn.on_tap = -> { Voyager.dispatch(:new_todo) }

      root << header.as(UI::View)
      root << chart_row.as(UI::View)
      if b = banner
        root << b
      end
      root << list_stack.as(UI::View)
      root << add_btn.as(UI::View)

      root.as(UI::View)
    end

    # Phase 10D-refocus — first-launch notification permission.
    # Guarded by @@requested_notification_permission so re-renders
    # don't re-prompt. The DispatchResult is informational; we don't
    # branch on it (a denied permission just means later
    # :show_notification intents will no-op).
    private def maybe_request_notification_permission : Nil
      return if @@requested_notification_permission
      @@requested_notification_permission = true
      UI::SystemAction.perform(:request_permission, kind: "notifications")
      nil
    end

    private def build_count_card(label : String, value : String, tint : Symbol, dimmed : Bool = false) : UI::View
      card = UI::VStack.new(spacing: 4.0)
      card.alignment = UI::Alignment::Leading
      card.padding = UI::EdgeInsets.new(top: 12.0, trailing: 16.0, bottom: 12.0, leading: 16.0)
      card.minimum_width = 120.0

      v = UI::Label.new(value)
      v.font = UI::Font.new(size: 32.0, weight: :bold)
      v.text_color_role = if dimmed
                            UI::LabelRole::Tertiary
                          else
                            tint == :primary ? UI::LabelRole::Primary : UI::LabelRole::Secondary
                          end
      v.test_id = "voyager-count-#{label.downcase}"

      l = UI::Label.new(label)
      l.font = UI::Font.new(size: 13.0, weight: :regular)
      l.text_color_role = UI::LabelRole::Tertiary
      l.opacity = dimmed ? 0.6 : 1.0

      card << v.as(UI::View)
      card << l.as(UI::View)
      card.as(UI::View)
    end

    # Phase 10D-refocus — todo row builder.
    #
    # Receives the resolved swipe-row widget class from the intent
    # resolver so the row construction is platform-honest. The Crystal
    # API surface (leading_actions / trailing_actions) is identical
    # across `UI::SwipeActionRow` and `UI::InlineActionRow` so the
    # composition code below can target the common contract.
    #
    # Row composition: HStack containing the checkbox + a label stack
    # (title + optional deadline subtitle). Whole-row tap navigates to
    # the editor (tap-to-edit). The checkbox toggles completion. The
    # swipe-row wraps the content with leading + trailing tiles.
    private def build_todo_row(
      todo : Todo,
      content_width : Float64,
      swipe_row_class : UI::View.class,
    ) : UI::View
      content = UI::HStack.new(spacing: 12.0)
      content.alignment = UI::Alignment::Center
      content.padding = UI::EdgeInsets.new(top: 10.0, trailing: 12.0, bottom: 10.0, leading: 12.0)
      content.test_id = "voyager-todo-row-#{todo.id}"

      check = UI::Checkbox.new(label: "", is_checked: todo.completed)
      check.accessibility_label = todo.completed ? "Mark '#{todo.title}' as not done" : "Mark '#{todo.title}' as done"
      check.test_id = "voyager-todo-row-#{todo.id}-check"
      todo_id_str = todo.id.to_s
      check.on_change = ->(_value : Bool) {
        Voyager.dispatch(:toggle_row, {"todo_id" => todo_id_str})
      }

      # Title + deadline subtitle inside a tap-to-edit Button (the whole
      # row label area is the tap target; the checkbox stays separate so
      # tapping the checkbox doesn't also fire the edit nav).
      label_stack = UI::VStack.new(spacing: 2.0)
      label_stack.alignment = UI::Alignment::Leading

      title_label = UI::Label.new(todo.title)
      title_label.font = UI::Font.new(size: 16.0, weight: :semibold)
      title_label.text_color_role = todo.completed ? UI::LabelRole::Secondary : UI::LabelRole::Primary
      title_label.strikethrough = todo.completed
      title_label.test_id = "voyager-todo-row-#{todo.id}-title"
      label_stack << title_label.as(UI::View)

      unless todo.deadline.empty?
        dl = UI::Label.new("Due #{todo.deadline}")
        dl.font = UI::Font.new(size: 12.0, weight: :regular)
        dl.text_color_role = UI::LabelRole::Tertiary
        dl.test_id = "voyager-todo-row-#{todo.id}-deadline"
        label_stack << dl.as(UI::View)
      end

      # Phase 10D-refocus — tap-to-edit. The label stack is wrapped in
      # a Button (borderless style so it visually reads as text, not a
      # chrome button). Tapping anywhere on the title/subtitle navigates
      # to the editor populated with the todo's data.
      tap_btn = UI::Button.new(todo.title, style: UI::ButtonStyle::Borderless)
      tap_btn.accessibility_label = "Edit todo: #{todo.title}"
      tap_btn.test_id = "voyager-todo-row-#{todo.id}-tap"
      tap_btn.on_tap = -> {
        Voyager.dispatch(:edit_row, {"todo_id" => todo_id_str})
      }

      content << check.as(UI::View)
      content << tap_btn.as(UI::View)

      # Phase 10D-refocus — leading swipe: Archive tile.
      archive_action = UI::SwipeAction.new(
        "Archive",
        on_tap: -> {
          Voyager.dispatch(:archive_row, {"todo_id" => todo_id_str})
        },
        icon: "archivebox",
      )

      # Phase 10D-refocus — trailing swipe: Edit + Share + Delete tiles.
      edit_action = UI::SwipeAction.new(
        "Edit",
        on_tap: -> {
          Voyager.dispatch(:edit_row, {"todo_id" => todo_id_str})
        },
        icon: "pencil",
        on_tap_route: "voyager-todo-editor",
      )
      share_action = UI::SwipeAction.new(
        "Share",
        on_tap: -> {
          Voyager.dispatch(:share_row, {"todo_id" => todo_id_str})
        },
        icon: "square.and.arrow.up",
      )
      del_action = UI::SwipeAction.new(
        "Delete",
        on_tap: -> {
          Voyager.dispatch(:delete_row, {"todo_id" => todo_id_str})
        },
        role: :destructive,
        icon: "trash",
      )

      leading_actions = [archive_action]
      trailing_actions = [edit_action, share_action, del_action]

      # Phase 10D-refocus — construct the resolved swipe row class.
      # Both `UI::SwipeActionRow` and `UI::InlineActionRow` share the
      # same `.new(content)` + `leading_actions=` / `trailing_actions=`
      # API surface. Dispatch on the runtime class to avoid the
      # `UI::View.class` static-type erasure that would otherwise hide
      # the per-row setters.
      row_view : UI::View = case swipe_row_class
                            when UI::InlineActionRow.class
                              r = UI::InlineActionRow.new(content.as(UI::View))
                              r.leading_actions = leading_actions
                              r.trailing_actions = trailing_actions
                              r.accessibility_label = "Todo: #{todo.title}"
                              r.minimum_width = content_width
                              r.maximum_width = content_width
                              r.as(UI::View)
                            else
                              # Default to SwipeActionRow — covers the iOS /
                              # iPadOS / web_narrow path resolved by the
                              # registry.
                              r = UI::SwipeActionRow.new(content.as(UI::View))
                              r.leading_actions = leading_actions
                              r.trailing_actions = trailing_actions
                              r.accessibility_label = "Todo: #{todo.title}"
                              r.minimum_width = content_width
                              r.maximum_width = content_width
                              r.as(UI::View)
                            end

      row_view
    end
  end
end
