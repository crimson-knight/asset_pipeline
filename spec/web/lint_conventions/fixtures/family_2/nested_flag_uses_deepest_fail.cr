# fixture_for: family_2/view_has_spec
# expected: fail
# synthetic_path: src/ui/views/no_such_nested_widget.cr
# diagnostic_message_contains: spec/native_ios/ui/views/no_such_nested_widget_spec.cr
# diagnostic_message_excludes: spec/native_macos
#
# Nested platform flags: an outer `{% if flag?(:macos) %}` wraps an
# inner `{% if flag?(:ios) %}`. The class inside the innermost guard
# must be classified by the DEEPEST flag (:ios), not the outer
# (:macos).
#
# Discriminating assertion: under the OLD outermost-flag-wins logic
# this diagnostic would have referenced `spec/native_macos/...`; under
# the corrected deepest-flag-wins logic it references
# `spec/native_ios/...`. The fixture pins both — must contain the
# ios path AND must NOT contain the macos prefix.
#
# Naming: `_fail` because the rule SHOULD fire (no spec exists at
# the synthetic_path under any platform dir), and the diagnostic
# content's expected path is what discriminates the corrected logic
# from the old logic.

require "../view"

{% if flag?(:macos) %}
  {% if flag?(:ios) %}
    module UI
      class NoSuchNestedWidget < View
        def initialize
        end
      end
    end
  {% end %}
{% end %}
