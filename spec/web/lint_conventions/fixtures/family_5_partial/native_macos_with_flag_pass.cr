# fixture_for: family_5_partial/native_spec_has_platform_flag
# expected: pass
# synthetic_path: spec/native_macos/example_spec.cr
#
# Native macOS spec correctly guards its body with
# `{% if flag?(:macos) %}`. Rule silent.

require "spec"

{% if flag?(:macos) %}
  describe "MacOS widget" do
    it "compiles only on macOS" do
      true.should be_true
    end
  end
{% end %}
