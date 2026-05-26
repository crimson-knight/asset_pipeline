# fixture_for: family_5_partial/native_spec_has_platform_flag
# expected: pass
# synthetic_path: spec/web/example_spec.cr
#
# A spec under spec/web/ doesn't need a platform flag — web is the
# default target. The rule must NOT fire on non-native paths.

require "spec"

describe "Web widget" do
  it "runs on web by default" do
    true.should be_true
  end
end
