# Font availability — "did the face we asked for actually load?"
#
# WHY THIS EXISTS. A named font family in `UI::Font` is a PostScript name the
# host is expected to have registered. When it has not, nothing anywhere fails:
# `UIFont(name:size:)` returns nil, `resolve_font` falls back to the system
# face, SwiftUI's `.custom(name:size:)` quietly resolves to the system face, and
# the app draws in San Francisco while every property, every spec and every
# static check still says it asked for the brand face.
#
# That is a false green over an artifact nobody looked at, and the only cure is
# to be able to ASK. This is the question, answered by the platform rather than
# by our own record of what we intended.
module UI
  {% if flag?(:macos) || flag?(:ios) %}
    lib LibFontQuery
      fun nsstring_from_cstr(cstr : UInt8*) : Void*
      fun nsfont_named(name : Void*, size : Float64) : Void*
      fun ui_dynamic_type_scaled(points : Float64, cap : Float64) : Float64
    end
  {% end %}

  # ── THE CEILING ON DYNAMIC TYPE SCALING ──────────────────────────────────
  #
  # Accessibility sizes run to roughly 3.1x the default on iOS, and a
  # fixed-height chrome band (a tab bar, a disclosure ribbon) cannot absorb that
  # without the layout coming apart — which is a worse outcome for the same
  # reader. 1.6x is a little past `.xxLarge` and is where the shipped layouts
  # still hold. It is a cap on the SCALE, not on the size, so every role keeps
  # its ratio to every other one.
  #
  # ONE NUMBER, TWO LANGUAGES. `APSKDynamicType.maxScale` in the Swift facade
  # is this value and the two must not drift. The consumer that depends on
  # both — a build that publishes the size it drew beside a frame — asserts
  # they agree (happy_coach `spec/demo/component_schema_spec.cr`, "the Dynamic
  # Type ceiling is one number in two languages").
  DYNAMIC_TYPE_MAX_SCALE = 1.6

  # What POINT SIZE a role declared at `points` is actually drawn at, under the
  # reader's current text-size setting and this ceiling.
  #
  # WHY IT IS PUBLIC. The scaling happens inside the platform facade, so a
  # renderer, a log line or an evidence sidecar upstream of it cannot otherwise
  # state what was drawn — and a build that reports the size it ASKED for beside
  # a frame that drew another size is a false statement in the evidence channel.
  # Off-device (specs, the web renderer) there is no content-size category to
  # ask about and the honest answer is the size itself.
  def self.dynamic_type_scaled(points : Float64) : Float64
    return points unless points > 0.0
    {% if flag?(:macos) || flag?(:ios) %}
      LibFontQuery.ui_dynamic_type_scaled(points, DYNAMIC_TYPE_MAX_SCALE)
    {% else %}
      points
    {% end %}
  end

  # Is this family loadable right now?
  #
  # "system" and "monospace" are the two names that are always available by
  # definition — they name a platform face rather than a bundled file. Anything
  # else is asked of the platform. Off-device (specs, the web renderer) there is
  # no font machinery to ask, and the honest answer for a bundled PostScript
  # name there is "no": a spec must not be able to assert a face reached a
  # screen that has no screen.
  def self.font_family_available?(family : String) : Bool
    return true if family.empty? || family == "system" || family == "monospace"
    {% if flag?(:macos) || flag?(:ios) %}
      name = LibFontQuery.nsstring_from_cstr(family.to_unsafe)
      return false if name.null?
      !LibFontQuery.nsfont_named(name, 17.0).null?
    {% else %}
      false
    {% end %}
  end
end
