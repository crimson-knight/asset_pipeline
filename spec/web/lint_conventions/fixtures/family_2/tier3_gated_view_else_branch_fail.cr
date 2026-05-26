# fixture_for: family_2/view_has_spec
# expected: fail
# synthetic_path: src/ui/views/no_such_widget.cr
# diagnostic_message_contains: spec/web/ui/views/no_such_widget_spec.cr
# diagnostic_message_excludes: spec/native_ios
#
# A view file with a `{% if flag?(:ios) %}` opener whose body does
# NOT declare the view; the class lives in the `{% else %}` branch.
# The gate detector must NOT classify the else-branch class as
# iOS-gated — it lives in the else branch, so the original `:ios`
# flag has been cleared from the active frame.
#
# Discriminating assertion: under the OLD logic that ignored
# `{% else %}` the active flag at the class line would still be
# `:ios`, producing a diagnostic referencing
# `spec/native_ios/...`. Under the corrected logic the flag is
# cleared, the default web path governs, and the diagnostic
# references `spec/web/ui/views/no_such_widget_spec.cr`. The
# fixture pins both: must contain the web path AND must NOT
# contain `spec/native_ios`.

require "../view"

{% if flag?(:ios) %}
  # stub branch on iOS — not the rule's target.
{% else %}
  module UI
    class NoSuchWidget < View
      def initialize
      end
    end
  end
{% end %}
