# Phase 10B.2c — Specs for `UI::Environment` (system-level user
# preferences), its threading through `UI::ScreenContext`, its
# request-hint reader for the web target, and the reactivity proof
# on `UI::Snackbar#effective_duration`.

require "spec"
require "../../../src/asset_pipeline/amber_integration"
require "../../../src/asset_pipeline/native_context"
require "../../../src/asset_pipeline/action_dispatcher"
require "../../../src/ui/renderers/web_renderer"

describe "UI::Environment (Phase 10B.2c)" do
  describe "construction + defaults" do
    it "defaults to the accessibility-conservative no-preference baseline" do
      env = UI::Environment.default
      env.reduce_motion.should be_false
      env.increase_contrast.should be_false
      env.dynamic_type_size.should eq(:medium)
      env.color_scheme.should eq(:light)
      env.accessibility_enabled.should be_false
    end

    it "exposes all 5 getters as the brief mandates" do
      env = UI::Environment.new(
        reduce_motion: true,
        increase_contrast: true,
        dynamic_type_size: :ax2,
        color_scheme: :dark,
        accessibility_enabled: true,
      )
      env.reduce_motion.should be_true
      env.increase_contrast.should be_true
      env.dynamic_type_size.should eq(:ax2)
      env.color_scheme.should eq(:dark)
      env.accessibility_enabled.should be_true
    end

    it "provides an `accessibility_active` preset for testing" do
      env = UI::Environment.accessibility_active
      env.reduce_motion.should be_true
      env.increase_contrast.should be_true
      env.accessibility_enabled.should be_true
      env.dynamic_type_size.should eq(:ax3)
      env.color_scheme.should eq(:high_contrast)
    end

    it "is immutable — copy_with returns a new instance with overrides" do
      base = UI::Environment.default
      derived = base.copy_with(reduce_motion: true)
      base.reduce_motion.should be_false
      derived.reduce_motion.should be_true
      # other fields preserved
      derived.color_scheme.should eq(base.color_scheme)
    end
  end

  describe "Web source: from_request_hints" do
    it "reads Sec-CH-Prefers-Reduced-Motion=reduce as reduce_motion=true" do
      env = UI::Environment.from_request_hints({
        "Sec-CH-Prefers-Reduced-Motion" => "reduce",
      })
      env.reduce_motion.should be_true
    end

    it "treats absent / no-preference as the conservative default" do
      env = UI::Environment.from_request_hints({} of String => String)
      env.reduce_motion.should be_false
      env.increase_contrast.should be_false
      env.color_scheme.should eq(:light)
    end

    it "reads Sec-CH-Prefers-Contrast=more as increase_contrast=true" do
      env = UI::Environment.from_request_hints({
        "Sec-CH-Prefers-Contrast" => "more",
      })
      env.increase_contrast.should be_true
    end

    it "reads Sec-CH-Prefers-Color-Scheme=dark" do
      env = UI::Environment.from_request_hints({
        "Sec-CH-Prefers-Color-Scheme" => "dark",
      })
      env.color_scheme.should eq(:dark)
    end

    it "escalates to :high_contrast when both increase_contrast and light scheme are set" do
      env = UI::Environment.from_request_hints({
        "Sec-CH-Prefers-Contrast" => "more",
      })
      env.color_scheme.should eq(:high_contrast)
    end

    it "treats reduced transparency as a contrast signal too" do
      env = UI::Environment.from_request_hints({
        "Sec-CH-Prefers-Reduced-Transparency" => "reduce",
      })
      env.increase_contrast.should be_true
    end

    it "accepts lowercase header keys (case-insensitive lookup)" do
      env = UI::Environment.from_request_hints({
        "sec-ch-prefers-reduced-motion" => "reduce",
      })
      env.reduce_motion.should be_true
    end

    # Phase 10B.2c iter 2 — Codex Finding 1 remediation. Real Client
    # Hints headers ship as RFC 8941 structured field values, which
    # means the wire bytes for the value are quoted. Strip outer
    # quotes before token matching so the same parse handles both
    # forms.
    it "parses the RFC 8941 quoted wire form for reduced-motion" do
      env = UI::Environment.from_request_hints({
        "Sec-CH-Prefers-Reduced-Motion" => "\"reduce\"",
      })
      env.reduce_motion.should be_true
    end

    it "parses the RFC 8941 quoted wire form for color-scheme" do
      env = UI::Environment.from_request_hints({
        "Sec-CH-Prefers-Color-Scheme" => "\"dark\"",
      })
      env.color_scheme.should eq(:dark)
    end

    it "parses the RFC 8941 quoted wire form for contrast" do
      env = UI::Environment.from_request_hints({
        "Sec-CH-Prefers-Contrast" => "\"more\"",
      })
      env.increase_contrast.should be_true
    end

    it "tolerates leading/trailing whitespace around quoted wire values" do
      env = UI::Environment.from_request_hints({
        "Sec-CH-Prefers-Reduced-Motion" => "  \"reduce\"  ",
      })
      env.reduce_motion.should be_true
    end
  end

  describe "Native sources: from_uikit / from_appkit / from_android" do
    it "from_uikit threads UIAccessibility-style values through" do
      env = UI::Environment.from_uikit(
        reduce_motion: true,
        dynamic_type_size: :xxxlarge,
        voice_over_running: true,
      )
      env.reduce_motion.should be_true
      env.dynamic_type_size.should eq(:xxxlarge)
      env.accessibility_enabled.should be_true
    end

    it "from_appkit threads NSWorkspace-style values through" do
      env = UI::Environment.from_appkit(
        reduce_motion: true,
        increase_contrast: true,
        color_scheme: :dark,
      )
      env.reduce_motion.should be_true
      env.increase_contrast.should be_true
      env.color_scheme.should eq(:dark)
    end

    it "from_android threads Settings.Global-style values through" do
      env = UI::Environment.from_android(
        reduce_motion: true,
        talk_back_active: true,
      )
      env.reduce_motion.should be_true
      env.accessibility_enabled.should be_true
    end
  end
