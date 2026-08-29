# fixture_for: family_5_partial/native_spec_has_platform_flag
# expected: pass
# synthetic_path: spec/native_macos/helper_loaded_spec.cr
#
# Spec uses a recognized native spec_helper require — accepted as
# platform-context evidence even without an inline flag guard.

require "spec"
require "../support/macos_spec_helper"

describe "wired via helper" do
  it "is accepted by the rule" do
    true.should be_true
  end
end
