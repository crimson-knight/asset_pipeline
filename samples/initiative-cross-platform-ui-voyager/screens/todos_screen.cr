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

      # Phase 10D-polish A4 — the row 16pt inset is now a UI::ListView
      # default (see src/ui/views/list_view.cr:content_inset_horizontal).
      # The screen still pads the OUTER content (header, chart row, add
      # button) at 16pt so the chrome aligns with the list rows. The
      # ListView itself ignores this outer inset; it owns its own
      # row-level inset via .listRowInsets.
      root = UI::VStack.new(spacing: 16.0)
      root.root_fill = true
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(
        top: 24.0 + metrics.safe_area_top_pt,
        trailing: 16.0 + metrics.safe_area_trailing_pt,
        bottom: 24.0 + metrics.safe_area_bottom_pt,
        leading: 16.0 + metrics.safe_area_leading_pt,
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

      # Phase 10D-polish B5 — overflow "•••" button. Tapping toggles
      # `state.show_overflow_menu`; the screen renders a `UI::Popover`
      # anchored under the button with the options Sort by deadline /
      # Hide completed / Clear all completed.
      overflow_btn = UI::Button.new("•••")
      overflow_btn.role = :secondary
      overflow_btn.accessibility_label = "More actions"
      overflow_btn.test_id = "voyager-todos-overflow"
      overflow_btn.on_tap = -> { Voyager.dispatch(:show_overflow) }

      settings_btn = UI::Button.new("Settings")
      settings_btn.role = :secondary
      settings_btn.accessibility_label = "Settings"
      settings_btn.test_id = "voyager-todos-settings"
      settings_btn.on_tap = -> { Voyager.dispatch(:open_settings) }

      header << title.as(UI::View)
      header << spacer.as(UI::View)
      header << print_btn.as(UI::View)
      header << overflow_btn.as(UI::View)
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
      # SwiftUI's List collapses to 0pt inside a parent VStack without
      # a height pin (UIHostingController has no natural intrinsic
      # height for List). Compute a height tall enough to show all
      # visible rows at ~64pt per row (16 + 12 + 12 + line gap + subtitle).
      list.minimum_height = (visible.size * 72.0).clamp(120.0, 560.0)
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
      # Phase 10D-polish — Delete and Share now route through the
      # request_* paths so the screen renders an Alert (B1) /
      # ActionSheet (B2) instead of mutating immediately.
      list.trailing_swipe_actions = ->(idx : Int32) : Array(UI::SwipeAction) {
        if idx < 0 || idx >= visible_ids.size
          [] of UI::SwipeAction
        else
          todo_id = visible_ids[idx]
          [
            UI::SwipeAction.new(
              "Delete",
              on_tap: -> { Voyager.dispatch(:request_delete, {"todo_id" => todo_id}); nil },
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
              on_tap: -> { Voyager.dispatch(:request_share, {"todo_id" => todo_id}); nil },
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

      # Phase 10D-polish B1 — Alert (delete confirmation). Render when
      # `pending_delete_todo_id` is set. The Cancel button clears the
      # pending flag; Delete dispatches :confirm_delete which performs
      # the mutation AND clears the flag. UI::Alert's `is_presented`
      # drives SwiftUI's `.alert(_:isPresented:)` reactive path.
      if delete_id = state.pending_delete_todo_id
        target = state.find_todo(delete_id)
        title_text = if target
                       "Delete \"#{target.title}\"?"
                     else
                       "Delete this todo?"
                     end
        alert = UI::Alert.new(title_text, "This can't be undone.")
        alert.add_button("Cancel", :cancel) {
          Voyager.dispatch(:cancel_pending)
          nil
        }
        alert.add_button("Delete", :destructive) {
          Voyager.dispatch(:confirm_delete)
          nil
        }
        alert.is_presented = true
        alert.test_id = "voyager-todos-delete-alert"
        alert.accessibility_label = "Confirm delete"
        root << alert.as(UI::View)
      end

      # Phase 10D-polish B2 — ActionSheet (share menu). Render when
      # `pending_share_todo_id` is set. Options: Copy / Print / Cancel.
      # UI::ActionSheet is iOS-gated (Tier 3) — we use the with-fallback
      # wrapper so non-iOS builds still compile.
      if share_id = state.pending_share_todo_id
        target = state.find_todo(share_id)
        sheet_title = target ? "Share \"#{target.title}\"" : "Share todo"
        share_sheet = UI::ActionSheetWithWebFallback.new(sheet_title, "Choose how to share this todo.")
        share_sheet.add_action("Copy to Clipboard") {
          Voyager.dispatch(:copy_pending_share)
          nil
        }
        share_sheet.add_action("Print This Todo") {
          Voyager.dispatch(:print_pending_share)
          nil
        }
        share_sheet.add_action("Cancel", :cancel) {
          Voyager.dispatch(:cancel_pending)
          nil
        }
        share_sheet.is_presented = true
        share_sheet.test_id = "voyager-todos-share-sheet"
        share_sheet.accessibility_label = "Share options"
        root << share_sheet.as(UI::View)
      end

      # Phase 10D-polish B3 — Sheet (editor as modal). Render when
      # `pending_editor_todo_id` is set (0 = new draft; >0 = edit
      # existing). The content view is the existing editor form,
      # extracted into `build_editor_content` so this screen owns the
      # form layout used inside the Sheet.
      if editor_id = state.pending_editor_todo_id
        editor_view = build_editor_content(state, editor_id)
        editor_sheet = UI::Sheet.new(editor_view, surface_style: :grouped_card)
        editor_sheet.detents = [:medium, :large]
        editor_sheet.shows_drag_indicator = true
        editor_sheet.on_dismiss = -> { Voyager.dispatch(:close_editor_sheet); nil }
        editor_sheet.is_presented = true
        editor_sheet.test_id = "voyager-todos-editor-sheet"
        editor_sheet.accessibility_label = "Edit todo"
        root << editor_sheet.as(UI::View)
      end

      # Phase 10D-polish B5 — Popover (overflow menu). Anchored under
      # the "•••" toolbar button. Options: Sort by deadline / Hide
      # completed / Clear all completed. The Popover content is a
      # VStack of borderless Buttons.
      if state.show_overflow_menu
        menu_content = UI::VStack.new(spacing: 4.0)
        menu_content.alignment = UI::Alignment::Leading
        menu_content.padding = UI::EdgeInsets.new(top: 8.0, trailing: 12.0, bottom: 8.0, leading: 12.0)
        menu_content.minimum_width = 220.0

        sort_btn = UI::Button.new("Sort by deadline")
        sort_btn.role = :secondary
        sort_btn.accessibility_label = "Sort by deadline"
        sort_btn.test_id = "voyager-overflow-sort"
        sort_btn.on_tap = -> { Voyager.dispatch(:sort_by_deadline) }

        hide_label = state.hide_completed ? "Show completed" : "Hide completed"
        hide_btn = UI::Button.new(hide_label)
        hide_btn.role = :secondary
        hide_btn.accessibility_label = hide_label
        hide_btn.test_id = "voyager-overflow-hide-completed"
        hide_btn.on_tap = -> { Voyager.dispatch(:toggle_hide_completed) }

        clear_btn = UI::Button.new("Clear all completed")
        clear_btn.role = :destructive
        clear_btn.accessibility_label = "Clear all completed todos"
        clear_btn.test_id = "voyager-overflow-clear-completed"
        clear_btn.on_tap = -> { Voyager.dispatch(:clear_all_completed) }

        menu_content << sort_btn.as(UI::View)
        menu_content << hide_btn.as(UI::View)
        menu_content << clear_btn.as(UI::View)

        overflow_popover = UI::Popover.new(menu_content.as(UI::View), :bottom)
        overflow_popover.preferred_width = 240.0
        overflow_popover.on_dismiss = -> { Voyager.dispatch(:hide_overflow); nil }
        overflow_popover.is_presented = true
        overflow_popover.test_id = "voyager-todos-overflow-popover"
        overflow_popover.accessibility_label = "More actions menu"
        root << overflow_popover.as(UI::View)
      end

      root.as(UI::View)
    end

    # Phase 10D-polish B3 + B4 — sheet-mode editor content builder.
    #
    # Renders the title field, deadline DatePicker, completed toggle,
    # and the Cancel + Save action row. The form-state seed mirrors the
    # legacy slug-pushed editor screen (TodoEditorScreen) so save logic
    # in TodoEditorController#save reads ctx.form_state["title"] etc.
    # When `editor_id` is 0 we render the "New todo" header; >0 selects
    # the matching todo for editing.
    private def build_editor_content(state : State, editor_id : Int32) : UI::View
      metrics = UI::DesignTokens::DeviceMetrics.current
      content_width = metrics.compact_horizontal? ? 320.0 : 460.0

      editing = editor_id > 0 ? state.find_todo(editor_id) : nil

      seed_title = editing ? editing.title : ""
      seed_completed = editing ? editing.completed : false
      seed_note = editing ? editing.note : ""
      seed_deadline = editing ? editing.deadline : ""

      # Seed FormState so TodoEditorController#save can read the values
      # on dispatch. Same shape as TodoEditorScreen.
      d = Voyager.dispatcher
      unless d.nil?
        fs = d.current_form_state
        fs.register("title", seed_title)
        fs.register("note", seed_note)
        fs.register("completed", seed_completed ? "true" : "false")
        fs.register("deadline", seed_deadline)
        # Mark the in-sheet edit so TodoEditorController#save knows
        # which todo it's mutating (the sheet has no route params).
        fs.register("todo_id", editor_id.to_s)
      end

      body = UI::VStack.new(spacing: 14.0)
      body.alignment = UI::Alignment::Leading
      body.padding = UI::EdgeInsets.new(top: 20.0, trailing: 20.0, bottom: 20.0, leading: 20.0)
      body.minimum_width = content_width
      body.test_id = "voyager-todos-editor-sheet-body"

      header_label = UI::Label.new(editing ? "Edit todo" : "New todo")
      header_label.font = UI::Font.new(size: 20.0, weight: :bold)
      header_label.text_color_role = if editing && seed_completed
                                       UI::LabelRole::Secondary
                                     else
                                       UI::LabelRole::Primary
                                     end
      header_label.strikethrough = !editing.nil? && seed_completed
      body << header_label.as(UI::View)

      title_field = UI::TextField.new(placeholder: "Title", name: "title")
      title_field.text = seed_title
      title_field.accessibility_label = "Todo title"
      title_field.test_id = "voyager-editor-sheet-title"
      title_field.minimum_width = content_width
      title_field.maximum_width = content_width
      body << title_field.as(UI::View)

      note_field = UI::TextField.new(placeholder: "Note (optional)", name: "note")
      note_field.text = seed_note
      note_field.accessibility_label = "Todo note"
      note_field.test_id = "voyager-editor-sheet-note"
      note_field.minimum_width = content_width
      note_field.maximum_width = content_width
      body << note_field.as(UI::View)

      # Phase 10D-polish B4 — native DatePicker. Replaces the YYYY-MM-DD
      # TextField. We initialize from the seeded ISO deadline if it
      # parses; otherwise today. on_change writes the date back into
      # FormState under "deadline" as ISO-8601 so the controller's save
      # reads the same key it always has.
      deadline_label = UI::Label.new("Deadline")
      deadline_label.font = UI::Font.new(size: 13.0, weight: :regular)
      deadline_label.text_color_role = UI::LabelRole::Tertiary
      body << deadline_label.as(UI::View)

      picker = UI::DatePicker.new(UI::DatePickerMode::Date)
      picker.label = "Deadline"
      picker.accessibility_label = "Todo deadline"
      picker.test_id = "voyager-editor-sheet-deadline"
      # Seed selected_date from ISO string if parseable. Use Time.utc
      # rather than Time.local because Crystal's iOS class-init gap
      # leaves Time::Location.local uninitialized → segfault in
      # find_zoneinfo_file. The picker doesn't care about timezone for
      # date-only mode; we re-serialize as ISO date on change.
      if !seed_deadline.empty?
        begin
          picker.selected_date = Time.parse_utc(seed_deadline, "%Y-%m-%d")
        rescue Time::Format::Error
          picker.selected_date = Time.utc
        end
      else
        picker.selected_date = Time.utc
      end
      picker.on_change = ->(t : Time) {
        d2 = Voyager.dispatcher
        unless d2.nil?
          # Use to_utc + format to avoid Time::Location.local on iOS.
          # The picker returns a UTC time; the YYYY-MM-DD form is fine
          # because the user only sees date-resolution chrome.
          d2.current_form_state.update("deadline", t.to_utc.to_s("%Y-%m-%d"))
        end
        nil
      }
      body << picker.as(UI::View)

      # Allow clearing the deadline by tapping "No deadline" — Crystal
      # DatePicker has no nilable value today, so we expose a button.
      clear_deadline_btn = UI::Button.new("No deadline")
      clear_deadline_btn.role = :secondary
      clear_deadline_btn.accessibility_label = "Clear deadline"
      clear_deadline_btn.test_id = "voyager-editor-sheet-clear-deadline"
      clear_deadline_btn.on_tap = -> {
        d2 = Voyager.dispatcher
        unless d2.nil?
          d2.current_form_state.update("deadline", "")
        end
        nil
      }
      body << clear_deadline_btn.as(UI::View)

      completed_toggle = UI::Toggle.new(label: "Completed", is_on: seed_completed)
      completed_toggle.accessibility_label = "Mark as completed"
      completed_toggle.test_id = "voyager-editor-sheet-completed"
      completed_toggle.minimum_width = content_width
      completed_toggle.maximum_width = content_width
      completed_toggle.on_change = ->(value : Bool) {
        d2 = Voyager.dispatcher
        unless d2.nil?
          d2.current_form_state.update("completed", value ? "true" : "false")
        end
      }
      body << completed_toggle.as(UI::View)

      actions = UI::HStack.new(spacing: 12.0)
      actions.alignment = UI::Alignment::Center
      actions.minimum_width = content_width
      actions.maximum_width = content_width

      half_button_width = (content_width - 12.0) / 2.0

      cancel_btn = UI::Button.new("Cancel")
      cancel_btn.role = :secondary
      cancel_btn.accessibility_label = "Cancel and discard changes"
      cancel_btn.test_id = "voyager-editor-sheet-cancel"
      cancel_btn.minimum_width = half_button_width
      cancel_btn.maximum_width = half_button_width
      cancel_btn.on_tap = -> { Voyager.dispatch(:close_editor_sheet) }

      save_btn = UI::Button.new("Save", style: UI::ButtonStyle::Prominent)
      save_btn.accessibility_label = "Save todo"
      save_btn.test_id = "voyager-editor-sheet-save"
      save_btn.minimum_width = half_button_width
      save_btn.maximum_width = half_button_width
      save_btn.disabled = seed_title.strip.empty?
      save_btn.on_tap = -> { Voyager.dispatch(:save_sheet) }
      title_field.on_change = ->(value : String) {
        save_btn.disabled = value.strip.empty?
      }

      actions << cancel_btn.as(UI::View)
      actions << save_btn.as(UI::View)
      body << actions.as(UI::View)

      body.as(UI::View)
    end

    # Phase 10D-refocus — first-launch notification permission.
    # Guarded by @@requested_notification_permission so re-renders
    # don't re-prompt. The DispatchResult is informational; we don't
    # branch on it (a denied permission just means later
    # :show_notification intents will no-op).
    private def maybe_request_notification_permission : Nil
      return if @@requested_notification_permission
      # Phase 10D-final — capture-mode bypass. The simctl screenshot
      # flow can't dismiss the system permission alert, so the
      # capture matrix sets VOYAGER_SKIP_NOTIF_PROMPT=1 to suppress
      # the first-launch :request_permission Class C dispatch.
      if ENV["VOYAGER_SKIP_NOTIF_PROMPT"]? == "1"
        @@requested_notification_permission = true
        return
      end
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
