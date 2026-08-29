# fixture_for: family_5_partial/native_spec_has_platform_flag
# expected: pass
# synthetic_path: spec/native_macos/menu_bar_spec.cr
#
# The widget under test (UI::MenuBar) is Apple-family, so the spec
# guards with `{% if flag?(:macos) || flag?(:ios) %}`. The OR form
# includes macos, so the rule accepts it.

require "spec"

{% if flag?(:macos) || flag?(:ios) %}
  describe UI::MenuBar do
    it "is Apple-family" do
      true.should be_true
    end
  end
{% end %}
