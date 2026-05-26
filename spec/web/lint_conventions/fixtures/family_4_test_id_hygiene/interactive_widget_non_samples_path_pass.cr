# fixture_for: family_4/interactive_widget_test_id
# expected: pass
# synthetic_path: src/ui/views/internal_helper.cr
#
# Non-samples files are entirely out of scope. A Button assignment
# without a test_id setter under `src/` must NOT trigger the rule —
# the view-source tree never instantiates widgets at runtime.

class WidgetHelper
  def build_button
    save = UI::Button.new("Save")
    save.accessibility_label = "Save"
    save
  end
end
