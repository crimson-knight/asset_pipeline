# fixture_for: family_4/spec_test_id_reference
# expected: pass
# synthetic_path: samples/demo/screens/layout_only.cr
#
# Non-spec paths are entirely out of scope. A reference-only line in
# a sample (no setter visible) must NOT trigger this rule — the
# reference rule only governs `_spec.cr` files. The interactive
# widget rule covers samples separately.

class LayoutOnlyScreen < UI::Screen
  def build(ctx)
    root = UI::VStack.new
    # Hypothetical helper that returns a view by id. Not a spec.
    looked_up = root.find_by_test_id("demo-not-declared-anywhere")
    root << looked_up.as(UI::View)
    root
  end
end
