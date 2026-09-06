import SwiftUI
import UIKit
import Darwin

/// Parameters supplied only by the physical-device evidence runner. A normal
/// benchmark UI-test may provide frames without a nonce, in which case it
/// retains the accessibility-report surface but does not write a file.
struct NativeReconcileBenchmarkLaunch {
    let frames: Int
    let commitMode: String
    let launchNonce: String?
    let runID: String?
}

/// Benchmark-only launch surface. Set VOYAGER_NATIVE_RECONCILE_BENCH_FRAMES to
/// a positive integer when launching the app. It runs on the main UIKit thread
/// and exposes the report for XCUITest/device-harness collection; normal app
/// launches never instantiate this view.
struct NativeReconcileBenchmarkView: View {
    let launch: NativeReconcileBenchmarkLaunch
    @State private var report = #"{"success":false,"error":"benchmark has not run"}"#

    var body: some View {
        Text(report)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .padding()
            .accessibilityIdentifier("voyager-native-reconcile-benchmark-result")
            .onAppear {
                let thermalBefore = NativeReconcileEvidence.thermalState()
                let lowPowerBefore = ProcessInfo.processInfo.isLowPowerModeEnabled
                let raw = VoyagerBridge.nativeReconcileBenchmark(frames: launch.frames, commitMode: launch.commitMode)
                let thermalAfter = NativeReconcileEvidence.thermalState()
                let lowPowerAfter = ProcessInfo.processInfo.isLowPowerModeEnabled

                let envelope = NativeReconcileEvidence.envelope(
                    rawBenchmarkJSON: raw,
                    launch: launch,
                    thermalBefore: thermalBefore,
                    thermalAfter: thermalAfter,
                    lowPowerBefore: lowPowerBefore,
                    lowPowerAfter: lowPowerAfter
                )
                report = NativeReconcileEvidence.encode(envelope)

                // A nonce makes the app-container file specific to exactly
                // one process launch. The host copies this file back and
                // rejects it if the nonce or contract differs, so stale data
                // can never be relabelled as a fresh device trial.
                if let nonce = launch.launchNonce {
                    do {
                        try NativeReconcileEvidence.writeAtomically(envelope, nonce: nonce)
                        // A trial is process-fresh only when this exact app
                        // launch finishes after atomically writing its result.
                        DispatchQueue.main.async { exit(EXIT_SUCCESS) }
                    } catch {
                        report = #"{"success":false,"error":"could not write native reconcile evidence: \#(error.localizedDescription)"}"#
                    NSLog("[VOYAGER_NATIVE_RECONCILE_BENCH] %@", report)
                    return
                }
                }
                NSLog("[VOYAGER_NATIVE_RECONCILE_BENCH] %@", report)
            }
    }
}

/// Reporting is deliberately outside the timed Crystal build/diff/commit
/// operation. It exists solely to make physical-device evidence durable and
/// fail-closed when console capture detaches during app termination.
enum NativeReconcileEvidence {
    static let contract = "asset-pipeline-native-reconcile-device-v1"

    static func envelope(
        rawBenchmarkJSON: String,
        launch: NativeReconcileBenchmarkLaunch,
        thermalBefore: String,
        thermalAfter: String,
        lowPowerBefore: Bool,
        lowPowerAfter: Bool
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "schema": 1,
            // `contract` belongs to the Crystal workload and is merged below;
            // keep the app-container evidence schema separately identifiable.
            "evidence_contract": contract,
            "launch_nonce": launch.launchNonce ?? NSNull(),
            "run_id": launch.runID ?? NSNull(),
            "platform": "ios-device",
            "frames_requested": launch.frames,
            "device_model": hardwareModel(),
            "os_version": UIDevice.current.systemVersion,
            "thermal_state_before": thermalBefore,
            "thermal_state_after": thermalAfter,
            "low_power_mode_before": lowPowerBefore,
            "low_power_mode_after": lowPowerAfter,
            "bundle_id": Bundle.main.bundleIdentifier ?? "unknown",
        ]

        guard let rawData = rawBenchmarkJSON.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any] else {
            payload["success"] = false
            payload["error"] = "Crystal bridge emitted invalid benchmark JSON"
            return payload
        }
        payload.merge(raw) { _, new in new }
        return payload
    }

    static func writeAtomically(_ payload: [String: Any], nonce: String) throws {
        guard nonce.range(of: "^[A-Za-z0-9_-]{16,128}$", options: .regularExpression) != nil else {
            throw EvidenceError.invalidNonce
        }
        let documents = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let directory = documents.appendingPathComponent("native-reconcile-results", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try data.write(to: directory.appendingPathComponent("\(nonce).json"), options: .atomic)
    }

    static func thermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    static func encode(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let value = String(data: data, encoding: .utf8) else {
            return #"{"success":false,"error":"could not encode benchmark evidence"}"#
        }
        return value
    }

    private static func hardwareModel() -> String {
        var system = utsname()
        uname(&system)
        return withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    private enum EvidenceError: LocalizedError {
        case invalidNonce
        var errorDescription: String? { "launch nonce is invalid" }
    }
}
