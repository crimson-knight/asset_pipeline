# spec/ui_interaction/support/simulator_harness.cr
#
# Crystal-driven iOS simulator harness for interaction-contract specs.
#
# Architecture (see docs/initiative-cross-platform-ui/architecture/interaction-contracts-harness.md):
#
#   1. Boot the named simulator UDID (or first booted simulator if no UDID).
#   2. Install the demo app from its built .app bundle.
#   3. Launch with APIC_ENABLED=1 (via SIMCTL_CHILD_APIC_ENABLED=1).
#   4. Start a background `xcrun simctl spawn ... log stream` filtered
#      for `[APIC:` markers; accumulate into an in-memory buffer.
#   5. Yield a `Simulator` driver to the spec block.
#   6. On block exit, terminate the app and stop the log stream.
#
# Tap delivery: scenarios are defined as YAML files under
# `spec/ui_interaction/scenarios/<screen>.yml`. Each file maps a stable
# accessibility_id to an (x, y) screen coordinate captured against a
# specific simulator device + screen pose. The harness reads the map at
# launch and provides `tap_accessibility_id(id)` as a thin wrapper over
# `xcrun simctl io <udid> touch tap <x> <y>`. When a scenario does not
# define the requested id, the spec example fails with a clear message
# pointing at the scenario file to update.
#
# This harness deliberately does NOT use XCUITest. The trade-offs are
# documented at the harness doc above.

require "spec"
require "yaml"
require "json"

