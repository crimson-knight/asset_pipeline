// FontDiagnostics — say it out loud when a named face did not load.
//
// The failure this exists for is silent by construction. `UIFont(name:size:)`
// returns nil, `Font.custom(_:size:)` resolves to the system face, and a build
// that asked for a bundled brand face draws San Francisco with every property,
// every spec and every static check still reporting the name it asked for. It
// is the project's named failure class — a false green over an artifact nobody
// looked at — and the cure is one line on the console beside the frame.
//
// ONCE PER FAMILY. A missing face is a build-level fact, not a per-label one,
// and a label that re-renders on every state change would otherwise print the
// same line hundreds of times and train everybody to scroll past it.

import Foundation
import os

@objc(APSKFontDiagnostics)
public class APSKFontDiagnostics: NSObject {
    private static let lock = NSLock()
    private static var reported = Set<String>()

    @objc public static func reportMissingFamily(_ family: String) {
        lock.lock()
        let isNew = reported.insert(family).inserted
        lock.unlock()
        guard isNew else { return }
        // Two channels on purpose: `os_log` is what a device console shows and
        // `print` is what an `xcodebuild test` transcript and a simulator run
        // capture, and the evidence harness reads the second one.
        os_log("[AssetPipeline] font family '%{public}@' is NOT registered — drawing the system face at the requested weight instead", family)
        print("[AssetPipeline] font family '\(family)' is NOT registered — drawing the system face at the requested weight instead")
    }

    // Everything reported so far, for a test that wants to assert the channel
    // fires rather than assert on a log scrape.
    @objc public static func missingFamilies() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(reported).sorted()
    }
}
