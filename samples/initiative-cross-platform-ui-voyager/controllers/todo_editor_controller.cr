module Voyager
  # Phase 8D.1 — TodoEditorController.
  #
  # Owns the editor's :save and :cancel actions.
  # :save reads context.params["todo_id"] (the Navigate-supplied route
  # params seeded into the mount's FormState by the dispatcher),
  # context.form_state["title"] (TextField-wired), and
  # context.form_state["completed"] (Toggle on_change writes here).
  # If todo_id resolves to an existing todo, mutates it in place.
  # Otherwise adds a fresh todo from the form values. Returns Pop in
  # both success cases.
  class TodoEditorController < UI::Controller
    def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
      case name
      when :save   then save(context)
      when :cancel then cancel(context)
      else
        raise UI::Controller::UnknownActionError.new(
          "TodoEditorController has no action :#{name}"
        )
      end
    end

    def save(context : UI::ScreenContext::Native) : UI::ActionResult
      todo_id_str = context.params["todo_id"]? || "0"
      todo_id = todo_id_str.to_i? || 0
      title = (context.form_state.values["title"]? || "").strip
      note = context.form_state.values["note"]? || ""
      completed = context.form_state.values["completed"]? == "true"

      # Save with blank title is a controller-level no-op. The view
      # disables the Save button while blank as the primary UX, but a
      # renderer that ignores the disabled flag would still post a
      # dispatch — we defensively pop without mutating.
      if title.empty?
        return UI::ActionResult::Pop.new
      end

      if existing = Voyager.state.find_todo(todo_id)
        existing.title = title
        existing.note = note
        existing.completed = completed
      else
        Voyager.state.add_todo(title, note, completed)
      end

      UI::ActionResult::Pop.new
    end

    def cancel(context : UI::ScreenContext::Native) : UI::ActionResult
      UI::ActionResult::Pop.new
    end
  end
end
