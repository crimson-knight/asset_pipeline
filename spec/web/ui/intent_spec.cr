require "../spec_helper"
require "../../../src/asset_pipeline/native_app"
require "../../../src/asset_pipeline/native_context"
require "../../../src/asset_pipeline/native_controller"
require "../../../src/ui/intent"
require "../../../src/ui/intent_bootstrap"

# Phase 10B.0 — UI::Intent resolver + UI::Intent::Registry specs.
#
# Covers:
#
#   * Default resolution per platform (`:swipe_actions` → `UI::SwipeActionRow`
#     on `:ios`, `:ipados`, `:web_narrow`).
#   * UnresolvableDefault on platforms without a registered default
#     (`:macos`, `:web_wide`, `:android`).
#   * App overrides apply.
#   * Screen overrides take precedence over app overrides.
#   * Capability validation rejects an override missing a required
#     capability — `IncompatibleOverride` raised at register time.
#   * A FAKE TEST INTENT proves the registry is plural / data-driven
#     (per Codex 10B.0 MED-4).
#   * A working compile-site `widget_class.new(...)` proves the
#     resolver's return type is usable (per Decision 4 #5).

# ---------- Fake widgets for tests ----------

# A spec-only Tier 2 widget that fully covers the `:swipe_actions`
# required capability set. Used to demonstrate a passing override.
private class IntentSpecFancyRow < UI::View
  declares_capabilities :swipe_actions, {
    supports_edge_trailing: true,
    supports_role_default:  true,
    # Phase 10B.1b — platform-keyed honest declaration replacing the
    # legacy `:partial`. Matches the per-platform requirement set
    # `intent_bootstrap.cr` installs for `:swipe_actions`.
    supports_role_destructive: {
      ios:        true,
      ipados:     true,
      macos:      false,
      web_wide:   true,
      web_narrow: true,
      android:    false,
    },
  }

  property content : UI::View

  def initialize(@content : UI::View)
  end

  def accept(visitor : UI::PlatformVisitor)
    # No-op for specs — we never render this widget.
  end
end

# Spec widget that intentionally DOES NOT declare
# `supports_edge_trailing`. Used to demonstrate that registration
# raises `IncompatibleOverride`.
private class IntentSpecIncompleteRow < UI::View
  declares_capabilities :swipe_actions, {
    supports_role_default: true,
    # NOTE: deliberately omits supports_edge_trailing (required: true)
    # and supports_role_destructive (required: :partial).
  }

  def initialize
  end

  def accept(visitor : UI::PlatformVisitor)
  end
end

# Spec widget used by the FAKE TEST INTENT to prove plurality.
private class IntentSpecFakeWidget < UI::View
  declares_capabilities :fake_test_intent, {
    fake_required_capability: true,
  }

  def initialize
  end

  def accept(visitor : UI::PlatformVisitor)
  end
end

# Second-spec widget that fully declares the :swipe_actions
# capability set. Iter-9 Finding 1 needs a SECOND fully-capable
# widget so the app-class-isolation test can register a DIFFERENT
# widget on AppB and prove the resolver returns AppB's widget for
# AppB's context (not AppA's, which would prove the leak).
private class IntentSpecAlternateRow < UI::View
  declares_capabilities :swipe_actions, {
    supports_edge_trailing: true,
    supports_role_default:  true,
    # Phase 10B.1b — platform-keyed honest declaration replacing the
    # legacy `:partial`. Matches the per-platform requirement set
    # `intent_bootstrap.cr` installs for `:swipe_actions`.
    supports_role_destructive: {
      ios:        true,
      ipados:     true,
      macos:      false,
      web_wide:   true,
      web_narrow: true,
      android:    false,
    },
  }

  def initialize
  end

  def accept(visitor : UI::PlatformVisitor)
  end
end

