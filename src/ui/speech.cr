# UI::Speech — cross-platform text-to-speech (the agent SPEAKS).
#
# Wraps AVSpeechSynthesizer on Apple platforms (macOS / iOS / watchOS — all ship
# AVFoundation). The other half of "voice conversation with your agent": dictation
# INPUT is already free via the native TextField (which opens the system dictation/
# scribble controller on iOS/watchOS), and this is the OUTPUT — the agent reads its
# reply aloud, including on the wrist.
#
# Native bridge functions live in:
#   * macOS / iOS — src/ui/native/objc_bridge.m (AVFoundation already imported)
#   * watchOS     — src/ui/native/speech_bridge.m (a portable Foundation +
#                   AVFoundation TU; objc_bridge.m can't compile on watch)
# Both keep a single retained AVSpeechSynthesizer so utterances aren't cut off by
# deallocation, and (on iOS/watchOS) activate an AVAudioSession for playback.
module UI
  module Speech
    extend self

    {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
      lib LibSpeechBridge
        # Returns 1 if the utterance was accepted by the synthesizer, 0 if not
        # (blank text / no synth). Speech starts asynchronously — query
        # `speaking?` after a beat for the runtime truth (see notes on `speak`).
        fun ap_speech_speak(text : UInt8*, rate : Float64, pitch : Float64, volume : Float64, language : UInt8*) : Int32
        fun ap_speech_stop : Void
        fun ap_speech_is_speaking : Int32
      end
    {% end %}

    # Speak `text` aloud. Returns true if the utterance was ENQUEUED (text valid +
    # synthesizer available) — analogous to `Notifications.schedule` returning
    # "accepted". Because AVSpeechSynthesizer starts playback asynchronously,
    # `speaking?` (queried after a beat / from a delegate-driven runloop) is the
    # authoritative "it is actually talking" signal — that's what verification
    # asserts, never this enqueue bool alone (cf. the SecureField "reports success,
    # does nothing" lesson).
    #
    # `rate` maps to AVSpeechUtterance.rate (0.0–1.0; ~0.5 is natural),
    # `pitch` to pitchMultiplier (0.5–2.0), `volume` 0.0–1.0. `language` is a
    # BCP-47 tag (e.g. "en-US"); empty uses the system default voice.
    def speak(text : String, rate : Float64 = 0.5, pitch : Float64 = 1.0, volume : Float64 = 1.0, language : String = "") : Bool
      return false if text.strip.empty?
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        LibSpeechBridge.ap_speech_speak(text.to_unsafe, rate, pitch, volume, language.to_unsafe) == 1
      {% else %}
        false
      {% end %}
    end

    # Immediately stop any in-progress and queued speech. No-op on non-Apple targets.
    def stop : Nil
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        LibSpeechBridge.ap_speech_stop
      {% end %}
    end

    # True while the synthesizer is actively speaking — the authoritative runtime
    # signal that speech started. False on non-Apple targets.
    def speaking? : Bool
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        LibSpeechBridge.ap_speech_is_speaking == 1
      {% else %}
        false
      {% end %}
    end
  end
end
