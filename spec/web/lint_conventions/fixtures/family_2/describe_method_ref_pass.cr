# fixture_for: family_2/spec_describe_matches_class
# expected: pass
# synthetic_path: spec/web/method_ref_describe_spec.cr
#
# `describe Foo.bar` and `describe Foo#bar` are method-reference forms.
# The rule's regex requires the next non-identifier char after the
# captured class name to be `,`, ` do`, or end-of-line — `.` and `#`
# disqualify, so no diagnostic.

require "spec"

describe UI::Button.new do
  it "stub" do
    true.should be_true
  end
end
