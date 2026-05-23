module Voyager
  # A single todo item — id, title, optional note, completed flag.
  class Todo
    property id : Int32
    property title : String
    property note : String
    property completed : Bool

    def initialize(@id : Int32, @title : String, @note : String = "", @completed : Bool = false)
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
  class State
    property current_user : String = ""
    property todos : Array(Todo)
    property hide_completed : Bool = false
    @next_id : Int32 = 1

    def initialize
      @todos = [] of Todo
      # Seed with a few items so the demo has visible content on
      # first launch (and the chart isn't empty).
      add_todo("Buy groceries", "Eggs, milk, bread", false)
      add_todo("Finish quarterly report", "Due Friday", false)
      add_todo("Call dentist", "", true)
      add_todo("Read a book", "Foundation, ch 3-5", false)
      add_todo("Water plants", "", true)
    end

    def add_todo(title : String, note : String = "", completed : Bool = false) : Todo
      todo = Todo.new(@next_id, title, note, completed)
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

    # The currently visible todos, after the Settings filter is
    # applied. This is the field the state-propagation litmus
    # exercises: toggling hide_completed in Settings + popping back
    # to Todos must immediately use the filtered result.
    def visible_todos : Array(Todo)
      return @todos unless @hide_completed
      @todos.reject(&.completed)
    end

    def open_count : Int32
      @todos.count { |t| !t.completed }
    end

    def completed_count : Int32
      @todos.count(&.completed)
    end
  end
end