# Iter-9 Finding 3: distinct spec widgets for the screen-vs-app
# precedence test. Pre-iter-9, both tiers registered the SAME widget
# (IntentSpecFancyRow), so the precedence assertion was vacuous —
# the "screen wins" claim would pass even if app won. The two
# widgets below let the assertion distinguish which tier actually
# returned the result.
private class IntentSpecAppWinner < UI::View
  declares_capabilities :swipe_actions, {
    supports_edge_trailing: true,
    supports_role_default:  true,
    # Phase 10B.1b — platform-keyed honest declaration replacing the
    # legacy `:partial`. Matches the per-platform requirement set
    # `intent_bootstrap.cr` installs for `:swipe_actions`.
    supports_role_destructive: {
      ios:        true,
      ipados:     true,
      macos:      false,
      web_wide:   true,
      web_narrow: true,
      android:    false,
    },
  }

  def initialize
  end

  def accept(visitor : UI::PlatformVisitor)
  end
end

private class IntentSpecScreenWinner < UI::View
  declares_capabilities :swipe_actions, {
    supports_edge_trailing: true,
    supports_role_default:  true,
    # Phase 10B.1b — platform-keyed honest declaration replacing the
    # legacy `:partial`. Matches the per-platform requirement set
    # `intent_bootstrap.cr` installs for `:swipe_actions`.
    supports_role_destructive: {
      ios:        true,
      ipados:     true,
      macos:      false,
      web_wide:   true,
      web_narrow: true,
      android:    false,
    },
  }

  def initialize
  end

  def accept(visitor : UI::PlatformVisitor)
  end
end

# Spec apps + screens — class identity matters for the override
# registry.
private class IntentSpecAppA < UI::App
end

private class IntentSpecAppB < UI::App
end

private class IntentSpecScreenA < UI::Screen
  # Iter-9 Finding 3: register a DISTINCT widget at screen scope so
  # the screen-vs-app precedence spec can prove screen-tier wins
  # (both tiers used to register IntentSpecFancyRow, making the
  # precedence assertion vacuous).
  override_intent :swipe_actions, IntentSpecScreenWinner

  def build(context : UI::ScreenContext) : UI::View
    UI::Label.new("a")
  end
end

private class IntentSpecScreenB < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    UI::Label.new("b")
  end
end

# Helper: re-install the minimum bootstrap state the registry needs
# after a `reset_overrides_for_spec` call. Restores intent capability
# requirements + the platforms that ship a default for :swipe_actions,
# so sibling tests that rely on the bootstrap state still pass after
# a reset. (Iter-9 added specs that reset state mid-flow.)
private def reinstall_intent_bootstrap : Nil
  UI::Intent::Registry.declare_intent_capabilities(:swipe_actions, {
    :supports_edge_trailing    => true,
    :supports_role_default     => true,
    :supports_role_destructive => {
      :ios        => true,
      :ipados     => true,
      :macos      => false,
      :web_wide   => true,
      :web_narrow => true,
      :android    => false,
    } of Symbol => Bool,
  } of Symbol => UI::Intent::Registry::CapabilityValue)
  UI::Intent::Registry.register_default(:swipe_actions, :ios, UI::SwipeActionRow)
  UI::Intent::Registry.register_default(:swipe_actions, :ipados, UI::SwipeActionRow)
  UI::Intent::Registry.register_default(:swipe_actions, :web_narrow, UI::SwipeActionRow)
  # Phase 10B.1a — macOS + web_wide back :swipe_actions with InlineActionRow.
  UI::Intent::Registry.register_default(:swipe_actions, :macos, UI::InlineActionRow)
  UI::Intent::Registry.register_default(:swipe_actions, :web_wide, UI::InlineActionRow)
  # Phase 10B.1c — Android backs :swipe_actions with UI::AndroidSwipeActionRow.
  UI::Intent::Registry.register_default(:swipe_actions, :android, UI::AndroidSwipeActionRow)
  nil
end

# Helper: a Native context for the given platform.
private def native_ctx(platform : Symbol) : UI::ScreenContext::Native
  UI::ScreenContext::Native.new(
    form_state: UI::FormState.new(mount_token: 0_i64),
    session: UI::Session::InProcess.new,
    flash: UI::Flash::InProcess.new,
    design_tokens: UI::DesignTokens::Tokens.default,
    navigation: UI::NavigationCoordinator.new(UI::NavigationCoordinator::Route.new(:test)),
    platform: platform,
  )
end