end

describe "UI::Animation duration helpers (Phase 10B.2c)" do
  it "duration_with_environment returns 0 when reduce_motion=true" do
    env = UI::Environment.new(reduce_motion: true)
    UI::Animation.duration_with_environment(env, 250).should eq(0.0)
  end

  it "duration_with_environment returns base_ms when reduce_motion=false" do
    env = UI::Environment.default
    UI::Animation.duration_with_environment(env, 250).should eq(250.0)
  end

  it "duration_seconds_with_environment respects reduce_motion (seconds form)" do
    on = UI::Environment.new(reduce_motion: true)
    off = UI::Environment.default
    UI::Animation.duration_seconds_with_environment(on, 4.0).should eq(0.0)
    UI::Animation.duration_seconds_with_environment(off, 4.0).should eq(4.0)
  end

  # Usability bar U2 — reduce-motion FADES a transition, it does not kill it.
  it "transition_duration_with_environment fades (non-zero) under reduce_motion" do
    on = UI::Environment.new(reduce_motion: true)
    # A present/dismiss transition must NOT collapse to 0ms under reduce-motion.
    UI::Animation.transition_duration_with_environment(on, 300).should eq(150.0)
    UI::Animation.transition_duration_with_environment(on, 300).should_not eq(0.0)
  end

  it "transition_duration_with_environment returns base_ms when reduce_motion=false" do
    off = UI::Environment.default
    UI::Animation.transition_duration_with_environment(off, 300).should eq(300.0)
  end

  it "transition_duration_with_environment honors a custom fade duration" do
    on = UI::Environment.new(reduce_motion: true)
    UI::Animation.transition_duration_with_environment(on, 300, fade_ms: 120).should eq(120.0)
  end

  it "transition_duration_seconds_with_environment fades (non-zero) under reduce_motion" do
    on = UI::Environment.new(reduce_motion: true)
    off = UI::Environment.default
    UI::Animation.transition_duration_seconds_with_environment(on, 0.4).should eq(0.150)
    UI::Animation.transition_duration_seconds_with_environment(on, 0.4).should_not eq(0.0)
    UI::Animation.transition_duration_seconds_with_environment(off, 0.4).should eq(0.4)
  end
end

