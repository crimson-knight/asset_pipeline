// Phase 6.5 D4 — Visual snapshot probe pattern.
//
// Wraps the HIGVisualTests one-slug capture flow. Tests opt into either
// full-screen XCUIScreen capture or element-scoped capture for tighter
// before/after deltas (BX5 runtime override).

import XCTest

enum VisualSnapshotPattern {
    /// Full screen XCUIScreen capture; attached with .keepAlways.
    static func snapshotScreen(testCase: XCTestCase, app: XCUIApplication, name: String) {
        testCase.attachScreenshot(app, name: name)
    }

    /// Element-scoped capture; attached with .keepAlways.
    static func snapshotElement(testCase: XCTestCase, element: XCUIElement, name: String) {
        testCase.attachElementScreenshot(element, name: name)
    }

    /// Run a HIGVisualTests-style capture loop. Reads HIG_SLUG +
    /// HIG_APPEARANCE from the test process environment, launches the
    /// host accordingly, and snapshots the screen.
    static func runWorklistCapture(testCase: XCTestCase) {
        let env = ProcessInfo.processInfo.environment
        let slug       = env["HIG_SLUG"]        ?? "buttons"
        let appearance = env["HIG_APPEARANCE"]  ?? "light"
        let backdrop   = env["HIG_BACKDROP_PATH"]

        var extraEnv: [String: String] = [:]
        if let bp = backdrop, !bp.isEmpty {
            extraEnv["HIG_BACKDROP_PATH"] = bp
        }

        let app = HostLaunchPattern.launchHost(
            slug: slug,
            appearance: appearance,
            extraEnv: extraEnv,
            waitForRoot: true,
        )

        // Settle: UIVisualEffectView materials need a beat to composite.
        Thread.sleep(forTimeInterval: 0.8)

        testCase.attachScreenshot(app, name: "\(slug)-ios-\(appearance).png")
    }
}