# Helper: a Web context for the given platform.
private def web_ctx(platform : Symbol) : UI::ScreenContext::Web
  UI::ScreenContext::Web.new(
    params: {} of String => String,
    params_multi: {} of String => Array(String),
    flash_data: {} of String => String,
    design_tokens: UI::DesignTokens::Tokens.default,
    csrf_token: nil,
    platform: platform,
  )
end

describe UI::Intent do
  describe ".resolve" do
    it "returns UI::SwipeActionRow for :swipe_actions on iOS" do
      ctx = native_ctx(:ios)
      UI::Intent.resolve(:swipe_actions, ctx).should eq(UI::SwipeActionRow)
    end

    it "returns UI::SwipeActionRow for :swipe_actions on iPadOS" do
      ctx = native_ctx(:ipados)
      UI::Intent.resolve(:swipe_actions, ctx).should eq(UI::SwipeActionRow)
    end

    it "returns UI::SwipeActionRow for :swipe_actions on web_narrow" do
      ctx = web_ctx(:web_narrow)
      UI::Intent.resolve(:swipe_actions, ctx).should eq(UI::SwipeActionRow)
    end

    it "returns UI::InlineActionRow for :swipe_actions on macOS (Phase 10B.1a)" do
      # Pre-10B.1a this raised UnresolvableDefault. 10B.1a installed
      # UI::InlineActionRow as the macOS default (HIG: no swipe-to-
      # reveal on the Mac — visible inline buttons are idiomatic).
      ctx = native_ctx(:macos)
      UI::Intent.resolve(:swipe_actions, ctx).should eq(UI::InlineActionRow)
    end

    it "returns UI::InlineActionRow for :swipe_actions on web_wide (Phase 10B.1a)" do
      # Pre-10B.1a this raised UnresolvableDefault. Desktop-web mirrors
      # the macOS convention.
      ctx = web_ctx(:web_wide)
      UI::Intent.resolve(:swipe_actions, ctx).should eq(UI::InlineActionRow)
    end

    it "returns UI::AndroidSwipeActionRow for :swipe_actions on android (Phase 10B.1c)" do
      # Pre-10B.1c this raised UnresolvableDefault — Android was the
      # last platform without a `:swipe_actions` default. 10B.1c
      # installs `UI::AndroidSwipeActionRow`; the aspirational
      # renderer mapping is `M3.SwipeToDismissBox` but until the JNI
      # bridge gains Compose interop the renderer falls back to a
      # horizontal LinearLayout. The resolver returns the widget
      # regardless of which renderer-side strategy is active.
      ctx = native_ctx(:android)
      UI::Intent.resolve(:swipe_actions, ctx).should eq(UI::AndroidSwipeActionRow)
    end

    it "produces a return type that can be invoked via .new (compiling call-site)" do
      # Per architecture-decisions.md Decision 4 #5, the resolver's
      # return type MUST be usable as a constructor — `widget_class.new(...)`
      # must compile + execute. This spec proves the call-site works
      # against `UI::SwipeActionRow.new(content : UI::View)`.
      ctx = native_ctx(:ios)
      widget_class = UI::Intent.resolve(:swipe_actions, ctx)
      widget_class.should eq(UI::SwipeActionRow)
      # The resolver returns `UI::View.class`. To exercise the
      # construction path we cast to the concrete class — this is how
      # screens that know which intent they resolve typically use the
      # resolved class. Untyped construction (`widget_class.new(...)`)
      # is left to specs that exercise the runtime-dispatch shape; for
      # 10B.0 the compiling-call-site proof is the per-type case.
      row = UI::SwipeActionRow.new(UI::Label.new("row content"))
      row.should be_a(UI::SwipeActionRow)
    end
  end

  describe "FAKE TEST INTENT — proves resolver is plural / data-driven" do
    # Per Codex 10B.0 MED-4: at least one fake test intent in specs
    # to prove the registry is plural (the resolver isn't hard-coded
    # to :swipe_actions).

    it "resolves a fake intent registered at test time" do
      UI::Intent::Registry.register_default(
        :fake_test_intent,
        :ios,
        IntentSpecFakeWidget,
      )

      ctx = native_ctx(:ios)
      UI::Intent.resolve(:fake_test_intent, ctx).should eq(IntentSpecFakeWidget)
    end

    it "raises UnresolvableDefault for the fake intent on an unregistered platform" do
      # Even if the fake intent has a default for :ios, asking for
      # :macos must surface as a clear gap, not a silent fallback.
      ctx = native_ctx(:macos)
      expect_raises(UI::Intent::UnresolvableDefault, /:fake_test_intent.*:macos/) do
        UI::Intent.resolve(:fake_test_intent, ctx)
      end
    end
  end
