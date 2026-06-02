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

    /// Proves the Happy Coach foundation: saving with the reminder ON schedules a
    /// REAL recurring local notification through UI::Notifications, and saving with
    /// it OFF cancels it. The status line is set by CheckInController#save_checkin
    /// from the system's actual pending queue (UI::Notifications.has_pending? /
    /// pending_count) — so asserting it reads "scheduled" proves the request truly
    /// landed in UNUserNotificationCenter, not that a flag flipped. (Functional
    /// outcome per the interactive-view Definition of Done.)
    func testSaveSchedulesAndCancelsRealReminder() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-check-in",
            // Suppress the first-launch permission dialog. Scheduling/pending
            // tracking is auth-independent (auth gates delivery), so the
            // pending-queue assertion still proves the real outcome.
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()

        // Reminder defaults ON. Save → schedules the recurring notification.
        let save = app.buttons["voyager-check-in-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Save button missing — screen didn't mount.")
        save.tap()

        let status = app.staticTexts["voyager-check-in-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 6),
            "No status line after Save — save_checkin did not run or set state.checkin_status.")
        XCTAssertTrue(status.label.contains("scheduled"),
            "Status was \"\(status.label)\" — the notification did not land in the system pending queue (has_pending? was false).")

        // Toggle reminder OFF, then Save → cancels the notification.
        app.switches["voyager-check-in-reminder"].tap()
        save.tap()

        let offStatus = app.staticTexts["voyager-check-in-status"]
        XCTAssertTrue(offStatus.waitForExistence(timeout: 6), "Status line vanished after cancel-save.")
        XCTAssertTrue(offStatus.label.contains("off"),
            "Status was \"\(offStatus.label)\" — expected the reminder-off confirmation after cancelling.")
    }
}
