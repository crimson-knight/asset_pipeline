# fixture_for: family_5_partial/spec_platform_directory
# expected: pass
# synthetic_path: spec/web/example_spec.cr
#
# Spec lives under spec/web/. The existing directory rule passes.

require "spec"

describe "anything" do
  it "is in the right tree" do
    true.should be_true
  end
end
