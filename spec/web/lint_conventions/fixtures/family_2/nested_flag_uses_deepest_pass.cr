# fixture_for: family_2/view_has_spec
# expected: pass
# synthetic_path: src/ui/views/action_sheet.cr
#
# Nested platform flags: an outer `{% if flag?(:macos) %}` wraps an
# inner `{% if flag?(:ios) %}`. The class inside the innermost guard
# must be classified by the DEEPEST flag (:ios), not the outer
# (:macos). The rule then accepts EITHER
# `spec/native_ios/ui/views/action_sheet_spec.cr` OR the default
# `spec/web/ui/views/action_sheet_spec.cr` — the latter exists today
# under the 10C.0 web-spec convention, so the rule passes.

require "../view"

{% if flag?(:macos) %}
  {% if flag?(:ios) %}
    module UI
      class ActionSheet < View
        def initialize
        end
      end
    end
  {% end %}
{% end %}
