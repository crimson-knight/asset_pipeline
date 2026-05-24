require "../spec_helper"
require "../../src/asset_pipeline/native_app"

# Stub screen + controller used by the registration specs. The real
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

private class NativeAppSpecController < UI::Controller
end

private class NativeAppSpecOtherController < UI::Controller
end

# Mock app with the conventional FooController -> FooScreen mapping.
private class NativeAppSpecApp < UI::App
  initial_route :primary

  screen :primary, NativeAppSpecController, screen_class: NativeAppSpecScreen
  screen :secondary, NativeAppSpecOtherController, screen_class: NativeAppSpecOtherScreen
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

  it "defaults app_design_tokens to a Tokens instance" do
    NativeAppSpecApp.app_design_tokens.should be_a(UI::DesignTokens::Tokens)
  end

  it "leaves initial_route_id unset for apps that don't declare one" do
    UI::App.initial_route_id.should eq(:_unset)
  end
end
