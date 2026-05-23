import XCTest

/// VoyagerVisualTests — Phase 6.10 iOS visual capture harness.
///
/// Unlike Cascade (which captures one slug at a time), Voyager runs a
/// navigable scenario: sign-in -> todos -> settings -> back -> todos.
/// This test taps through the full state-propagation litmus and
/// captures a screenshot at each step.
///
/// Pattern mirrors
/// samples/initiative-cross-platform-ui-demo/ios/UITests/CascadeVisualTests.swift
/// for the launch + screenshot pieces; the navigation taps + assertions
/// are the new bits.
final class VoyagerVisualTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Snapshot one slug (used by the audit harness when capturing
    /// individual screen baselines).
    func testRenderInitialSlug() throws {
        let env = ProcessInfo.processInfo.environment
        let slug = env["VOYAGER_ROOT_SLUG"] ?? "voyager-sign-in"
        let appearance = env["VOYAGER_APPEARANCE"] ?? env["HIG_APPEARANCE"] ?? "light"

        let app = XCUIApplication()
        app.launchArguments = ["-VoyagerRoot", slug]
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": slug,
            "VOYAGER_APPEARANCE": appearance,
        ]
        app.launch()

        let crystalRoot = app.otherElements["voyager-root-\(slug)"]
        let hostRoot    = app.otherElements["voyager-root-host"]
        let foundRoot   = crystalRoot.waitForExistence(timeout: 10)
                       || hostRoot.waitForExistence(timeout: 2)
        if !foundRoot {
            XCTContext.runActivity(named: "root-not-found") { _ in }
        }

        Thread.sleep(forTimeInterval: 0.4)

        let snapshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: snapshot)
        attachment.name = "\(slug)-\(appearance)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Full navigation flow — the manual verification the owner asked
    /// for, automated as a smoke test. Launches at sign-in, taps
    /// through to Todos, then Settings, then back. Captures a
    /// screenshot at each step.
    func testNavigationFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-VoyagerRoot", "voyager-sign-in"]
        app.launch()

        // Step 1: sign-in screen
        Thread.sleep(forTimeInterval: 0.5)
        attachScreenshot(name: "step1-sign-in")

        // Step 2: tap Sign in — Crystal wires the tap to coord.push(:todos)
        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5), "Sign in button not found on launch")
        signIn.tap()
        Thread.sleep(forTimeInterval: 1.0)
        attachScreenshot(name: "step2-todos")

        // Step 3: navigate to Settings via the settings link
        let settingsBtn = app.buttons["Settings"]
        XCTAssertTrue(settingsBtn.waitForExistence(timeout: 5), "Settings button not found on Todos screen — navigation from sign-in may have failed")
        settingsBtn.tap()
        Thread.sleep(forTimeInterval: 1.0)
        attachScreenshot(name: "step3-settings")

        // Step 4: back to Todos
        let back = app.buttons["Back to todos"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Back to todos button not found on Settings screen")
        back.tap()
        Thread.sleep(forTimeInterval: 1.0)
        attachScreenshot(name: "step4-back-to-todos")
    }

    private func attachScreenshot(name: String) {
        let snapshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: snapshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
