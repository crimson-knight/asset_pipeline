# fixture_for: family_5_partial/cross_target_spec_purity
# expected: pass
# synthetic_path: spec/native_macos/legitimate_appkit_spec.cr
#
# A macOS native spec references UI::AppKit::Renderer — this is
# legitimate. The cross-target rule allows AppKit refs inside
# spec/native_macos/.

require "spec"

{% if flag?(:macos) %}
  describe UI::AppKit::Renderer do
    it "exists" do
      true.should be_true
    end
  end
{% end %}
