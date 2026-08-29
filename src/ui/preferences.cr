# UI::Preferences — cross-platform persistent key-value settings.
#
# Wraps NSUserDefaults on Apple platforms (macOS / iOS / watchOS — all in
# Foundation) so an app's settings survive relaunch. Every real app needs this;
# it's what makes the Voyager voice/check-in preferences "stick".
#
# Native bridge functions live in:
#   * macOS / iOS — src/ui/native/objc_bridge.m
#   * watchOS     — src/ui/native/prefs_bridge.m (a portable Foundation-only TU;
#                   objc_bridge.m can't compile on watch)
#
# On web / other targets the getters return the supplied default and setters are
# no-ops (no persistence sink wired) — honest, not a silent fake store.
#
# Keys are plain strings; namespace them per app (e.g. "voyager.speak_replies").
module UI
  module Preferences
    extend self

    {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
      lib LibPrefsBridge
        fun ap_prefs_set_bool(key : UInt8*, value : Int32) : Void
        # default_value is returned when the key is unset (distinguishes "absent"
        # from a stored false / 0.0).
        fun ap_prefs_get_bool(key : UInt8*, default_value : Int32) : Int32
        fun ap_prefs_set_double(key : UInt8*, value : Float64) : Void
        fun ap_prefs_get_double(key : UInt8*, default_value : Float64) : Float64
        fun ap_prefs_clear_all : Void
      end
    {% end %}

    # Remove ALL persisted keys for this app (clears the NSUserDefaults persistent
    # domain). Intended for test reset / "restore defaults" — used by the Voyager
    # hosts when VOYAGER_RESET_PREFS=1 so UI tests start from known defaults. No-op
    # on targets without a persistence sink.
    def clear_all : Nil
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        LibPrefsBridge.ap_prefs_clear_all
      {% end %}
      nil
    end

    # Persist a boolean under `key`.
    def set_bool(key : String, value : Bool) : Nil
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        LibPrefsBridge.ap_prefs_set_bool(key.to_unsafe, value ? 1 : 0)
      {% end %}
      nil
    end

    # Read a boolean; returns `default` when the key has never been set (or on a
    # target without a persistence sink).
    def bool?(key : String, default : Bool = false) : Bool
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        LibPrefsBridge.ap_prefs_get_bool(key.to_unsafe, default ? 1 : 0) == 1
      {% else %}
        default
      {% end %}
    end

    # Persist a float under `key`. (Store integers as Float64 and round on read.)
    def set_double(key : String, value : Float64) : Nil
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        LibPrefsBridge.ap_prefs_set_double(key.to_unsafe, value)
      {% end %}
      nil
    end

    # Read a float; returns `default` when the key has never been set.
    def double(key : String, default : Float64 = 0.0) : Float64
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        LibPrefsBridge.ap_prefs_get_double(key.to_unsafe, default)
      {% else %}
        default
      {% end %}
    end

    # Convenience: persist an Int (stored as Float64).
    def set_int(key : String, value : Int32) : Nil
      set_double(key, value.to_f)
    end

    # Convenience: read an Int (rounded from the stored Float64).
    def int(key : String, default : Int32 = 0) : Int32
      double(key, default.to_f).round.to_i
    end
  end
end
