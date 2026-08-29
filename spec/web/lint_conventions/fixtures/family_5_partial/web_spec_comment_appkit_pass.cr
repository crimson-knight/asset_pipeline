# fixture_for: family_5_partial/cross_target_spec_purity
# expected: pass
# synthetic_path: spec/web/comment_mentions_appkit_spec.cr
#
# The token UI::AppKit::Renderer appears only inside a comment. The
# rule skips comment lines, so this is silent.

require "spec"

describe "Web spec discussing AppKit only in comments" do
  # NOTE: this is the cross-platform analog of UI::AppKit::Renderer.
  # The web build emits HTML; the AppKit build emits NSViews.
  it "doesn't touch AppKit at runtime" do
    true.should be_true
  end
end
