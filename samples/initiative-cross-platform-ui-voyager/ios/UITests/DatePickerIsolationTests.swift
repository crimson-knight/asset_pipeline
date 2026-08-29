import XCTest

/// DatePickerIsolationTests — isolate the DatePicker crash. The component gallery is
/// a pushed, scrolling screen (NOT a Sheet). If tapping its DatePicker crashes, the
/// UI::DatePicker facade is broken on iOS in general; if it survives, the crash is
/// specific to hosting a DatePicker inside a presented UI::Sheet.
final class DatePickerIsolationTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testGalleryDatePickerOnPushedScreen() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-component-gallery",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
            "VOYAGER_RESET_PREFS": "1",
        ]
        app.launch()

        XCTAssertTrue(app.otherElements["voyager-component-gallery-root"].waitForExistence(timeout: 10)
            || app.staticTexts["DatePicker"].waitForExistence(timeout: 5),
            "Component gallery didn't mount.")

        // Scroll until the DatePicker is on screen.
        let dp = app.datePickers["voyager-gallery-datepicker"]
        var tries = 0
        while !dp.exists && tries < 12 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(dp.waitForExistence(timeout: 4), "Gallery DatePicker not found after scrolling.")

        // Interact with it. If the DatePicker facade is broken on iOS, this crashes
        // even on a pushed screen (no Sheet).
        dp.tap()

        // App must still be alive (not springboard).
        XCTAssertTrue(app.datePickers["voyager-gallery-datepicker"].waitForExistence(timeout: 5)
            || app.otherElements["voyager-component-gallery-root"].waitForExistence(timeout: 3)
            || app.staticTexts["DatePicker"].waitForExistence(timeout: 3),
            "App became unresponsive after tapping the gallery DatePicker — the DatePicker facade crashes on iOS even on a pushed screen.")
    }
}
