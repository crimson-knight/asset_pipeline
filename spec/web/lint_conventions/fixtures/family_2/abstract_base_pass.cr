# fixture_for: family_2/view_has_spec
# expected: pass
# synthetic_path: src/ui/view.cr
#
# The abstract `UI::View` base class file is explicitly skipped. Even
# though no `spec/web/ui/views/view_spec.cr` exists, the rule must NOT
# fire — the abstract base has no view-spec pair obligation.

module UI
  abstract class View
    def accept(visitor)
    end
  end
end
