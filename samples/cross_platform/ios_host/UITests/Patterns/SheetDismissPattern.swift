// Phase 6.5 D4 — Sheet present/dismiss pattern.
//
// Extracts the BX8 sheet-dismiss machinery: open via trigger, wait for
// content to enter AX tree, dismiss via primary / cancel / swipe paths,
// capture the dismiss reason via a mirror Label.

import XCTest

enum SheetDismissPattern {
    /// Open the sheet (tap trigger; wait for primaryId to enter the AX tree).
    /// Returns the primary button element.
    static func openSheet(app: XCUIApplication, triggerId: String, primaryId: String) -> XCUIElement {
        let trigger = app.buttons[triggerId]
        trigger.tap()
        let primary = app.buttons[primaryId]
        XCTAssertTrue(primary.waitForExistence(timeout: 5),
                      "SheetDismissPattern: \(primaryId) must appear after \(triggerId) tap")
        return primary
    }

    /// Wait for primaryId to leave the AX tree (sheet dismissed).
    static func waitSheetClosed(app: XCUIApplication, primaryId: String) {
        let pred = NSPredicate(format: "exists == false")
        let exp = XCTNSPredicateExpectation(predicate: pred,
                                             object: app.buttons[primaryId])
        let result = XCTWaiter().wait(for: [exp], timeout: 5)
        XCTAssertEqual(result, .completed,
                       "SheetDismissPattern: sheet must dismiss within 5s")
    }

    /// Perform a swipe-down to dismiss the topmost sheet surface (.sheet).
    /// Falls back to the `sheet-content` otherElement if app.sheets is empty.
    static func swipeDismiss(app: XCUIApplication, sheetContentId: String = "sheet-content") {
        let sheetSurface: XCUIElement = {
            let s = app.sheets.firstMatch
            return s.exists ? s : app.otherElements[sheetContentId]
        }()
        if sheetSurface.exists {
            let start = sheetSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
            let end = sheetSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
                .withOffset(CGVector(dx: 0, dy: 400))
            start.press(forDuration: 0.05, thenDragTo: end)
        } else {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.0))
                .withOffset(CGVector(dx: 0, dy: 200))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }
}
