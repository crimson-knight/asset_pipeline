# Side-panel detail / inspector view. The HIG `inspector` analog — a
# trailing side panel that complements primary content rather than
# replacing it (in contrast to `UI::Sheet`, which is modal).
#
# Per the Phase 9 intent catalog (`:inspector`):
#   - SwiftUI:   `.inspector(isPresented:content:)` (iOS 17+/macOS 14+)
#   - UIKit:     `UISplitViewController` with inspector column
#   - AppKit:    `NSSplitViewController` inspector pane
#   - Android:   No first-class analog; side-panel layout fallback
#   - Web:       CSS grid / flex side panel
#
# `UI::Inspector` is the Phase 10B.4 widget backing the intent. The
# Crystal-side surface is a wrapper holding the primary content plus
# the inspector pane content, the presented flag, and an optional
# preferred width. Native renderers fall back to a horizontal stack
# (primary + inspector) until proper `NSSplitViewController` /
# `UISplitViewController` facades land in a follow-up phase. Web emits
# a CSS-grid layout that mirrors the SwiftUI side-by-side semantics.
#
# Example:
#   inspector = UI::Inspector.new(primary_view, inspector_view)
#   inspector.is_presented = true
#   inspector.preferred_width = 320.0

require "../view"

module UI
  # Inspector — Side-panel detail view that complements primary content.
  # Detail-on-side, never modal. The Phase 10B.4 default for the
  # `:inspector` intent.
  #
  # Compared to `UI::Sheet` (modal, takes focus): the Inspector is a
  # non-modal sibling pane. The primary content remains interactive
  # while the inspector is presented.
  #
  # Compared to `UI::NavigationSplitView` (master/detail navigation):
  # the Inspector is a tertiary surface — typically a metadata pane
  # alongside detail content, not a top-level navigation slot.
  #
  # Renderer mapping (forward-looking; Phase 10B.4 ships the data path):
  #   - iOS / iPadOS (17+): `.inspector` via SwiftKit facade. Current
  #                  fallback: horizontal UIStackView (primary +
  #                  trailing inspector pane).
  #   - macOS:       `NSSplitViewController` with inspector pane.
  #                  Current fallback: horizontal NSStackView.
  #   - web_wide:    CSS-grid 2-column layout (primary 1fr,
  #                  inspector `var(--ap-inspector-width)`).
  #   - web_narrow / android / iOS-compact: degrade to a sheet
  #                  fallback (inspector content rendered into a
  #                  sheet at large detent). Documented limitation —
  #                  full bridging tracked in B-009.
  class Inspector < View
    # The primary content of the parent surface. Always rendered.
    property content : View? = nil

    # The inspector-pane content rendered when `is_presented` is true.
    # Lives alongside (not on top of) the primary content.
    property inspector_content : View? = nil

    # Whether the inspector pane is currently displayed.
    property is_presented : Bool = true

    # Preferred width of the inspector pane in points / CSS pixels.
    # Renderers honor this where the platform's split / grid surface
    # supports it. Nil = renderer chooses (typical default 320pt).
    property preferred_width : Float64? = nil

    # Optional callback fired when the inspector is dismissed (closed
    # via the platform's chrome or a programmatic toggle).
    property on_dismiss : Proc(Nil)? = nil

    def initialize(@content : View? = nil, @inspector_content : View? = nil)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:none`. The Inspector is a
    # structural container; the inspector pane content carries its
    # own semantics (an article, region, or complementary landmark).
    # Web emits `role="complementary"` on the trailing pane via the
    # renderer to match the WAI-ARIA landmark.
    def default_accessibility_role : Symbol?
      :none
    end
  end
end
