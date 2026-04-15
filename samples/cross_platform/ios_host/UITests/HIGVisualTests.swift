import XCTest

// HIG visual-validation XCUITest.
//
// Data source: the wrapper script (scripts/run_ios_hig_tests.sh) invokes this
// test once per slug per appearance, passing env vars via TEST_RUNNER_* prefix
// (xcodebuild strips the prefix before exposing them to the test process;
// the test process then re-exposes them to the app under test via
// app.launchEnvironment).
//
// Environment variables consumed:
//   HIG_SLUG            (test process)  -- which component slug to render
//   HIG_APPEARANCE      (test process)  -- "light" or "dark"
//   HIG_BACKDROP_PATH   (test process)  -- absolute path to a backdrop image
//                                          (optional; fallback = Amber gradient)
//
// The test forwards all three into app.launchEnvironment so the app process
// reads them from its own ProcessInfo.environment.
//
// Screenshot naming: "<slug>-ios-<appearance>.png" -- extracted from the
// xcresult bundle by the wrapper script.
//
// Phase 0.2 change: backdrop path forwarding + increased settling delay so
// UIVisualEffectView materials fully composite before the screenshot is taken.

final class HIGVisualTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRenderSlug() throws {
        let env = ProcessInfo.processInfo.environment
        let slug       = env["HIG_SLUG"]        ?? "buttons"
        let appearance = env["HIG_APPEARANCE"]  ?? "light"

        let app = XCUIApplication()
        app.launchArguments = ["-HIGSlug", slug]

        // Forward appearance and backdrop to the app-under-test.
        // The app reads these from its own ProcessInfo.environment in
        // HIGSceneDelegate and HIGBackdropController.
        app.launchEnvironment["HIG_APPEARANCE"]   = appearance
        if let backdropPath = env["HIG_BACKDROP_PATH"] {
            app.launchEnvironment["HIG_BACKDROP_PATH"] = backdropPath
        }

        app.launch()

        // Wait for the Crystal-rendered root or the SwiftUI host shell.
        // We always attach the screenshot so a visual artifact exists for
        // the VLM even if the accessibility-tree probe fails.
        let crystalRoot = app.otherElements["hig-component-root"]
        let hostRoot    = app.otherElements["hig-component-root-host"]
        let anyRoot     = crystalRoot.waitForExistence(timeout: 10)
                       || hostRoot.waitForExistence(timeout: 2)

        // Settling delay:
        //   - 0.8s was insufficient for UIVisualEffectView materials to
        //     fully composite against the backdrop in Phase 0 testing.
        //   - 1.2s gives UIKit one additional layout pass + CA transaction
        //     commit + the CoreImage blur kernel to stabilize.
        //   - UIVisualEffectView blur is driven by the render server
        //     (backboardd); it needs at least one off-screen compositing
        //     pass before XCUIScreen.main.screenshot() reads the framebuffer.
        Thread.sleep(forTimeInterval: 1.2)

        // Screenshot strategy:
        // - For most slugs: app.windows.firstMatch.screenshot() captures only
        //   the app window bounds, eliminating SpringBoard chrome (status bar
        //   and home indicator region). June fix #5.
        // - For action-sheets: the HIG places the Cancel capsule flush with
        //   the bottom safe-area inset. window.screenshot() crops the bottom
        //   of the sheet. Use XCUIScreen.main.screenshot() for this slug so
        //   the full iPhone viewport including the home-indicator region is
        //   captured and the Cancel capsule is fully visible.
        let window = app.windows.firstMatch
        // Use XCUIScreen.main.screenshot() for presentation-style components
        // (action-sheets, activity-views) that extend to the bottom safe-area
        // edge or below. window.screenshot() crops the bottom of the glass card
        // and the Cancel button region for these components. Full-screen capture
        // includes the home-indicator region and eliminates bottom crop.
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
