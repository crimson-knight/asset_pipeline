# fixture_for: family_4/interactive_widget_test_id
# expected: fail
# synthetic_path: samples/demo/screens/missing_test_id.cr
#
# A Button is assigned to `save` but no `save.test_id =` appears within
# the lookahead window. Rule must fire on line 9.

class MissingTestIdScreen < UI::Screen
  def build(ctx)
    save = UI::Button.new("Save")
    save.accessibility_label = "Save document"
    save.on_tap = ->{ }

    UI::VStack.new([save.as(UI::View)])
  end
end
