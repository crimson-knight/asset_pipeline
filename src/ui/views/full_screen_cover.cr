# Full-screen modal cover. The HIG `fullScreenCover` analog — a modal
# that takes the entire screen with no peek of the parent (in contrast
# to `UI::Sheet`, which leaves the parent partially visible).
#
# Per the Phase 9 intent catalog (`:full_screen_cover`):
#   - SwiftUI:   `.fullScreenCover(isPresented:onDismiss:content:)`
#   - UIKit:     `UIViewController.modalPresentationStyle = .fullScreen`
#   - AppKit:    Full-window modal via `NSWindow`
#   - Android:   Full-screen `Dialog` or full-screen activity
#   - Web:       Full-viewport modal overlay (`role="dialog"`, fixed
#                inset 0)
#
# `UI::FullScreenCover` is the Phase 10B.4 widget that backs the
# intent. Until SwiftKit's `apsk_make_full_screen_cover` facade lands,
# native renderers fall back to a non-detented full-screen overlay
# built from existing primitives (NSView / UIView / FrameLayout). The
# web renderer emits a fixed-position overlay with focus-trap-ready
# aria attributes.
#
# Example:
#   cover = UI::FullScreenCover.new(content_view)
#   cover.is_presented = true
#   cover.on_dismiss = -> { puts "dismissed" }

require "../view"

module UI
  # FullScreenCover — Modal that takes the entire screen, with no peek of
  # the parent surface behind it. The Phase 10B.4 default for the
  # `:full_screen_cover` intent.
  #
  # Differences from `UI::Sheet`:
  #   - `UI::Sheet` is a bottom-aligned partial modal with detents.
  #   - `UI::FullScreenCover` covers the entire viewport (no detents,
  #     no drag indicator, no peek of parent).
  #
  # Renderer mapping (forward-looking; Phase 10B.4 ships the data path):
  #   - iOS:   `UIViewController.modalPresentationStyle = .fullScreen`
  #            (via a SwiftKit facade in a follow-up phase). Current
  #            fallback: a hidden-until-presented full-bounds UIView.
  #   - macOS: full-window modal via `NSWindow.beginSheet:` with
  #            preferred size = main window bounds. Current fallback:
  #            full-bounds NSView.
  #   - web:   fixed-position overlay with `role="dialog"`
  #            `aria-modal="true"`.
  #   - Android: full-screen `Dialog`. Current fallback: a hidden-
  #            until-presented full-bounds LinearLayout.
  class FullScreenCover < View
    # The content rendered when the cover is presented. Nil renders an
    # empty container (apps typically populate this before flipping
    # `is_presented`).
    property content : View? = nil

    # Whether the cover is currently displayed. Setting this after
    # render is the public reactivity contract: the renderer-emitted
    # surface must reflect the change on the next render pass.
    property is_presented : Bool = false

    # Optional callback fired when the user dismisses the cover (via
    # back gesture on iOS, ESC on macOS / web, or system back on
    # Android). Apps that programmatically dismiss via
    # `is_presented = false` should call this themselves if they want
    # the same lifecycle hook.
    property on_dismiss : Proc(Nil)? = nil

    def initialize(@content : View? = nil)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:dialog`. A full-screen modal
    # IS a dialog per WAI-ARIA semantics.
    def default_accessibility_role : Symbol?
      :dialog
    end

    # Phase 10B.2b — A full-screen modal should be focusable so
    # keyboard users can land on the overlay container and tab into
    # its content. Web emits `tabindex="-1"` (programmatic focus only)
    # via `effective_tab_index`.
    def default_focusable : Bool
      true
    end
  end
end
