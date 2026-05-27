require "../spec_helper"
require "../../../src/asset_pipeline/native_app"
require "../../../src/asset_pipeline/native_context"
require "../../../src/asset_pipeline/native_controller"
require "../../../src/ui/intent"
require "../../../src/ui/intent_bootstrap"

# Phase 10B.1b — `:swipe_actions` capability honesty audit specs.
#
# Backs the audit doc
# `docs/initiative-cross-platform-ui/architecture/swipe-actions-capability-audit.md`
# by asserting the platform-keyed capability declarations on
# `UI::SwipeActionRow` + `UI::InlineActionRow` are honest, and by
# proving the registry's platform-aware validator rejects an override
# that **under-claims** a required platform/capability cell.
#
# Covers four guarantees:
#
#   1. The audit matrix matches the resolver's runtime answer.
#      For each platform with a default, `UI::Intent.resolve` returns
#      the widget the audit lists as the platform default, and the
#      `capabilities_required:` kwarg gates per-platform honestly.
#   2. `IncompatibleOverride` fires when a candidate override widget
#      UNDER-CLAIMS a required cell — e.g. declares
#      `:web_wide => false` for `supports_role_destructive` while the
#      intent demands `:web_wide => true`, or declares
#      `:macos => false` for `supports_edge_trailing` while macOS has
#      a registered default for the intent.
#   3. The legacy `:partial` value no longer satisfies a `true` /
#      platform-keyed requirement — apps that previously relied on the
#      fuzzy declaration must migrate to platform-keyed honesty.
#   4. Rocket-style HashLiteral keys (`:ios => true`) produce plain
#      `:ios` symbol keys in the registry — not `:":ios"` — and pass
#      override validation end-to-end (iter-2 Finding 1 regression
#      guard).
#
# # What the registry does NOT enforce (honesty-doc disclosure)
#
# The validator walks only required-`true` cells (see
# `registry.cr:305` — `next unless needed`). A widget that declares
# `:macos => true` for `supports_role_destructive` when the intent's
# required Hash has `:macos => false` registers successfully. The
# registry has no oracle for what a renderer paints, so over-claims
# are caught by the audit doc + Codex review of renderer code, not
# by this spec or `IncompatibleOverride`.
#
# This is intentional. If a future intent flip raises a previously-
# unrequired cell to `true`, the validator re-checks the override at
# the next registration and rejects an over-claim that didn't back the
# renderer. The over-claim → silent renderer gap is closed when (and
# only when) the requirement cell flips.

# ---------------- Spec helper: re-install honest bootstrap ----------------

# Re-installs the bootstrap state with the platform-keyed
# `:swipe_actions` requirement so mid-flow `reset_overrides_for_spec`
# calls in this file don't strand the validator. Mirrors the helper
# in `intent_spec.cr` but lives here so this file is self-contained.
private def reinstall_audit_bootstrap : Nil
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
  UI::Intent::Registry.register_default(:swipe_actions, :macos, UI::InlineActionRow)
  UI::Intent::Registry.register_default(:swipe_actions, :web_wide, UI::InlineActionRow)
  nil
end

private def audit_native_ctx(platform : Symbol) : UI::ScreenContext::Native
  UI::ScreenContext::Native.new(
    form_state: UI::FormState.new(mount_token: 0_i64),
    session: UI::Session::InProcess.new,
    flash: UI::Flash::InProcess.new,
    design_tokens: UI::DesignTokens::Tokens.default,
    navigation: UI::NavigationCoordinator.new(UI::NavigationCoordinator::Route.new(:test)),
    platform: platform,
  )
end

private def audit_web_ctx(platform : Symbol) : UI::ScreenContext::Web
  UI::ScreenContext::Web.new(
    params: {} of String => String,
    params_multi: {} of String => Array(String),
    flash_data: {} of String => String,
    design_tokens: UI::DesignTokens::Tokens.default,
    csrf_token: nil,
    platform: platform,
  )
end

# ---------------- Honest-override fixtures ----------------

# A spec app + screen used to scope override registrations.
private class AuditSpecApp < UI::App
end

# A spec widget that mirrors the platform-honest declaration of the
# real `UI::InlineActionRow` (used to assert the validator ACCEPTS a
# correct override).
private class AuditHonestRow < UI::View
  declares_capabilities :swipe_actions, {
    supports_edge_trailing: {
      ios:        true,
      ipados:     true,
      macos:      true,
      web_wide:   true,
      web_narrow: true,
      android:    true,
    },
    supports_edge_leading: {
      ios:        true,
      ipados:     true,
      macos:      true,
      web_wide:   true,
      web_narrow: true,
      android:    true,
    },
    supports_role_default: {
      ios:        true,
      ipados:     true,
      macos:      true,
      web_wide:   true,
      web_narrow: true,
      android:    true,
    },
    supports_role_destructive: {
      ios:        true,
      ipados:     true,
      macos:      false,
      web_wide:   true,
      web_narrow: true,
      android:    true,
    },
  }

  def initialize
  end

  def accept(visitor : UI::PlatformVisitor)
  end
