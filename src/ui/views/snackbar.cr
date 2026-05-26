# Transient toast / snackbar notification anchored to the bottom of the screen.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # Snackbar — Transient toast / snackbar notification anchored to the bottom of the screen.
  class Snackbar < View
    # Body / message text shown in the alert / dialog.
    property message : String
    # Text value.
    property action_label : String? = nil
    # Numeric value (pt unless otherwise noted).
    property duration : Float64 = 4.0 # seconds
    # Whether the modal / overlay is currently presented.
    property is_presented : Bool = false
    property on_action : Proc(Nil)? = nil
    # Invoked when the overlay is dismissed (by tap-outside, escape, or programmatic close).
    property on_dismiss : Proc(Nil)? = nil

    def initialize(@message : String, @action_label : String? = nil)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:status`.
    def default_accessibility_role : Symbol?
      :status
    end

    # Phase 10B.2c — environment-driven duration. Honors the user's
    # reduce-motion preference: returns `0.0` when
    # `env.reduce_motion == true` (the snackbar's auto-dismiss
    # animation is replaced by an instant transition); otherwise
    # returns the author-configured `duration`.
    #
    # This is the canonical reactivity proof for Phase 10B.2c — the
    # same `UI::Snackbar` view + two `UI::ScreenContext`s that differ
    # only in `environment.reduce_motion` produces two different
    # `effective_duration` values. Hosts that drive the dismiss timer
    # (Web JS animation, AppKit `NSAnimationContext`, UIKit `UIView.
    # animate`, Compose `LaunchedEffect`) read this rather than the
    # raw `duration` property.
    def effective_duration(env : UI::Environment) : Float64
      UI::Animation.duration_seconds_with_environment(env, @duration)
    end
  end

  # Presentation state for a Snackbar (is_presenting flag + the underlying view).
  class SnackbarPresenter
    property snackbar : Snackbar
    # Whether the controller is in the act of presenting the overlay.
    property is_presenting : Bool = false

    def initialize(@snackbar : Snackbar)
    end

    # Renders the overlay / modal in the visible state.
    def show
      @is_presenting = true
      @snackbar.is_presented = true
    end

    # Dismisses the overlay / modal.
    def dismiss
      @is_presenting = false
      @snackbar.is_presented = false
      @snackbar.on_dismiss.try(&.call)
    end
  end
end