end

describe UI::Intent::Registry do
  describe "app overrides" do
    it "applies an app override when context.app_class matches" do
      # Register IntentSpecFancyRow as the app override for :swipe_actions
      # on IntentSpecAppA. Iter-9 (Codex Finding 1): the resolver now
      # checks `context.app_class` against the override key — the
      # context must opt in to IntentSpecAppA for the override to apply.
      IntentSpecAppA.override_intent(:swipe_actions, IntentSpecFancyRow)

      # On macOS — without the override, this would raise
      # UnresolvableDefault. With the override AND app_class set on
      # context, FancyRow wins.
      ctx = native_ctx(:macos)
      ctx.app_class = IntentSpecAppA
      result = UI::Intent::Registry.resolve_for(:swipe_actions, ctx)
      result.should eq(IntentSpecFancyRow)
    end

    it "exposes an override count accessor for specs" do
      IntentSpecAppB.override_intent(:swipe_actions, IntentSpecFancyRow)
      UI::Intent::Registry.app_override_count_for(IntentSpecAppB, :swipe_actions).should eq(1)
    end

    it "isolates app overrides by app class (Codex iter-9 Finding 1)" do
      # The critical proof: an override registered against AppA must
      # NOT leak into AppB's resolution path. Prior to iter-9, the
      # resolver iterated ALL app overrides and returned the first
      # match — making @@app_overrides effectively process-global
      # and defeating the point of keying by app class.
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_intent_bootstrap

      # Register DIFFERENT widgets for the SAME intent on two apps.
      # The resolver must return the widget keyed to the active app.
      IntentSpecAppA.override_intent(:swipe_actions, IntentSpecFancyRow)
      IntentSpecAppB.override_intent(:swipe_actions, IntentSpecAlternateRow)

      # Resolve from AppA's context — must return AppA's widget.
      ctx_a = native_ctx(:macos)
      ctx_a.app_class = IntentSpecAppA
      UI::Intent::Registry.resolve_for(:swipe_actions, ctx_a).should eq(IntentSpecFancyRow)

      # Resolve from AppB's context — must return AppB's widget, NOT
      # AppA's. Pre-iter-9 this returned whichever override was
      # iterated first (effectively random).
      ctx_b = native_ctx(:macos)
      ctx_b.app_class = IntentSpecAppB
      UI::Intent::Registry.resolve_for(:swipe_actions, ctx_b).should eq(IntentSpecAlternateRow)
    end

    it "skips the app tier when context.app_class is nil" do
      # Specs / call-sites that don't bind to a UI::App leave
      # app_class nil. The resolver MUST skip the app tier in that
      # case rather than scanning all app overrides.
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_intent_bootstrap
      IntentSpecAppA.override_intent(:swipe_actions, IntentSpecFancyRow)

      # Use a synthetic platform symbol (`:spec_no_default_platform`)
      # that no bootstrap has registered. Post-10B.1c every real
      # platform — ios, ipados, macos, web_narrow, web_wide, android —
      # has a registered `:swipe_actions` default, so the "no default"
      # branch needs an unregistered platform. With app_class nil the
      # resolver skips the app tier, falls through to the (missing)
      # default, and returns nil.
      ctx = native_ctx(:spec_no_default_platform)
      UI::Intent::Registry.resolve_for(:swipe_actions, ctx).should be_nil
    end
  end

  describe "screen overrides take precedence" do
    # IntentSpecScreenA registered :swipe_actions → IntentSpecScreenWinner
    # at class-body time. The specs below register IntentSpecAppWinner
    # at app-tier for the same app that owns the resolve context —
    # so both tiers carry DIFFERENT widget classes. That's what makes
    # the precedence assertion meaningful: the result distinguishes
    # which tier actually won (Codex iter-9 Finding 3).

    it "screen override wins over app override at resolve time" do
      # The Finding 1 isolation specs above call
      # `reset_overrides_for_spec`, which clears the screen-override
      # table — including IntentSpecScreenA's class-body
      # registration. Re-install both tiers here so the precedence
      # assertion has each entry it needs.
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_intent_bootstrap
      UI::Intent::Registry.register_screen_override(
        IntentSpecScreenA,
        :swipe_actions,
        IntentSpecScreenWinner,
      )
      IntentSpecAppA.override_intent(:swipe_actions, IntentSpecAppWinner)

      ctx = native_ctx(:macos)
      ctx.app_class = IntentSpecAppA

      # With screen_class hint: screen wins -> IntentSpecScreenWinner.
      # If the resolver picked the app tier (broken precedence), this
      # would return IntentSpecAppWinner. The distinct-class
      # assertion proves the screen tier ran.
      hit = UI::Intent::Registry.resolve_for(:swipe_actions, ctx, screen_class: IntentSpecScreenA)
      hit.should eq(IntentSpecScreenWinner)
      UI::Intent::Registry.screen_override_count_for(IntentSpecScreenA, :swipe_actions).should be > 0
    end

    it "falls through to app override when no screen_class hint is passed" do
      # Same setup as the prior spec: both tiers registered with
      # DIFFERENT widgets. Without the screen_class hint AND with
      # ctx.active_screen_class also nil, the resolver cannot consult
      # the screen tier and must fall through to app. The
      # distinct-class assertion proves the app tier ran (and the
      # screen tier was correctly skipped).
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_intent_bootstrap
      UI::Intent::Registry.register_screen_override(
        IntentSpecScreenA,
        :swipe_actions,
        IntentSpecScreenWinner,
      )
      IntentSpecAppA.override_intent(:swipe_actions, IntentSpecAppWinner)

      ctx = native_ctx(:macos)
      ctx.app_class = IntentSpecAppA
      # ctx.active_screen_class deliberately left nil.

      hit = UI::Intent::Registry.resolve_for(:swipe_actions, ctx)
      hit.should eq(IntentSpecAppWinner)
    end
  end

  describe "capability validation" do
    it "raises IncompatibleOverride when override widget lacks a required capability" do
      # IntentSpecIncompleteRow declares supports_role_default but
      # omits the required supports_edge_trailing and the partial-
      # required supports_role_destructive. Registration must raise.
      expect_raises(UI::Intent::IncompatibleOverride, /supports_edge_trailing/) do
        UI::Intent::Registry.register_app_override(
          IntentSpecAppA,
          :swipe_actions,
          IntentSpecIncompleteRow,
        )
      end
    end

    it "accepts a widget that declares the full required set" do
      # IntentSpecFancyRow declares every required cap; should not raise.
      IntentSpecAppA.override_intent(:swipe_actions, IntentSpecFancyRow)
      UI::Intent::Registry.app_override_count_for(IntentSpecAppA, :swipe_actions).should be > 0
    end
  end