module UI
  module InteractionContracts
    module Spec
      # Default device/runtime — overridable per spec via Harness.with(...).
      DEFAULT_DEVICE  = ENV.fetch("APIC_DEVICE", "iPhone 17 Pro")
      DEFAULT_RUNTIME = ENV.fetch("APIC_RUNTIME", "iOS 26.5")

      # Where the harness expects to find built app bundles. The build
      # phase (Phase 12.A acceptance) is responsible for placing them.
      DEFAULT_APP_BUNDLE_ROOT = ENV.fetch(
        "APIC_APP_BUNDLE_ROOT",
        File.join(__DIR__, "../../../tmp/interaction-contracts/bundles")
      )

      # Where scenario YAML files live.
      SCENARIO_ROOT = File.expand_path(File.join(__DIR__, "../scenarios"))

      # Where the harness writes per-spec evidence (video, marker log).
      EVIDENCE_ROOT = ENV.fetch(
        "APIC_EVIDENCE_ROOT",
        File.join(__DIR__, "../../../tmp/interaction-contracts/evidence")
      )

      # ---------------------------------------------------------------------
      # Public entry point
      # ---------------------------------------------------------------------

      module Harness
        # Boot + install + launch + yield + teardown.
        def self.with_voyager(route : String, & : Simulator -> _) : Nil
          with_app(
            bundle_id: "com.assetpipeline.voyager.VoyagerDemo",
            bundle_name: "VoyagerDemo.app",
            scenario: "voyager",
            launch_env: {"VOYAGER_ROOT_SLUG" => route},
          ) do |sim|
            yield sim
          end
        end

        # Demo apps queued behind Voyager (per demo-app-ladder.md). Each
        # follows the same shape; bundle ids land when the respective
        # Phase 13/14/.../17 brief authors the app.
        def self.with_notes(route : String, & : Simulator -> _) : Nil
          with_app(
            bundle_id: "com.assetpipeline.notes.NotesDemo",
            bundle_name: "NotesDemo.app",
            scenario: "notes",
            launch_env: {"NOTES_ROOT_SLUG" => route},
          ) do |sim|
            yield sim
          end
        end

        def self.with_app(
          bundle_id : String,
          bundle_name : String,
          scenario : String,
          launch_env : Hash(String, String),
          & : Simulator -> _
        ) : Nil
          Dir.mkdir_p(EVIDENCE_ROOT)
          udid = ensure_simulator_booted
          install_app(udid, bundle_name)
          scenario_map = load_scenario(scenario)

          sim = Simulator.new(udid, bundle_id, scenario_map)
          sim.start_log_stream

          launch_with_env = launch_env.merge({"APIC_ENABLED" => "1"})
          sim.launch(launch_with_env)

          begin
            yield sim
          ensure
            sim.terminate
            sim.stop_log_stream
          end
        end

        # ---- Internal helpers --------------------------------------------

        def self.ensure_simulator_booted : String
          # Look for a booted simulator with the right device + runtime.
          listing = `xcrun simctl list --json devices booted 2>/dev/null`
          if listing.empty?
            raise "simctl listing failed"
          end
          parsed = JSON.parse(listing)
          device_lists = parsed["devices"].as_h

          device_lists.each do |runtime_key, device_array|
            runtime_match = runtime_key.includes?(DEFAULT_RUNTIME.gsub(" ", "-").gsub(".", "-"))
            next unless runtime_match
            device_array.as_a.each do |device|
              name = device["name"].as_s
              if name == DEFAULT_DEVICE
                udid = device["udid"].as_s
                return udid
              end
            end
          end

          raise "No booted simulator matching #{DEFAULT_DEVICE} / #{DEFAULT_RUNTIME}. " \
                "Run `xcrun simctl boot <udid>` first or set APIC_DEVICE / APIC_RUNTIME."
        end

        def self.install_app(udid : String, bundle_name : String) : Nil
          bundle_path = File.join(DEFAULT_APP_BUNDLE_ROOT, bundle_name)
          unless Dir.exists?(bundle_path)
            raise "App bundle not found at #{bundle_path}. " \
                  "Build the demo app first or set APIC_APP_BUNDLE_ROOT."
          end
          status = Process.run("xcrun", ["simctl", "install", udid, bundle_path],
            output: STDOUT, error: STDERR)
          raise "simctl install failed for #{bundle_name}" unless status.success?
        end

        def self.load_scenario(scenario_name : String) : Hash(String, Tuple(Int32, Int32))
          path = File.join(SCENARIO_ROOT, "#{scenario_name}.yml")
          unless File.exists?(path)
            return {} of String => Tuple(Int32, Int32)
          end

          parsed = YAML.parse(File.read(path))
          map = {} of String => Tuple(Int32, Int32)
          taps = parsed["taps"]?
          if taps
            taps.as_a.each do |entry|
              id = entry["id"].as_s
              x = entry["x"].as_i
              y = entry["y"].as_i
              map[id] = {x, y}
            end
          end
          map
        end
      end

      # ---------------------------------------------------------------------
      # Simulator driver
      # ---------------------------------------------------------------------

      class Simulator
        getter udid : String
        getter bundle_id : String
        getter scenario_map : Hash(String, Tuple(Int32, Int32))
        getter markers : Array(String)

        @log_process : Process? = nil
        @log_io : IO::FileDescriptor? = nil
        @markers_mutex : Mutex
        @log_pump_fiber : Fiber? = nil

        def initialize(@udid, @bundle_id, @scenario_map)
          @markers = [] of String
          @markers_mutex = Mutex.new
        end

        def start_log_stream : Nil
          # Stream the simulator's unified log filtered for APIC markers.
          process = Process.new(
            command: "xcrun",
            args: [
              "simctl", "spawn", @udid, "log", "stream",
              "--predicate", "eventMessage CONTAINS \"[APIC:\"",
              "--style", "compact",
            ],
            output: Process::Redirect::Pipe,
            error: Process::Redirect::Pipe,
          )
          @log_process = process
          @log_io = process.output

          @log_pump_fiber = spawn do
            io = process.output
            begin
              io.each_line do |line|
                next unless line.includes?("[APIC:")
                @markers_mutex.synchronize { @markers << line }
              end
            rescue
              # Process terminated; stop pumping.
            end
          end
        end

        def stop_log_stream : Nil
          if process = @log_process
            begin
              process.terminate
            rescue
              # already gone
            end
            @log_process = nil
          end
        end

        def launch(env : Hash(String, String)) : Nil
          # simctl passes SIMCTL_CHILD_* env vars through to the launched
          # app, stripping the prefix.
          args = ["simctl", "launch", @udid, @bundle_id]
          child_env = {} of String => String?
          env.each do |k, v|
            child_env["SIMCTL_CHILD_#{k}"] = v
          end
          status = Process.run("xcrun", args, env: child_env,
            output: STDOUT, error: STDERR)
          raise "simctl launch failed for #{@bundle_id}" unless status.success?
        end

        def terminate : Nil
          Process.run("xcrun", ["simctl", "terminate", @udid, @bundle_id],
            output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
        end

        # -------------------------------------------------------------------
        # Tap delivery
        # -------------------------------------------------------------------

        def tap_at_point(x : Int32, y : Int32) : Nil
          Process.run("xcrun",
            ["simctl", "io", @udid, "touch", "tap", "#{x},#{y}"],
            output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
        end

        def tap_accessibility_id(id : String) : Nil
          coord = @scenario_map[id]?
          if coord.nil?
            raise "No coordinate mapped for accessibility_id '#{id}' in scenario " \
                  "(add to #{SCENARIO_ROOT}/<scenario>.yml taps:)"
          end
          x, y = coord
          tap_at_point(x, y)
        end

        # -------------------------------------------------------------------
        # Marker assertions
        # -------------------------------------------------------------------

        # Snapshot the marker buffer.
        def snapshot_markers : Array(String)
          @markers_mutex.synchronize { @markers.dup }
        end

        # Wait until a marker matching the token substring appears, up to
        # `timeout`. Returns the matching line on success; raises on timeout.
        def wait_for_marker(token : String, timeout : Time::Span = 2.seconds) : String
          deadline = Time.instant + timeout
          loop do
            if marker = snapshot_markers.find { |m| m.includes?(token) }
              return marker
            end
            if Time.instant >= deadline
              raise "Timed out waiting for marker '#{token}' " \
                    "(buffer size=#{snapshot_markers.size})"
            end
            sleep 50.milliseconds
          end
        end

        # Assert no marker matching the token appears within `window`.
        def assert_no_marker(token : String, window : Time::Span = 500.milliseconds) : Nil
          start = Time.instant
          while Time.instant - start < window
            if marker = snapshot_markers.find { |m| m.includes?(token) }
              raise "Expected no marker matching '#{token}' but saw: #{marker}"
            end
            sleep 50.milliseconds
          end
        end

        # Assert marker A appeared in the buffer before marker B.
        def assert_marker_order(first_token : String, second_token : String) : Nil
          snap = snapshot_markers
          first_idx = snap.index { |m| m.includes?(first_token) }
          second_idx = snap.index { |m| m.includes?(second_token) }
          raise "Marker '#{first_token}' not found" if first_idx.nil?
          raise "Marker '#{second_token}' not found" if second_idx.nil?
          unless first_idx < second_idx
            raise "Expected '#{first_token}' to appear before '#{second_token}' " \
                  "(actual order: #{second_token} at #{second_idx}, " \
                  "#{first_token} at #{first_idx})"
          end
        end

        # Clear the marker buffer. Useful between scenarios within one
        # spec example.
        def clear_markers : Nil
          @markers_mutex.synchronize { @markers.clear }
        end
      end
    end
  end
end

# Auto-skip when simctl is unavailable (non-mac CI runners, etc.).
unless Process.run("which", ["xcrun"], output: Process::Redirect::Inherit,
         error: Process::Redirect::Inherit).success?
  STDERR.puts "[APIC HARNESS] xcrun not available — interaction-contract specs skipped"
  exit 0
end
