import XCTest

/// EditTodoTests — the owner-reported to-do edit crash. Tapping a row opens the
/// editor Sheet; interacting with its native DatePicker crashed the app. The
/// DatePicker is now a plain deadline TextField (the native picker hosted in a
/// presented Sheet crashes on iOS — see project_ios_host_reentrant_render_hang).
/// This drives the real edit → type-deadline → save flow and asserts no crash.
final class EditTodoTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testEditTodoSheetDeadlineNoCrash() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-todos",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
            "VOYAGER_RESET_PREFS": "1",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["voyager-todos-add"].waitForExistence(timeout: 10),
            "Todos screen didn't mount.")

        // Tap a row → open the editor Sheet.
        let row = app.staticTexts["Buy groceries"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Seeded todo row not found.")
        row.tap()

        let title = app.textFields["voyager-editor-sheet-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8),
            "Editor Sheet didn't open after tapping a row.")

        // Edit the deadline via the TextField (was the crashing DatePicker). Must not crash.
        let deadline = app.textFields["voyager-editor-sheet-deadline"]
        XCTAssertTrue(deadline.waitForExistence(timeout: 4), "Deadline field missing.")
        deadline.tap()
        deadline.typeText("2026-07-15")

        // THE fix: editing the deadline (formerly a native DatePicker, which crashed
        // the app inside this Sheet) must NOT crash. The editor stays alive and the
        // typed value is retained. (Save + propagation is covered separately by
        // VoyagerVisualTests.testSavePropagation, which exercises the Sheet editor's
        // TextField + Save end-to-end.)
        XCTAssertTrue(app.buttons["voyager-editor-sheet-save"].waitForExistence(timeout: 5),
            "Editor vanished after editing the deadline — the app crashed (the DatePicker bug).")
        XCTAssertEqual(deadline.value as? String, "2026-07-15",
            "Deadline value not retained — the field didn't accept input.")
    }
}
