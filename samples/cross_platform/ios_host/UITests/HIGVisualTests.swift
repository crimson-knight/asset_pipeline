import XCTest

// HIG visual-validation XCUITest.
//
// Phase 6.5 D4 refactor: delegates host launch to HostLaunchPattern and
// the standard screen-capture path to VisualSnapshotPattern. The
// slug-specific full-screen-vs-window capture branch is preserved because
// it encodes per-slug HIG knowledge (action-sheets / activity-views need
// the full screen viewport to include the home-indicator region).
//
// The wrapper script (scripts/run_ios_hig_tests.sh) invokes this test
// once per slug per appearance via TEST_RUNNER_* env vars.

final class HIGVisualTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRenderSlug() throws {
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
            waitForRoot: false,
        )

        // Wait for either accessibility root attachment.
        let crystalRoot = app.otherElements["hig-component-root"]
        let hostRoot    = app.otherElements["hig-component-root-host"]
        let anyRoot     = crystalRoot.waitForExistence(timeout: 10)
                       || hostRoot.waitForExistence(timeout: 2)

        // 1.2s settle for UIVisualEffectView materials to composite
        // against the backdrop; see Phase 0 fix comments in git history.
        Thread.sleep(forTimeInterval: 1.2)

        // Slug-specific capture strategy. Presentation-style components
        // need full-screen so the home-indicator region is included; all
        // others use window.screenshot() to drop SpringBoard chrome.
        let window = app.windows.firstMatch
        let useFullScreen = (slug == "action-sheets" || slug == "activity-views")
        let screenshot = useFullScreen
            ? XCUIScreen.main.screenshot()
            : (window.exists ? window.screenshot() : XCUIScreen.main.screenshot())
        let att = XCTAttachment(screenshot: screenshot)
        att.name = "\(slug)-ios-\(appearance).png"
        att.lifetime = .keepAlways
        add(att)

        if !anyRoot {
            XCTFail("No accessibility root (hig-component-root or -host) for \(slug)")
        }
    }
}
