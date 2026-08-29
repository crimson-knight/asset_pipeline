import XCTest

/// ReconcileTests — proves the in-place reconciler preserves keyboard
/// focus across a per-keystroke Rerender.
///
/// The Reconcile Probe screen has a controlled TextField whose on_change
/// dispatches a Rerender on EVERY keystroke. Before the reconciler, that
/// tore down + rebuilt the whole host (a fresh UITextField), losing first
/// responder after one character. With in-place reconciliation, the
/// mounted UITextField is NOT torn down (its native view is reused), so
/// focus survives, the full word lands, and the echo Label — updated in
/// place via apsk_label_set_text — reflects every keystroke.
final class ReconcileTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchProbe() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VoyagerRoot", "voyager-reconcile-probe"]
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-reconcile-probe",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()
        return app
    }

    func testReconcileProbeKeepsFocusAcrossPerKeystrokeRerender() throws {
        let app = launchProbe()

        let field = app.textFields["voyager-reconcile-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10),
            "Reconcile probe field did not mount.")
        field.tap()

        // Type one character at a time. Each keystroke triggers a Rerender;
        // the in-place reconcile must keep this SAME field as first
        // responder so the next keystroke lands. XCUITest's typeText THROWS
        // ("Neither element nor any descendant has keyboard focus") if the
        // field lost focus — so the loop completing without a failure is
        // itself the focus-retention proof. (Before the reconciler, the 2nd
        // character failed here because the .id() teardown rebuilt the
        // field and dropped first responder.)
        for ch in "charlie" {
            field.typeText(String(ch))
            usleep(250_000) // let dispatch -> Rerender -> reconcile settle
        }

        // The echo Label was updated IN PLACE on every keystroke.
        let echo = app.staticTexts["voyager-reconcile-echo"]
        XCTAssertTrue(echo.waitForExistence(timeout: 4), "Echo label missing.")
        let deadline = Date().addingTimeInterval(4)
        while echo.label != "Echo: charlie" && Date() < deadline {
            usleep(150_000)
        }
        XCTAssertEqual(echo.label, "Echo: charlie",
            "Echo label did not reflect the full typed word. The reconcile " +
            "either lost characters (focus loss) or did not update the " +
            "Label in place. Got '\(echo.label)'.")

        // Secondary signal: the keyboard is still up (the field kept focus
        // through every per-keystroke rerender).
        XCTAssertTrue(app.keyboards.firstMatch.exists,
            "Keyboard dismissed mid-typing — focus was not preserved.")
    }
}
