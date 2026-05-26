# fixture_for: family_2/spec_describe_matches_class
# expected: fail
# synthetic_path: spec/web/ui/views/phantom_spec.cr
#
# `describe` references a class that does NOT exist anywhere in src/,
# samples/, or spec/*/support/. The rule must fire.

require "spec"

describe ZzzPhantomClassNeverDeclared do
  it "stub" do
    true.should be_true
  end
end
