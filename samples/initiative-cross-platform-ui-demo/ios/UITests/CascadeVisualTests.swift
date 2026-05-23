import XCTest

/// CascadeVisualTests — Phase 6 iOS visual capture harness.
///
/// One parameterized test method `testRenderDemoSlug` reads the slug
/// from the `DEMO_SLUG` env var (set by the audit harness or the
/// capture script). The test:
///   1. Launches the CascadeDemo app with -DemoSlug <slug>.
///   2. Waits for `cascade-root-<slug>` to appear.
///   3. Takes an XCTAttachment screenshot (kept always).
///
/// Pattern mirrors samples/cross_platform/ios_host/UITests/HIGVisualTests.swift.
final class CascadeVisualTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRenderDemoSlug() throws {
        let env = ProcessInfo.processInfo.environment
        let slug = env["DEMO_SLUG"] ?? "demo-sign-in"
        let appearance = env["DEMO_APPEARANCE"] ?? env["HIG_APPEARANCE"] ?? "light"

        let app = XCUIApplication()
        app.launchArguments = ["-DemoSlug", slug]
        app.launchEnvironment = [
            "DEMO_SLUG": slug,
            "DEMO_APPEARANCE": appearance,
        ]
        app.launch()

        // Wait for the cascade root identifier — the bridge sets it on the
        // produced UIView, which becomes the SwiftUI-hosted view's
        // accessibilityIdentifier.
        let rootId = "cascade-root-\(slug)"
        let predicate = NSPredicate(format: "exists == true")
        let root = app.descendants(matching: .any).matching(identifier: rootId).firstMatch
        let exp = expectation(for: predicate, evaluatedWith: root, handler: nil)
        wait(for: [exp], timeout: 15.0)

        // Capture a screenshot attachment so the audit harness can
        // pull it via xcresultparser (see scripts/capture_demo_quad.cr).
        let snapshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: snapshot)
        attachment.name = "\(slug)-\(appearance)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
