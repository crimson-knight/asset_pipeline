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
      when :new_todo       then new_todo(context)
      when :edit_row       then edit_row(context)
      when :delete_row     then delete_row(context)
      when :toggle_row     then toggle_row(context)
      when :open_settings  then open_settings(context)
      when :archive_row    then archive_row(context)
      when :share_row      then share_row(context)
      when :print_list     then print_list(context)
      when :move_row       then move_row(context)
      else
        raise UI::Controller::UnknownActionError.new(
          "TodosController has no action :#{name}"
        )
      end
    end

    def new_todo(context : UI::ScreenContext::Native) : UI::ActionResult
      UI::ActionResult::Navigate.new(
        :todo_editor,
        {:todo_id => "0"} of Symbol => String
      )
    end

    def edit_row(context : UI::ScreenContext::Native) : UI::ActionResult
      todo_id = context.action_params["todo_id"]? || "0"
      UI::ActionResult::Navigate.new(
        :todo_editor,
        {:todo_id => todo_id} of Symbol => String
      )
    end

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
  end
end
