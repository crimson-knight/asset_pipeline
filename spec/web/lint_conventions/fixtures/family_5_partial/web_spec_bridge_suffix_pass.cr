# fixture_for: family_5_partial/cross_target_spec_purity
# expected: pass
# synthetic_path: spec/web/recorder_suffix_spec.cr
#
# Right-boundary regression: a renamed test double that shares the
# `LibObjCBridge` prefix — e.g. `LibObjCBridgeFake`, `LibObjCBridgeSpy`,
# `LibObjCBridgeRecorder` — must NOT trip the rule. Identifier word
# boundaries are checked on BOTH sides; suffix-only matches are
# rejected. Symmetrically, `LibAndroidBridgeFake` is also safe.

require "spec"

class LibObjCBridgeFake
  def self.record(*args)
  end
end

class LibObjCBridgeSpy
  def self.observe(*args)
  end
end

class LibAndroidBridgeFake
  def self.record(*args)
  end
end

describe "suffix-pattern bridge doubles" do
  it "exercises the suffix-pattern doubles" do
    LibObjCBridgeFake.record(:foo)
    LibObjCBridgeSpy.observe(:bar)
    LibAndroidBridgeFake.record(:baz)
  end
end
