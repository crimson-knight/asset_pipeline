import XCTest

/// CheckInTests — proves the Daily Check-in controls are FUNCTIONAL, not decorative
/// (per the interactive-view Definition of Done: drive the real control + assert the
/// functional outcome). Flips the reminder Toggle and asserts the screen's live summary
/// readout updates — i.e. the on_change reached CheckInController, mutated Voyager.state,
/// and the Rerender rebuilt the screen from the new state.
final class CheckInTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testToggleReminderUpdatesSummary() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-check-in",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()

        // The reminder defaults ON — the summary reads "Reminder on".
        let onSummary = app.staticTexts["Mood 7/10 · Goal 5/day · Reminder on"]
        XCTAssertTrue(onSummary.waitForExistence(timeout: 10),
            "Check-in summary (reminder on) not found — screen didn't mount.")

        // Flip the reminder Toggle (a UISwitch).
        let toggle = app.switches["voyager-check-in-reminder"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 4), "Reminder toggle missing.")
        toggle.tap()

        // Functional outcome: the live summary readout flips to "Reminder off".
        let offSummary = app.staticTexts["Mood 7/10 · Goal 5/day · Reminder off"]
        XCTAssertTrue(offSummary.waitForExistence(timeout: 6),
            "Summary did not update to 'Reminder off' after toggling — the control's value never reached state / the screen did not rebuild.")
    }
}