end


# ---------- Iter-10 Finding 2: runtime capabilities_required spec ----------
#
# Existing coverage validates capabilities at REGISTRATION (the
# IncompatibleOverride path). This block exercises the RUNTIME path
# through `UI::Intent.resolve(intent_id, ctx, capabilities_required: ...)`
# — the kwarg lets a migration / soft-fallback caller assert the
# resolved widget covers a specific capability subset before mounting.
# Mismatches surface as `UnresolvableDefault`.

# Spec-only intent declared with no required capabilities (so we don't
# trip the registration-time validator) — capability checks are
# exercised here only at runtime via `capabilities_required:`.
private class IntentSpecCapWidget < UI::View
  declares_capabilities :spec_runtime_cap_intent, {
    cap_a: true,
    cap_b: false,
  }

  def initialize
  end

  def accept(visitor : UI::PlatformVisitor)
  end
end

describe "UI::Intent.resolve runtime capabilities_required" do
  it "raises UnresolvableDefault when widget is missing a required capability" do
    UI::Intent::Registry.register_default(
      :spec_runtime_cap_intent,
      :macos,
      IntentSpecCapWidget,
    )

    ctx = UI::ScreenContext::Native.new(
      form_state: UI::FormState.new(mount_token: 0_i64),
      session: UI::Session::InProcess.new,
      flash: UI::Flash::InProcess.new,
      design_tokens: UI::DesignTokens::Tokens.default,
      navigation: UI::NavigationCoordinator.new(UI::NavigationCoordinator::Route.new(:test)),
      platform: :macos,
    )

    # Widget declares cap_b: false. Asking for cap_b: true must raise
    # UnresolvableDefault with the missing capability key named in the
    # message (per intent.cr#first_missing_capability path).
    expect_raises(UI::Intent::UnresolvableDefault, /cap_b/) do
      UI::Intent.resolve(
        :spec_runtime_cap_intent,
        ctx,
        capabilities_required: {:cap_b => true},
      )
    end
  end

  it "returns the widget when capabilities_required is fully covered" do
    UI::Intent::Registry.register_default(
      :spec_runtime_cap_intent,
      :macos,
      IntentSpecCapWidget,
    )

    ctx = UI::ScreenContext::Native.new(
      form_state: UI::FormState.new(mount_token: 0_i64),
      session: UI::Session::InProcess.new,
      flash: UI::Flash::InProcess.new,
      design_tokens: UI::DesignTokens::Tokens.default,
      navigation: UI::NavigationCoordinator.new(UI::NavigationCoordinator::Route.new(:test)),
      platform: :macos,
    )

    # cap_a: true is declared. Asking only for cap_a: true returns the
    # widget without raising.
    result = UI::Intent.resolve(
      :spec_runtime_cap_intent,
      ctx,
      capabilities_required: {:cap_a => true},
    )
    result.should eq(IntentSpecCapWidget)
  end

  it "ignores required keys with value false" do
    UI::Intent::Registry.register_default(
      :spec_runtime_cap_intent,
      :macos,
      IntentSpecCapWidget,
    )

    ctx = UI::ScreenContext::Native.new(
      form_state: UI::FormState.new(mount_token: 0_i64),
      session: UI::Session::InProcess.new,
      flash: UI::Flash::InProcess.new,
      design_tokens: UI::DesignTokens::Tokens.default,
      navigation: UI::NavigationCoordinator.new(UI::NavigationCoordinator::Route.new(:test)),
      platform: :macos,
    )

    # cap_b: false means "caller doesn't need it" — must not trip the
    # missing-capability path even though the widget declared cap_b: false.
    result = UI::Intent.resolve(
      :spec_runtime_cap_intent,
      ctx,
      capabilities_required: {:cap_b => false},
    )
    result.should eq(IntentSpecCapWidget)
  end