describe "UI::ScreenContext.environment threading (Phase 10B.2c)" do
  it "ScreenContext::Web defaults environment to the default baseline" do
    ctx = UI::ScreenContext::Web.new(
      params: {} of String => String,
      params_multi: {} of String => Array(String),
      flash_data: {} of String => String,
      design_tokens: UI::DesignTokens::Tokens.default,
      csrf_token: nil,
    )
    ctx.environment.reduce_motion.should be_false
    ctx.environment.color_scheme.should eq(:light)
  end

  it "ScreenContext::Web accepts an explicit environment kwarg" do
    env = UI::Environment.accessibility_active
    ctx = UI::ScreenContext::Web.new(
      params: {} of String => String,
      params_multi: {} of String => Array(String),
      flash_data: {} of String => String,
      design_tokens: UI::DesignTokens::Tokens.default,
      csrf_token: nil,
      environment: env,
    )
    ctx.environment.reduce_motion.should be_true
    ctx.environment.color_scheme.should eq(:high_contrast)
  end

  it "ScreenContext::Native defaults environment to the default baseline" do
    coord = UI::NavigationCoordinator.new(UI::NavigationCoordinator::Route.new(:home))
    ctx = UI::ScreenContext::Native.new(
      form_state: UI::FormState.new,
      session: UI::Session::InProcess.new,
      flash: UI::Flash::InProcess.new,
      design_tokens: UI::DesignTokens::Tokens.default,
      navigation: coord,
    )
    ctx.environment.reduce_motion.should be_false
  end

  it "ScreenContext::Native accepts an explicit environment kwarg" do
    coord = UI::NavigationCoordinator.new(UI::NavigationCoordinator::Route.new(:home))
    env = UI::Environment.new(reduce_motion: true, dynamic_type_size: :ax1)
    ctx = UI::ScreenContext::Native.new(
      form_state: UI::FormState.new,
      session: UI::Session::InProcess.new,
      flash: UI::Flash::InProcess.new,
      design_tokens: UI::DesignTokens::Tokens.default,
      navigation: coord,
      environment: env,
    )
    ctx.environment.reduce_motion.should be_true
    ctx.environment.dynamic_type_size.should eq(:ax1)
  end

  it "environment is mutable on the abstract base (so dispatchers can swap mid-mount)" do
    ctx = UI::ScreenContext::Web.new(
      params: {} of String => String,
      params_multi: {} of String => Array(String),
      flash_data: {} of String => String,
      design_tokens: UI::DesignTokens::Tokens.default,
      csrf_token: nil,
    )
    ctx.environment.reduce_motion.should be_false
    ctx.environment = UI::Environment.accessibility_active
    ctx.environment.reduce_motion.should be_true
  end
end

# Minimal app harness for the dispatcher-environment threading spec.
# The screen + controller need to exist so the App.screen macro can
# register a native route the dispatcher can locate when building a
# context; the action itself is a no-op rerender so the dispatch path
# completes without side effects.
private class Phase10B2cController < UI::Controller
  property captured_env : UI::Environment? = nil

  def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
    @captured_env = context.environment
    UI::ActionResult::Rerender.new
  end
end

# Module-level slot so `dispatch_action` (which receives a fresh
# controller instance on every dispatch) can publish what it saw back
# to the spec. The dispatcher constructs a NEW controller via `.new`
# on every dispatch, so capturing on the instance isn't reachable.
module Phase10B2cCapture
  class_property env : UI::Environment? = nil
end

private class Phase10B2cController2 < UI::Controller
  def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
    Phase10B2cCapture.env = context.environment
    UI::ActionResult::Rerender.new
  end
end

private class Phase10B2cHomeScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    UI::Label.new("home")
  end
end

private class Phase10B2cApp < UI::App
  screen :home, Phase10B2cController2, screen_class: Phase10B2cHomeScreen
end

describe "UI::ActionDispatcher environment threading (Phase 10B.2c)" do
  it "carries environment as a settable property defaulting to default" do
    coord = UI::NavigationCoordinator.new(UI::NavigationCoordinator::Route.new(:home))
    dispatcher = UI::ActionDispatcher.new(
      app: Phase10B2cApp,
      navigation: coord,
      session: UI::Session::InProcess.new,
      flash: UI::Flash::InProcess.new,
      design_tokens: UI::DesignTokens::Tokens.default,
    )
    dispatcher.environment.reduce_motion.should be_false
    dispatcher.environment = UI::Environment.new(reduce_motion: true)
    dispatcher.environment.reduce_motion.should be_true
  end

  it "threads dispatcher.environment into every built ScreenContext::Native via dispatch" do
    coord = UI::NavigationCoordinator.new(UI::NavigationCoordinator::Route.new(:home))
    dispatcher = UI::ActionDispatcher.new(
      app: Phase10B2cApp,
      navigation: coord,
      session: UI::Session::InProcess.new,
      flash: UI::Flash::InProcess.new,
      design_tokens: UI::DesignTokens::Tokens.default,
      environment: UI::Environment.new(reduce_motion: true, dynamic_type_size: :ax2),
    )

    Phase10B2cCapture.env = nil
    dispatcher.dispatch(:noop)

    captured = Phase10B2cCapture.env
    captured.should_not be_nil
    captured.not_nil!.reduce_motion.should be_true
    captured.not_nil!.dynamic_type_size.should eq(:ax2)
  end

  it "swapping dispatcher.environment between dispatches yields different context envs" do
    coord = UI::NavigationCoordinator.new(UI::NavigationCoordinator::Route.new(:home))
    dispatcher = UI::ActionDispatcher.new(
      app: Phase10B2cApp,
      navigation: coord,
      session: UI::Session::InProcess.new,
      flash: UI::Flash::InProcess.new,
      design_tokens: UI::DesignTokens::Tokens.default,
    )

    Phase10B2cCapture.env = nil
    dispatcher.dispatch(:noop)
    Phase10B2cCapture.env.not_nil!.reduce_motion.should be_false

    dispatcher.environment = UI::Environment.new(reduce_motion: true)
    Phase10B2cCapture.env = nil
    dispatcher.dispatch(:noop)
    Phase10B2cCapture.env.not_nil!.reduce_motion.should be_true
  end
