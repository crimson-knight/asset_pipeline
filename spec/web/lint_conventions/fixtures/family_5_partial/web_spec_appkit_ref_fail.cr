# fixture_for: family_5_partial/cross_target_spec_purity
# expected: fail
# synthetic_path: spec/web/wrong_renderer_spec.cr
#
# Web spec instantiates UI::AppKit::Renderer — a macOS-only type.
# The spec belongs in spec/native_macos/, not spec/web/.

require "spec"

describe "AppKit on web — wrong" do
  it "shouldn't be here" do
    renderer = UI::AppKit::Renderer.new
    renderer.should_not be_nil
  end
end