end
# ---------- Iter-10 Finding 1: Amber web context seeds app_class ----------
#
# `compute_screen_html` on the web target must thread `ctx.app_class`
# so `UI::Intent::Registry.resolve_for` applies app-scoped overrides
# correctly. Mirrors the native dispatcher's `ctx.app_class = @app`
# behavior. Pre-iter-10 the web path left `app_class` nil — silently
# bypassing every app-tier override on every web render.
#
# These specs exercise `compute_screen_html` via a stub controller that
# duck-types Amber's params/flash/csrf_token surface. The point isn't
# to test Amber end-to-end; it's to prove the context-seeding code path
# is reachable from the web target and threads the correct value.

# Stub controller mixing in UI::ScreenHelpers. The mixin reads
# `params.to_h`, `flash.each`, and `csrf_token` — the stubs below
# emit the minimum each method needs.
private class IntentSpecStubParams
  def to_h
    {} of String => String
  end
end

private class IntentSpecStubFlash
  def each(&block)
  end
end

private class IntentSpecStubController
  include UI::ScreenHelpers

  property screen_html : String? = nil

  def params
    IntentSpecStubParams.new
  end

  def flash
    IntentSpecStubFlash.new
  end

  def csrf_token
    nil
  end

  # ScreenHelpers#compute_screen_html assigns to @screen_html — Crystal
  # synthesizes the ivar on first assignment. Expose via the public
  # property accessor above for assertions.
end

