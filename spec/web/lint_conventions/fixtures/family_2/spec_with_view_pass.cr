# fixture_for: family_2/spec_has_view
# expected: pass
# synthetic_path: spec/web/ui/views/button_spec.cr
#
# A spec file whose paired source view `src/ui/views/button.cr` exists
# on disk. The rule passes.

require "spec"

describe "Button" do
  it "stub" do
    true.should be_true
  end
end
