import XCTest

/// DeadlineRenderTests — a todo WITH a deadline must render on iOS. The Todos
/// humanized-deadline subtitle used Time.local / Time.parse / Time#to_s, which crash
/// on the iOS class-init gap; any deadline-bearing row crashed the screen (hidden
/// because every seed had an empty deadline). After the integer-safe rewrite + a
/// seed that carries a deadline, the "Due …" subtitle must appear with no crash.
final class DeadlineRenderTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testTodoWithDeadlineRendersNoCrash() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-todos",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
            "VOYAGER_RESET_PREFS": "1",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["voyager-todos-add"].waitForExistence(timeout: 10),
            "Todos screen didn't mount (the deadline-bearing row may have crashed humanize_deadline).")
        XCTAssertTrue(app.staticTexts["Finish quarterly report"].waitForExistence(timeout: 5),
            "Deadline-bearing todo row missing.")
        // The humanized subtitle proves humanize_deadline ran on iOS without crashing.
        XCTAssertTrue(app.staticTexts["Due Dec 19, 2026"].waitForExistence(timeout: 5),
            "Humanized deadline subtitle 'Due Dec 19, 2026' not rendered — humanize_deadline failed on iOS.")
    }
}
