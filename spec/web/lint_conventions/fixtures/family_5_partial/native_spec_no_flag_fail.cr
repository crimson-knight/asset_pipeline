# fixture_for: family_5_partial/native_spec_has_platform_flag
# expected: fail
# synthetic_path: spec/native_ios/missing_flag_spec.cr
#
# Spec under spec/native_ios/ but no `flag?(:ios)` guard anywhere.
# Rule must fire on line 1.

require "spec"

describe "iOS widget" do
  it "compiles unconditionally — wrong" do
    true.should be_true
  end
end
