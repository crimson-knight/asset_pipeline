module Voyager
  # Voyager — Todos screen.
  #
  # Phase 8D.1: migrated to `UI::Screen` subclass with
  # `build(ctx : UI::ScreenContext) : UI::View`. All callbacks route
  # through `Voyager.dispatch(action_ref, action_params)`.
  #
  # Phase 10D-final: Mail-app row rebuild. The screen is the integrated
  # Phase 10 demo, with the rename from UI::Intent → UI::WidgetRoute +
  # UI::SystemAction landed in D1. The Phase 10 surface exercised here:
  #
  #   * UI::ListView with per-row callbacks (Phase 10D-final D3):
  #     `on_row_tap` (whole-row tap → edit), `on_move` (long-press-drag
  #     reorder → :move_row), `leading_swipe_actions` (Archive),
  #     `trailing_swipe_actions` (Delete, Done, Share, Edit — ordered
  #     so SwiftUI full-swipe fires Delete).
  #   * UI::SystemAction.perform(:print, ...) — Class C OS dispatch
  #     fired from the toolbar Print button.
  #   * UI::SystemAction.perform(:request_permission, ...) — first-
  #     launch notifications dispatch, guarded so re-renders don't
  #     re-prompt.
  #
  # Rows are plain VStacks of labels (title + optional humanised
  # deadline subtitle). No checkbox, no borderless-button wrapping —
  # the list owns all interactivity. Completion is indicated by
  # strikethrough + Secondary label role on the title.
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

      # Phase 10D-final — Mail-app row rebuild. Replaces the per-row
      # `UI::SwipeActionRow` composition with a single `UI::ListView`
      # that owns per-row tap + leading swipe + trailing swipe + drag
      # reorder via the new D3 callback surface. Each row is a plain
      # VStack of labels (title + optional subtitle) — no checkbox, no
      # borderless-button wrapping, no inline chrome. The interactivity
      # lives on the list, not the row.
      visible = state.visible_todos
      visible_ids = visible.map(&.id.to_s)

      list = UI::ListView.new
      list.minimum_width = content_width
      list.maximum_width = content_width
      list.shows_separators = true
      list.test_id = "voyager-todos-list"
      list.accessibility_label = "Todo list"

      list.sections = [
        UI::ListView::Section.new(
          items: visible.map { |todo| build_todo_row(todo).as(UI::View) },
        ),
      ]

      # Whole-row tap → edit. The dispatcher resolves the id from the
      # row index via the visible_ids snapshot captured in the closure
      # so a stale post-mutation render cannot mis-route.
      list.on_row_tap = ->(idx : Int32) {
        if idx >= 0 && idx < visible_ids.size
          Voyager.dispatch(:edit_row, {"todo_id" => visible_ids[idx]})
        end
        nil
      }

      # Long-press-drag reorder. Forwards absolute indexes to the
      # existing :move_row controller action.
      list.on_move = ->(from : Int32, to : Int32) {
        Voyager.dispatch(:move_row, {"from" => from.to_s, "to" => to.to_s})
        nil
      }

      # Per-row leading swipe — single Archive tile.
      list.leading_swipe_actions = ->(idx : Int32) : Array(UI::SwipeAction) {
        if idx < 0 || idx >= visible_ids.size
          [] of UI::SwipeAction
        else
          todo_id = visible_ids[idx]
          [
            UI::SwipeAction.new(
              "Archive",
              on_tap: -> { Voyager.dispatch(:archive_row, {"todo_id" => todo_id}); nil },
              icon: "archivebox",
            ),
          ]
        end
      }

      # Per-row trailing swipe — Mail-app order: [delete, mark_done,
      # share, edit] so SwiftUI fires Delete on full-swipe AND renders
      # it as the rightmost (outermost) tile when fully revealed.
      list.trailing_swipe_actions = ->(idx : Int32) : Array(UI::SwipeAction) {
        if idx < 0 || idx >= visible_ids.size
          [] of UI::SwipeAction
        else
          todo_id = visible_ids[idx]
          [
            UI::SwipeAction.new(
              "Delete",
              on_tap: -> { Voyager.dispatch(:delete_row, {"todo_id" => todo_id}); nil },
              role: :destructive,
              icon: "trash",
            ),
            UI::SwipeAction.new(
              "Done",
              on_tap: -> { Voyager.dispatch(:toggle_row, {"todo_id" => todo_id}); nil },
              icon: "checkmark.circle",
            ),
            UI::SwipeAction.new(
              "Share",
              on_tap: -> { Voyager.dispatch(:share_row, {"todo_id" => todo_id}); nil },
              icon: "square.and.arrow.up",
            ),
            UI::SwipeAction.new(
              "Edit",
              on_tap: -> { Voyager.dispatch(:edit_row, {"todo_id" => todo_id}); nil },
              icon: "pencil",
            ),
          ]
        end
      }

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
      root << list.as(UI::View)
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

    # Phase 10D-final — todo row builder.
    #
    # The row is a plain VStack of labels — title and optional humanised
    # deadline subtitle. No checkbox, no borderless-button wrapping; the
    # surrounding `UI::ListView` owns the tap + swipe + drag chrome.
    # When the todo is completed, the title uses Secondary label role
    # and a strikethrough so the completed state reads at a glance.
    #
    # Mirrors the iOS Mail row visual:
    #   - Bold title (semibold 16pt)
    #   - Tertiary 12pt subtitle (humanized "Due Today" / "Due Tomorrow")
    #   - 10pt vertical inset so 44pt minimum tap target is honored
    private def build_todo_row(todo : Todo) : UI::View
      row = UI::VStack.new(spacing: 2.0)
      row.alignment = UI::Alignment::Leading
      row.padding = UI::EdgeInsets.new(top: 10.0, trailing: 12.0, bottom: 10.0, leading: 12.0)
      row.test_id = "voyager-todo-row-#{todo.id}"
      row.accessibility_label = "Todo: #{todo.title}"

      title_label = UI::Label.new(todo.title)
      title_label.font = UI::Font.new(size: 16.0, weight: :semibold)
      title_label.text_color_role = todo.completed ? UI::LabelRole::Secondary : UI::LabelRole::Primary
      title_label.strikethrough = todo.completed
      title_label.test_id = "voyager-todo-row-#{todo.id}-title"
      row << title_label.as(UI::View)

      if subtitle = humanize_deadline(todo.deadline)
        dl = UI::Label.new(subtitle)
        dl.font = UI::Font.new(size: 12.0, weight: :regular)
        dl.text_color_role = UI::LabelRole::Tertiary
        dl.test_id = "voyager-todo-row-#{todo.id}-deadline"
        row << dl.as(UI::View)
      end

      row.as(UI::View)
    end

    # Phase 10D-final D6 — humanize a raw deadline string into a
    # subtitle suitable for the Mail-app subtitle position.
    #
    # Returns:
    #   - nil if the raw string is empty (no subtitle rendered)
    #   - "Due Today" / "Due Tomorrow" when the parsed date matches
    #   - "Due Mon Jun 1" style when the date parses but is further out
    #   - "Due <raw>" passthrough when the date is not parseable
    private def humanize_deadline(raw : String) : String?
      return nil if raw.empty?

      today = Time.local.at_beginning_of_day
      tomorrow = today + 1.day

      # Try to parse the deadline. The Voyager state stores deadlines
      # as ISO-8601 dates (`YYYY-MM-DD`); fall back to passthrough on
      # any parse failure rather than masking the raw string.
      parsed : Time? = nil
      formats = ["%Y-%m-%d", "%Y/%m/%d"]
      formats.each do |fmt|
        begin
          parsed = Time.parse(raw, fmt, Time::Location.local).at_beginning_of_day
          break
        rescue Time::Format::Error
          # try next format
        end
      end

      if t = parsed
        if t == today
          "Due Today"
        elsif t == tomorrow
          "Due Tomorrow"
        else
          "Due #{t.to_s("%a %b %-d")}"
        end
      else
        "Due #{raw}"
      end
    end
  end
end
