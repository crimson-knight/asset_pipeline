# Phase 8B — Action result type hierarchy.
#
# Controllers return one of these subtypes from action methods. The
# `UI::ActionDispatcher` translates the result into a coordinator
# operation (push / pop / replace_root / republish) or an inline render
# emission to the host.
#
# Authors do not construct these directly — the `UI::Controller`
# protected helpers (navigate_to / pop_navigation / render_current_screen
# / replace_root / respond_with) build them on the controller's behalf.

require "../ui"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # Abstract base for the ActionResult type hierarchy returned from
  # `UI::Controller` action methods.
  #
  # Concrete subclasses:
  #
  # * `ActionResult::Navigate`     — push a route on the navigation stack.
  # * `ActionResult::Pop`          — pop the top route off the stack.
  # * `ActionResult::Rerender`     — re-render the current route.
  # * `ActionResult::ReplaceRoot`  — replace the entire stack.
  # * `ActionResult::RenderInline` — render a view in a host-bound slot
  #                                  (sheet / popover).
  #
  # Authors return one of these from an action method; the
  # `UI::ActionDispatcher` translates the value into a coordinator
  # operation (push / pop / replace_root / republish) or an inline
  # emission to the host.
  #
  # The supported way to construct results is through the
  # `UI::Controller` protected helpers — `navigate_to`, `pop_navigation`,
  # `render_current_screen`, `replace_root`, `respond_with`. The classes
  # are public so the dispatcher can `case ... when` on them, not so
  # authors instantiate them directly.
  abstract class ActionResult
    # Navigate to a new route, pushing it on the navigation stack.
    #
    # The dispatcher mounts the new screen (allocating a fresh
    # `UI::FormState` and bumping the mount token) BEFORE the
    # coordinator's `push` notifies subscribers — so the renderer's
    # wire-time read of `UI::FormState.current` sees the new mount.
    #
    # ```
    # def submit(ctx : UI::ScreenContext::Native) : UI::ActionResult
    #   email = ctx.form_state["email"]
    #   user_id = AuthService.sign_in(email)
    #   navigate_to(:dashboard, {user_id: user_id})
    # end
    # ```
    class Navigate < ActionResult
      # The route id to push (must be registered on `UI::App` via
      # `screen :route_id, ...`).
      getter route_id : Symbol

      # Per-route params merged into the new screen's `FormState` at
      # mount time. String values cross the native/web boundary safely.
      getter params : Hash(Symbol, String)

      def initialize(@route_id : Symbol, @params : Hash(Symbol, String) = {} of Symbol => String)
      end
    end

    # Pop the top route off the navigation stack (back navigation).
    #
    # The dispatcher mounts the route BELOW the top before popping so
    # the renderer's subsequent rebuild sees the right form state.
    # When the stack depth is 1 (root only), pop is a no-op.
    #
    # ```
    # def cancel(ctx : UI::ScreenContext::Native) : UI::ActionResult
    #   pop_navigation
    # end
    # ```
    class Pop < ActionResult
    end

    # Re-render the current route without changing the stack (e.g. after
    # mutating shared state in-place).
    #
    # The dispatcher re-mounts the current route (fresh FormState +
    # mount token) and triggers `coord.republish` so the host rebuilds
    # the view tree.
    #
    # ```
    # def refresh(ctx : UI::ScreenContext::Native) : UI::ActionResult
    #   Voyager.state.reload!
    #   render_current_screen
    # end
    # ```
    class Rerender < ActionResult
    end

    # Replace the entire navigation stack with a new root (e.g. after
    # sign-in / sign-out — when the previous stack is no longer
    # accessible).
    #
    # ```
    # def sign_in(ctx : UI::ScreenContext::Native) : UI::ActionResult
    #   AuthService.sign_in(ctx.form_state["email"])
    #   replace_root(:dashboard)
    # end
    # ```
    class ReplaceRoot < ActionResult
      # The route id of the new root.
      getter route_id : Symbol

      # Per-route params merged into the new root's `FormState` at mount.
      getter params : Hash(Symbol, String)

      def initialize(@route_id : Symbol, @params : Hash(Symbol, String) = {} of Symbol => String)
      end
    end

    # Render the given view inline (e.g. in a popover / sheet host)
    # without affecting the navigation stack.
    #
    # The host (macOS / iOS / web) wires a callback via
    # `UI::ActionDispatcher#on_render_inline`. If no callback is bound
    # at dispatch time the result is silently dropped — without a host
    # the inline render has nowhere to land.
    #
    # ```
    # def show_options(ctx : UI::ScreenContext::Native) : UI::ActionResult
    #   sheet = build_options_sheet
    #   respond_with(UI::ActionResult::RenderInline.new(sheet))
    # end
    # ```
    class RenderInline < ActionResult
      # The view to render in the host-bound inline slot.
      getter view : UI::View

      def initialize(@view : UI::View)
      end
    end
  end
end
