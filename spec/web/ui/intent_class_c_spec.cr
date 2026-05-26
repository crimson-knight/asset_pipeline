require "../spec_helper"
require "../../../src/ui/intent"
require "../../../src/ui/intent/class_c_bootstrap"
require "../../../src/ui/environment"

# Phase 10B.3.0 — UI::Intent::ClassCRegistry + UI::Intent.dispatch
# + UI::Environment.feature_supported? specs.
#
# Covers:
#
#   * `dispatch(:hello_world_alert, ...)` on the web platform returns
#     `DispatchResult.success`.
#   * `dispatch(:unknown_intent, ...)` returns
#     `DispatchResult.unsupported` (no binding registered).
#   * Dispatch on a platform missing from the binding's map returns
#     `DispatchResult.unsupported` with a helpful detail.
#   * A binding whose lambda raises returns
#     `DispatchResult.failed(reason)`.
#   * `feature_supported?` returns true when a binding covers the
#     current platform AND the capability check passes; false
#     otherwise.
#   * `PlatformFeatureBinding#supports?` honours
#     `api_capability_check`.

# Helper: fully reset Class C registry + Environment platform between
# test groups so each describe block starts from a clean state. We
# call `ClassCBootstrap.install` after a reset to put the framework
# `:hello_world_alert` binding back so the dispatch tests pass.
private def reinstall_class_c_bootstrap : Nil
  UI::Intent::ClassCRegistry.reset_for_spec
  UI::Environment.reset_platform_for_spec
  UI::Intent::ClassCBootstrap.install
  nil
end

describe UI::Intent::ClassCRegistry do
  before_each { reinstall_class_c_bootstrap }

  describe ".binding_for" do
    it "returns the registered binding for :hello_world_alert" do
      binding = UI::Intent::ClassCRegistry.binding_for(:hello_world_alert)
      binding.should_not be_nil
      binding.not_nil!.intent_id.should eq(:hello_world_alert)
    end

    it "returns nil for an unknown intent" do
      UI::Intent::ClassCRegistry.binding_for(:no_such_intent).should be_nil
    end
  end

  describe ".supports?" do
    it "returns true when a binding covers the platform" do
      UI::Intent::ClassCRegistry.supports?(:hello_world_alert, :web_wide).should be_true
      UI::Intent::ClassCRegistry.supports?(:hello_world_alert, :web_narrow).should be_true
      UI::Intent::ClassCRegistry.supports?(:hello_world_alert, :macos).should be_true
    end

    it "returns false when the intent isn't registered" do
      UI::Intent::ClassCRegistry.supports?(:no_such_intent, :web_wide).should be_false
    end

    it "returns false when the binding's api_capability_check fails" do
      UI::Intent::ClassCRegistry.register(
        UI::Intent::PlatformFeatureBinding.new(
          intent_id: :spec_check_fail,
          api_capability_check: ->(_p : Symbol) { false },
          platforms: {
            :web_wide => ->(_a : UI::Intent::PlatformFeatureBinding::Args) { nil },
          } of Symbol => UI::Intent::PlatformFeatureBinding::PlatformProc,
        )
      )
      UI::Intent::ClassCRegistry.supports?(:spec_check_fail, :web_wide).should be_false
    end
  end

  describe ".registered_intents" do
    it "includes :hello_world_alert after bootstrap" do
      UI::Intent::ClassCRegistry.registered_intents.should contain(:hello_world_alert)
    end
  end
end

describe UI::Intent::PlatformFeatureBinding do
  it "exposes intent_id, api_capability_check, platforms" do
    binding = UI::Intent::PlatformFeatureBinding.new(
      intent_id: :spec_binding,
      platforms: {
        :web_wide => ->(_a : UI::Intent::PlatformFeatureBinding::Args) { nil },
      } of Symbol => UI::Intent::PlatformFeatureBinding::PlatformProc,
    )
    binding.intent_id.should eq(:spec_binding)
    binding.platforms.has_key?(:web_wide).should be_true
  end

  it "supports? consults both the platforms map and the capability check" do
    binding = UI::Intent::PlatformFeatureBinding.new(
      intent_id: :spec_binding,
      api_capability_check: ->(p : Symbol) { p == :web_wide },
      platforms: {
        :web_wide   => ->(_a : UI::Intent::PlatformFeatureBinding::Args) { nil },
        :web_narrow => ->(_a : UI::Intent::PlatformFeatureBinding::Args) { nil },
      } of Symbol => UI::Intent::PlatformFeatureBinding::PlatformProc,
    )
    binding.supports?(:web_wide).should be_true
    # web_narrow is in the platforms map but the capability check
    # returns false for it.
    binding.supports?(:web_narrow).should be_false
    # :macos isn't in the platforms map at all.
    binding.supports?(:macos).should be_false
  end
end

