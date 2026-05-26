# fixture_for: family_4/unique_test_id_per_screen
# expected: fail
# synthetic_path: src/screens/duplicate_ids_screen.cr
#
# Two distinct views share the same test_id literal "row-cta" inside
# the same Screen's build body. The rule must fire on the SECOND
# occurrence.

class DuplicateIdsScreen < UI::Screen
  def build(ctx)
    primary = UI::Button.new("Primary")
    primary.test_id = "row-cta"

    secondary = UI::Button.new("Secondary")
    secondary.test_id = "row-cta"  # duplicate

    UI::VStack.new([primary.as(UI::View), secondary.as(UI::View)])
  end
end
