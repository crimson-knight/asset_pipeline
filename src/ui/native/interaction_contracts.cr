# UI::InteractionContracts — emits unique-grep-token markers that the
# interaction-contracts harness asserts against.
#
# Convention (see docs/initiative-cross-platform-ui/architecture/interaction-contracts-harness.md):
#
#   [APIC:<Widget>:<event>] key1=value1 key2=value2 ...
#
# Markers are only emitted when ENV["APIC_ENABLED"] == "1". The harness
# sets SIMCTL_CHILD_APIC_ENABLED=1 when launching the simulator app, which
# propagates to ENV inside the app process.
#
# Output goes through NSLog via the `apsk_apic_log` C bridge on Apple
# targets (so markers reliably land in the simulator's unified log
# captured by `xcrun simctl spawn ... log stream`). On non-Apple targets
# the emitter falls back to STDERR.
#
# Swift facades have a mirror at
# `swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/InteractionContracts.swift`
# that uses NSLog directly. Both emit through the same Foundation log
# stream so the harness sees a unified view of contract events.
#
# Codex Phase 12.A review CONCERN 6 fix — STDERR is not reliably captured
# on iOS sim; NSLog is.

module UI
  module InteractionContracts
    # Internally cached after first ENV lookup — env var stability over a
    # process lifetime is assumed (the harness sets it at launch).
    @@enabled : Bool? = nil

    def self.enabled? : Bool
      enabled = @@enabled
      return enabled unless enabled.nil?
      env = ENV["APIC_ENABLED"]?
      @@enabled = (env == "1" || env == "true")
      @@enabled.not_nil!
    end

    # Write the marker line via NSLog (Apple) or STDERR (other targets).
    private def self.write_line(line : String) : Nil
      {% if flag?(:macos) || flag?(:ios) %}
        LibSwiftKitBridge.apsk_apic_log(line.to_unsafe)
      {% else %}
        STDERR.puts(line)
        STDERR.flush
      {% end %}
    end

    # Emit a marker. No-op when APIC_ENABLED is unset.
    #
    # Args:
    #   widget — the cataloged widget name (e.g. "ConfirmationDialog")
    #   event  — the lifecycle event (e.g. "present", "binding-write-false",
    #            "platform-dismissed", "action-handler-fire", "tap")
    #   **kv   — additional structured fields; emitted as `key=value`
    #            space-separated
    def self.emit(widget : String, event : String, **kv) : Nil
      return unless enabled?
      line = String.build do |io|
        io << "[APIC:" << widget << ":" << event << "]"
        kv.each do |k, v|
          io << ' ' << k << '=' << v
        end
      end
      write_line(line)
    end

    # Convenience for marker pairs that need a stable identifier so the
    # harness can correlate emit sites across a runloop. Caller passes the
    # widget's accessibility_identifier (or any unique key); harness uses
    # the `view=` field to correlate.
    def self.emit_for(widget : String, event : String, view_id : String?, **kv) : Nil
      return unless enabled?
      merged = Hash(Symbol, String).new
      kv.each { |k, v| merged[k] = v.to_s }
      merged[:view] = (view_id || "anonymous")
      line = String.build do |io|
        io << "[APIC:" << widget << ":" << event << "]"
        merged.each do |k, v|
          io << ' ' << k << '=' << v
        end
      end
      write_line(line)
    end

    # Test-only: reset the cached enabled flag so specs that toggle ENV
    # can observe the change.
    def self.reset_cache! : Nil
      @@enabled = nil
    end
  end
end
