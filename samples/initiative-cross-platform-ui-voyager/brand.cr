require "../../src/ui/design_tokens"

# Phase 6.10 — Voyager demo brand override.
#
# Voyager is the second demo (after Cascade). Per the brief, its brand
# must be visibly distinct from Cascade's deep teal so the consumer can
# tell at a glance which demo they're running. We pick a deep indigo
# (OKLCH ~ 0.42 / 0.20 / 280) — a clearly different hue family from
# Cascade's teal (h ~ 195).
module Voyager
  BRAND_PRIMARY_LIGHT  = UI::DesignTokens::Color.oklch(0.42, 0.20, 280.0)
  BRAND_PRIMARY_HOVER  = UI::DesignTokens::Color.oklch(0.36, 0.20, 280.0)
  BRAND_PRIMARY_ACTIVE = UI::DesignTokens::Color.oklch(0.30, 0.20, 280.0)

  BRAND_PRIMARY_DARK        = UI::DesignTokens::Color.oklch(0.62, 0.18, 280.0)
  BRAND_PRIMARY_DARK_HOVER  = UI::DesignTokens::Color.oklch(0.68, 0.18, 280.0)
  BRAND_PRIMARY_DARK_ACTIVE = UI::DesignTokens::Color.oklch(0.56, 0.18, 280.0)

  # Brand secondary — a coordinated violet for selected-state contrast.
  BRAND_SECONDARY_LIGHT = UI::DesignTokens::Color.oklch(0.52, 0.18, 305.0)
  BRAND_SECONDARY_DARK  = UI::DesignTokens::Color.oklch(0.70, 0.16, 305.0)

  class VoyagerBrand < UI::DesignTokens::Brand
    protected def override_color_light(palette : UI::DesignTokens::ColorPalette) : UI::DesignTokens::ColorPalette
      palette.copy_with(
        brand_primary: BRAND_PRIMARY_LIGHT,
        brand_primary_hover: BRAND_PRIMARY_HOVER,
        brand_primary_active: BRAND_PRIMARY_ACTIVE,
        brand_secondary: BRAND_SECONDARY_LIGHT,
      )
    end

    protected def override_color_dark(palette : UI::DesignTokens::ColorPalette) : UI::DesignTokens::ColorPalette
      palette.copy_with(
        brand_primary: BRAND_PRIMARY_DARK,
        brand_primary_hover: BRAND_PRIMARY_DARK_HOVER,
        brand_primary_active: BRAND_PRIMARY_DARK_ACTIVE,
        brand_secondary: BRAND_SECONDARY_DARK,
      )
    end
  end

  # Module-level method (NOT a constant) so the iOS embedding's
  # class-init gap can't silently produce stale tokens. See
  # samples/initiative-cross-platform-ui-demo/brand.cr for the
  # canonical workaround.
  def self.brand_tokens : UI::DesignTokens::Tokens
    UI::DesignTokens::Tokens.default.with_brand(VoyagerBrand.new)
  end
end