describe UI::Intent do
  describe ".dispatch" do
    before_each { reinstall_class_c_bootstrap }

    it "returns DispatchResult.success for :hello_world_alert on web" do
      UI::Environment.set_platform(:web_wide)
      result = UI::Intent.dispatch(:hello_world_alert, {:message => "hi from spec"})
      result.success?.should be_true
      result.unsupported?.should be_false
      result.failed?.should be_false
    end

    it "accepts kwargs and packs them into the args hash" do
      UI::Environment.set_platform(:web_wide)
      result = UI::Intent.dispatch(:hello_world_alert, message: "via kwargs")
      result.success?.should be_true
    end

    it "accepts a custom title arg" do
      UI::Environment.set_platform(:web_narrow)
      result = UI::Intent.dispatch(
        :hello_world_alert,
        {:title => "Greetings", :message => "from web_narrow"}
      )
      result.success?.should be_true
    end

    it "returns DispatchResult.unsupported for an unknown intent" do
      UI::Environment.set_platform(:web_wide)
      result = UI::Intent.dispatch(:no_such_intent)
      result.unsupported?.should be_true
      result.reason.not_nil!.should contain("No Class C binding registered")
    end

    it "returns DispatchResult.unsupported when the binding does not cover the platform" do
      UI::Intent::ClassCRegistry.register(
        UI::Intent::PlatformFeatureBinding.new(
          intent_id: :web_only_feature,
          platforms: {
            :web_wide => ->(_a : UI::Intent::PlatformFeatureBinding::Args) { nil },
          } of Symbol => UI::Intent::PlatformFeatureBinding::PlatformProc,
        )
      )
      UI::Environment.set_platform(:macos)
      result = UI::Intent.dispatch(:web_only_feature)
      result.unsupported?.should be_true
      result.reason.not_nil!.should contain("does not cover platform")
    end

    it "returns DispatchResult.failed when the platform lambda raises" do
      UI::Intent::ClassCRegistry.register(
        UI::Intent::PlatformFeatureBinding.new(
          intent_id: :raising_feature,
          platforms: {
            :web_wide => ->(_a : UI::Intent::PlatformFeatureBinding::Args) {
              raise "boom from spec"
              nil
            },
          } of Symbol => UI::Intent::PlatformFeatureBinding::PlatformProc,
        )
      )
      UI::Environment.set_platform(:web_wide)
      result = UI::Intent.dispatch(:raising_feature)
      result.failed?.should be_true
      result.reason.not_nil!.should contain("boom from spec")
    end

    it "honours api_capability_check at dispatch time" do
      UI::Intent::ClassCRegistry.register(
        UI::Intent::PlatformFeatureBinding.new(
          intent_id: :gated_feature,
          api_capability_check: ->(_p : Symbol) { false },
          platforms: {
            :web_wide => ->(_a : UI::Intent::PlatformFeatureBinding::Args) { nil },
          } of Symbol => UI::Intent::PlatformFeatureBinding::PlatformProc,
        )
      )
      UI::Environment.set_platform(:web_wide)
      result = UI::Intent.dispatch(:gated_feature)
      result.unsupported?.should be_true
    end
  end
end

describe UI::Environment do
  before_each { reinstall_class_c_bootstrap }

  describe ".feature_supported?" do
    it "returns true when the binding covers the current platform" do
      UI::Environment.set_platform(:web_wide)
      UI::Environment.feature_supported?(:hello_world_alert).should be_true
    end

    it "returns false for an unregistered intent" do
      UI::Environment.set_platform(:web_wide)
      UI::Environment.feature_supported?(:nope).should be_false
    end

    it "tracks platform changes" do
      UI::Intent::ClassCRegistry.register(
        UI::Intent::PlatformFeatureBinding.new(
          intent_id: :macos_only_feature,
          platforms: {
            :macos => ->(_a : UI::Intent::PlatformFeatureBinding::Args) { nil },
          } of Symbol => UI::Intent::PlatformFeatureBinding::PlatformProc,
        )
      )
      UI::Environment.set_platform(:macos)
      UI::Environment.feature_supported?(:macos_only_feature).should be_true
      UI::Environment.set_platform(:web_wide)
      UI::Environment.feature_supported?(:macos_only_feature).should be_false
    end
  end

  describe ".platform" do
    it "defaults to :web_wide on builds without a platform flag" do
      UI::Environment.reset_platform_for_spec
      # Default depends on compile-time flag — the test suite runs
      # without -Dmacos/-Dios/-Dandroid, so the default is :web_wide.
      UI::Environment.platform.should eq(:web_wide)
    end

    it "round-trips through set_platform / reset_platform_for_spec" do
      UI::Environment.set_platform(:android)
      UI::Environment.platform.should eq(:android)
      UI::Environment.reset_platform_for_spec
      UI::Environment.platform.should eq(:web_wide)
    end
  end
end

describe UI::Intent::DispatchResult do
  it "Success predicates" do
    s = UI::Intent::DispatchResult.success
    s.success?.should be_true
    s.unsupported?.should be_false
    s.failed?.should be_false
    s.reason.should be_nil
  end

  it "Unsupported predicates carry the detail in reason" do
    u = UI::Intent::DispatchResult.unsupported("test detail")
    u.unsupported?.should be_true
    u.reason.should eq("test detail")
  end

  it "Failed predicates carry the reason" do
    f = UI::Intent::DispatchResult.failed("boom")
    f.failed?.should be_true
    f.reason.should eq("boom")
  end
end
