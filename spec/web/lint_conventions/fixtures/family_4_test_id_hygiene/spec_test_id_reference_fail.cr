# fixture_for: family_4/spec_test_id_reference
# expected: fail
# synthetic_path: spec/web/screens/stale_locator_spec.cr
#
# The spec calls `find_by_test_id("demo-sign-in-email")` but only
# `demo-sign-in-emial` (typo) is set in the test setup. The rule
# must flag the reference line.

require "spec"

describe SignInScreen do
  it "looks up the email field" do
    email = UI::TextField.new
    email.test_id = "demo-sign-in-emial"  # typo'd setter

    found = root.find_by_test_id("demo-sign-in-email")
    found.should_not be_nil
  end
end
