module Voyager
  # Voyager — Todo Editor screen.
  #
  # Phase 8D.1: migrated from module-level class with
  # `build(state, coord, todo_id)` to `UI::Screen` subclass with
  # `build(ctx : UI::ScreenContext) : UI::View`. The todo_id arrives via
  # `ctx.params["todo_id"]` — when the dispatcher mounts this screen via
  # `Navigate.new(:todo_editor, params: {todo_id: "5"})`, it seeds the
  # mount FormState with that key. `ctx.params == ctx.form_state.to_h`
  # on native.
  #
  # Title TextField uses `name: "title"` so the renderer's FormState
  # hook records typed values; `TodoEditorController#save` reads
  # `ctx.form_state["title"]`. The completed Toggle has no renderer
  # FormState hook (Phase 8B only ships hooks for TextField + SecureField),
  # so the screen manually writes its value into FormState under
  # `"completed"` via the dispatcher's current_form_state.
  class TodoEditorScreen < UI::Screen
    SLUG = "voyager-todo-editor"

    def build(context : UI::ScreenContext) : UI::View
      state = Voyager.state

      # Phase 8D.1 — read the route-supplied todo_id from FormState
      # (the dispatcher mounted the screen with route.params seeded
      # into form_state, keyed by string). Treat absent / non-numeric
      # / "0" as a new-todo signal (blank draft).
      todo_id_str = context.params["todo_id"]? || "0"
      todo_id = todo_id_str.to_i? || 0
      editing = state.find_todo(todo_id)

      # On a fresh mount, seed the title + completed FormState entries
      # from the live editing target so the field renders with the
      # current values. The renderer's FormState hook for TextField will
      # `register` (idempotent for already-set entries) and update on
      # type. Toggle's on_change writes its own value into FormState via
      # the dispatcher accessor (see below).
      seed_title = editing ? editing.title : ""
      seed_completed = editing ? editing.completed : false
      seed_note = editing ? editing.note : ""
      # Phase 10D-refocus — optional deadline (ISO YYYY-MM-DD or empty).
      seed_deadline = editing ? editing.deadline : ""
      d = Voyager.dispatcher
      unless d.nil?
        fs = d.current_form_state
        fs.register("title", seed_title)
        fs.register("note", seed_note)
        fs.register("completed", seed_completed ? "true" : "false")
        fs.register("deadline", seed_deadline)
      end

      # Phase D Track 2 — whole-composition adapt via DeviceMetrics#responsive
      # (width/spacing/padding/title type). half_button_width derives from
      # content_width so the action row reflows with it.
      metrics = UI::DesignTokens::DeviceMetrics.current
      content_width = metrics.responsive(compact: 340.0, regular: 480.0)
      pad_h = metrics.responsive(compact: 20.0, regular: 28.0)
      pad_v = metrics.responsive_vertical(compact: 16.0, regular: 32.0)
      root = UI::VStack.new(spacing: metrics.responsive_vertical(compact: 10.0, regular: 18.0))
      root.root_fill = true
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(
        top: pad_v + metrics.safe_area_top_pt,
        trailing: pad_h + metrics.safe_area_trailing_pt,
        bottom: pad_v + metrics.safe_area_bottom_pt,
        leading: pad_h + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Voyager todo editor"
      root.test_id = "voyager-todo-editor-root"

      title_label = UI::Label.new(editing ? "Edit todo" : "New todo")
      title_label.font = UI::Font.new(size: metrics.responsive(compact: 22.0, regular: 26.0), weight: :bold)
      title_label.maximum_width = content_width

      # Phase 10D-final D5 — completion styling on the detail title.
      # When the editing todo is already completed, the header label
      # uses Secondary role + strikethrough so the state reads at a
      # glance, matching the list-row visual contract.
      if editing && seed_completed
        title_label.text_color_role = UI::LabelRole::Secondary
        title_label.strikethrough = true
      end

      title_field = UI::TextField.new(placeholder: "Title", name: "title")
      title_field.text = seed_title
      title_field.accessibility_label = "Todo title"
      title_field.test_id = "voyager-todo-editor-title"
      title_field.minimum_width = content_width
      title_field.maximum_width = content_width

      note_field = UI::TextField.new(placeholder: "Note (optional)", name: "note")
      note_field.text = seed_note
      note_field.accessibility_label = "Todo note"
      note_field.test_id = "voyager-todo-editor-note"
      note_field.minimum_width = content_width
      note_field.maximum_width = content_width

      # Phase 10D-refocus — optional deadline field. Plain text field
      # (YYYY-MM-DD format expected); a native DatePicker bridge for
      # cross-platform deadline parsing is a follow-up. The text-field
      # path is sufficient for the hand-test acceptance.
      deadline_field = UI::TextField.new(placeholder: "Deadline (YYYY-MM-DD, optional)", name: "deadline")
      deadline_field.text = seed_deadline
      deadline_field.accessibility_label = "Todo deadline"
      deadline_field.test_id = "voyager-todo-editor-deadline"
      deadline_field.minimum_width = content_width
      deadline_field.maximum_width = content_width

      completed_toggle = UI::Toggle.new(label: "Completed", is_on: seed_completed)
      completed_toggle.accessibility_label = "Mark as completed"
      completed_toggle.test_id = "voyager-todo-editor-completed"
      completed_toggle.minimum_width = content_width
      completed_toggle.maximum_width = content_width
      # Toggle has no Phase 8B FormState renderer hook (only TextField +
      # SecureField do). Write the boolean into FormState manually so
      # TodoEditorController#save can read ctx.form_state["completed"].
      completed_toggle.on_change = ->(value : Bool) {
        d2 = Voyager.dispatcher
        unless d2.nil?
          d2.current_form_state.update("completed", value ? "true" : "false")
        end
      }

      actions = UI::HStack.new(spacing: 12.0)
      actions.alignment = UI::Alignment::Center
      actions.minimum_width = content_width
      actions.maximum_width = content_width

      half_button_width = (content_width - 12.0) / 2.0

      cancel = UI::Button.new("Cancel")
      cancel.role = :secondary
      cancel.accessibility_label = "Cancel and discard changes"
      cancel.test_id = "voyager-todo-editor-cancel"
      cancel.minimum_width = half_button_width
      cancel.maximum_width = half_button_width
      cancel.on_tap = -> { Voyager.dispatch(:cancel) }

      save = UI::Button.new("Save", style: UI::ButtonStyle::Prominent)
      save.accessibility_label = "Save todo"
      save.test_id = "voyager-todo-editor-save"
      save.minimum_width = half_button_width
      save.maximum_width = half_button_width
      # Initial disabled state mirrors the seeded title's blank-ness;
      # the live update path is wired by the on_change closure below.
      save.disabled = seed_title.strip.empty?
      save.on_tap = -> { Voyager.dispatch(:save) }

      # Phase 8D.3a — Save-enabled-on-type wiring.
      #
      # View-local affordance: `save.disabled` mirrors title-emptiness
      # on every keystroke. `UI::Button#disabled=` is reactive (see
      # `src/ui/views/button.cr` — propagates through SwiftKit's
      # `apsk_button_set_disabled` so SwiftUI re-renders without a tree
      # rebuild), so a closure assignment is sufficient.
      #
      # Composition with the renderer's FormState hook: the UIKit /
      # AppKit renderer's `visit(UI::TextField)` wraps this proc via
      # `UI::FormStateRendererHook.wrap_text_handler`, which runs
      # `captured_fs.update("title", new_value)` FIRST (domain state),
      # then invokes this closure (view-local affordance). Both writes
      # happen on every keystroke. App/domain state still flows through
      # FormState; this closure only governs the visible affordance.
      title_field.on_change = ->(value : String) {
        save.disabled = value.strip.empty?
      }

      actions << cancel.as(UI::View)
      actions << save.as(UI::View)

      # Phase 10D-final D5 — Mark Done button. Stand-alone full-width
      # button that flips the completed flag and pops back to the list.
      # Only emitted when editing an existing todo (no-op for new draft).
      mark_done_btn : UI::View? = nil
      if editing
        mdb = UI::Button.new(
          seed_completed ? "Mark as Not Done" : "Mark Done",
          style: UI::ButtonStyle::Bordered,
        )
        mdb.accessibility_label = seed_completed ? "Mark this todo as not done" : "Mark this todo as done"
        mdb.test_id = "voyager-todo-editor-mark-done"
        mdb.minimum_width = content_width
        mdb.maximum_width = content_width
        mdb.on_tap = -> { Voyager.dispatch(:mark_done) }
        mark_done_btn = mdb.as(UI::View)
      end

      root << title_label.as(UI::View)
      root << title_field.as(UI::View)
      root << note_field.as(UI::View)
      root << deadline_field.as(UI::View)
      root << completed_toggle.as(UI::View)
      if mdb_view = mark_done_btn
        root << mdb_view
      end
      root << actions.as(UI::View)

      root.as(UI::View)
    end
  end
end
