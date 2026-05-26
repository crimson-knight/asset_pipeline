# fixture_for: family_5_partial/cross_target_spec_purity
# expected: fail
# synthetic_path: spec/web/wrong_renderer_android_spec.cr
#
# Web spec references LibAndroidBridge. The JNI bridge cannot link
# in a web build; the spec must move under spec/native_android/.

require "spec"

describe "JNI bridge on web — wrong" do
  it "shouldn't be here" do
    LibAndroidBridge.something
  end
end