end

describe "UI::Snackbar#effective_duration — reactivity proof (Phase 10B.2c)" do
  it "returns the configured duration when reduce_motion=false" do
    snack = UI::Snackbar.new("Saved")
    snack.duration = 4.0
    snack.effective_duration(UI::Environment.default).should eq(4.0)
  end

  it "returns 0.0 when reduce_motion=true (env-driven reactivity)" do
    snack = UI::Snackbar.new("Saved")
    snack.duration = 4.0
    env = UI::Environment.new(reduce_motion: true)
    snack.effective_duration(env).should eq(0.0)
  end

  it "same view + two contexts that differ ONLY in environment yields different outputs" do
    # The brief's "reactivity proof": one view, two environments, two outputs.
    snack = UI::Snackbar.new("Saved")
    snack.duration = 3.5

    ctx_default = UI::ScreenContext::Web.new(
      params: {} of String => String,
      params_multi: {} of String => Array(String),
      flash_data: {} of String => String,
      design_tokens: UI::DesignTokens::Tokens.default,
      csrf_token: nil,
      environment: UI::Environment.default,
    )

    ctx_reduce_motion = UI::ScreenContext::Web.new(
      params: {} of String => String,
      params_multi: {} of String => Array(String),
      flash_data: {} of String => String,
      design_tokens: UI::DesignTokens::Tokens.default,
      csrf_token: nil,
      environment: UI::Environment.new(reduce_motion: true),
    )

    snack.effective_duration(ctx_default.environment).should eq(3.5)
    snack.effective_duration(ctx_reduce_motion.environment).should eq(0.0)
    snack.effective_duration(ctx_default.environment).should_not eq(
      snack.effective_duration(ctx_reduce_motion.environment)
    )
  end
end

# Phase 10B.2c iter 2 — Codex Finding 2 remediation. The end-to-end
# reactivity proof: one Snackbar view, two `UI::RenderContext`s that
# differ only in their `environment`, rendered through the actual web
# renderer — the emitted HTML must differ in the `data-duration`
# attribute. This proves the full chain:
#
#   ScreenContext.environment
#     → RenderContext.environment (compute_screen_html threads it)
#     → renderer @render_context.environment
#     → view.effective_duration(env)
#     → data-duration attribute on the rendered element
#
# A unit-only test on `effective_duration` is insufficient because the
# renderer could ignore the helper entirely; only an end-to-end render
# assertion proves the renderer actually consumes the environment.
describe "UI::Snackbar end-to-end reactivity through Web::Renderer (Phase 10B.2c iter 2)" do
  it "renders different data-duration when env.reduce_motion flips" do
    snack = UI::Snackbar.new("Saved")
    snack.duration = 4.0
    snack.is_presented = true

    renderer_default = UI::Web::Renderer.new
    html_default = renderer_default.render(
      snack,
      render_context: UI::RenderContext.new(
        csrf_token: nil,
        environment: UI::Environment.default,
      ),
    )

    renderer_reduce = UI::Web::Renderer.new
    html_reduce = renderer_reduce.render(
      snack,
      render_context: UI::RenderContext.new(
        csrf_token: nil,
        environment: UI::Environment.new(reduce_motion: true),
      ),
    )

    # Both renders produce snackbar markup.
    html_default.should contain(%(data-component="snackbar"))
    html_reduce.should contain(%(data-component="snackbar"))

    # Default env honors the configured duration.
    html_default.should contain(%(data-duration="4.0"))

    # Reduce-motion env collapses the duration to 0.0 — the visible
    # proof that environment threads end-to-end into the rendered HTML.
    html_reduce.should contain(%(data-duration="0.0"))

    # And the two outputs are genuinely different.
    html_default.should_not eq(html_reduce)
  end

  it "RenderContext.empty defaults environment to the conservative baseline" do
    ctx = UI::RenderContext.empty
    ctx.environment.reduce_motion.should be_false
    ctx.environment.color_scheme.should eq(:light)
  end

  it "RenderContext carries the environment when constructed explicitly" do
    env = UI::Environment.accessibility_active
    ctx = UI::RenderContext.new(csrf_token: "abc", environment: env)
    ctx.environment.reduce_motion.should be_true
    ctx.environment.color_scheme.should eq(:high_contrast)
    ctx.csrf_token.should eq("abc")
  end
end
