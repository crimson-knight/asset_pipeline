require "../../spec_helper"
require "../../../src/ui/design_tokens"

# Phase 5 probe placeholder — slug `macos.glass.material.contrast.wcag_aa`.
#
# Mirror of `ios_glass_contrast_spec.cr` for the AppKit renderer.
# AX identifier convention: `ap.glass.contrast.<step>.intensity_<intensity_x100>`.
describe "Phase 5 probe: macos.glass.material.contrast.wcag_aa" do
  intensities = [0.5, 1.0, 1.3, 1.5]
  steps = [:ultra_thin, :thin, :regular, :thick, :chrome]

  intensities.each do |intensity|
    steps.each do |step|
      pending "text_primary on `#{step}` at intensity=#{intensity} meets WCAG-AA 4.5:1 contrast on macOS" do
        # Expected shape (Phase 6.5 will implement) — see iOS counterpart.
      end
    end
  end
end
