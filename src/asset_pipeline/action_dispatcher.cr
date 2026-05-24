# Phase 8B — UI::ActionDispatcher.
#
# The dispatcher is the per-app coordinator that translates user
# actions (Button taps, form submits) into navigation operations or
# inline view renders. It owns:
#
#   * the registered `UI::App` subclass (for screen lookup),
#   * the `UI::NavigationCoordinator` (route stack + on_change),
#   * the `UI::Session` + `UI::Flash` (in-process or app-supplied),
#   * the `UI::DesignTokens::Tokens` (per-app brand),
#   * the CURRENT `UI::FormState` (replaced on every screen mount),
#   * a monotonic `current_mount_token : Int64` (per-mount fresh).
#
# Lifecycle:
#
#   * App startup creates ONE dispatcher and wires
#     `UI::FormState.current = @current_form_state` +
#     `UI::FormState.current_mount_token = 0` (via mount_screen).
#   * Each screen mount calls `dispatcher.mount_screen(route_id)`,
#     which increments the token and allocates a fresh FormState.
#     Renderer hook reads the new current FormState on its next
#     visit pass.
#   * Each Button tap with `action: :submit` invokes
#     `dispatcher.dispatch(action_ref, explicit_params)`. The
#     dispatcher resolves the action_ref to a controller method,
#     runs any before_actions, calls dispatch_action, and translates
#     the returned UI::ActionResult into a coordinator op.
#
# Action refs:
#
#   * `Symbol`: the action runs on the CURRENT screen's controller
#     (looked up via `app.registration_for(coord.current.id)`).
#   * `Tuple(UI::Controller.class, Symbol)`: the action runs on the
#     given controller (e.g. cross-screen action wiring).
#
# Inline render results (UI::ActionResult::RenderInline) emit through
# the dispatcher's `on_render_inline : Proc(UI::View, Nil)?` hook
# rather than the navigation coordinator. macOS/iOS hosts bind to
# this hook for sheet / popover presentation.

require "../ui"
require "./native_app"
require "./native_controller"
require "./native_context"
require "./action_result"

