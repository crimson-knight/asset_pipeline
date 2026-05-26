# fixture_for: family_4/spec_test_id_reference
# expected: pass
# synthetic_path: spec/web/screens/named_arg_spec.cr
#
# Named-arg `test_id: "foo"` references are matched as long as the
# string is declared anywhere via `.test_id = "foo"` in the same file.

require "spec"

describe SomeScreen do
  it "matches the named-arg form" do
    button = UI::Button.new("Save")
    button.test_id = "save-button"

    # Some helper accepting test_id kwarg
    locator = make_locator(test_id: "save-button")
    locator.should_not be_nil
  end
end
