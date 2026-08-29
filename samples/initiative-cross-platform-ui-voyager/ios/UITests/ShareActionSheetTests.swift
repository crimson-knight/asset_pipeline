import XCTest

/// ShareActionSheetTests — the user's literal complaint, automated.
///
/// "When I click on something and an action sheet opens, it shouldn't
/// instantly close."
///
/// The share action sheet is a DIFFERENT presentation path than the
/// editor Sheet covered by V1ContractTests: it is a
/// `UI::ActionSheetWithWebFallback` (Tier 3, maps to the SwiftKit
/// ConfirmationDialog reactive bridge on iOS), presented when the user
/// swipes a todo row and taps the "Share" trailing-swipe tile.
///
/// Flow under test (matches todos_screen.cr):
///   1. Launch on todos (notif prompt skipped).
///   2. Swipe the first row left to reveal [Delete, Done, Share, Edit].
///   3. Tap "Share" → dispatch(:request_share) → pending_share_todo_id
///      set → Rerender → ActionSheet wired with is_presented=true.
///   4. The action sheet (title "Share ...", actions Copy / Print /
///      Cancel) MUST appear AND stay presented with no user input.
///   5. Tapping Cancel MUST dismiss it cleanly (it must be interactive,
///      not a one-frame flash).
final class ShareActionSheetTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchTodos() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VoyagerRoot", "voyager-todos"]
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-todos",
            "APIC_ENABLED": "1",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()
        return app
    }

    /// Reveal the trailing swipe actions on the first row and tap Share.
    /// Returns once the tap has been synthesized.
    private func swipeFirstRowAndTapShare(_ app: XCUIApplication) {
        let firstRow = app.staticTexts["Buy groceries"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10),
            "'Buy groceries' row not found — seeded-state or AX regression.")

        // A fast `swipeLeft()` is flaky on a SwiftUI List row: at high
        // velocity it triggers the FULL-swipe (firing the destructive
        // Delete) instead of revealing the trailing action tiles. Use a
        // slow press-and-drag across ~80% of the row width so the row only
        // REVEALS its [Delete, Done, Share, Edit] tiles. Retry once if the
        // Share tile doesn't surface.
        func revealTrailingActions() {
            let start = firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            let end = firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5))
            start.press(forDuration: 0.25, thenDragTo: end)
        }
        revealTrailingActions()
        var shareTile = app.buttons["Share"]
        if !shareTile.waitForExistence(timeout: 2) {
            revealTrailingActions()
            shareTile = app.buttons["Share"]
        }
        XCTAssertTrue(shareTile.waitForExistence(timeout: 3),
            "'Share' trailing-swipe tile did not appear after revealing the " +
            "first row's actions. Either swipe-action exposure regressed or " +
            "the gesture full-swiped (check for a Delete alert instead).")
        shareTile.tap()
    }

    /// THE user's complaint: the action sheet must not instantly close.
    func testShareActionSheetStaysPresented() throws {
        let app = launchTodos()
        swipeFirstRowAndTapShare(app)

        // The action sheet exposes its actions as buttons. "Copy to
        // Clipboard" is unique to the share sheet, so finding it proves
        // the sheet presented.
        let copyAction = app.buttons["Copy to Clipboard"]
        let sheetByLabel = app.otherElements["Share options"]
        let presented =
            copyAction.waitForExistence(timeout: 4)
            || sheetByLabel.waitForExistence(timeout: 1)
        XCTAssertTrue(presented,
            "Share action sheet did not appear within 4s of tapping Share. " +
            "Either :request_share did not fire, OR the sheet appeared and " +
            "auto-dismissed before the poll window (the V1 auto-dismiss bug " +
            "applied to the ConfirmationDialog path).")

        // THE CONTRACT: 2 seconds, no interaction. The sheet must persist.
        Thread.sleep(forTimeInterval: 2.0)

        let stillThere =
            app.buttons["Copy to Clipboard"].exists
            || app.otherElements["Share options"].exists
        XCTAssertTrue(stillThere,
            "V1 (action sheet): the share action sheet auto-dismissed " +
            "within 2s of opening with no user interaction. This is the " +
            "exact 'tap Share, it instantly closes' bug.")
    }

    /// Launch with the share sheet already presented (capture scenario),
    /// avoiding the flaky swipe gesture. Same runtime path — the screen
    /// renders the UI::Sheet with is_presented=true — so the Cancel button
    /// and its dispatch are exactly what the real flow produces.
    private func launchTodosWithShareOpen() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-todos",
            "VOYAGER_CAPTURE_SCENARIO": "polish-02-share-actionsheet",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()
        return app
    }

    /// The sheet must be INTERACTIVE — tapping Cancel dismisses it
    /// cleanly (proving it isn't just a frozen one-frame flash).
    ///
    /// KNOWN OPEN ISSUE (skipped): the iOS ConfirmationDialog/ActionSheet
    /// presents as a regular-size-class popover anchored to its embedded
    /// host view, and SwiftUI suppresses the cancel-role button in that
    /// presentation — so there is no "Cancel" button to tap. Tracked
    /// separately; fix is a trait-override on a dialog-specific host or a
    /// native UIAlertController. Re-enable this test when the action sheet
    /// renders as a proper bottom sheet with Cancel.
    func testShareActionSheetCancelDismisses() throws {
        let app = launchTodosWithShareOpen()

        let copyAction = app.buttons["Copy to Clipboard"]
        XCTAssertTrue(copyAction.waitForExistence(timeout: 6),
            "Share sheet did not present (capture scenario).")

        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 2),
            "Cancel button not found in the share sheet — the sheet must " +
            "render an explicit, tappable Cancel.")
        cancel.tap()

        // After Cancel, the sheet's actions must be gone (Cancel fired its
        // callback → :cancel_pending → state cleared → Rerender → sheet
        // unmounted).
        let gone = !app.buttons["Copy to Clipboard"].waitForExistence(timeout: 3)
        XCTAssertTrue(gone,
            "Share sheet did not dismiss after tapping Cancel — the Cancel " +
            "button is present but its callback did not fire / dismiss.")
    }
}