module UI
  class ActionDispatcher
    getter app : UI::App.class
    getter navigation : UI::NavigationCoordinator
    getter session : UI::Session
    getter flash : UI::Flash
    getter design_tokens : UI::DesignTokens::Tokens
    getter current_form_state : UI::FormState

    # Monotonically-increasing mount token. The dispatcher writes this
    # to `UI::FormState.current_mount_token` on every screen mount so
    # the renderer's stale-callback guard fires correctly.
    getter current_mount_token : Int64

    # Optional callback for `UI::ActionResult::RenderInline` results.
    # The host (macOS / iOS) wires this on startup to present the
    # inline view (e.g. sheet, popover) without disturbing the
    # navigation stack.
    property on_render_inline : Proc(UI::View, Nil)? = nil

    def initialize(
      @app : UI::App.class,
      @navigation : UI::NavigationCoordinator,
      @session : UI::Session,
      @flash : UI::Flash,
      @design_tokens : UI::DesignTokens::Tokens,
    )
      @current_mount_token = 0_i64
      @current_form_state = UI::FormState.new(mount_token: 0_i64)
      sync_renderer_hooks
    end

    # Called when a new screen mounts. Increments the mount token AND
    # creates a new FormState carrying that token. Renderer callbacks
    # captured under the prior token become no-ops (Codex finding #3).
    #
    # Initial form-state values are seeded from the route's params hash
    # (e.g. a `:detail` route's `:id => "42"` ends up as
    # form_state["id"] == "42") — convenient for screens that need to
    # know which row they're showing without the controller pre-pop'ing.
    def mount_screen(route_id : Symbol) : Nil
      @current_mount_token += 1
      @current_form_state = UI::FormState.new(mount_token: @current_mount_token)

      # Seed from coord current-route params (string keys).
      current_route = @navigation.current
      current_route.params.each do |key, value|
        @current_form_state.register(key.to_s, value)
      end

      sync_renderer_hooks
      nil
    end

    # Resolve + dispatch an action_ref. Builds a fresh Native context
    # with the dispatcher's current FormState + the explicit params
    # from the action_ref's button. Runs before_actions on the
    # resolved controller class; if any returns a UI::ActionResult,
    # the dispatch short-circuits. Otherwise calls dispatch_action
    # and translates the returned result via `translate_result`.
    def dispatch(
      action_ref : Symbol | Tuple(UI::Controller.class, Symbol),
      explicit_params : Hash(String, String) = {} of String => String,
    ) : Nil
      ctx = build_context(explicit_params)
      result = call_action(action_ref, ctx)
      translate_result(result)
      nil
    end

    # Build a fresh Native context for this dispatch. The dispatcher
    # owns the FormState reference; new context wraps it (along with
    # session, flash, etc.). The explicit_params arrive from the
    # Button's per-tap payload (action_params on the context).
    private def build_context(explicit_params : Hash(String, String)) : UI::ScreenContext::Native
      UI::ScreenContext::Native.new(
        form_state: @current_form_state,
        session: @session,
        flash: @flash,
        design_tokens: @design_tokens,
        navigation: @navigation,
        action_params: explicit_params,
      )
    end

    private def call_action(
      action_ref : Symbol | Tuple(UI::Controller.class, Symbol),
      ctx : UI::ScreenContext::Native,
    ) : UI::ActionResult
      case action_ref
      when Symbol
        # Current screen's controller, action_ref method.
        registration = @app.registration_for(@navigation.current.id)
        controller = registration.controller_class.new
        run_before_actions(controller, ctx) || controller.dispatch_action(action_ref, ctx)
      when Tuple(UI::Controller.class, Symbol)
        ctrl_class, action_method = action_ref
        controller = ctrl_class.new
        run_before_actions(controller, ctx) || controller.dispatch_action(action_method, ctx)
      else
        raise "UI::ActionDispatcher cannot resolve action_ref of type #{action_ref.class}"
      end
    end

    private def run_before_actions(controller : UI::Controller, ctx : UI::ScreenContext::Native) : UI::ActionResult?
      controller.class._before_actions.each do |cb|
        result = cb.call(controller, ctx)
        return result if result.is_a?(UI::ActionResult)
      end
      nil
    end

    private def translate_result(result : UI::ActionResult) : Nil
      case result
      when UI::ActionResult::Navigate
        @navigation.push(
          UI::NavigationCoordinator::Route.new(result.route_id, result.params)
        )
        mount_screen(result.route_id)
      when UI::ActionResult::Pop
        popped = @navigation.pop
        if popped
          mount_screen(@navigation.current.id)
        end
      when UI::ActionResult::Rerender
        # `republish` re-fires the on_change callbacks with the same
        # current route — the host rebuilds the view from the same
        # state but the underlying mount is the same. We allocate a
        # fresh FormState anyway so any in-flight stale-fire callbacks
        # captured under the prior mount become no-ops (Codex finding
        # #3 — defensive even on Rerender).
        @navigation.republish
        mount_screen(@navigation.current.id)
      when UI::ActionResult::ReplaceRoot
        @navigation.replace_root(
          UI::NavigationCoordinator::Route.new(result.route_id, result.params)
        )
        mount_screen(result.route_id)
      when UI::ActionResult::RenderInline
        # Host-specific. Emit via on_render_inline if a callback is
        # bound; otherwise silently drop (the inline render result is
        # invalid without a host to receive it — log when we add a
        # debug-mode warning in a later phase).
        @on_render_inline.try(&.call(result.view))
      else
        # Unknown ActionResult subtype — should never happen with the
        # current sealed hierarchy, but Crystal's case-when isn't
        # exhaustive against an abstract class so we guard explicitly.
        raise "UI::ActionDispatcher cannot translate result of type #{result.class}"
      end
      nil
    end

    # Push the dispatcher's FormState reference + token into
    # `UI::FormState`'s renderer-hook surface. The renderer reads
    # those module-level slots inside `visit(UI::TextField)` /
    # `visit(UI::SecureField)`; this sync makes the wire-time capture
    # see the dispatcher's current per-mount state.
    private def sync_renderer_hooks : Nil
      UI::FormState.current = @current_form_state
      UI::FormState.current_mount_token = @current_mount_token
      nil
    end
  end
end
