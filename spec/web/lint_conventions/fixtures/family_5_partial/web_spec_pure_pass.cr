# fixture_for: family_5_partial/cross_target_spec_purity
# expected: pass
# synthetic_path: spec/web/clean_renderer_spec.cr
#
# Web spec only references the web renderer. Rule silent.

require "spec"

describe UI::Web::Renderer do
  it "renders" do
    renderer = UI::Web::Renderer.new
    renderer.should_not be_nil
  end
end
