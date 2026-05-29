import XCTest

/// GalleryInteractionTests — proves the Component Gallery widgets actually
/// FUNCTION on-device, not merely render.
///
/// The gallery's "Live Interaction" section wires a Button, Toggle,
/// SegmentedControl, and Stepper through the controller (dispatch →
/// mutate GalleryState → Rerender). Each test performs a REAL interaction
/// and asserts the live readout label changed — which can only happen if
/// the widget's callback fired, the dispatch routed, the controller ran,
/// and the screen re-rendered with the new state.
final class GalleryInteractionTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchGallery() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VoyagerRoot", "voyager-component-gallery"]
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-component-gallery",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["voyager-gallery-title"].waitForExistence(timeout: 10),
            "Gallery did not mount.")
        return app
    }

    /// Tapping the wired Button must increment the live "Taps:" readout.
    func testTapButtonIncrementsCounter() throws {
        let app = launchGallery()

        XCTAssertTrue(app.staticTexts["Taps: 0"].waitForExistence(timeout: 3),
            "Initial 'Taps: 0' readout not found.")

        let btn = app.buttons["voyager-gallery-live-tap-button"]
        XCTAssertTrue(btn.waitForExistence(timeout: 3), "Live tap button not found.")
        btn.tap()

        XCTAssertTrue(app.staticTexts["Taps: 1"].waitForExistence(timeout: 4),
            "Tapping the button did NOT update the readout to 'Taps: 1'. The " +
            "Button callback did not fire, or dispatch/Rerender is broken — " +
            "the widget renders but does not function.")

        btn.tap()
        XCTAssertTrue(app.staticTexts["Taps: 2"].waitForExistence(timeout: 4),
            "Second tap did not advance the counter to 'Taps: 2'.")
    }

    /// Flipping the wired Toggle must update the "Toggle:" readout.
    func testToggleUpdatesReadout() throws {
        let app = launchGallery()

        XCTAssertTrue(app.staticTexts["Toggle: OFF"].waitForExistence(timeout: 3),
            "Initial 'Toggle: OFF' readout not found.")

        let toggle = app.switches["voyager-gallery-live-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3), "Live toggle not found.")
        toggle.tap()

        XCTAssertTrue(app.staticTexts["Toggle: ON"].waitForExistence(timeout: 4),
            "Flipping the toggle did NOT update the readout to 'Toggle: ON'. " +
            "The Toggle on_change callback did not fire end-to-end.")
    }

    /// Selecting a segment must update the "Mode:" readout.
    func testSegmentedControlUpdatesMode() throws {
        let app = launchGallery()

        XCTAssertTrue(app.staticTexts["Mode: Day"].waitForExistence(timeout: 3),
            "Initial 'Mode: Day' readout not found.")

        // "Month" is unique to the live segmented control (the showcase one
        // uses List/Grid/Columns).
        let month = app.buttons["Month"]
        XCTAssertTrue(month.waitForExistence(timeout: 3), "'Month' segment not found.")
        month.tap()

        XCTAssertTrue(app.staticTexts["Mode: Month"].waitForExistence(timeout: 4),
            "Selecting 'Month' did NOT update the readout to 'Mode: Month'. " +
            "The SegmentedControl on_change callback did not fire end-to-end.")
    }
}
