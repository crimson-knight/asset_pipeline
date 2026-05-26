# fixture_for: family_5_partial/cross_target_spec_purity
# expected: pass
# synthetic_path: spec/web/some_recording_spec.cr
#
# `FakeLibObjCBridge` is a Crystal-side test double that mimics the
# bridge surface without linking. The rule uses identifier word
# boundaries so the bare `LibObjCBridge` token does NOT match inside
# `FakeLibObjCBridge`. Rule silent.

require "spec"

class FakeLibObjCBridge
  def self.record(*args)
  end
end

describe "recording suite" do
  it "exercises the fake" do
    FakeLibObjCBridge.record(:foo, [], "")
  end
end
