module Voyager
  # Phase 8D.1 / 10D-refocus — TodosController.
  #
  # Owns the user-intent actions reachable from TodosScreen:
  #   :new_todo       — Navigate(:todo_editor, params: {todo_id: "0"})
  #   :edit_row       — Navigate(:todo_editor, params: {todo_id: <action_params["todo_id"]>})
  #   :delete_row     — mutate Voyager.state, Rerender
  #   :toggle_row     — flip Todo.completed, Rerender
  #   :open_settings  — Navigate(:settings)
  #   :archive_row    — Phase 10D-refocus: leading-swipe Archive tile
  #                     hides the row from visible_todos, Rerender.
  #   :share_row      — Phase 10D-refocus: trailing-swipe Share tile
  #                     fires Class C :copy_to_clipboard intent.
  #   :print_list     — Phase 10D-refocus: toolbar Print button fires
  #                     Class C :print intent with formatted list.
  #   :move_row       — Phase 10D-refocus: long-press-drag reorder
  #                     reads action_params["from"] + ["to"] visible
  #                     indexes, mutates state, Rerender.
  class TodosController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :new_todo        then new_todo(context)
      when :edit_row        then edit_row(context)
      when :delete_row      then delete_row(context)
      when :toggle_row      then toggle_row(context)
      when :open_settings   then open_settings(context)
      when :open_agent_chat then open_agent_chat(context)
      when :archive_row     then archive_row(context)
      when :share_row       then share_row(context)
      when :print_list      then print_list(context)
      when :move_row        then move_row(context)
        # Phase 10D-polish B1 — Alert (delete confirmation flow).
      when :request_delete then request_delete(context)
      when :confirm_delete then confirm_delete(context)
      when :cancel_pending then cancel_pending(context)
        # Phase 10D-polish B2 — ActionSheet (share flow).
      when :request_share       then request_share(context)
      when :copy_pending_share  then copy_pending_share(context)
      when :print_pending_share then print_pending_share(context)
        # Phase 10D-polish B3 — Sheet (editor as modal).
      when :open_editor_sheet  then open_editor_sheet(context)
      when :close_editor_sheet then close_editor_sheet(context)
      when :save_sheet         then save_sheet(context)
        # Phase 10D-polish B5 — Popover (overflow menu).
      when :show_overflow         then show_overflow(context)
      when :hide_overflow         then hide_overflow(context)
      when :sort_by_deadline      then sort_by_deadline(context)
      when :toggle_hide_completed then toggle_hide_completed(context)
      when :clear_all_completed   then clear_all_completed(context)
      else
        raise UI::Controller::UnknownActionError.new(
          "TodosController has no action :#{name}"
        )
      end
    end

    # Phase 10D-polish B3 — :new_todo now opens the editor SHEET instead
    # of pushing a full editor screen. The Sheet modal renders inline as
    # the screen tree decorates the root with `.sheet(isPresented:)`.
    # The legacy navigate-to-editor path is preserved by setting state to
    # 0 (new draft) — the screen reads `pending_editor_todo_id` to know
    # whether to render the sheet.
    def new_todo(context : UI::ScreenContext::Native) : UI::ActionResult
      Voyager.state.pending_editor_todo_id = 0
      UI::ActionResult::Rerender.new
    end

    # Phase 10D-polish B3 — :edit_row now triggers the editor SHEET
    # instead of navigating to a new screen. Sets `pending_editor_todo_id`
    # to the target id; the todos screen renders a `UI::Sheet` wrapping
    # the editor view when this value is set.
    def edit_row(context : UI::ScreenContext::Native) : UI::ActionResult
      id_str = context.action_params["todo_id"]? || "0"
      id = id_str.to_i? || 0
      Voyager.state.pending_editor_todo_id = id
      UI::ActionResult::Rerender.new
    end

    # Phase 10D-polish B1 — :delete_row routes through the Alert
    # confirmation flow. The original immediate-delete path is preserved
    # as `:confirm_delete` (invoked by the Alert's destructive button).
    def delete_row(context : UI::ScreenContext::Native) : UI::ActionResult
      id = (context.action_params["todo_id"]? || "0").to_i? || 0
      Voyager.state.delete_todo(id)
      UI::ActionResult::Rerender.new
    end

    def toggle_row(context : UI::ScreenContext::Native) : UI::ActionResult
      id = (context.action_params["todo_id"]? || "0").to_i? || 0
      if todo = Voyager.state.find_todo(id)
        todo.completed = !todo.completed
      end
      UI::ActionResult::Rerender.new
    end

    def open_settings(context : UI::ScreenContext::Native) : UI::ActionResult
      UI::ActionResult::Navigate.new(:settings)
    end

    # Navigate to the cross-platform Agent Chat surface.
    def open_agent_chat(context : UI::ScreenContext::Native) : UI::ActionResult
      UI::ActionResult::Navigate.new(:agent_chat)
    end

    # Phase 10D-refocus — leading-swipe Archive action.
    def archive_row(context : UI::ScreenContext::Native) : UI::ActionResult
      id = (context.action_params["todo_id"]? || "0").to_i? || 0
      Voyager.state.archive_todo(id)
      UI::ActionResult::Rerender.new
    end

    # Phase 10D-refocus — Share via Class C :copy_to_clipboard intent.
    # We dispatch and ignore the DispatchResult (clipboard write is
    # fire-and-forget). Returning Rerender keeps the UI consistent.
    def share_row(context : UI::ScreenContext::Native) : UI::ActionResult
      id = (context.action_params["todo_id"]? || "0").to_i? || 0
      if todo = Voyager.state.find_todo(id)
        text = todo.deadline.empty? ? todo.title : "#{todo.title} (due #{todo.deadline})"
        UI::SystemAction.perform(:copy_to_clipboard, text: text)
      end
      UI::ActionResult::Rerender.new
    end

    # Phase 10D-refocus — Print toolbar action. Builds a formatted
    # list of all visible todos and dispatches :print as Class C.
    def print_list(context : UI::ScreenContext::Native) : UI::ActionResult
      todos = Voyager.state.visible_todos
      lines = todos.map_with_index do |t, i|
        status = t.completed ? "[x]" : "[ ]"
        deadline_str = t.deadline.empty? ? "" : " (due #{t.deadline})"
        "#{i + 1}. #{status} #{t.title}#{deadline_str}"
      end
      text = "Todos\n=====\n" + lines.join("\n")
      UI::SystemAction.perform(:print, text: text)
      UI::ActionResult::Rerender.new
    end

    # Phase 10D-refocus — reorder action wired to the iOS list
    # long-press-drag gesture. action_params carries the from/to
    # indexes into `visible_todos`. The on-screen list is rebuilt
    # from the mutated state.
    def move_row(context : UI::ScreenContext::Native) : UI::ActionResult
      from = (context.action_params["from"]? || "-1").to_i? || -1
      to = (context.action_params["to"]? || "-1").to_i? || -1
      Voyager.state.move_todo(from, to)
      UI::ActionResult::Rerender.new
    end

    # Phase 10D-polish B1 — Alert confirmation flow.
    # The trailing-swipe Delete tile dispatches :request_delete with the
    # row's todo_id. We set the pending flag; the screen reads it and
    # renders a `UI::Alert` with Cancel + Delete (destructive). The
    # Alert's Delete button dispatches :confirm_delete which performs
    # the actual mutation; Cancel dispatches :cancel_pending.
    def request_delete(context : UI::ScreenContext::Native) : UI::ActionResult
      id = (context.action_params["todo_id"]? || "0").to_i? || 0
      Voyager.state.pending_delete_todo_id = id
      UI::ActionResult::Rerender.new
    end

    def confirm_delete(context : UI::ScreenContext::Native) : UI::ActionResult
      if id = Voyager.state.pending_delete_todo_id
        Voyager.state.delete_todo(id)
      end
      Voyager.state.pending_delete_todo_id = nil
      UI::ActionResult::Rerender.new
    end

    # Generic dismiss for any pending modal (Alert / ActionSheet / Sheet
    # cancel paths all clear their respective pending flag).
    def cancel_pending(context : UI::ScreenContext::Native) : UI::ActionResult
      Voyager.state.pending_delete_todo_id = nil
      Voyager.state.pending_share_todo_id = nil
      Voyager.state.show_overflow_menu = false
      UI::ActionResult::Rerender.new
    end

    # Phase 10D-polish B2 — ActionSheet share flow.
    # The trailing-swipe Share tile dispatches :request_share with the
    # row's todo_id. We set the pending flag; the screen renders a
    # `UI::ActionSheet` with Copy / Print / Cancel. Each chosen action
    # dispatches the corresponding controller method, which performs
    # the work AND clears the pending flag.
    def request_share(context : UI::ScreenContext::Native) : UI::ActionResult
      id = (context.action_params["todo_id"]? || "0").to_i? || 0
      Voyager.state.pending_share_todo_id = id
      UI::ActionResult::Rerender.new
    end

    def copy_pending_share(context : UI::ScreenContext::Native) : UI::ActionResult
      if id = Voyager.state.pending_share_todo_id
        if todo = Voyager.state.find_todo(id)
          text = todo.deadline.empty? ? todo.title : "#{todo.title} (due #{todo.deadline})"
          UI::SystemAction.perform(:copy_to_clipboard, text: text)
        end
      end
      Voyager.state.pending_share_todo_id = nil
      UI::ActionResult::Rerender.new
    end

    def print_pending_share(context : UI::ScreenContext::Native) : UI::ActionResult
      if id = Voyager.state.pending_share_todo_id
        if todo = Voyager.state.find_todo(id)
          deadline_str = todo.deadline.empty? ? "" : " (due #{todo.deadline})"
          status = todo.completed ? "[x]" : "[ ]"
          text = "#{status} #{todo.title}#{deadline_str}"
          UI::SystemAction.perform(:print, text: text)
        end
      end
      Voyager.state.pending_share_todo_id = nil
      UI::ActionResult::Rerender.new
    end

    # Phase 10D-polish B3 — Sheet (editor presentation).
    # The slug-pushed editor flow is preserved for fallback; the primary
    # path now sets `pending_editor_todo_id` and the screen wraps the
    # editor view in a `UI::Sheet`. Cancel + Save both dispatch
    # :close_editor_sheet to clear the flag.
    def open_editor_sheet(context : UI::ScreenContext::Native) : UI::ActionResult
      id_str = context.action_params["todo_id"]? || "0"
      Voyager.state.pending_editor_todo_id = id_str.to_i? || 0
      UI::ActionResult::Rerender.new
    end

    def close_editor_sheet(context : UI::ScreenContext::Native) : UI::ActionResult
      Voyager.state.pending_editor_todo_id = nil
      UI::ActionResult::Rerender.new
    end

    # Phase 10D-polish B3 — Save action for the in-sheet editor. Reads
    # FormState[title|note|deadline|completed] (seeded by the sheet's
    # build_editor_content) and mutates the matching todo (or creates a
    # new one when pending_editor_todo_id == 0). Closes the sheet on
    # success.
    def save_sheet(context : UI::ScreenContext::Native) : UI::ActionResult
      fs = context.form_state
      title = fs["title"]? || ""
      note = fs["note"]? || ""
      deadline = fs["deadline"]? || ""
      completed = (fs["completed"]? || "false") == "true"

      if title.strip.empty?
        # No-op — the disabled save button should normally prevent this,
        # but a defensive guard keeps the sheet open without mutating.
        return UI::ActionResult::Rerender.new
      end

      editor_id = Voyager.state.pending_editor_todo_id || 0
      if editor_id == 0
        Voyager.state.add_todo(title, note, completed, deadline)
      else
        if todo = Voyager.state.find_todo(editor_id)
          todo.title = title
          todo.note = note
          todo.completed = completed
          todo.deadline = deadline
        end
      end
      Voyager.state.pending_editor_todo_id = nil
      UI::ActionResult::Rerender.new
    end

    # Phase 10D-polish B5 — Popover overflow menu.
    # The toolbar "•••" button toggles `show_overflow_menu`. The screen
    # renders a `UI::Popover` anchored to the button when set. Each
    # menu option dispatches its action (which clears the flag).
    def show_overflow(context : UI::ScreenContext::Native) : UI::ActionResult
      Voyager.state.show_overflow_menu = true
      UI::ActionResult::Rerender.new
    end

    def hide_overflow(context : UI::ScreenContext::Native) : UI::ActionResult
      Voyager.state.show_overflow_menu = false
      UI::ActionResult::Rerender.new
    end

    # Sort visible todos by deadline ascending (todos with no deadline
    # at the end). Mutates state.todos so the order persists across
    # rerenders.
    def sort_by_deadline(context : UI::ScreenContext::Native) : UI::ActionResult
      Voyager.state.sort_by_deadline!
      Voyager.state.show_overflow_menu = false
      UI::ActionResult::Rerender.new
    end

    def toggle_hide_completed(context : UI::ScreenContext::Native) : UI::ActionResult
      Voyager.state.hide_completed = !Voyager.state.hide_completed
      Voyager.state.show_overflow_menu = false
      UI::ActionResult::Rerender.new
    end

    def clear_all_completed(context : UI::ScreenContext::Native) : UI::ActionResult
      Voyager.state.clear_completed_todos
      Voyager.state.show_overflow_menu = false
      UI::ActionResult::Rerender.new
    end
  end
end
