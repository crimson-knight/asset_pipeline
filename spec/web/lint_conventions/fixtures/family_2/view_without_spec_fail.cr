# fixture_for: family_2/view_has_spec
# expected: fail
# synthetic_path: src/ui/views/no_such_widget.cr
#
# A view file with NO paired spec at the expected default location
# `spec/web/ui/views/no_such_widget_spec.cr`. The rule must fire
# because the synthetic_path is not on the .lint_conventions.yml
# allowlist and no spec exists for it.

module UI
  class NoSuchWidget < View
    def initialize
    end
  end
end
