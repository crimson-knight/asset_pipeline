module Voyager
  # A single todo item — id, title, optional note, completed flag,
  # optional deadline (ISO-8601 date string YYYY-MM-DD or empty),
  # archived flag (Phase 10D-refocus: archive swipe action moves rows
  # off the main list without deleting them).
  class Todo
    property id : Int32
    property title : String
    property note : String
    property completed : Bool
    property deadline : String
    property archived : Bool

    def initialize(
      @id : Int32,
      @title : String,
      @note : String = "",
      @completed : Bool = false,
      @deadline : String = "",
      @archived : Bool = false,
    )
    end
  end

  # Voyager's shared app state. Held by the NavigationCoordinator's
  # owning module-level VoyagerApp instance (NOT a class var with
  # initializer — per I-9 + the iOS class-init gap memory).
  #
  # State mutations (e.g. Settings toggle of `hide_completed`) take
  # effect AFTER the coordinator's on_change fires, so the visible
  # route is rebuilt from the new state. This is the state-propagation
  # litmus path:
  #   Settings toggle → state.hide_completed = true → coord.pop →
  #   coord notifies → host rebuilds Todos route with filtered list +
  #   recalculated chart counts.
  # A single message in the Agent Chat transcript.
  class ChatMessage
    property text : String
    property is_agent : Bool

    def initialize(@text : String, @is_agent : Bool)
    end
  end

  class State
    property current_user : String = ""
    property todos : Array(Todo)
    property hide_completed : Bool = false
    # Daily Check-in surface (CheckInScreen) — exercises the interactive control widgets
    # (Slider / Stepper / Toggle) cohesively across platforms. Primitive defaults are set
    # when State.new runs (HostBootstrap.build), so no class-init-gap concern.
    property checkin_mood : Int32 = 7        # 0..10, via Slider
    property checkin_goal : Int32 = 5        # daily task goal, via Stepper
    property checkin_reminder : Bool = true  # remind tomorrow, via Toggle
    property checkin_focus_index : Int32 = 0 # focus area, via Picker (see .checkin_focuses)
    # Feedback line shown after Save: reflects the REAL outcome of scheduling /
    # cancelling the daily check-in local notification (see CheckInController#save_checkin).
    # Empty until the user saves. Honest signal — derived from UI::Notifications
    # pending state, not a synthetic "saved" flag.
    property checkin_status : String = ""
    # Whether the agent reads its chat replies aloud (UI::Speech). Toggled by the
    # speaker control in the Agent Chat header; gates AgentChatController's auto-speak.
    property speak_replies : Bool = true

    # Coaching focus areas offered by the check-in Picker. A METHOD, not a constant: a
    # class-level `CHECKIN_FOCUSES = [...]` array literal is NOT reliably initialized on
    # iOS (the class-init gap skips constant initializers when _main is hidden for Swift
    # @main — the same trap that crashed SystemAction's WEB_UNWIRED_INTENTS). Building the
    # array at call time sidesteps it entirely.
    def self.checkin_focuses : Array(String)
      ["Sleep", "Movement", "Nutrition", "Mindfulness"]
    end

    # Agent Chat transcript (the cross-platform agent-chat surface). A nilable
    # default would be safest for the iOS class-init gap, but it's assigned in
    # `initialize` (instance init runs in voyager_init via HostBootstrap.build),
    # so a typed Array property seeded there is fine.
    property chat_messages : Array(ChatMessage) = [] of ChatMessage
    @next_id : Int32 = 1

    # Phase 10D-polish — transient UI flags driving the catalog widget
    # demos integrated into the todos flow. Each flag is set by an
    # action (delete swipe, share swipe, edit tap, overflow menu) and
    # cleared when the corresponding modal dismisses.
    #
    # Why this lives on State (not on the screen) — Voyager's screen
    # build(ctx) returns a fresh tree on every Rerender, so any
    # screen-local @ivar would be reset. The dispatcher's Rerender
    # action result re-renders the active route from the state we
    # mutate here.
    property pending_delete_todo_id : Int32? = nil # B1 — Alert
    property pending_share_todo_id : Int32? = nil  # B2 — ActionSheet
    property pending_editor_todo_id : Int32? = nil # B3 — Sheet (nil = closed; 0 = new draft; >0 = edit)
    property show_overflow_menu : Bool = false     # B5 — Popover

    def initialize
      @todos = [] of Todo
      # Seed with a few items so the demo has visible content on
      # first launch (and the chart isn't empty).
      add_todo("Buy groceries", "Eggs, milk, bread", false)
      add_todo("Finish quarterly report", "Due Friday", false)
      add_todo("Call dentist", "", true)
      add_todo("Read a book", "Foundation, ch 3-5", false)
      add_todo("Water plants", "", true)

      # Seed the agent-chat transcript so the surface has content on first open.
      @chat_messages = [
        ChatMessage.new("Morning! Your first meeting moved to 10:00.", true),
        ChatMessage.new("Thanks — remind me at 9:45", false),
        ChatMessage.new("Done. I'll buzz your wrist at 9:45.", true),
      ]
    end

    # Append a user message to the transcript, plus a canned agent acknowledgement
    # so a Send feels like a real exchange. Returns nothing; the screen re-reads
    # `chat_messages` on the next render.
    def send_chat_message(text : String) : Nil
      trimmed = text.strip
      return if trimmed.empty?
      @chat_messages << ChatMessage.new(trimmed, false)
      @chat_messages << ChatMessage.new("On it — I'll take care of that.", true)
    end

    def add_todo(
      title : String,
      note : String = "",
      completed : Bool = false,
      deadline : String = "",
    ) : Todo
      todo = Todo.new(@next_id, title, note, completed, deadline, false)
      @next_id += 1
      @todos << todo
      todo
    end

    def find_todo(id : Int32) : Todo?
      @todos.find { |t| t.id == id }
    end

    def delete_todo(id : Int32) : Nil
      @todos.reject! { |t| t.id == id }
    end

    # Phase 10D-refocus — archive workflow. Toggling archived hides
    # the row from `visible_todos` without losing the entry. The
    # leading-swipe Archive action calls this; an unarchive workflow
    # is deferred to a later slice.
    def archive_todo(id : Int32) : Nil
      if todo = find_todo(id)
        todo.archived = true
      end
    end

    def unarchive_todo(id : Int32) : Nil
      if todo = find_todo(id)
        todo.archived = false
      end
    end

    # Phase 10D-refocus — move a row from one position to another so
    # the long-press-drag reorder gesture has a backing mutation. The
    # `from` / `to` indexes are positions within the `visible_todos`
    # filtered view (the user can only see and drag what's visible),
    # so we map them back into the underlying `@todos` indexes before
    # mutating.
    def move_todo(from_visible_index : Int32, to_visible_index : Int32) : Nil
      vis = visible_todos
      return if from_visible_index < 0 || from_visible_index >= vis.size
      return if to_visible_index < 0 || to_visible_index >= vis.size
      return if from_visible_index == to_visible_index

      moving = vis[from_visible_index]
      target = vis[to_visible_index]
      from_idx = @todos.index(moving)
      to_idx = @todos.index(target)
      return unless from_idx && to_idx

      @todos.delete_at(from_idx)
      # After delete, the to_idx may shift left by one if from_idx < to_idx.
      adjusted_to = from_idx < to_idx ? to_idx - 1 : to_idx
      @todos.insert(adjusted_to, moving)
    end

    # The currently visible todos, after the Settings filter is
    # applied. Phase 10D-refocus also hides archived rows.
    def visible_todos : Array(Todo)
      list = @todos.reject(&.archived)
      return list unless @hide_completed
      list.reject(&.completed)
    end

    # Phase 10D-refocus — archived rows for the Settings → Archived
    # screen (future). Exposed now for symmetry with `visible_todos`.
    def archived_todos : Array(Todo)
      @todos.select(&.archived)
    end

    # Open count over the visible todos (so the chart reflects the
    # filtered list when hide_completed is on — matches the brief's
    # state-propagation litmus: "Todos list AND chart reflect"
    # means the chart numbers move when filtering kicks in).
    def open_count : Int32
      visible_todos.count { |t| !t.completed }
    end

    def completed_count : Int32
      visible_todos.count(&.completed)
    end

    # Underlying counts (full list, regardless of filter) — exposed
    # for callers that need the unfiltered totals.
    def open_count_total : Int32
      @todos.count { |t| !t.completed }
    end

    def completed_count_total : Int32
      @todos.count(&.completed)
    end

    # Phase 10D-polish B5 — overflow menu actions.
    # Sort by deadline ascending; todos with no deadline (empty string)
    # sink to the end. ISO-8601 (YYYY-MM-DD) sorts lexicographically so
    # we use the raw string.
    def sort_by_deadline! : Nil
      @todos.sort! do |a, b|
        a_empty = a.deadline.empty?
        b_empty = b.deadline.empty?
        if a_empty && b_empty
          0
        elsif a_empty
          1
        elsif b_empty
          -1
        else
          a.deadline <=> b.deadline
        end
      end
    end

    def clear_completed_todos : Nil
      @todos.reject!(&.completed)
    end
  end

  # Phase 8D.1 — Voyager.state module singleton.
  #
  # The new `UI::Screen` API hands screens a `ScreenContext::Native` and
  # NO direct `state` reference. So Voyager screens reach into the
  # process-wide `Voyager::State` via this accessor. macOS host sets it
  # once in `VoyagerHost.run!`; the `Voyager.build_route` compat shim
  # sets it on every call (so existing test specs that construct a fresh
  # `state = Voyager::State.new` and pass it through the shim continue to
  # exercise the same state-propagation contract).
  #
  # iOS class-init gap (see `project_crystal_ios_class_init_gap` memory):
  # we deliberately AVOID a default-initialiser class var. The accessor
  # lazy-allocates a default `State.new` on first read so even targets
  # that skip module-load side effects work.
  @@state : State? = nil

  def self.state : State
    @@state ||= State.new
  end

  def self.state=(new_state : State) : State
    @@state = new_state
  end
end
