# fixture_for: family_5_partial/spec_platform_directory
# expected: fail
# synthetic_path: spec/orphan_spec.cr
#
# Spec lives at spec/ root, not under any platform tree. The
# directory rule must fire.

require "spec"

describe "orphan" do
  it "is in the wrong place" do
    true.should be_true
  end
end
