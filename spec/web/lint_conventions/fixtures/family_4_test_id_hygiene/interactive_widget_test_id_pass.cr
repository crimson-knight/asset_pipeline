# fixture_for: family_4/interactive_widget_test_id
# expected: pass
# synthetic_path: samples/demo/screens/sign_in.cr
#
# Every interactive widget assignment has a paired test_id setter
# within the lookahead window. The rule should be silent.

class SignInScreen < UI::Screen
  def build(ctx)
    email_field = UI::TextField.new(placeholder: "Email")
    email_field.accessibility_label = "Email address"
    email_field.test_id = "demo-sign-in-email"

    primary = UI::Button.new("Sign in")
    primary.accessibility_label = "Sign in"
    primary.test_id = "demo-sign-in-submit"

    UI::VStack.new([email_field.as(UI::View), primary.as(UI::View)])
  end
end
