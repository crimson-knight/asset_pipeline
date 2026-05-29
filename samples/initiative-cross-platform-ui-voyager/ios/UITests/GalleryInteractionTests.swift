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

    // Scroll the gallery until `el` is hittable (the showcase widgets are
    // below the fold).
    private func scrollToHittable(_ app: XCUIApplication, _ el: XCUIElement, max: Int = 10) {
        var n = 0
        while !el.isHittable && n < max {
            app.swipeUp()
            n += 1
        }
    }

    /// A showcase Button (below the fold) must update the shared readout —
    /// proves the wiring works for widgets beyond the live section.
    func testShowcaseButtonUpdatesReadout() throws {
        let app = launchGallery()
        let btn = app.buttons["voyager-gallery-button-secondary"]
        scrollToHittable(app, btn)
        XCTAssertTrue(btn.isHittable, "Secondary showcase button not reachable.")
        btn.tap()
        XCTAssertTrue(app.staticTexts["Last interaction: Secondary Button tapped"].waitForExistence(timeout: 4),
            "Tapping the showcase Secondary Button did not update the shared readout.")
    }

    /// A showcase Toggle must update the shared readout.
    func testShowcaseToggleUpdatesReadout() throws {
        let app = launchGallery()
        let toggle = app.switches["voyager-gallery-toggle"]
        scrollToHittable(app, toggle)
        XCTAssertTrue(toggle.isHittable, "Showcase toggle not reachable.")
        toggle.tap()
        // Starts on (is_on: true) → tapping turns it off.
        XCTAssertTrue(app.staticTexts["Last interaction: Toggle → off"].waitForExistence(timeout: 4),
            "Flipping the showcase Toggle did not update the shared readout.")
    }

    /// A TextField must accept typed input (native SwiftUI behavior, no
    /// dispatch needed) — the honest "it works" for text entry.
    func testTextFieldAcceptsInput() throws {
        let app = launchGallery()
        let field = app.textFields["voyager-gallery-textfield"]
        scrollToHittable(app, field)
        XCTAssertTrue(field.isHittable, "Text field not reachable.")
        field.tap()
        field.typeText("hello")
        XCTAssertEqual(field.value as? String, "hello",
            "TextField did not accept typed input.")
    }

    /// A Slider drag must update the shared readout (Float64 callback path).
    func testSliderUpdatesReadout() throws {
        let app = launchGallery()
        let slider = app.sliders["voyager-gallery-slider"]
        scrollToHittable(app, slider)
        XCTAssertTrue(slider.isHittable, "Slider not reachable.")
        slider.adjust(toNormalizedSliderPosition: 0.1)
        // Value is imprecise; assert the readout now reports a Slider event.
        let readout = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Last interaction: Slider")
        ).firstMatch
        XCTAssertTrue(readout.waitForExistence(timeout: 4),
            "Dragging the Slider did not update the readout (Float64 callback path).")
    }

    /// A Stepper increment must update the shared readout (Float64 path).
    func testStepperUpdatesReadout() throws {
        let app = launchGallery()
        let stepper = app.steppers["voyager-gallery-stepper"]
        scrollToHittable(app, stepper)
        XCTAssertTrue(stepper.isHittable, "Stepper not reachable.")
        // SwiftUI Stepper exposes Increment/Decrement child buttons.
        let inc = stepper.buttons["Increment"]
        if inc.exists { inc.tap() } else { stepper.buttons.element(boundBy: 1).tap() }
        let readout = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Last interaction: Stepper")
        ).firstMatch
        XCTAssertTrue(readout.waitForExistence(timeout: 4),
            "Incrementing the Stepper did not update the readout (Float64 path).")
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
