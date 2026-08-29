# fixture_for: family_2/view_has_spec
# expected: pass
# synthetic_path: src/ui/views/action_sheet.cr
#
# A Tier-3 view gated by `{% if flag?(:ios) %}` whose class declaration
# lies inside the macro guard. The rule's gate detector records the
# active flag `:ios` and accepts the spec at EITHER
# `spec/native_ios/ui/views/action_sheet_spec.cr` (preferred) OR the
# default `spec/web/ui/views/action_sheet_spec.cr` (which exists on
# disk under the 10C.0 web-spec convention with an internal
# `{% if flag?(:ios) %}` body guard).

require "../view"

{% if flag?(:ios) %}
  module UI
    class ActionSheet < View
      def initialize
      end
    end
  end
{% else %}
  require "./_gate_stubs/action_sheet"
{% end %}
