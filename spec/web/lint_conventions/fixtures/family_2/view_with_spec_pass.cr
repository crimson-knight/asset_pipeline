# fixture_for: family_2/view_has_spec
# expected: pass
# synthetic_path: src/ui/views/action_sheet_with_web_fallback.cr
#
# A view file whose paired spec ALREADY exists on disk at
# `spec/web/ui/views/action_sheet_with_web_fallback_spec.cr`. The rule
# checks File.exists? against the live tree, so this fixture passes
# whenever the paired spec is in place.

module UI
  class ActionSheetWithWebFallback < View
    def initialize
    end
  end
end
