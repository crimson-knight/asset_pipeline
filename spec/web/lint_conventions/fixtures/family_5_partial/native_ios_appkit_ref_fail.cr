# fixture_for: family_5_partial/cross_target_spec_purity
# expected: fail
# synthetic_path: spec/native_ios/wrong_renderer_spec.cr
#
# An iOS native spec references UI::AppKit::Renderer — the AppKit
# renderer is macOS-only. The spec should move to spec/native_macos/
# (or split into two).

require "spec"

{% if flag?(:ios) %}
  describe "AppKit reference on iOS — wrong" do
    it "should not be here" do
      renderer = UI::AppKit::Renderer.new
    end
  end
{% end %}
