module Voyager
  # Voyager — Todo Editor screen.
  #
  # Title TextField + note TextField + completed Toggle + Save + Cancel.
  # Route params: `id` = todo id (or "0" for a new todo).
  # Save mutates the todo + coord.pop. Cancel just pops.
  module TodoEditorScreen
    extend self

    SLUG = "voyager-todo-editor"

    def build(state : State, coord : UI::NavigationCoordinator, todo_id : Int32) : UI::View
      # If editing an existing todo, look it up; otherwise create a
      # fresh draft Todo that Save will commit to state.
      editing = state.find_todo(todo_id)
      draft = editing || Todo.new(id: 0, title: "", note: "")

      # Phase 6.10 Rem 4 (Item 2D/2E) — device-aware sizing. Outer
      # root_fill; inner fields still carry an explicit content_width
      # cap so the Save+Cancel half-button math stays meaningful on
      # all devices.
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
      root.accessibility_label = "Voyager todo editor"
      root.test_id = "voyager-todo-editor-root"

      title_label = UI::Label.new(editing ? "Edit todo" : "New todo")
      title_label.font = UI::Font.new(size: 24.0, weight: :bold)

      title_field = UI::TextField.new(placeholder: "Title")
      title_field.text = draft.title
      title_field.accessibility_label = "Todo title"
      title_field.test_id = "voyager-todo-editor-title"
      title_field.minimum_width = content_width
      title_field.maximum_width = content_width
      title_field.on_change = ->(value : String) { draft.title = value }

      note_field = UI::TextField.new(placeholder: "Note (optional)")
      note_field.text = draft.note
      note_field.accessibility_label = "Todo note"
      note_field.test_id = "voyager-todo-editor-note"
      note_field.minimum_width = content_width
      note_field.maximum_width = content_width
      note_field.on_change = ->(value : String) { draft.note = value }

      completed_toggle = UI::Toggle.new(label: "Completed", is_on: draft.completed)
      completed_toggle.accessibility_label = "Mark as completed"
      completed_toggle.test_id = "voyager-todo-editor-completed"
      completed_toggle.minimum_width = content_width
      completed_toggle.maximum_width = content_width
      completed_toggle.on_change = ->(value : Bool) { draft.completed = value }

      actions = UI::HStack.new(spacing: 12.0)
      actions.alignment = UI::Alignment::Center
      actions.minimum_width = content_width
      actions.maximum_width = content_width

      # Half-width buttons so the Cancel + Save row fills the
      # content_width band without stretching to intrinsic-only labels.
      half_button_width = (content_width - 12.0) / 2.0

      cancel = UI::Button.new("Cancel")
      cancel.role = :secondary
      cancel.accessibility_label = "Cancel and discard changes"
      cancel.test_id = "voyager-todo-editor-cancel"
      cancel.minimum_width = half_button_width
      cancel.maximum_width = half_button_width
      cancel.on_tap = -> {
        Voyager.log_interaction("todo-editor cancel tapped")
        coord.pop
        nil
      }

      save = UI::Button.new("Save", style: UI::ButtonStyle::Prominent)
      save.accessibility_label = "Save todo"
      save.test_id = "voyager-todo-editor-save"
      save.minimum_width = half_button_width
      save.maximum_width = half_button_width
      save.on_tap = -> {
        Voyager.log_interaction("todo-editor save tapped")
        if editing
          # Mutate existing in place — draft IS editing, so any
          # changes from on_change closures already applied.
          # No-op here for clarity.
        else
          # Commit the draft as a new todo in state.
          state.add_todo(draft.title, draft.note, draft.completed)
        end
        coord.pop
        nil
      }

      actions << cancel.as(UI::View)
      actions << save.as(UI::View)

      root << title_label.as(UI::View)
      root << title_field.as(UI::View)
      root << note_field.as(UI::View)
      root << completed_toggle.as(UI::View)
      root << actions.as(UI::View)

      # Phase 6.10 Rem 3 (Item 3): framework default in VoyagerHost
      # wraps the root in a UIScrollView when content overflows; see
      # screens/todos.cr for the rationale. Editor sticks with the
      # plain VStack root so the inner content_width pin + half-button
      # math stay authoritative.
      root.as(UI::View)
    end
  end
end
