require "../views/navigation_stack"

module UI::Android
  # A render's visible navigation scopes, containing Crystal views only. Native
  # views and callback IDs belong to NativeView and are never retained here.
  # For independent sibling stacks, the last rendered eligible stack wins Back.
  class NavigationState
    record Entry, stack : UI::NavigationStack, ancestors : Array(Tuple(UI::NavigationStack, UI::View))

    @entries = [] of Entry
    @scopes = [] of UI::NavigationStack

    def within(stack : UI::NavigationStack, &block : ->) : Nil
      raise ArgumentError.new("Cyclic Android navigation hierarchy") if @scopes.includes?(stack)
      @entries << Entry.new(stack, @scopes.map { |scope| {scope, scope.current_view} }) unless stack.hidden
      @scopes << stack
      begin
        yield
      ensure
        @scopes.pop
      end
    end

    def current_stack : UI::NavigationStack?
      @scopes.last?
    end

    def can_go_back? : Bool
      !back_entry.nil?
    end

    def go_back : Bool
      if entry = back_entry
        entry.stack.pop
        true
      else
        false
      end
    end

    # Reject a second tap on an outgoing (not yet unmounted) screen, including
    # links whose enclosing stack has already navigated out of view.
    def push_link(stack : UI::NavigationStack, source : UI::View, destination : UI::View) : Nil
      return unless actionable?(stack, source)
      stack.push(destination)
    end

    def pop_stack(stack : UI::NavigationStack, source : UI::View) : Nil
      stack.pop if actionable?(stack, source)
    end

    private def actionable?(stack : UI::NavigationStack, source : UI::View) : Bool
      stack.current_view.same?(source) && @entries.any? { |entry| entry.stack.same?(stack) && visible?(entry) }
    end

    private def visible?(entry : Entry) : Bool
      !entry.stack.hidden && entry.ancestors.all? { |(ancestor, screen)| !ancestor.hidden && ancestor.current_view.same?(screen) }
    end

    private def back_entry : Entry?
      @entries.reverse_each.find { |entry| !entry.stack.stack.empty? && visible?(entry) }
    end
  end
end
