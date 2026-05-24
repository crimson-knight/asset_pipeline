require "../spec_helper"
require "../../src/asset_pipeline/native_app"

# Stub screens + controllers used by the registration specs. The real
# `UI::Controller` base class lands in `native_controller.cr` (iter 2);
# the forward declaration in `native_app.cr` is enough for screen
# registration to compile here.
private class NativeAppSpecScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    UI::Label.new("stub")
  end
end

private class NativeAppSpecOtherScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    UI::Label.new("other")
  end
end

# This pair tests the implicit FooController -> FooScreen derivation:
# `screen :detail, NativeAppSpecDetailController` (with no explicit
# screen_class) must resolve to NativeAppSpecDetailScreen.
private class NativeAppSpecDetailScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    UI::Label.new("detail")
  end
end

private class NativeAppSpecController < UI::Controller
end

private class NativeAppSpecOtherController < UI::Controller
end

private class NativeAppSpecDetailController < UI::Controller
end

# Mock app: two explicit screen_class registrations + one implicit
# derivation (NativeAppSpecDetailController -> NativeAppSpecDetailScreen).
private class NativeAppSpecApp < UI::App
  initial_route :primary

  screen :primary, NativeAppSpecController, screen_class: NativeAppSpecScreen
  screen :secondary, NativeAppSpecOtherController, screen_class: NativeAppSpecOtherScreen
  screen :detail, NativeAppSpecDetailController
end

# Mock app that exercises the design_tokens macro override.
private class NativeAppSpecBrandedApp < UI::App
  initial_route :primary
  screen :primary, NativeAppSpecController, screen_class: NativeAppSpecScreen

  design_tokens do
    # The macro body has a local `tokens` initialised to
    # UI::DesignTokens::Tokens.default. Touching the variable
    # proves the block body actually runs and the resulting
    # value is wired into the class-getter. We avoid the internal
    # tokens shape so the spec stays resilient to brand contract
    # refactors.
    tokens
  end
end

describe UI::App do
  it "captures the declared initial_route_id" do
    NativeAppSpecApp.initial_route_id.should eq(:primary)
  end

  it "registers every screen declared by the `screen` macro" do
    NativeAppSpecApp.screens.keys.should contain(:primary)
    NativeAppSpecApp.screens.keys.should contain(:secondary)
  end

  it "looks up a registered screen via registration_for" do
    reg = NativeAppSpecApp.registration_for(:primary)
    reg.route_id.should eq(:primary)
    reg.controller_class.should eq(NativeAppSpecController)
    reg.screen_class.should eq(NativeAppSpecScreen)
  end

  it "raises UnknownRouteError with the available routes for an unknown id" do
    expect_raises(UI::App::UnknownRouteError, /not_a_route/) do
      NativeAppSpecApp.registration_for(:not_a_route)
    end
  end

  it "derives FooController -> FooScreen by default when screen_class omitted" do
    reg = NativeAppSpecApp.registration_for(:detail)
    reg.controller_class.should eq(NativeAppSpecDetailController)
    reg.screen_class.should eq(NativeAppSpecDetailScreen)
  end

  it "defaults app_design_tokens to a Tokens instance" do
    NativeAppSpecApp.app_design_tokens.should be_a(UI::DesignTokens::Tokens)
  end

  it "leaves initial_route_id unset for apps that don't declare one" do
    UI::App.initial_route_id.should eq(:_unset)
  end

  it "exposes a Tokens instance via the design_tokens macro override" do
    NativeAppSpecBrandedApp.app_design_tokens.should be_a(UI::DesignTokens::Tokens)
  end

  it "bootstrap! is idempotent and re-registers every screen" do
    # Force-clear the registry, then bootstrap, and verify both explicit
    # and derived registrations land back in. Two passes prove idempotence.
    original_keys = NativeAppSpecApp.screens.keys.dup
    NativeAppSpecApp.screens.clear
    NativeAppSpecApp.screens.size.should eq(0)
    NativeAppSpecApp.bootstrap!
    NativeAppSpecApp.screens.size.should eq(original_keys.size)
    original_keys.each { |k| NativeAppSpecApp.screens.has_key?(k).should be_true }
    # Second call — must not duplicate or fail.
    NativeAppSpecApp.bootstrap!
    NativeAppSpecApp.screens.size.should eq(original_keys.size)
  end
end
