# fixture_for: family_2/spec_has_view
# expected: fail
# synthetic_path: spec/web/ui/views/totally_orphaned_widget_spec.cr
#
# A spec under `spec/web/ui/views/` with no paired source view file
# (`src/ui/views/totally_orphaned_widget.cr` does not exist and no
# known role-suffix strip lands on a real file). The rule must fire.

require "spec"

describe "TotallyOrphanedWidget" do
  it "stub" do
    true.should be_true
  end
end
