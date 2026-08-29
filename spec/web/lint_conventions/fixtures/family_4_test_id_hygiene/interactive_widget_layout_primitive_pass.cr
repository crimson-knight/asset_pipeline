# fixture_for: family_4/interactive_widget_test_id
# expected: pass
# synthetic_path: samples/demo/screens/layout_only.cr
#
# Layout primitives (VStack, HStack, Card, Label) are NOT in the
# interactive catalog. Assigning a VStack without test_id must NOT
# trigger the rule.

class LayoutOnlyScreen < UI::Screen
  def build(ctx)
    row = UI::HStack.new
    container = UI::VStack.new
    label = UI::Label.new("Hello")
    container << label.as(UI::View)
    container << row.as(UI::View)
    container
  end
end
