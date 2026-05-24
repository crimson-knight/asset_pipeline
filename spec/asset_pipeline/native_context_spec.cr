require "../spec_helper"
require "../../src/asset_pipeline/native_context"

private def build_native_context(
  *,
  form_state : UI::FormState = UI::FormState.new,
  session : UI::Session = UI::Session::InProcess.new,
  flash : UI::Flash = UI::Flash::InProcess.new,
  navigation : UI::NavigationCoordinator = UI::NavigationCoordinator.new(
    UI::NavigationCoordinator::Route.new(:sign_in)
  ),
  action_params : Hash(String, String) = {} of String => String,
) : UI::ScreenContext::Native
  UI::ScreenContext::Native.new(
    form_state: form_state,
    session: session,
    flash: flash,
    design_tokens: UI::DesignTokens::Tokens.default,
    navigation: navigation,
    action_params: action_params,
  )
end

describe UI::Session::InProcess do
  it "stores and reads keys" do
    sess = UI::Session::InProcess.new
    sess["user_email"] = "seth@example.com"
    sess["user_email"].should eq("seth@example.com")
    sess["missing"]?.should be_nil
  end

  it "returns a defensive copy via to_h" do
    sess = UI::Session::InProcess.new
    sess["k"] = "v"
    snapshot = sess.to_h
    snapshot["k"] = "mutated"
    sess["k"].should eq("v")
  end
end

describe UI::Flash::InProcess do
  it "stores and clears one-shot messages" do
    flash = UI::Flash::InProcess.new
    flash["notice"] = "saved"
    flash["notice"].should eq("saved")
    flash.clear
    flash["notice"]?.should be_nil
  end

  it "to_h returns a defensive copy" do
    flash = UI::Flash::InProcess.new
    flash["k"] = "v"
    flash.to_h["k"] = "mutated"
    flash["k"].should eq("v")
  end
end

describe UI::ScreenContext::Native do
  it "exposes form_state, session, flash, design_tokens, navigation, action_params" do
    sess = UI::Session::InProcess.new
    sess["user_email"] = "seth@example.com"
    flash = UI::Flash::InProcess.new
    flash["notice"] = "welcome"
    nav = UI::NavigationCoordinator.new(UI::NavigationCoordinator::Route.new(:sign_in))

    ctx = build_native_context(
      session: sess, flash: flash, navigation: nav,
      action_params: {"todo_id" => "42"},
    )

    ctx.session.should be(sess)
    ctx.flash.should be(flash)
    ctx.navigation.should be(nav)
    ctx.action_params["todo_id"].should eq("42")
    ctx.design_tokens.should be_a(UI::DesignTokens::Tokens)
  end

  it "params + action_params stay SEPARATE (no silent merge)" do
    # Per Codex finding #2 on Phase 8B brief.
    ctx = build_native_context(
      action_params: {"todo_id" => "42", "email" => "FROM_BUTTON"},
    )

    # form_state is the iter-3 stub: its to_h returns {} until iter 3
    # ships the real FormState. The key point we test here is that
    # action_params is NOT silently merged into ctx.params.
    ctx.params.has_key?("todo_id").should be_false
    ctx.action_params["todo_id"].should eq("42")
  end

  it "csrf_token is explicitly nil for native targets" do
    ctx = build_native_context
    ctx.csrf_token.should be_nil
  end

  it "flash_data returns a Hash snapshot of flash messages" do
    flash = UI::Flash::InProcess.new
    flash["notice"] = "ok"
    ctx = build_native_context(flash: flash)
    ctx.flash_data["notice"].should eq("ok")
  end

  it "params_multi returns an empty hash (native targets are scalar-only for now)" do
    ctx = build_native_context
    ctx.params_multi.should be_empty
  end
end
