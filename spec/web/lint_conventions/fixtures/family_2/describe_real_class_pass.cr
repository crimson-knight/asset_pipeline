# fixture_for: family_2/spec_describe_matches_class
# expected: pass
# synthetic_path: spec/web/ui/views/button_spec.cr
#
# `describe` references a real class declared in src/. The rule's
# class registry includes `Button` (from src/ui/views/button.cr) and
# the deepest-segment lookup of `UI::Button` resolves to `Button`.
# Pass.

require "spec"

describe UI::Button do
  it "stub" do
    true.should be_true
  end
end
