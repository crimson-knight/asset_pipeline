# Pure (no AppKit FFI) policy for the background fill baked onto a container
# NSStackView's layer in the macOS renderer. Extracted from
# `AppKitRenderer#visit(UI::VStack)` so the decision can be unit-tested in the
# default (non `-Dmacos`) spec suite — the native renderer file is wrapped in
# `{% if flag?(:macos) %}` and is never compiled in the headless suite.
#
# ## Why a fill is baked at all
# NSStackView's offscreen `cacheDisplayInRect:` path renders a layer that has
# no explicit fill as TRANSPARENT, so subview NSTextField text (drawn via
# `NSColor.labelColor`, ~white in dark mode) is lost on the white capture
# bitmap. To keep standalone *screenshot captures* legible we bake an opaque,
# appearance-correct window-background approximation.
#
# ## Why the LIVE app must NOT get that fill
# In the running app a background-less VStack has to be TRANSPARENT so its
# parent's background shows through — exactly how HStack and ZStack already
# behave (neither bakes a fill). Baking opaque white in the live app turns
# every nested, background-less layout container into a solid white block that
# hides its children. This is the regression Happy Coach's "My Affirmations"
# screen surfaced: its card list lived in a background-less `list_container`
# VStack, which the live renderer painted solid white, swallowing the cards.
#
# The capture path is distinguished by `HIG_APPEARANCE` (always set —
# "light"/"dark" — by the capture harness; absent in the live app) and by
# `HIG_BACKDROP_PATH` (glass-backdrop captures).
module UI
  module StackBake
    # (r, g, b, a) for a container VStack's baked layer fill.
    alias RGBA = Tuple(Float64, Float64, Float64, Float64)

    TRANSPARENT = {0.0, 0.0, 0.0, 0.0}
    # Offscreen-capture window-background approximations (NSColor.windowBackgroundColor).
    CAPTURE_LIGHT = {1.0, 1.0, 1.0, 1.0}
    CAPTURE_DARK  = {0.12, 0.12, 0.12, 1.0}

    # Decide the layer fill for a container VStack that has NO explicit
    # background. An explicit `view.background` always wins and is handled by
    # the renderer directly; this method covers only the fallback branch.
    #
    # * *backdrop_path* — value of `ENV["HIG_BACKDROP_PATH"]?` (glass backdrop capture).
    # * *capture_appearance* — value of `ENV["HIG_APPEARANCE"]?`; present only
    #   in the offscreen capture path, absent in the live app.
    def self.fallback_rgba(backdrop_path : String?, capture_appearance : String?) : RGBA
      # Glass/backdrop capture → transparent so the visual-effect view can blur
      # the backdrop image beneath this container.
      if bp = backdrop_path
        return TRANSPARENT unless bp.empty?
      end

      # Offscreen capture (appearance pinned) → opaque legibility fill.
      if appr = capture_appearance
        unless appr.empty?
          return appr == "dark" ? CAPTURE_DARK : CAPTURE_LIGHT
        end
      end

      # Live app → transparent; the parent's background shows through.
      TRANSPARENT
    end
  end
end
