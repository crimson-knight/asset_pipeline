# fixture_for: family_4/unique_test_id_per_screen
# expected: pass
# synthetic_path: src/screens/dynamic_ids_screen.cr
#
# test_ids computed at runtime (interpolated / variable expressions)
# are uncheckable at lint time. The literal-only collector skips them,
# so this passes despite the apparent shape collision.

class DynamicIdsScreen < UI::Screen
  def build(ctx)
    stack = UI::VStack.new
    [1, 2, 3].each do |i|
      btn = UI::Button.new("Item #{i}")
      btn.test_id = "row-#{i}"
      stack << btn.as(UI::View)
    end
    stack
  end
end
