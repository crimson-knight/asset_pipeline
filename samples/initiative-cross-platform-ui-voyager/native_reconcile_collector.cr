# Shared, collector-neutral logical-tree reconciliation plan for Voyager's
# native hosts. It deliberately stages all native writes before the caller
# performs one, so a structural mismatch cannot leave a partially updated UI.

require "../../src/ui"

module Voyager
  module NativeReconcileCollector
    enum CommitMode
      # Historical behavior: write every label after a successful structural
      # walk, even if its text did not change.
      AllLabelCommit
      # Production behavior: write only labels whose prior and current text
      # differ. Text fields remain outside this collector to preserve focus and
      # their live editing buffer.
      DirtyLabelCommit
    end

    alias Op = Tuple(Void*, String)

    # Retains the last successfully mounted logical tree. Native handles alone
    # cannot tell whether a leaf is dirty; this is the required second input to
    # a correct three-way reconciliation (prior logical, current logical,
    # mounted native). The prior tree advances only after a fully staged and
    # successfully committed update.
    class Session
      getter previous : UI::View?

      @previous : UI::View?

      def initialize
        @previous = nil
      end

      def replace!(view : UI::View) : Nil
        @previous = view
      end

      def collect(current : UI::View, native : UI::NativeView, ops : Array(Op), mode : CommitMode) : Int32?
        prior = @previous
        return nil if prior.nil?
        NativeReconcileCollector.collect(prior, current, native, ops, mode)
      end

      def commit!(current : UI::View) : Nil
        @previous = current
      end

      def reset! : Nil
        @previous = nil
      end
    end

    # Returns the number of label leaves structurally visited, or nil for a
    # mismatch. `ops` is empty on failure. Its writes are intentionally staged
    # rather than committed here.
    def self.collect(previous : UI::View, current : UI::View, native : UI::NativeView, ops : Array(Op), mode : CommitMode) : Int32?
      ops.clear
      visits = collect_inner(previous, current, native, ops, mode)
      unless visits
        ops.clear
        return nil
      end
      visits
    end

    private def self.collect_inner(previous : UI::View, current : UI::View, native : UI::NativeView, ops : Array(Op), mode : CommitMode) : Int32?
      return nil if native.state.torn_down? || native.handle.released?
      native_kind = native.view_kind
      return nil if native_kind.nil? || native_kind != previous.reconcile_kind || native_kind != current.reconcile_kind

      visits = 0
      if current.is_a?(UI::Label)
        return nil unless previous.is_a?(UI::Label)
        state = native.handle.state_handle
        return nil if state.nil? || state.null?
        visits = 1
        if mode.all_label_commit? || previous.text != current.text
          ops << {state, current.text}
        end
      end

      previous_children = previous.reconcile_children
      current_children = current.reconcile_children
      return nil unless previous_children.size == current_children.size
      return nil unless current_children.size == native.children.size

      current_children.each_with_index do |child, index|
        child_visits = collect_inner(previous_children[index], child, native.children[index], ops, mode)
        return nil if child_visits.nil?
        visits += child_visits
      end
      visits
    end
  end
end