end

# A spec widget that uses rocket-style HashLiteral keys (`:ios => true`)
# instead of the NamedTuple shorthand. The macro must produce a
# `Hash(Symbol, Bool)` whose keys are plain `:ios` / `:macos` / etc. and
# NOT double-symbolized `:":ios"`. Used to prove the macro's HashLiteral
# branch is honest end-to-end: declaration → registry → resolver lookup.
private class AuditRocketHashRow < UI::View
  declares_capabilities :swipe_actions, {
    :supports_edge_trailing => {
      :ios        => true,
      :ipados     => true,
      :macos      => true,
      :web_wide   => true,
      :web_narrow => true,
      :android    => true,
    },
    :supports_edge_leading => {
      :ios        => true,
      :ipados     => true,
      :macos      => true,
      :web_wide   => true,
      :web_narrow => true,
      :android    => true,
    },
    :supports_role_default => {
      :ios        => true,
      :ipados     => true,
      :macos      => true,
      :web_wide   => true,
      :web_narrow => true,
      :android    => true,
    },
    :supports_role_destructive => {
      :ios        => true,
      :ipados     => true,
      :macos      => false,
      :web_wide   => true,
      :web_narrow => true,
      :android    => true,
    },
  }

  def initialize
  end

  def accept(visitor : UI::PlatformVisitor)
  end
end

# A spec widget that LIES — claims destructive support on macOS even
# though no macOS renderer paints the tint. The registry must reject
# this when the intent's required set demands `:macos => false` is
# fine BUT the widget would also need to honor required `:ios => true`,
# which is fine. So we make the widget lie in the opposite direction:
# claim destructive support on `:web_wide` is `false` while the intent
# requires it `true` on `:web_wide`. The registry must catch the gap.
private class AuditDishonestWebRow < UI::View
  declares_capabilities :swipe_actions, {
    supports_edge_trailing:    true,
    supports_role_default:     true,
    supports_role_destructive: {
      ios:    true,
      ipados: true,
      macos:  false,
      # LIE: web_wide is REQUIRED true but this widget declares false.
      web_wide:   false,
      web_narrow: true,
      android:    false,
    },
  }

  def initialize
  end

  def accept(visitor : UI::PlatformVisitor)
  end
end

# A spec widget that fails the universal `supports_edge_trailing` (`true`)
# requirement by declaring it as a platform-keyed hash with macOS = false.
# Since macOS has a registered default for :swipe_actions, an override
# shadowing it must back the capability on macOS.
private class AuditDishonestTrailingRow < UI::View
  declares_capabilities :swipe_actions, {
    supports_edge_trailing: {
      ios:    true,
      ipados: true,
      # LIE: macOS shadowed-default case requires true here.
      macos:      false,
      web_wide:   true,
      web_narrow: true,
      android:    true,
    },
    supports_role_default:     true,
    supports_role_destructive: {
      ios:        true,
      ipados:     true,
      macos:      false,
      web_wide:   true,
      web_narrow: true,
      android:    true,
    },
  }

  def initialize
  end

  def accept(visitor : UI::PlatformVisitor)
  end
end

# Widget that uses the legacy `:partial` Symbol value. Pre-10B.1b this
# satisfied a `true` requirement (the validator's `:partial` clause was
# the half-pass path). Post-10B.1b the validator rejects it when the
# requirement is `true` AND there are platform defaults that the
# override would shadow — `:partial` is too fuzzy to prove coverage.
private class AuditLegacyPartialRow < UI::View
  declares_capabilities :swipe_actions, {
    supports_edge_trailing:    :partial,
    supports_role_default:     true,
    supports_role_destructive: :partial,
  }

  def initialize
  end

  def accept(visitor : UI::PlatformVisitor)
  end
end

# ---------------- Specs ----------------

