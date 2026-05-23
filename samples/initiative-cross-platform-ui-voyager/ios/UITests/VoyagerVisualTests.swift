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

        // Step 1: sign-in screen. Wait for the Crystal-rendered host
        // to appear in the AX tree — SwiftUI's UIViewRepresentable
        // doesn't surface its hosted UIView children until the first
        // full layout pass completes (~2-3s on the iPhone 17 sim).
        let host = app.otherElements["voyager-root-host"]
        XCTAssertTrue(host.waitForExistence(timeout: 10),
            "voyager-root-host not found after launch")
        Thread.sleep(forTimeInterval: 1.5)
        attachScreenshot(name: "step1-sign-in")

        // Step 2: tap Sign in — Crystal wires the tap to coord.push(:todos).
        // The Crystal-rendered Button surfaces an XCUI button element via
        // SwiftUI's .accessibilityLabel("Sign in"). If the query times
        // out we fall back to the test_id identifier path.
        var signIn = app.buttons["Sign in"]
        if !signIn.waitForExistence(timeout: 5) {
            signIn = app.buttons["voyager-sign-in-submit"]
        }
        XCTAssertTrue(signIn.waitForExistence(timeout: 5),
            "Sign in button not found on launch")
        signIn.tap()
        Thread.sleep(forTimeInterval: 1.5)
        attachScreenshot(name: "step2-todos")

        // Step 3: navigate to Settings via the settings link.
        var settingsBtn = app.buttons["Settings"]
        if !settingsBtn.waitForExistence(timeout: 5) {
            settingsBtn = app.buttons["voyager-todos-settings"]
        }
        XCTAssertTrue(settingsBtn.waitForExistence(timeout: 5),
            "Settings button not found on Todos screen — navigation may have failed")
        settingsBtn.tap()
        Thread.sleep(forTimeInterval: 1.5)
        attachScreenshot(name: "step3-settings")

        // Step 4: back to Todos.
        var back = app.buttons["Back to todos"]
        if !back.waitForExistence(timeout: 5) {
            back = app.buttons["voyager-settings-back"]
        }
        XCTAssertTrue(back.waitForExistence(timeout: 5),
            "Back to todos button not found on Settings screen")
        back.tap()
        Thread.sleep(forTimeInterval: 1.5)
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
