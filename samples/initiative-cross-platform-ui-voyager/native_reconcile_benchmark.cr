# A deliberately small, production-path benchmark for the Voyager native
# renderers. It mounts the real ReconcileProbe widget tree once, then measures
# the three phases of each stable-tree update independently:
#
#   1. build   — a new UI::View tree from the current state
#   2. diff    — Voyager's positional native reconciliation walk
#   3. commit  — actual SwiftKit/AppKit/UIKit label-state writes
#
# It is intentionally collector-neutral: callers compile this with the normal
# open-source runtime (Boehm today), and it neither selects nor refers to a
# premium collector. The tree and reconciliation algorithm are the same ones
# used by the Voyager application; no JSON transport is involved. It does NOT
# attach the root to a window or time Auto Layout/display compositing, so it is
# a production native-property-commit benchmark, not a full screen-render FPS
# benchmark.

require "./host_bootstrap"
require "./native_reconcile_collector"

{% if flag?(:ios) %}
  require "../../src/ui/renderers/uikit_renderer"
{% elsif flag?(:macos) %}
  require "../../src/ui/renderers/appkit_renderer"
{% end %}

module Voyager
  module NativeReconcileBenchmark
    record Result,
      frames : Int32,
      build_ns_total : Int64,
      diff_ns_total : Int64,
      commit_ns_total : Int64,
      reconcile_ops_total : Int32,
      structural_label_visits_total : Int32,
      dynamic_label_updates_total : Int32,
      commit_mode : String,
      checksum : UInt64,
      success : Bool,
      error : String?

    # Fixed input shape: the actual ReconcileProbe screen has one stable title
    # and one stateful echo label. Both modes walk both labels; only the dirty
    # mode skips the stable title's native-property write.
    EXPECTED_STRUCTURAL_LABEL_VISITS_PER_FRAME = 2
    EXPECTED_DYNAMIC_LABEL_UPDATES_PER_FRAME = 1

    def self.run(frames : Int32, mode : NativeReconcileCollector::CommitMode = NativeReconcileCollector::CommitMode::DirtyLabelCommit) : Result
      return failure(frames, "frames must be positive", mode) if frames <= 0

      # Initialise counters before any native setup so the rescue path always
      # has a complete, typed partial result.
      build_ns_total = 0_i64
      diff_ns_total = 0_i64
      commit_ns_total = 0_i64
      reconcile_ops_total = 0
      structural_label_visits_total = 0
      dynamic_label_updates_total = 0
      checksum = 1469598103934665603_u64

      bootstrap = HostBootstrap.build(:reconcile_probe, platform: platform)
      renderer = new_renderer

      # The first render is setup, not part of the update timing lane.
      ReconcileProbeState.text = "frame-0"
      initial_view = build_view(bootstrap.dispatcher)
      mounted = renderer.render(initial_view)
      session = NativeReconcileCollector::Session.new
      session.replace!(initial_view)

      begin
        frames.times do |index|
          frame = index + 1
          ReconcileProbeState.text = "frame-#{frame}"

          build_started = Time.instant
          fresh = build_view(bootstrap.dispatcher)
          build_ns_total += elapsed_ns(build_started)

          ops = [] of Tuple(Void*, String)
          diff_started = Time.instant
          structural_label_visits = session.collect(fresh, mounted, ops, mode)
          if structural_label_visits.nil?
            return failure(
              frames, "reconcile structure/state mismatch at frame #{frame}", mode,
              build_ns_total, diff_ns_total + elapsed_ns(diff_started), commit_ns_total,
              reconcile_ops_total, structural_label_visits_total, dynamic_label_updates_total, checksum,
            )
          end
          diff_ns_total += elapsed_ns(diff_started)

          commit_started = Time.instant
          ops.each do |state, text|
            LibSwiftKitBridge.apsk_label_set_text(state, text.to_unsafe)
          end
          commit_ns_total += elapsed_ns(commit_started)
          session.commit!(fresh)

          expected_ops = expected_label_ops_per_frame(mode)
          unless ops.size == expected_ops
            return failure(
              frames, "expected #{expected_ops} label ops, got #{ops.size} at frame #{frame}", mode,
              build_ns_total, diff_ns_total, commit_ns_total,
              reconcile_ops_total, structural_label_visits_total, dynamic_label_updates_total, checksum,
            )
          end

          reconcile_ops_total += ops.size
          structural_label_visits_total += structural_label_visits
          dynamic_label_updates_total += EXPECTED_DYNAMIC_LABEL_UPDATES_PER_FRAME
          checksum = mix(checksum, frame.to_u64)
          # Keep the checksum mode-independent: both modes must see the exact
          # same logical updates and structural walk. Operation count is a
          # measured result, not part of the workload identity.
          checksum = mix(checksum, structural_label_visits.to_u64)
          checksum = mix(checksum, ReconcileProbeState.text.bytesize.to_u64)
        end
      ensure
        # Native handles have explicit ownership independent of collector
        # timing. Releasing here keeps trial-to-trial native lifetime bounded.
        mounted.teardown!
      end

      Result.new(
        frames, build_ns_total, diff_ns_total, commit_ns_total,
        reconcile_ops_total, structural_label_visits_total, dynamic_label_updates_total,
        mode_name(mode), checksum, true, nil,
      )
    rescue ex
      failure(
        frames, "#{ex.class}: #{ex.message}", mode,
        build_ns_total || 0_i64, diff_ns_total || 0_i64, commit_ns_total || 0_i64,
        reconcile_ops_total || 0, structural_label_visits_total || 0,
        dynamic_label_updates_total || 0, checksum || 0_u64,
      )
    end

    # Compact JSON avoids bringing a serialization workload into a benchmark
    # that is specifically intended to be free of JSON bridge work.
    def self.json(result : Result) : String
      String.build do |io|
        io << "{\"contract\":\"asset-pipeline-native-reconcile-v1\""
        io << ",\"measurement_scope\":\"widget-build,reconcile-walk,native-property-commit\""
        io << ",\"mount_attached\":false"
        io << ",\"layout_or_compositing_measured\":false"
        # The benchmark deliberately does not choose a collector. The external
        # harness must record the compiler/runtime provenance it supplied.
        io << ",\"collector_configuration\":\"caller-recorded\""
        io << ",\"frames\":" << result.frames
        io << ",\"build_ns_total\":" << result.build_ns_total
        io << ",\"diff_ns_total\":" << result.diff_ns_total
        io << ",\"commit_ns_total\":" << result.commit_ns_total
        io << ",\"commit_mode\":\"" << result.commit_mode << '"'
        io << ",\"reconcile_ops_total\":" << result.reconcile_ops_total
        io << ",\"structural_label_visits_total\":" << result.structural_label_visits_total
        io << ",\"dynamic_label_updates_total\":" << result.dynamic_label_updates_total
        io << ",\"checksum\":" << result.checksum
        io << ",\"success\":" << result.success
        if error = result.error
          io << ",\"error\":\"" << escape_json(error) << '"'
        end
        io << '}'
      end
    end

    private def self.platform : Symbol
      {% if flag?(:ios) %}
        :ios
      {% elsif flag?(:macos) %}
        :macos
      {% else %}
        raise "NativeReconcileBenchmark requires -Dios or -Dmacos"
      {% end %}
    end

    private def self.new_renderer
      {% if flag?(:ios) %}
        UI::UIKit::Renderer.new
      {% elsif flag?(:macos) %}
        UI::AppKit::Renderer.new
      {% else %}
        raise "NativeReconcileBenchmark requires -Dios or -Dmacos"
      {% end %}
    end

    private def self.build_view(dispatcher : UI::ActionDispatcher) : UI::View
      reg = VoyagerApp.registration_for(:reconcile_probe)
      screen_class = reg.screen_class.not_nil!
      context = UI::ScreenContext::Native.new(
        form_state: dispatcher.current_form_state,
        session: dispatcher.session,
        flash: dispatcher.flash,
        design_tokens: dispatcher.design_tokens,
        navigation: dispatcher.navigation,
        action_params: {} of String => String,
        platform: dispatcher.platform,
        environment: dispatcher.environment,
      )
      screen_class.new.build(context)
    end

    def self.mode_from(value : String?) : NativeReconcileCollector::CommitMode?
      case value
      when "all-label-commit"   then NativeReconcileCollector::CommitMode::AllLabelCommit
      when "dirty-label-commit" then NativeReconcileCollector::CommitMode::DirtyLabelCommit
      else                            nil
      end
    end

    # Keep invalid caller input in the normal evidence schema so device runners
    # can fail a trial without inferring anything from a bridge crash.
    def self.failure_for_invalid_mode(frames : Int32, mode_value : String?) : Result
      failure(frames, "unsupported commit mode: #{mode_value || "(missing)"}", NativeReconcileCollector::CommitMode::DirtyLabelCommit)
    end

    private def self.mode_name(mode : NativeReconcileCollector::CommitMode) : String
      mode.all_label_commit? ? "all-label-commit" : "dirty-label-commit"
    end

    private def self.expected_label_ops_per_frame(mode : NativeReconcileCollector::CommitMode) : Int32
      mode.all_label_commit? ? EXPECTED_STRUCTURAL_LABEL_VISITS_PER_FRAME : EXPECTED_DYNAMIC_LABEL_UPDATES_PER_FRAME
    end

    private def self.elapsed_ns(started : Time::Instant) : Int64
      (Time.instant - started).total_nanoseconds.to_i64
    end

    private def self.mix(hash : UInt64, value : UInt64) : UInt64
      (hash ^ value) &* 1099511628211_u64
    end

    private def self.failure(
      frames : Int32, error : String, mode : NativeReconcileCollector::CommitMode,
      build_ns_total : Int64 = 0_i64, diff_ns_total : Int64 = 0_i64, commit_ns_total : Int64 = 0_i64,
      reconcile_ops_total : Int32 = 0, structural_label_visits_total : Int32 = 0,
      dynamic_label_updates_total : Int32 = 0,
      checksum : UInt64 = 0_u64,
    ) : Result
      Result.new(
        frames, build_ns_total, diff_ns_total, commit_ns_total,
        reconcile_ops_total, structural_label_visits_total, dynamic_label_updates_total,
        mode_name(mode), checksum, false, error,
      )
    end

    private def self.escape_json(value : String) : String
      value.gsub('\\', "\\\\").gsub('"', "\\\"").gsub('\n', "\\n")
    end
  end
end
