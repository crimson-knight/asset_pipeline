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

      # Phase D Track 2 — the WHOLE composition adapts via DeviceMetrics#responsive
      # (not just width): column width, root spacing, outer padding, and the title
      # type scale all reflow when the size class changes (live, via the macOS
      # windowDidResize→rebuild hook and the iOS live-metrics provider). Matches the
      # sign-in / welcome migration. See foundational-output-and-layout-model.md
      # §"Track 2".
      metrics = UI::DesignTokens::DeviceMetrics.current

      state = Voyager.state

      # Phase 10D-polish A4 — the row 16pt inset is now a UI::ListView
      # default (see src/ui/views/list_view.cr:content_inset_horizontal).
      # The screen still pads the OUTER content (header, chart row, add
      # button) at 16pt so the chrome aligns with the list rows. The
      # ListView itself ignores this outer inset; it owns its own
      # row-level inset via .listRowInsets.
      # Vertical rhythm keys off the VERTICAL size class (tightens in landscape /
      # short windows); horizontal padding keys off the horizontal class.
      root = UI::VStack.new(spacing: metrics.responsive_vertical(compact: 10.0, regular: 18.0))
      root.root_fill = true
      root.alignment = UI::Alignment::Leading
      pad_v = metrics.responsive_vertical(compact: 16.0, regular: 28.0)
      pad_h = metrics.responsive(compact: 16.0, regular: 24.0)
      # Adaptive column width (shared helper) — clamps to the device so the todos
      # header, chart, list and add button reflow onto the watch.
      content_width = metrics.adaptive_content_width(compact: 340.0, regular: 480.0, horizontal_padding: pad_h)
      root.padding = UI::EdgeInsets.new(
        top: pad_v + metrics.safe_area_top_pt,
        trailing: pad_h + metrics.safe_area_trailing_pt,
        bottom: pad_v + metrics.safe_area_bottom_pt,
        leading: pad_h + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Voyager todos screen"
      root.test_id = "voyager-todos-root"

      # The header REFLOWS (built below, once the buttons exist): a single inline row
      # (title + action buttons) on phone/desktop, but a stacked column on a narrow
      # canvas (watch) — four side-by-side buttons can't fit 176pt, they'd squeeze to
      # unreadable 1-char strips. compact_canvas? is the shared signal.
      stacked_header = metrics.compact_canvas?

      title = UI::Label.new("Todos")
      title.font = UI::Font.new(size: metrics.responsive(compact: 26.0, regular: 30.0), weight: :bold)
      title.text_color_role = UI::LabelRole::Primary
      # The title is the row's flexible element (fill_horizontal) instead of pairing it
      # with a greedy Spacer: a Spacer expands and COMPRESSES the title below its
      # intrinsic width, wrapping "Todos" to two lines. As the grow element the title
      # keeps (and exceeds) its intrinsic width, pushing the icon toolbar to the trailing
      # edge — no wrap. (Harmless on the watch column: it just fills the column width.)
      title.fill_horizontal = true

      # The header actions, defined once as data so the same set renders two ways:
      # a compact SF-Symbol toolbar on phone/desktop (idiomatic + fits the width) and a
      # stacked column of full-width TEXT buttons on the watch (readable when stacked —
      # an icon-only button is ambiguous as a wrist list row). Agent opens the shared
      # cross-platform chat; the rest fire their existing dispatches. test_ids are
      # preserved so the XCUITest suite (voyager-todos-agent, …) still resolves them.
      actions = [
        {label: "Agent", icon: "bubble.left.fill", tid: "voyager-todos-agent", act: :open_agent_chat},
        {label: "Print", icon: "printer.fill", tid: "voyager-todos-print", act: :print_list},
        {label: "More", icon: "ellipsis.circle", tid: "voyager-todos-overflow", act: :show_overflow},
        {label: "Settings", icon: "gearshape.fill", tid: "voyager-todos-settings", act: :open_settings},
      ]

      # Build the header in its reflowed form. Each branch fully configures a concrete
      # stack and yields a UI::View, so we never call stack-only methods (<<, alignment=)
      # on a widened type.
      header =
        if stacked_header
          # Watch: title on its own line, then each action full-width and readable.
          col = UI::VStack.new(spacing: 6.0)
          col.alignment = UI::Alignment::Leading
          col.minimum_width = content_width
          col.maximum_width = content_width
          col << title.as(UI::View)
          actions.each do |a|
            btn = UI::Button.new(a[:label])
            btn.role = :secondary
            btn.accessibility_label = a[:label]
            btn.test_id = a[:tid]
            btn.on_tap = -> { Voyager.dispatch(a[:act]) }
            btn.minimum_width = content_width
            btn.maximum_width = content_width
            col << btn.as(UI::View)
          end
          col.as(UI::View)
        else
          # Phone/desktop: a large title on its OWN line, with an SF-Symbol toolbar row
          # beneath it. Keeping the title on its own line gives it the full column width
          # so it can never be compressed/wrapped by the action row beside it (an inline
          # title + 4 controls fought for width and "Todos" wrapped). The icon row sits
          # leading under the title — a clean large-title + toolbar layout.
          outer = UI::VStack.new(spacing: 8.0)
          outer.alignment = UI::Alignment::Leading
          outer.minimum_width = content_width
          outer.maximum_width = content_width
          outer << title.as(UI::View)
          icon_row = UI::HStack.new(spacing: 18.0)
          icon_row.alignment = UI::Alignment::Center
          actions.each do |a|
            btn = UI::IconButton.new(a[:icon])
            btn.accessibility_label = a[:label]
            btn.test_id = a[:tid]
            btn.on_tap = -> { Voyager.dispatch(a[:act]) }
            icon_row << btn.as(UI::View)
          end
          outer << icon_row.as(UI::View)
          outer.as(UI::View)
        end

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

      # Per-row leading swipe — single Archive tile. Phase 10D-polish
      # iter 2 demonstrates the new `tint:` knob on SwipeAction: Archive
      # in orange instead of the role-derived default green.
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
              tint: :orange,
            ),
          ]
        end
      }

      # Per-row trailing swipe — Mail-app order: [delete, mark_done,
      # share, edit] so SwiftUI fires Delete on full-swipe AND renders
      # it as the rightmost (outermost) tile when fully revealed.
      # Phase 10D-polish iter 2 — Done shows in green, Share in gray,
      # Edit in blue. Delete stays role-derived red (destructive).
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
              tint: :green,
            ),
            UI::SwipeAction.new(
              "Share",
              on_tap: -> { Voyager.dispatch(:request_share, {"todo_id" => todo_id}); nil },
              icon: "square.and.arrow.up",
              tint: :gray,
            ),
            UI::SwipeAction.new(
              "Edit",
              on_tap: -> { Voyager.dispatch(:edit_row, {"todo_id" => todo_id}); nil },
              icon: "pencil",
              tint: :blue,
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

      # Share menu — rendered as a real bottom UI::Sheet (the same proven
      # presentation the editor sheet uses) with explicit action buttons,
      # NOT a system action sheet. iOS 26 renders UIAlertController/
      # SwiftUI `.confirmationDialog` action sheets as a floating card that
      # does not surface a tappable Cancel in this embedded-host context
      # (verified: presenting VC is compact/phone yet no Cancel — see the
      # project_voyager_action_sheet_popover note). Building the buttons
      # ourselves inside a Sheet gives full control: a guaranteed
      # bottom-sheet presentation AND a real, tappable, AX-discoverable
      # Cancel button. Each button dispatches the same action the old
      # ActionSheet did.
      if share_id = state.pending_share_todo_id
        target = state.find_todo(share_id)
        sheet_title = target ? "Share \"#{target.title}\"" : "Share todo"
        share_width = metrics.responsive(compact: 320.0, regular: 460.0)

        share_body = UI::VStack.new(spacing: 12.0)
        share_body.alignment = UI::Alignment::Leading
        share_body.padding = UI::EdgeInsets.new(top: 20.0, trailing: 20.0, bottom: 20.0, leading: 20.0)
        share_body.minimum_width = share_width
        share_body.test_id = "voyager-todos-share-sheet-body"

        share_heading = UI::Label.new(sheet_title)
        share_heading.font = UI::Font.new(size: 20.0, weight: :bold)
        share_heading.text_color_role = UI::LabelRole::Primary
        share_body << share_heading.as(UI::View)

        share_subtitle = UI::Label.new("Choose how to share this todo.")
        share_subtitle.font = UI::Font.new(size: 13.0, weight: :regular)
        share_subtitle.text_color_role = UI::LabelRole::Secondary
        share_body << share_subtitle.as(UI::View)

        copy_btn = UI::Button.new("Copy to Clipboard", style: UI::ButtonStyle::Prominent)
        copy_btn.accessibility_label = "Copy to Clipboard"
        copy_btn.test_id = "voyager-share-copy"
        copy_btn.minimum_width = share_width
        copy_btn.maximum_width = share_width
        copy_btn.on_tap = -> { Voyager.dispatch(:copy_pending_share) }
        share_body << copy_btn.as(UI::View)

        print_btn = UI::Button.new("Print This Todo")
        print_btn.role = :secondary
        print_btn.accessibility_label = "Print This Todo"
        print_btn.test_id = "voyager-share-print"
        print_btn.minimum_width = share_width
        print_btn.maximum_width = share_width
        print_btn.on_tap = -> { Voyager.dispatch(:print_pending_share) }
        share_body << print_btn.as(UI::View)

        cancel_btn = UI::Button.new("Cancel")
        cancel_btn.role = :secondary
        cancel_btn.accessibility_label = "Cancel"
        cancel_btn.test_id = "voyager-share-cancel"
        cancel_btn.minimum_width = share_width
        cancel_btn.maximum_width = share_width
        cancel_btn.on_tap = -> { Voyager.dispatch(:cancel_pending) }
        share_body << cancel_btn.as(UI::View)

        share_sheet = UI::Sheet.new(share_body.as(UI::View), surface_style: :grouped_card)
        share_sheet.detents = [:medium]
        share_sheet.shows_drag_indicator = true
        share_sheet.on_dismiss = -> { Voyager.dispatch(:cancel_pending); nil }
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
        # Phase 10D-polish iter 2 (B-POPOVER-ANCHOR-VIEW) — anchor the
        # popover's arrow at the "•••" overflow button by referencing
        # its test_id. The iOS renderer looks the UIView pointer up in
        # its per-render registry and threads it into
        # UIPopoverPresentationController.sourceView.
        overflow_popover.anchor_view_id = "voyager-todos-overflow"
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
      # Adaptive column width (shared helper) — the inline editor's body padding is
      # 20pt each side, so clamp to that; reflows the editor fields onto the watch.
      content_width = metrics.adaptive_content_width(compact: 320.0, regular: 460.0, horizontal_padding: 20.0)

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

      # Deadline — a plain TextField (YYYY-MM-DD), NOT a native DatePicker. The
      # native UIDatePicker hosted inside this presented Sheet CRASHES the iOS app
      # on interaction (owner-reported; reproduced — see
      # project_ios_host_reentrant_render_hang). A TextField in this same Sheet is
      # stable (testSavePropagation types into the title TextField + saves and
      # passes), and writing the deadline via name:"deadline" feeds the exact same
      # FormState key the save path already reads. The fancy DatePicker returns once
      # the kit's Sheet/DatePicker hosting bug is fixed.
      deadline_field = UI::TextField.new(placeholder: "Deadline (YYYY-MM-DD, optional)", name: "deadline")
      deadline_field.text = seed_deadline
      deadline_field.accessibility_label = "Todo deadline"
      deadline_field.test_id = "voyager-editor-sheet-deadline"
      deadline_field.minimum_width = content_width
      deadline_field.maximum_width = content_width
      body << deadline_field.as(UI::View)

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

      # CLASS-INIT-GAP SAFE (iOS): format the deadline from INTEGERS ONLY — no Time
      # at all. The previous version used Time.local / Time.parse / Time#to_s (all
      # crash on iOS: Time::Location.local segfaults, Time::Format lookup tables
      # uninitialized), and even Time.utc(y,m,d) FAILS on the iOS embedding (the
      # Time::Location::UTC constant initializer is skipped — verified: it fell back
      # to "Due 2026-12-19" passthrough). So we never construct a Time: split the ISO
      # string, validate the integer fields, and format "Due <Mon> <d>, <yyyy>" via a
      # method-local month-name array. See project_crystal_ios_class_init_gap.
      parts = raw.includes?('-') ? raw.split('-') : raw.split('/')
      return "Due #{raw}" unless parts.size == 3
      y = parts[0].to_i?
      m = parts[1].to_i?
      d = parts[2].to_i?
      return "Due #{raw}" unless y && m && d && (1..12).includes?(m) && (1..31).includes?(d)
      "Due #{month_abbreviation(m)} #{d}, #{y}"
    end

    # Month abbreviation from a 1-based month index. A method-local array (NOT a
    # class constant — the iOS class-init gap skips constant initializers) and pure
    # Int indexing; no locale/Time#to_s.
    private def month_abbreviation(month : Int32) : String
      names = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
      names[month]? || month.to_s
    end
  end
end