describe "Phase 10B.1b — :swipe_actions capability audit" do
  describe "matrix matches resolver answers" do
    it "iOS resolves to UI::SwipeActionRow (audit lists it as iOS default)" do
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap
      UI::Intent.resolve(:swipe_actions, audit_native_ctx(:ios)).should eq(UI::SwipeActionRow)
    end

    it "macOS resolves to UI::InlineActionRow" do
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap
      UI::Intent.resolve(:swipe_actions, audit_native_ctx(:macos)).should eq(UI::InlineActionRow)
    end

    it "web_wide resolves to UI::InlineActionRow" do
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap
      UI::Intent.resolve(:swipe_actions, audit_web_ctx(:web_wide)).should eq(UI::InlineActionRow)
    end

    it "web_narrow resolves to UI::SwipeActionRow" do
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap
      UI::Intent.resolve(:swipe_actions, audit_web_ctx(:web_narrow)).should eq(UI::SwipeActionRow)
    end
  end

  describe "iOS SwipeActionRow honest declarations" do
    it "supports destructive on iOS (capabilities_required passes)" do
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap
      result = UI::Intent.resolve(
        :swipe_actions,
        audit_native_ctx(:ios),
        capabilities_required: {:supports_role_destructive => true},
      )
      result.should eq(UI::SwipeActionRow)
    end

    it "does NOT support destructive on macOS (capabilities_required raises)" do
      # On macOS, the resolver returns UI::InlineActionRow, which the
      # audit honestly declares `supports_role_destructive` as
      # `macos: false`. Asking for the capability via the runtime
      # gate must raise UnresolvableDefault rather than handing back
      # a widget that cannot paint the tint.
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap
      expect_raises(
        UI::Intent::UnresolvableDefault,
        /supports_role_destructive.*:macos/,
      ) do
        UI::Intent.resolve(
          :swipe_actions,
          audit_native_ctx(:macos),
          capabilities_required: {:supports_role_destructive => true},
        )
      end
    end
  end

  describe "InlineActionRow on web_wide" do
    it "supports destructive on web_wide (renders as button with .danger styling)" do
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap
      result = UI::Intent.resolve(
        :swipe_actions,
        audit_web_ctx(:web_wide),
        capabilities_required: {:supports_role_destructive => true},
      )
      result.should eq(UI::InlineActionRow)
    end

    it "supports leading edge on web_wide (InlineActionRow renders both edges)" do
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap
      result = UI::Intent.resolve(
        :swipe_actions,
        audit_web_ctx(:web_wide),
        capabilities_required: {:supports_edge_leading => true},
      )
      result.should eq(UI::InlineActionRow)
    end
  end

  describe "leading edge honesty for SwipeActionRow" do
    it "honors supports_edge_leading on iOS (Phase 10D-refocus enabled SwiftUI .swipeActions(edge:.leading))" do
      # Phase 10D-refocus: the UIKit renderer routes through the
      # APSKSwipeActionRowFacade which emits both leading + trailing
      # `.swipeActions(edge:)` modifiers. The widget honestly declares
      # `supports_edge_leading.ios = true`, and the resolver must now
      # return SwipeActionRow itself (no UnresolvableDefault).
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap
      result = UI::Intent.resolve(
        :swipe_actions,
        audit_native_ctx(:ios),
        capabilities_required: {:supports_edge_leading => true},
      )
      result.should eq(UI::SwipeActionRow)
    end
  end

  describe "registry rejects overrides that lie per-platform" do
    it "rejects an override that claims web_wide destructive but declares false" do
      # The intent requires `supports_role_destructive => {web_wide:
      # true, ...}`. AuditDishonestWebRow declares it as a Hash with
      # `web_wide: false`. Registration must raise IncompatibleOverride
      # naming the platform.
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap

      expect_raises(
        UI::Intent::IncompatibleOverride,
        /supports_role_destructive.*:web_wide/,
      ) do
        UI::Intent::Registry.register_app_override(
          AuditSpecApp,
          :swipe_actions,
          AuditDishonestWebRow,
        )
      end
    end

    it "rejects an override that claims supports_edge_trailing but drops macOS" do
      # `supports_edge_trailing` is required `true` (universal).
      # AuditDishonestTrailingRow declares a platform-keyed hash with
      # `macos: false`. Because macOS has a registered default for
      # :swipe_actions (UI::InlineActionRow), an override shadowing
      # that default MUST back the capability on macOS — otherwise
      # the override silently drops trailing actions on macOS.
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap

      expect_raises(
        UI::Intent::IncompatibleOverride,
        /supports_edge_trailing/,
      ) do
        UI::Intent::Registry.register_app_override(
          AuditSpecApp,
          :swipe_actions,
          AuditDishonestTrailingRow,
        )
      end
    end

    it "rejects an override using the legacy `:partial` value when the requirement is platform-keyed" do
      # Pre-10B.1b a widget could pass with `:partial` everywhere.
      # Now the validator demands honest per-platform coverage for
      # the platform-keyed requirement. `:partial` for
      # `supports_role_destructive` does not prove ios/ipados/web_wide
      # are covered, so the registration must raise.
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap

      expect_raises(
        UI::Intent::IncompatibleOverride,
        /widget declared :partial/,
      ) do
        UI::Intent::Registry.register_app_override(
          AuditSpecApp,
          :swipe_actions,
          AuditLegacyPartialRow,
        )
      end
    end

    it "accepts an honest override that backs every required (platform, capability)" do
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap

      AuditSpecApp.override_intent(:swipe_actions, AuditHonestRow)
      UI::Intent::Registry.app_override_count_for(AuditSpecApp, :swipe_actions).should eq(1)
    end
  end

  describe "macro HashLiteral key handling (rocket-style)" do
    # Iter-2 finding 1 (Codex REVISE): the `declares_capabilities` macro
    # claims to accept both NamedTupleLiteral (`ios: true`) and HashLiteral
    # (`:ios => true`) shapes for the per-capability platform map. Pre-fix
    # the HashLiteral branch ran `.symbolize` on a key that was already a
    # SymbolLiteral, producing `:":ios"` — which never matched a `:ios`
    # lookup in the registry. These specs prove the post-fix end-to-end
    # chain: rocket-style declaration → registry stores plain `:ios` →
    # resolver gates correctly per platform.

    it "stores plain platform symbol keys (not double-symbolized) in the registry" do
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap

      declared = UI::Intent::Registry.declared_capabilities_for(
        AuditRocketHashRow, :swipe_actions
      )
      declared.should_not be_nil
      d = declared.not_nil!
      value = d[:supports_role_destructive]
      value.is_a?(Hash).should be_true
      h = value.as(Hash(Symbol, Bool))

      # Plain :ios / :macos lookups must succeed — pre-fix these would
      # return nil because the macro had stored `:":ios"`.
      h[:ios].should be_true
      h[:ipados].should be_true
      h[:macos].should be_false
      h[:web_wide].should be_true
      h[:web_narrow].should be_true
      h[:android].should be_true

      # Belt-and-braces: the double-symbolized form must NOT be present.
      h[:":ios"]?.should be_nil
      h[:":macos"]?.should be_nil
    end

    it "rocket-style key declaration accepts as honest override on macOS" do
      UI::Intent::Registry.reset_overrides_for_spec
      reinstall_audit_bootstrap

      # AuditRocketHashRow is honest on every required cell (it declares
      # `supports_role_destructive` as `:macos => false`, matching the
      # intent requirement). Registration must succeed.
      AuditSpecApp.override_intent(:swipe_actions, AuditRocketHashRow)
      UI::Intent::Registry.app_override_count_for(AuditSpecApp, :swipe_actions).should eq(1)
    end
  end

  describe "library widget declarations match the audit doc" do
    # Sanity-check that the platform-keyed declarations the audit
    # describes are the ones loaded into the registry. Acts as a
    # change-detector: if a future implementer flips a cell without
    # updating the audit doc, this spec is the trip-wire.

    it "SwipeActionRow declares supports_edge_leading true on iOS (Phase 10D-refocus)" do
      # Phase 10D-refocus flipped this cell from false to true once
      # the SwiftUI .swipeActions(edge: .leading) facade landed.
      declared = UI::Intent::Registry.declared_capabilities_for(
        UI::SwipeActionRow, :swipe_actions
      )
      declared.should_not be_nil
      d = declared.not_nil!
      value = d[:supports_edge_leading]
      value.is_a?(Hash).should be_true
      value.as(Hash(Symbol, Bool))[:ios].should be_true
      value.as(Hash(Symbol, Bool))[:ipados].should be_true
      value.as(Hash(Symbol, Bool))[:web_wide].should be_true
    end

    it "SwipeActionRow declares supports_role_destructive false on macOS" do
      declared = UI::Intent::Registry.declared_capabilities_for(
        UI::SwipeActionRow, :swipe_actions
      )
      d = declared.not_nil!
      value = d[:supports_role_destructive]
      value.is_a?(Hash).should be_true
      value.as(Hash(Symbol, Bool))[:macos].should be_false
      value.as(Hash(Symbol, Bool))[:ios].should be_true
    end

    it "InlineActionRow declares supports_role_destructive false on macOS, true on Android" do
      declared = UI::Intent::Registry.declared_capabilities_for(
        UI::InlineActionRow, :swipe_actions
      )
      d = declared.not_nil!
      value = d[:supports_role_destructive]
      value.is_a?(Hash).should be_true
      value.as(Hash(Symbol, Bool))[:macos].should be_false
      value.as(Hash(Symbol, Bool))[:android].should be_true
    end
  end
end
