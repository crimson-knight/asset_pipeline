# fixture_for: family_4/spec_test_id_reference
# expected: pass
# synthetic_path: spec/web/screens/sign_in_screen_spec.cr
#
# Every test_id REFERENCED by a locator call is also DECLARED with
# a `<receiver>.test_id = "..."` setter in the same file. Rule silent.

require "spec"

describe SignInScreen do
  it "wires the email field" do
    screen = SignInScreen.new
    ctx = stub_screen_context
    root = screen.build(ctx)

    email = UI::TextField.new
    email.test_id = "demo-sign-in-email"

    found = root.find_by_test_id("demo-sign-in-email")
    found.should_not be_nil
  end
end
