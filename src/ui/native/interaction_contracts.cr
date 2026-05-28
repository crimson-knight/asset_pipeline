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
# Output goes to STDERR. iOS simulator's unified log captures STDERR for
# apps launched via `xcrun simctl launch`; macOS captures it too. The
# harness reads via `xcrun simctl spawn <udid> log stream --predicate
# 'eventMessage CONTAINS "[APIC:"'` on iOS and via direct STDERR capture
# on macOS.
#
# Swift facades have a mirror at
# `swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/InteractionContracts.swift`
# that uses NSLog for the same marker convention. Both Crystal and Swift
# emitters write into the same log stream so the harness sees a unified
# view of contract events regardless of which layer emitted them.

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

    # Emit a marker. No-op when APIC_ENABLED is unset.
    #
    # Args:
    #   widget — the cataloged widget name (e.g. "ConfirmationDialog")
    #   event  — the lifecycle event (e.g. "present", "dismiss-token-fire",
    #            "platform-dismissed", "action-handler-fire", "binding-read")
    #   **kv   — additional structured fields; emitted as `key=value`
    #            space-separated
    def self.emit(widget : String, event : String, **kv) : Nil
      return unless enabled?
      String.build do |io|
        io << "[APIC:" << widget << ":" << event << "]"
        kv.each do |k, v|
          io << ' ' << k << '=' << v
        end
      end.tap do |line|
        STDERR.puts(line)
        STDERR.flush
      end
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
      String.build do |io|
        io << "[APIC:" << widget << ":" << event << "]"
        merged.each do |k, v|
          io << ' ' << k << '=' << v
        end
      end.tap do |line|
        STDERR.puts(line)
        STDERR.flush
      end
    end

    # Test-only: reset the cached enabled flag so specs that toggle ENV
    # can observe the change.
    def self.reset_cache! : Nil
      @@enabled = nil
    end
  end
end
