# Phase 10B.2c — UI::Environment: system-level user preferences surface.
#
# `UI::Environment` is a per-render, immutable value object exposing the
# system accessibility preferences a view tree needs to honor at render
# time:
#
#   * `reduce_motion`         — kill / shorten animations, parallax, transitions.
#   * `increase_contrast`     — boost separator + outline contrast, dim glass.
#   * `dynamic_type_size`     — symbolic Apple-style text-size scale.
#   * `color_scheme`          — `:light`, `:dark`, `:high_contrast`.
#   * `accessibility_enabled` — true when an assistive tech (VoiceOver,
#                               TalkBack, etc.) is active.
#
# Environment is plumbed through `UI::ScreenContext.environment` and read
# by widgets that need to react. The canonical reactivity proof is
# `UI::Animation.duration_with_environment(env, base_ms)` — returns `0`
# when `env.reduce_motion`, otherwise `base_ms`. Widgets such as
# `UI::Snackbar` (auto-dismiss animation) call this helper so the same
# view tree renders differently across two `ScreenContext`s that differ
# only in their environment.
#
# # Per-platform source map (see close-handoff for the full table)
#
#   * Web (server-side): `UI::Environment.from_request_hints(hints)`
#     consumes a `Hash(String, String)` of HTTP header values (e.g.
#     `Sec-CH-Prefers-Reduced-Motion`, `Sec-CH-Prefers-Contrast`,
#     `Sec-CH-Prefers-Color-Scheme`). Consumer apps populate the hash
#     from `request.headers` (or test fixtures from a stubbed map).
#   * UIKit: `UI::Environment.from_uikit` is sketched as a stub that
#     queries `UIAccessibility.isReduceMotionEnabled`,
#     `UITraitCollection.accessibilityContrast`, `UIContentSizeCategory`,
#     `UITraitCollection.userInterfaceStyle`, and
#     `UIAccessibility.isVoiceOverRunning`. Per-platform implementation
#     is wired by the host app at App boot or per-render.
#   * AppKit: `UI::Environment.from_appkit` reads
#     `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`,
#     `NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast`,
#     and `NSApp.effectiveAppearance`.
#   * Android: `UI::Environment.from_android` reads
#     `Settings.Global.ANIMATOR_DURATION_SCALE == 0`,
#     `AccessibilityManager.isHighTextContrastEnabled`, and font scale.
#
# All platform helpers ship as stubs returning a conservative default;
# the OS-query bridges land alongside the per-platform renderer work.
# The web request-hints reader is fully implemented because the web
# target has a deterministic in-process source (HTTP headers).

