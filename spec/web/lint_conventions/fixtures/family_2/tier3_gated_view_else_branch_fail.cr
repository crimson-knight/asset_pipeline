# fixture_for: family_2/view_has_spec
# expected: fail
# synthetic_path: src/ui/views/no_such_widget.cr
#
# A view file with a `{% if flag?(:ios) %}` opener that declares a
# *stub-style* class on the iOS branch, then declares the *real*
# cross-platform class in the `{% else %}` branch. The gate detector
# must NOT classify the else-branch class as iOS-gated — it lives in
# the else branch, so the original `:ios` flag has been cleared from
# the active frame.
#
# The fixture targets a synthetic_path with no paired spec at the
# default `spec/web/ui/views/no_such_widget_spec.cr` and no
# `spec/native_ios/ui/views/no_such_widget_spec.cr`. Because the
# class lives in the else branch, the default web path is the
# governing expectation; rule must fire because that path is absent.

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
