// InteractionContracts.swift — Swift mirror of
// src/ui/native/interaction_contracts.cr.
//
// Emits the same [APIC:<Widget>:<event>] marker format the Crystal
// emitter does, but uses NSLog so SwiftUI / UIKit facade events land in
// the unified log alongside Crystal's STDERR output.
//
// The harness reads both via `xcrun simctl spawn <udid> log stream
// --predicate 'eventMessage CONTAINS "[APIC:"'` and so sees a unified
// log of contract events regardless of which side emitted them.
//
// Marker convention (matches Crystal):
//
//   [APIC:<Widget>:<event>] key1=value1 key2=value2 ...
//
// Markers are only emitted when ENV["APIC_ENABLED"] == "1" / "true".

import Foundation

@objc(APSKInteractionContracts)
public final class InteractionContracts: NSObject {
    private static var cachedEnabled: Bool? = nil

    /// Whether marker emission is currently enabled. Cached after first
    /// env lookup; the harness sets APIC_ENABLED at launch and does not
    /// toggle it mid-run.
    @objc public static var enabled: Bool {
        if let cached = cachedEnabled { return cached }
        let env = ProcessInfo.processInfo.environment["APIC_ENABLED"]
        let value = (env == "1" || env == "true")
        cachedEnabled = value
        return value
    }

    /// Emit a marker. No-op when APIC_ENABLED is unset.
    ///
    /// - Parameters:
    ///   - widget: cataloged widget name (e.g. "ConfirmationDialog")
    ///   - event:  lifecycle event (e.g. "present", "dismiss-token-fire")
    ///   - viewID: optional accessibility_identifier of the emitting view;
    ///             logged as `view=<id>` for harness correlation
    ///   - kv:     additional structured fields, logged as `key=value`
    @objc public static func emit(
        widget: String,
        event: String,
        viewID: String? = nil,
        kv: [String: String] = [:]
    ) {
        guard enabled else { return }
        var line = "[APIC:\(widget):\(event)]"
        if let viewID = viewID {
            line += " view=\(viewID)"
        }
        for (k, v) in kv.sorted(by: { $0.key < $1.key }) {
            line += " \(k)=\(v)"
        }
        NSLog("%@", line)
    }

    /// Test-only: reset the cached enabled flag so unit tests that
    /// toggle env vars can observe the change.
    @objc public static func resetCache() {
        cachedEnabled = nil
    }
}
