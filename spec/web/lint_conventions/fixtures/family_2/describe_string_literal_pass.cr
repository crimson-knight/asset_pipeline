# fixture_for: family_2/spec_describe_matches_class
# expected: pass
# synthetic_path: spec/web/some_string_describe_spec.cr
#
# `describe "literal string" do` carries no class binding. The rule's
# regex never matches the identifier branch, so no diagnostic is
# emitted even if no class is referenced.

require "spec"

describe "Free-form description with no class reference" do
  it "stub" do
    true.should be_true
  end
end
