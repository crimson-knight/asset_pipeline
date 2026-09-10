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
    end
  {% end %}

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
