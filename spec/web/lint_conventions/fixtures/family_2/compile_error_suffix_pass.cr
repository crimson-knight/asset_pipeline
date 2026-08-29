# fixture_for: family_2/spec_has_view
# expected: pass
# synthetic_path: spec/web/ui/views/action_sheet_compile_error_spec.cr
#
# A spec named with the `_compile_error` role suffix maps back to
# `src/ui/views/action_sheet.cr` via the role-suffix strip rule. The
# rule must pass because action_sheet.cr exists in the source tree.

require "spec"

describe "ActionSheet compile-time gate" do
  it "stub" do
    true.should be_true
  end
end
