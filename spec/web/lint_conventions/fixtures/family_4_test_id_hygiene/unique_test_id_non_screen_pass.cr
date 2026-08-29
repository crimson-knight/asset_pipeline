# fixture_for: family_4/unique_test_id_per_screen
# expected: pass
# synthetic_path: spec/web/some_unit_spec.cr
#
# Non-Screen classes are out of scope for this rule. A test helper
# that legitimately reuses test_id strings across distinct fixtures
# (e.g. one per `it` block) must not be flagged.

require "spec"

class TestFixture
  def setup
    a = UI::Button.new
    a.test_id = "shared-fixture-id"

    b = UI::Button.new
    b.test_id = "shared-fixture-id"
  end
end
