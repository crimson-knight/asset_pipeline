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
# ## Capture vs live: the signal
# Capture mode is NOT "HIG_APPEARANCE is set" — that is an APPEARANCE knob
# (light/dark), and hosts set it for live windows too (e.g. Voyager's macOS
# host syncs VOYAGER_APPEARANCE -> HIG_APPEARANCE before BOTH capture and
# interactive rendering). Using it as a capture flag both (a) failed to fix
# live apps that set it and (b) regressed captures that DON'T set it (they
# default appearance to light). The reliable signal is a screenshot-OUTPUT
# path env var: every capture harness writes its PNG to one of those, and a
# live app sets none. The AppKit renderer already keys other capture-only
# decisions off HIG_SCREENSHOT_PATH (see `visit(UI::PathControl)`).
module UI
  module StackBake
    # (r, g, b, a) for a container VStack's baked layer fill.
    alias RGBA = Tuple(Float64, Float64, Float64, Float64)

    TRANSPARENT = {0.0, 0.0, 0.0, 0.0}
    # Offscreen-capture window-background approximations (NSColor.windowBackgroundColor).
    CAPTURE_LIGHT = {1.0, 1.0, 1.0, 1.0}
    CAPTURE_DARK  = {0.12, 0.12, 0.12, 1.0}

    # Env vars whose presence (nonempty) marks an offscreen screenshot-capture
    # render. Each capture harness writes the output PNG to a path from one of
    # these (HIG/Cascade -> HIG_SCREENSHOT_PATH; Voyager -> VOYAGER_SCREENSHOT_PATH
    # or HIG_SCREENSHOT_PATH); a live app sets none.
    CAPTURE_PATH_ENV_KEYS = ["HIG_SCREENSHOT_PATH", "VOYAGER_SCREENSHOT_PATH"]

    # True when any capture-path signal is set and nonempty. Pass the RESOLVED
    # env values — renderer: `CAPTURE_PATH_ENV_KEYS.map { |k| ENV[k]? }` — so
    # this stays pure and headlessly testable.
    def self.capturing?(screenshot_path_values : Enumerable(String?)) : Bool
      screenshot_path_values.any? { |v| !(v.nil? || v.empty?) }
    end

    # Decide the layer fill for a container VStack that has NO explicit
    # background. An explicit `view.background` always wins and is handled by
    # the renderer directly; this method covers only the fallback branch.
    #
    # * *backdrop_path* — value of `ENV["HIG_BACKDROP_PATH"]?` (glass backdrop capture).
    # * *capture_appearance* — value of `ENV["HIG_APPEARANCE"]?` ("light"/"dark").
    #   Selects the FILL color in capture mode; it is NOT a capture-mode signal.
    # * *capturing* — true iff rendering for an offscreen screenshot capture
    #   (see `capturing?`). The opaque legibility fill applies ONLY then.
    def self.fallback_rgba(backdrop_path : String?, capture_appearance : String?, capturing : Bool) : RGBA
      # Glass/backdrop capture → transparent so the visual-effect view can blur
      # the backdrop image beneath this container.
      if bp = backdrop_path
        return TRANSPARENT unless bp.empty?
      end

      # Offscreen capture → opaque legibility fill (appearance default: light).
      if capturing
        return capture_appearance == "dark" ? CAPTURE_DARK : CAPTURE_LIGHT
      end

      # Live app → transparent; the parent's background shows through.
      TRANSPARENT
    end
  end
end
