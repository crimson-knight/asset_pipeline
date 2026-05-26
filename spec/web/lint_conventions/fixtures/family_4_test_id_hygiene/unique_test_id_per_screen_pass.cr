# fixture_for: family_4/unique_test_id_per_screen
# expected: pass
# synthetic_path: src/screens/unique_ids_screen.cr
#
# All test_id literals inside `build` are distinct. The rule is silent.

class UniqueIdsScreen < UI::Screen
  def build(ctx)
    email = UI::TextField.new
    email.test_id = "sign-in-email"

    password = UI::SecureField.new
    password.test_id = "sign-in-password"

    submit = UI::Button.new("Sign in")
    submit.test_id = "sign-in-submit"

    UI::VStack.new([email.as(UI::View), password.as(UI::View), submit.as(UI::View)])
  end
end