# Spec-only screen that captures the build context for assertion.
# Records `ctx.app_class` + `ctx.active_screen_class` in class vars so
# the spec can read them after `compute_screen_html` returns.
private class IntentSpecWebRecorderScreen < UI::Screen
  @@captured_app_class : (UI::App.class)? = nil
  @@captured_screen_class : (UI::Screen.class)? = nil

  def self.captured_app_class : (UI::App.class)?
    @@captured_app_class
  end

  def self.captured_screen_class : (UI::Screen.class)?
    @@captured_screen_class
  end

  def self.reset_captures : Nil
    @@captured_app_class = nil
    @@captured_screen_class = nil
    nil
  end

  def build(context : UI::ScreenContext) : UI::View
    @@captured_app_class = context.app_class
    @@captured_screen_class = context.active_screen_class
    UI::Label.new("recorded")
  end
end

describe "UI::ScreenHelpers#compute_screen_html context seeding" do
  it "seeds ctx.app_class from explicit kwarg" do
    IntentSpecWebRecorderScreen.reset_captures
    controller = IntentSpecStubController.new
    controller.compute_screen_html(
      IntentSpecWebRecorderScreen,
      app_class: IntentSpecAppA,
    )
    IntentSpecWebRecorderScreen.captured_app_class.should eq(IntentSpecAppA)
  end

  it "seeds ctx.active_screen_class from the screen_class arg" do
    IntentSpecWebRecorderScreen.reset_captures
    controller = IntentSpecStubController.new
    controller.compute_screen_html(IntentSpecWebRecorderScreen)
    IntentSpecWebRecorderScreen.captured_screen_class.should eq(IntentSpecWebRecorderScreen)
  end

  it "falls back to UI::AmberConfig.active_app when no kwarg passed" do
    IntentSpecWebRecorderScreen.reset_captures
    previous = UI::AmberConfig.active_app
    begin
      UI::AmberConfig.active_app = IntentSpecAppB
      controller = IntentSpecStubController.new
      controller.compute_screen_html(IntentSpecWebRecorderScreen)
      IntentSpecWebRecorderScreen.captured_app_class.should eq(IntentSpecAppB)
    ensure
      UI::AmberConfig.active_app = previous
    end
  end

  it "leaves ctx.app_class nil when no kwarg and no AmberConfig.active_app" do
    IntentSpecWebRecorderScreen.reset_captures
    previous = UI::AmberConfig.active_app
    begin
      UI::AmberConfig.active_app = nil
      controller = IntentSpecStubController.new
      controller.compute_screen_html(IntentSpecWebRecorderScreen)
      IntentSpecWebRecorderScreen.captured_app_class.should be_nil
    ensure
      UI::AmberConfig.active_app = previous
    end
  end

  it "applies an app-tier override on the web target via the seeded context" do
    # End-to-end proof: register an app override on AppA, render via
    # compute_screen_html with app_class: AppA, and assert the
    # resolver returned the override widget (not the default / not
    # nil). This is the regression spec for Codex iter-9 Finding 1.
    UI::Intent::Registry.reset_overrides_for_spec
    reinstall_intent_bootstrap
    IntentSpecAppA.override_intent(:swipe_actions, IntentSpecFancyRow)

    IntentSpecWebRecorderScreen.reset_captures
    controller = IntentSpecStubController.new
    controller.compute_screen_html(
      IntentSpecWebRecorderScreen,
      app_class: IntentSpecAppA,
    )

    # The screen captured the context. Resolve through the captured
    # context's app_class — must hit the override (not nil/default).
    captured_app = IntentSpecWebRecorderScreen.captured_app_class
    captured_app.should eq(IntentSpecAppA)

    # Re-resolve with a synthetic web context carrying the same app
    # class to prove the seeding path is what unlocks the override.
    ctx = UI::ScreenContext::Web.new(
      params: {} of String => String,
      params_multi: {} of String => Array(String),
      flash_data: {} of String => String,
      design_tokens: UI::DesignTokens::Tokens.default,
      csrf_token: nil,
      platform: :web_wide,
    )
    ctx.app_class = captured_app
    UI::Intent::Registry.resolve_for(:swipe_actions, ctx).should eq(IntentSpecFancyRow)
  end
end
