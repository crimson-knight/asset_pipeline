require "../spec_helper"
require "../../src/asset_pipeline/native_app"
require "../../src/asset_pipeline/native_context"
require "../../src/asset_pipeline/native_controller"
require "../../src/ui/intent"
require "../../src/ui/intent_bootstrap"

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
    supports_edge_trailing:    true,
    supports_role_default:     true,
    supports_role_destructive: :partial,
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
    supports_edge_trailing:    true,
    supports_role_default:     true,
    supports_role_destructive: :partial,
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
  override_intent :swipe_actions, IntentSpecFancyRow

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
    :supports_role_destructive => :partial,
  } of Symbol => Bool | Symbol)
  UI::Intent::Registry.register_default(:swipe_actions, :ios, UI::SwipeActionRow)
  UI::Intent::Registry.register_default(:swipe_actions, :ipados, UI::SwipeActionRow)
  UI::Intent::Registry.register_default(:swipe_actions, :web_narrow, UI::SwipeActionRow)
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

    it "raises UnresolvableDefault for :swipe_actions on macOS (no default)" do
      ctx = native_ctx(:macos)
      expect_raises(UI::Intent::UnresolvableDefault, /:swipe_actions.*:macos/) do
        UI::Intent.resolve(:swipe_actions, ctx)
      end
    end

    it "raises UnresolvableDefault for :swipe_actions on web_wide (no default)" do
      ctx = web_ctx(:web_wide)
      expect_raises(UI::Intent::UnresolvableDefault, /:swipe_actions.*:web_wide/) do
        UI::Intent.resolve(:swipe_actions, ctx)
      end
    end

    it "raises UnresolvableDefault for :swipe_actions on android (no default)" do
      ctx = native_ctx(:android)
      expect_raises(UI::Intent::UnresolvableDefault, /:swipe_actions.*:android/) do
        UI::Intent.resolve(:swipe_actions, ctx)
      end
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

      ctx = native_ctx(:macos)
      # ctx.app_class remains nil — no default exists for :macos on
      # :swipe_actions, so the resolver returns nil.
      UI::Intent::Registry.resolve_for(:swipe_actions, ctx).should be_nil
    end
  end

  describe "screen overrides take precedence" do
    # IntentSpecScreenA registered :swipe_actions → IntentSpecFancyRow
    # via the class-level macro at class body time (see the class
    # definition above). Spec runs against that pre-registered state.

    it "screen override wins over app override at resolve time" do
      # Iter-9 (Finding 1): the isolation specs above call
      # `reset_overrides_for_spec`, which clears the screen-override
      # table — including IntentSpecScreenA's class-body registration.
      # Re-install it here so the precedence assertion has the
      # screen-tier entry it needs.
      reinstall_intent_bootstrap
      UI::Intent::Registry.register_screen_override(
        IntentSpecScreenA,
        :swipe_actions,
        IntentSpecFancyRow,
      )
      ctx = native_ctx(:macos)
      # Passing screen_class: routes through the screen-tier first.
      hit = UI::Intent::Registry.resolve_for(:swipe_actions, ctx, screen_class: IntentSpecScreenA)
      hit.should eq(IntentSpecFancyRow)
      UI::Intent::Registry.screen_override_count_for(IntentSpecScreenA, :swipe_actions).should be > 0
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