# Phase 10B.2c iter 2 — Environment must load BEFORE `view.cr` because
# `UI::RenderContext` (defined in view.cr) carries a `UI::Environment`
# field. The forward dependency lives in `src/ui.cr`'s ordered
# require list, not in this file.

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # System-level user-preference snapshot read by views at render time.
  #
  # Environment values follow accessibility-conservative defaults: when
  # nothing is known about the user's preferences, behave as if NO
  # accommodations are requested (`reduce_motion: false`,
  # `increase_contrast: false`, `dynamic_type_size: :medium`,
  # `color_scheme: :light`, `accessibility_enabled: false`). Consumer
  # apps that detect a preference MUST override this default by
  # populating the field explicitly.
  #
  # Environment is immutable — to "change" the environment between
  # renders the host constructs a new `Environment` and a new
  # `ScreenContext`. This keeps reactivity explicit: rerunning
  # `screen.build(ctx)` with a different `ctx.environment` produces a
  # different view tree.
  class Environment
    # True when the user has requested reduced motion (vestibular /
    # photosensitive accommodations). Views with animation MUST shorten
    # or skip the animation entirely.
    getter reduce_motion : Bool

    # True when the user has requested increased contrast. Views should
    # boost separator / outline / placeholder contrast and dim glass
    # / translucent materials.
    getter increase_contrast : Bool

    # Symbolic dynamic-type size. One of:
    # `:xsmall`, `:small`, `:medium`, `:large`, `:xlarge`, `:xxlarge`,
    # `:xxxlarge`, `:ax1`, `:ax2`, `:ax3`, `:ax4`, `:ax5`.
    # `:medium` is the platform-default; `:ax*` are the
    # accessibility-extra sizes that activate larger touch targets
    # and stacked layouts.
    getter dynamic_type_size : Symbol

    # Color scheme. `:light`, `:dark`, or `:high_contrast`.
    # `:high_contrast` is the explicit "increased contrast variant"
    # the OS publishes separately from `:dark`.
    getter color_scheme : Symbol

    # True when an assistive technology (VoiceOver / TalkBack / Switch
    # Control / Narrator) is currently active. Views may surface extra
    # affordances (e.g. always-visible focus rings) when this is true.
    getter accessibility_enabled : Bool

    # Accessibility-conservative default. No preferences set: no
    # accommodations, light color scheme, default text size.
    def self.default : Environment
      new
    end

    # "Maximum accessibility" preset — useful for testing the
    # accessibility-active render path without hand-constructing each
    # flag. Reduce motion ON, increase contrast ON, AX text size,
    # accessibility-tech active.
    def self.accessibility_active : Environment
      new(
        reduce_motion: true,
        increase_contrast: true,
        dynamic_type_size: :ax3,
        color_scheme: :high_contrast,
        accessibility_enabled: true,
      )
    end

    def initialize(
      @reduce_motion : Bool = false,
      @increase_contrast : Bool = false,
      @dynamic_type_size : Symbol = :medium,
      @color_scheme : Symbol = :light,
      @accessibility_enabled : Bool = false,
    )
    end

    # Returns a new `Environment` with the given fields replaced; the
    # rest are inherited from self. Useful for tests + for hosts that
    # only know a subset of the flags.
    def copy_with(
      reduce_motion : Bool = @reduce_motion,
      increase_contrast : Bool = @increase_contrast,
      dynamic_type_size : Symbol = @dynamic_type_size,
      color_scheme : Symbol = @color_scheme,
      accessibility_enabled : Bool = @accessibility_enabled,
    ) : Environment
      Environment.new(
        reduce_motion: reduce_motion,
        increase_contrast: increase_contrast,
        dynamic_type_size: dynamic_type_size,
        color_scheme: color_scheme,
        accessibility_enabled: accessibility_enabled,
      )
    end

    # ------------------------------------------------------------------
    # Per-platform sources
    # ------------------------------------------------------------------

    # Web target: build an `Environment` from a hash of HTTP client
    # hints. Recognized keys (case-insensitive — caller normalizes):
    #
    #   * `Sec-CH-Prefers-Reduced-Motion`  → "reduce" / "no-preference"
    #   * `Sec-CH-Prefers-Contrast`        → "more" / "less" / "no-preference"
    #   * `Sec-CH-Prefers-Color-Scheme`    → "dark" / "light"
    #   * `Sec-CH-Prefers-Reduced-Transparency` → "reduce" / "no-preference"
    #     (currently rolled into `increase_contrast` as a stronger signal)
    #
    # Sec-CH-Prefers-* hints are encoded as RFC 8941 Structured Field
    # Values — the wire form is a quoted sFV string, e.g.
    # `Sec-CH-Prefers-Color-Scheme: "dark"`. This reader strips the
    # outer double quotes (and surrounding whitespace) before matching
    # so that both the wire form (`"dark"`) and the bare token (`dark`)
    # parse identically. Caller-side normalization (lowercase key) is
    # still honored.
    #
    # Note on standards status: at the time of writing, the Client
    # Hints `Sec-CH-Prefers-*` family is a WICG draft (not yet a W3C
    # Recommendation). The asset_pipeline implementation tracks the
    # current draft — consumers depending on this surface should pin
    # their server-side detection accordingly. See the close handoff
    # for the spec link + tracking notes.
    #
    # Unknown / missing keys → conservative default (no accommodation).
    # The `Hash` lookup is case-insensitive on the key (the caller is
    # expected to normalize header names to the canonical casing or to
    # populate both forms). This implementation does both.
    def self.from_request_hints(hints : Hash(String, String)) : Environment
      lookup = ->(name : String) {
        raw = hints[name]? || hints[name.downcase]? || hints[name.upcase]?
        # RFC 8941 structured-field value: strip outer whitespace and
        # outer double quotes. Real Client Hints headers ship as
        # `Sec-CH-Prefers-Color-Scheme: "dark"`; a permissive parse
        # also accepts the bare token form (`dark`) used in tests and
        # synthetic fixtures.
        raw.try(&.strip.strip('"'))
      }

      rm_raw = lookup.call("Sec-CH-Prefers-Reduced-Motion")
      reduce_motion = rm_raw == "reduce"

      ct_raw = lookup.call("Sec-CH-Prefers-Contrast")
      tx_raw = lookup.call("Sec-CH-Prefers-Reduced-Transparency")
      increase_contrast = ct_raw == "more" || tx_raw == "reduce"

      cs_raw = lookup.call("Sec-CH-Prefers-Color-Scheme")
      color_scheme = case cs_raw
                     when "dark"
                       :dark
                     else
                       increase_contrast ? :high_contrast : :light
                     end

      # The web platform does not (yet) ship a header for AT activation;
      # consumer apps that need it override post-construction via
      # `copy_with(accessibility_enabled: ...)`.
      new(
        reduce_motion: reduce_motion,
        increase_contrast: increase_contrast,
        color_scheme: color_scheme,
        # Dynamic type maps to root-font CSS variable, defaulting to
        # :medium when no hint is present.
        dynamic_type_size: :medium,
        accessibility_enabled: false,
      )
    end

    # UIKit / iOS source. Stub — the OS query lives in the host app's
    # boot path because Crystal's iOS embedding does not expose the
    # UIKit shared instances directly from the framework layer. The
    # host pulls the values via `UIAccessibility.isReduceMotionEnabled`
    # etc. and passes them in.
    #
    # Default-returns the conservative environment so unconfigured iOS
    # builds behave as if the user has no preferences set — same as
    # an unconfigured web request.
    def self.from_uikit(
      reduce_motion : Bool = false,
      increase_contrast : Bool = false,
      dynamic_type_size : Symbol = :medium,
      color_scheme : Symbol = :light,
      voice_over_running : Bool = false,
    ) : Environment
      new(
        reduce_motion: reduce_motion,
        increase_contrast: increase_contrast,
        dynamic_type_size: dynamic_type_size,
        color_scheme: color_scheme,
        accessibility_enabled: voice_over_running,
      )
    end

    # AppKit / macOS source. Stub — same shape as `from_uikit`. The
    # host queries `NSWorkspace.shared.accessibilityDisplayShould*` and
    # `NSApp.effectiveAppearance` at boot (or per-render) and passes
    # the values in.
    def self.from_appkit(
      reduce_motion : Bool = false,
      increase_contrast : Bool = false,
      color_scheme : Symbol = :light,
      voice_over_running : Bool = false,
    ) : Environment
      new(
        reduce_motion: reduce_motion,
        increase_contrast: increase_contrast,
        dynamic_type_size: :medium,
        color_scheme: color_scheme,
        accessibility_enabled: voice_over_running,
      )
    end

    # Android source. Stub — same shape; host queries `Settings.Global.
    # ANIMATOR_DURATION_SCALE == 0`, `AccessibilityManager.isHighText
    # ContrastEnabled`, configuration font scale, and `AccessibilityMan
    # ager.isTouchExplorationEnabled` (TalkBack proxy) and passes in.
    def self.from_android(
      reduce_motion : Bool = false,
      increase_contrast : Bool = false,
      dynamic_type_size : Symbol = :medium,
      color_scheme : Symbol = :light,
      talk_back_active : Bool = false,
    ) : Environment
      new(
        reduce_motion: reduce_motion,
        increase_contrast: increase_contrast,
        dynamic_type_size: dynamic_type_size,
        color_scheme: color_scheme,
        accessibility_enabled: talk_back_active,
      )
    end
    # ------------------------------------------------------------------
    # Phase 10B.3.0 — Process-level platform identity (for Class C
    # intent dispatch).
    # ------------------------------------------------------------------
    #
    # The runtime platform is sourced from Crystal's compile-time
    # `flag?(:macos | :ios | :ipados | :android)` markers. The Web build
    # (no flag) falls through to `:web_wide`. Consumer apps that want
    # viewport-aware behavior call `set_platform(:web_narrow)` from
    # their JS bridge after viewport detection.
    @@platform : Symbol = begin
      {% if flag?(:macos) %}
        :macos
      {% elsif flag?(:ipados) %}
        :ipados
      {% elsif flag?(:ios) %}
        :ios
      {% elsif flag?(:android) %}
        :android
      {% else %}
        :web_wide
      {% end %}
    end

    # Returns the current platform identity. The same symbol used by
    # `UI::Intent::Registry` lookups and by `PlatformFeatureBinding`
    # platform maps.
    def self.platform : Symbol
      @@platform
    end

    # Override the platform at runtime. Used by web hosts detecting a
    # narrow viewport client-side, and by tests exercising multiple
    # platform branches. Production native apps do NOT call this — the
    # compile-time flag is authoritative.
    def self.set_platform(platform : Symbol) : Nil
      @@platform = platform
      nil
    end

    # SPEC-ONLY — restore the compile-time default platform.
    def self.reset_platform_for_spec : Nil
      @@platform = {% if flag?(:macos) %}
                     :macos
                   {% elsif flag?(:ipados) %}
                     :ipados
                   {% elsif flag?(:ios) %}
                     :ios
                   {% elsif flag?(:android) %}
                     :android
                   {% else %}
                     :web_wide
                   {% end %}
      nil
    end

    # Returns `true` when a Class C `PlatformFeatureBinding` exists for
    # `intent_id` on the current platform AND the binding's
    # `api_capability_check` returns `true`. Use to feature-detect
    # before rendering UI that calls `UI::Intent.dispatch`.
    def self.feature_supported?(intent_id : Symbol) : Bool
      UI::Intent::ClassCRegistry.supports?(intent_id, @@platform)
    end

  end

  # Animation helper namespace. Phase 10B.2c ships only
  # `duration_with_environment` — the canonical reactivity hook.
  # Future motion helpers (e.g. spring stiffness, parallax depth)
  # land here as they're needed.
  module Animation
    # Given a `UI::Environment` and a base duration in milliseconds,
    # returns the duration the view should actually use:
    #
    #   * `env.reduce_motion == true`  → `0` (animation skipped)
    #   * `env.reduce_motion == false` → `base_ms` (unchanged)
    #
    # The contract is intentionally absolute: when reduce_motion is on,
    # the animation runs in 0 ms so the visual end-state is achieved
    # without intermediate motion. Widgets that prefer a softened
    # ("80 %") rather than killed animation should make that policy
    # decision themselves; this helper is the floor.
    def self.duration_with_environment(env : UI::Environment, base_ms : Int32 | Float64) : Float64
      return 0.0 if env.reduce_motion
      base_ms.to_f64
    end

    # Convenience for seconds-valued widgets (Snackbar auto-dismiss
    # carries duration in seconds, not ms). Same contract: 0.0 when
    # reduce_motion is on, otherwise base_s.
    def self.duration_seconds_with_environment(env : UI::Environment, base_s : Float64) : Float64
      return 0.0 if env.reduce_motion
      base_s
    end
  end
end
