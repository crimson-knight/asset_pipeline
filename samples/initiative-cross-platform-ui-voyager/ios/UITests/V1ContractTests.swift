import XCTest

/// V1ContractTests — Phase 12.C V1 lifecycle contract test.
///
/// V1 = "When a user taps a todo row, the editor sheet opens then
/// immediately auto-dismisses, preventing interaction."
///
/// This test asserts the architectural contract: when a user action
/// presents a modal sheet, the sheet MUST remain presented until
/// either (a) the user explicitly dismisses it OR (b) controller code
/// explicitly closes it. The sheet MUST NOT auto-dismiss as a side
/// effect of the SwiftUI host's render pipeline.
///
/// Mechanism:
///   1. Launch Voyager on the todos screen.
///   2. Tap the first todo row by AX label ("Buy groceries").
///   3. Wait for the editor sheet to appear via its accessibility
///      identifier "voyager-todos-editor-sheet".
///   4. Sleep 2 seconds. The user has not interacted with the sheet.
///   5. Assert the editor sheet's AX node is STILL present.
///
/// Pass = green = the sheet persists across the 2-second window.
/// Fail = red = the sheet auto-dismissed (V1 bug).
///
/// XCUITest's tap-by-AX-id works for UITableViewCell row taps because
/// UIKit's UITableView.didSelectRowAt path doesn't suffer the Phase
/// 6.10 SwiftUI Button tap synthesis gap. Row taps drive the Crystal
/// dispatcher via the UI::ListView.on_row_tap callback bridge.
final class V1ContractTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// V1 — editor sheet stays presented after row tap (no auto-dismiss).
    func testEditorSheetSurvivesRowTap() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-VoyagerRoot", "voyager-todos"]
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-todos",
            "APIC_ENABLED": "1",
            // Skip the first-launch notification permission prompt that
            // otherwise modally blocks the row tap.
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()

        // 1. Wait for the todos screen to mount.
        let root = app.otherElements["voyager-root-voyager-todos"]
        XCTAssertTrue(root.waitForExistence(timeout: 10),
            "voyager-root-voyager-todos did not appear within 10s. " +
            "Cold-render failure — cannot proceed with V1 test.")

        attachScreenshot(name: "01-todos-screen-mounted")

        // 2. Find the first todo row. Voyager's seeded state ships
        //    "Buy groceries" as the first row, surfaced via the row's
        //    cell label.
        let firstRow = app.staticTexts["Buy groceries"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5),
            "'Buy groceries' row not found in AX tree. Seeded-state " +
            "regression or AX exposure changed.")

        // 3. Tap the row. This drives UI::ListView.on_row_tap →
        //    Voyager.dispatch(:edit_row) → state.pending_editor_todo_id = id
        //    → Rerender → UI::Sheet wired into the new tree.
        firstRow.tap()
        attachScreenshot(name: "02-after-row-tap")

        // 4. Wait for the editor sheet to appear. We poll for either
        //    the test_id ("voyager-todos-editor-sheet") OR the
        //    accessibility_label ("Edit todo"). Per Phase 12.C iter-3,
        //    both are propagated through the UIKit renderer.
        let editorByID = app.otherElements["voyager-todos-editor-sheet"]
        let editorByLabel = app.otherElements["Edit todo"]
        let editorFound =
            editorByID.waitForExistence(timeout: 3)
            || editorByLabel.waitForExistence(timeout: 1)
        XCTAssertTrue(editorFound,
            "Editor sheet did not appear within 4s after row tap. " +
            "Either the row tap did not fire :edit_row (regression in " +
            "UI::ListView.on_row_tap bridge), OR the sheet appeared and " +
            "auto-dismissed before our 4s poll window. Check APIC " +
            "markers for [APIC:Sheet:present] without a paired " +
            "[APIC:Sheet:host-mounted] or with an immediate " +
            "[APIC:Sheet:host-disappeared].")

        attachScreenshot(name: "03-editor-sheet-presented")

        // 5. THE CONTRACT: wait 2 seconds without touching anything.
        //    The user has not dismissed. The sheet MUST still be there.
        Thread.sleep(forTimeInterval: 2.0)

        attachScreenshot(name: "04-after-2s-no-interaction")

        let stillThere =
            app.otherElements["voyager-todos-editor-sheet"].exists
            || app.otherElements["Edit todo"].exists
        XCTAssertTrue(stillThere,
            "V1 BUG: editor sheet auto-dismissed within 2s of opening, " +
            "with no user interaction. This is the auto-dismiss " +
            "regression — likely the SwiftUI .sheet modifier is being " +
            "unmounted because the parent UIView (Crystal-rendered) is " +
            "discarded on every Rerender via ContentView.swift's " +
            ".id(\"\\(slug)#\\(renderVersion)\") bump. Phase 12.C's " +
            "cross-render reactive-presentation sweep flips bindings " +
            "AFTER SwiftUI has already begun dismissing — the sweep " +
            "addresses tree-removal cause but not the host-discard root " +
            "cause. See docs/initiative-cross-platform-ui/" +
            "architecture/presentation-lifecycle-contract.md for the " +
            "C1 invariant this violates.")
    }

    /// V1 — add-todo path. Tapping the "Add Todo" button at the bottom
    /// dispatches :new_todo, which sets pending_editor_todo_id = 0 and
    /// rerenders. Same architectural class as the row-tap path.
    func testEditorSheetSurvivesAddTodoTap() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-VoyagerRoot", "voyager-todos"]
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-todos",
            "APIC_ENABLED": "1",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()

        let root = app.otherElements["voyager-root-voyager-todos"]
        XCTAssertTrue(root.waitForExistence(timeout: 10),
            "Todos cold-render failed.")

        // Find Add Todo by AX label.
        let addBtn = app.buttons["Add a new todo"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5),
            "Add Todo button not found in AX tree.")

        addBtn.tap()

        let editorByID = app.otherElements["voyager-todos-editor-sheet"]
        let editorByLabel = app.otherElements["Edit todo"]
        let editorFound =
            editorByID.waitForExistence(timeout: 3)
            || editorByLabel.waitForExistence(timeout: 1)
        XCTAssertTrue(editorFound,
            "Editor sheet did not appear within 4s after Add Todo tap.")

        Thread.sleep(forTimeInterval: 2.0)

        let stillThere =
            app.otherElements["voyager-todos-editor-sheet"].exists
            || app.otherElements["Edit todo"].exists
        XCTAssertTrue(stillThere,
            "V1 BUG: editor sheet (Add Todo path) auto-dismissed " +
            "within 2s of opening with no user interaction.")
    }

    // MARK: - Helpers

    private func attachScreenshot(name: String) {
        let snapshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: snapshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
