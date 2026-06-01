import XCTest

/// FilePickerTests — proves `UI::SystemAction.perform(:open_file_picker)` ACTUALLY
/// presents a `UIDocumentPickerViewController` on iOS, instead of silently
/// no-oping while reporting success.
///
/// THE BUG THIS GUARDS. The SystemAction path has no concrete anchor view, so
/// the iOS bridge used to early-return on a null anchor and present nothing —
/// yet `perform` returned `success`. The fix (objc_bridge.m
/// `ap_open_file_picker_ios`) resolves the key window's rootViewController as
/// the presenter and presents a real picker, and now resolves the presenter
/// SYNCHRONOUSLY so the int return honestly reflects whether a picker can be
/// shown (returning 0 → Crystal raises → not-performed, never fake success).
///
/// SURFACE. The Phase 10 Class C dispatch exerciser
/// (`screens/phase_10/class_c_dispatch_screen.cr`, slug
/// `voyager-phase-10-class-c-dispatch`): the "Open file picker" button (test_id
/// `phase-10-class-c-file-picker`) fires the intent.
final class FilePickerTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchClassC() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VoyagerRoot", "voyager-phase-10-class-c-dispatch"]
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-phase-10-class-c-dispatch",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()
        return app
    }

    func testOpenFilePickerPresentsDocumentPicker() throws {
        let app = launchClassC()

        let trigger = app.buttons["phase-10-class-c-file-picker"]
        XCTAssertTrue(trigger.waitForExistence(timeout: 12),
            "'Open file picker' trigger not found — screen/route regression.")
        XCTAssertTrue(trigger.isHittable, "Trigger not hittable before tap.")
        trigger.tap()

        // The document picker's chrome (a Cancel affordance) runs in the
        // presenting app's process; its appearance proves the picker actually
        // presented. Before the key-window-presenter fix the dispatch returned
        // success but presented nothing → no Cancel → this fails.
        let cancel = app.buttons["Cancel"]
        let cancelNav = app.navigationBars.buttons["Cancel"]
        let presented = cancel.waitForExistence(timeout: 8)
            || cancelNav.waitForExistence(timeout: 2)

        if !presented {
            // Diagnostic dump so a miss is debuggable without re-running the
            // slow iOS build (the picker may expose its chrome via a different
            // query on some iOS versions).
            print("FILEPICKER_DIAG element tree after tap:\n\(app.debugDescription)")
        }
        XCTAssertTrue(presented,
            "open_file_picker did not present a UIDocumentPickerViewController "
            + "(no Cancel chrome appeared). The picker silently no-oped.")

        // Leave no modal up.
        if cancel.exists {
            cancel.tap()
        } else if cancelNav.exists {
            cancelNav.tap()
        }
    }
}
