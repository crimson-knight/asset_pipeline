# Layout-only view that expands to fill remaining space along a stack's axis.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # A flexible space that expands to fill available room in a stack.
  #
  # When placed inside a VStack or HStack, Spacer pushes adjacent
  # views apart. An optional `min_length` sets a minimum size.
  class Spacer < View
    # Minimum length of the spacer in points
    property min_length : Float64 = 0.0

    def initialize(@min_length : Float64 = 0.0)
      # A Spacer's whole job is to absorb slack along the stack axis. On the
      # AppKit renderer that requires (a) the spacer to have low content-hugging
      # so NSStackView stretches IT (not sibling content), and (b) the enclosing
      # HStack to use Fill distribution. Both are already wired to
      # `fill_horizontal`: apply_common_properties lowers the hugging priority,
      # and the HStack switches to Fill distribution when `any?(&.fill_horizontal)`.
      # Without this, `HStack { Spacer; content; Spacer }` stayed GravityAreas and
      # the spacers collapsed — so the canonical center-an-element idiom did
      # nothing (content hugged to one side). Defaulting it on makes Spacer space.
      @fill_horizontal = true
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
